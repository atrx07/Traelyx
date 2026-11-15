import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

class EventCorrectionRepository {
  EventCorrectionRepository(this.db, {int Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc().microsecondsSinceEpoch);
  final AppDatabase db;
  final int Function() _now;

  Future<Trip> _trip(String id) async {
    final trip = await (db.select(
      db.trips,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (trip == null ||
        !const {'completed', 'incomplete'}.contains(trip.completionState) ||
        trip.endWallTimeMicros == null ||
        trip.telemetrySchemaVersion != 1) {
      throw StateError('A finalized supported trip is required.');
    }
    return trip;
  }

  CorrectionTarget? _target(Trip trip, TripEvent row) {
    if (!correctionEventLabels.containsKey(row.eventType) ||
        row.algorithmVersion != '1' ||
        row.mlEvidenceJson != null) {
      return null;
    }
    return CorrectionTarget(
      snapshot: jsonEncode({
        'snapshotVersion': 1,
        'tripId': trip.id,
        'eventId': row.id,
        'telemetrySchemaVersion': trip.telemetrySchemaVersion,
        'eventType': row.eventType,
        'startNanos': row.startElapsedNanos,
        'peakNanos': row.peakElapsedNanos,
        'endNanos': row.endElapsedNanos,
        'severity': row.severity,
        'confidence': row.confidence,
        'severityCalibrationVersion': row.severityCalibrationVersion,
        'algorithmVersion': row.algorithmVersion,
        'createdAtMicros': row.createdAtMicros,
        'qualityFlagsJson': row.qualityFlagsJson,
        'primaryMeasurementsJson': row.primaryMeasurementsJson,
        'ruleEvidenceJson': row.ruleEvidenceJson,
        'mlEvidenceJson': row.mlEvidenceJson,
        'contextTagsJson': row.contextTagsJson,
      }),
    );
  }

  Future<CorrectionCatalog> load(String tripId) => db.transaction(() async {
    final trip = await _trip(tripId);
    final events =
        await (db.select(db.tripEvents)
              ..where(
                (row) =>
                    row.tripId.equals(tripId) &
                    row.eventType.isIn(correctionEventLabels.keys) &
                    row.algorithmVersion.equals('1') &
                    row.mlEvidenceJson.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.startElapsedNanos),
                (row) => OrderingTerm.asc(row.id),
              ])
              ..limit(128))
            .get();
    final notes = await _notes(tripId);
    final current = await _currentSnapshots(trip, notes);
    return CorrectionCatalog(
      targets: List.unmodifiable(
        events.map((row) => _target(trip, row)).whereType<CorrectionTarget>(),
      ),
      notes: List.unmodifiable(notes),
      staleCount: notes
          .where((note) => !current.contains(note.target.snapshot))
          .length,
    );
  });

  Future<List<CorrectionNote>> _notes(String tripId) async {
    final rows =
        await (db.select(db.tripEventCorrections)
              ..where((row) => row.tripId.equals(tripId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.eventId),
                (row) => OrderingTerm.asc(row.sourceSnapshotJson),
              ])
              ..limit(129))
            .get();
    if (rows.length > 128) {
      throw const FormatException('Stored correction limit exceeded.');
    }
    return rows.map((row) {
      final target = CorrectionTarget(snapshot: row.sourceSnapshotJson);
      if (target.tripId != row.tripId ||
          target.eventId != row.eventId ||
          row.revision < 1 ||
          row.createdAtMicros <= 0 ||
          row.updatedAtMicros <= 0 ||
          ((row.consentVersion == null) != (row.consentedAtMicros == null)) ||
          (row.consentVersion != null &&
              (row.consentVersion != 1 || row.consentedAtMicros! <= 0))) {
        throw const FormatException('Invalid stored correction.');
      }
      return CorrectionNote(
        target: target,
        choice: CorrectionChoice.parse(row.reportedLabel),
        revision: row.revision,
        createdAtMicros: row.createdAtMicros,
        updatedAtMicros: row.updatedAtMicros,
        consentVersion: row.consentVersion,
        consentedAtMicros: row.consentedAtMicros,
      );
    }).toList();
  }

  Future<Set<String>> _currentSnapshots(
    Trip trip,
    List<CorrectionNote> notes,
  ) async {
    if (notes.isEmpty) return {};
    final rows =
        await (db.select(db.tripEvents)..where(
              (row) =>
                  row.tripId.equals(trip.id) &
                  row.id.isIn(notes.map((note) => note.target.eventId)),
            ))
            .get();
    return {
      for (final row in rows)
        if (_target(trip, row) case final target?) target.snapshot,
    };
  }

  Future<void> save(
    CorrectionTarget target,
    CorrectionChoice choice, {
    required int expectedRevision,
    bool contribute = false,
  }) => db.transaction(() async {
    final trip = await _trip(target.tripId);
    final source =
        await (db.select(db.tripEvents)..where(
              (row) =>
                  row.tripId.equals(target.tripId) &
                  row.id.equals(target.eventId),
            ))
            .getSingleOrNull();
    if (source == null || _target(trip, source)?.snapshot != target.snapshot) {
      throw StateError('Detection changed; review it again.');
    }
    final notes = await _notes(trip.id);
    final matches = notes
        .where((note) => note.target.snapshot == target.snapshot)
        .toList();
    final existing = matches.isEmpty ? null : matches.single;
    if (expectedRevision != (existing?.revision ?? 0)) {
      throw StateError('Correction changed; review it again.');
    }
    if (existing == null && notes.length >= 128) {
      throw StateError('Remove a note before adding another.');
    }
    final now = _now();
    if (now <= 0) {
      throw StateError('Correction clock is unavailable.');
    }
    final values = TripEventCorrectionsCompanion.insert(
      tripId: trip.id,
      eventId: target.eventId,
      sourceSnapshotJson: target.snapshot,
      reportedLabel: choice.wireName,
      revision: expectedRevision + 1,
      createdAtMicros: existing?.createdAtMicros ?? now,
      updatedAtMicros: now,
      consentVersion: Value(contribute ? 1 : null),
      consentedAtMicros: Value(contribute ? now : null),
    );
    if (existing == null) {
      await db.into(db.tripEventCorrections).insert(values);
    } else {
      final changed =
          await (db.update(db.tripEventCorrections)..where(
                (row) =>
                    row.tripId.equals(trip.id) &
                    row.eventId.equals(target.eventId) &
                    row.sourceSnapshotJson.equals(target.snapshot) &
                    row.revision.equals(expectedRevision),
              ))
              .write(values);
      if (changed != 1) {
        throw StateError('Correction changed; review it again.');
      }
    }
  });

  Future<void> remove(CorrectionNote note) => db.transaction(() async {
    await _trip(note.target.tripId);
    final changed =
        await (db.delete(db.tripEventCorrections)..where(
              (row) =>
                  row.tripId.equals(note.target.tripId) &
                  row.eventId.equals(note.target.eventId) &
                  row.sourceSnapshotJson.equals(note.target.snapshot) &
                  row.revision.equals(note.revision),
            ))
            .go();
    if (changed != 1) throw StateError('Correction changed; review it again.');
  });

  Future<void> clear(String tripId) => db.transaction(() async {
    await _trip(tripId);
    await (db.delete(
      db.tripEventCorrections,
    )..where((row) => row.tripId.equals(tripId))).go();
  });

  Future<CorrectionContribution> prepare(String tripId) =>
      db.transaction(() async {
        final trip = await _trip(tripId);
        final notes = await _notes(tripId);
        final current = await _currentSnapshots(trip, notes);
        final allowed = notes
            .where(
              (note) =>
                  note.contributionAllowed &&
                  current.contains(note.target.snapshot),
            )
            .toList();
        if (allowed.isEmpty) {
          throw StateError('No current notes have export permission.');
        }
        final payload = correctionContributionPayload(allowed);
        final token = jsonEncode([
          for (final note in allowed)
            [note.target.snapshot, note.revision, note.consentedAtMicros],
        ]);
        return CorrectionContribution(reviewToken: token, payload: payload);
      });
}
