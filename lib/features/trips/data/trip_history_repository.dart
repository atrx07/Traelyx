import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

abstract interface class TripHistoryRepository {
  Stream<List<TripHistoryItem>> watchHistory();

  Future<TripResult?> loadResult(String tripId);
}

class DriftTripHistoryRepository implements TripHistoryRepository {
  const DriftTripHistoryRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<TripHistoryItem>> watchHistory() {
    final query =
        _database.select(_database.trips).join([
          innerJoin(
            _database.vehicles,
            _database.vehicles.id.equalsExp(_database.trips.vehicleId),
          ),
        ])..orderBy([
          OrderingTerm.desc(_database.trips.startWallTimeMicros),
          OrderingTerm.desc(_database.trips.id),
        ]);

    return query.watch().map(
      (rows) => List.unmodifiable(rows.map(_historyItemFromRow)),
    );
  }

  @override
  Future<TripResult?> loadResult(String tripId) async {
    if (tripId.isEmpty) return null;

    final tripQuery = _database.select(_database.trips).join([
      innerJoin(
        _database.vehicles,
        _database.vehicles.id.equalsExp(_database.trips.vehicleId),
      ),
    ])..where(_database.trips.id.equals(tripId));
    final row = await tripQuery.getSingleOrNull();
    if (row == null) return null;

    final chunks = await (_database.select(
      _database.tripChunks,
    )..where((chunk) => chunk.tripId.equals(tripId))).get();
    final events =
        await (_database.select(_database.tripEvents)
              ..where((event) => event.tripId.equals(tripId))
              ..orderBy([(event) => OrderingTerm.asc(event.startElapsedNanos)]))
            .get();
    final scores =
        await (_database.select(_database.tripScores)
              ..where((score) => score.tripId.equals(tripId))
              ..orderBy([(score) => OrderingTerm.desc(score.createdAtMicros)]))
            .get();
    final trip = row.readTable(_database.trips);

    return TripResult(
      trip: _historyItemFromRow(row),
      telemetrySchemaVersion: trip.telemetrySchemaVersion,
      telemetryConfidenceRecorded: trip.telemetryConfidence != null,
      evidence: _evidenceFromChunks(chunks),
      finalization: _finalizationFromJson(
        trip.telemetryQualitySummaryJson,
        indexedChunkCount: chunks.length,
      ),
      events: List.unmodifiable(
        events.map(
          (event) => TripEventSummary(
            type: event.eventType,
            startElapsedNanos: event.startElapsedNanos,
            endElapsedNanos: event.endElapsedNanos,
          ),
        ),
      ),
      score: scores.isEmpty ? null : _scoreFromRow(scores.first),
    );
  }

  TripHistoryItem _historyItemFromRow(TypedResult row) {
    final trip = row.readTable(_database.trips);
    final vehicle = row.readTable(_database.vehicles);
    return TripHistoryItem(
      id: trip.id,
      vehicleName: vehicle.displayName,
      startedAtUtc: DateTime.fromMicrosecondsSinceEpoch(
        trip.startWallTimeMicros,
        isUtc: true,
      ),
      duration: trip.durationMillis == null
          ? null
          : Duration(milliseconds: trip.durationMillis!),
      distanceMeters: trip.distanceMeters,
      completionState: _completionState(trip.completionState),
      recoveryState: _recoveryState(trip.recoveryState),
      integrityState: _integrityState(trip.integrityStatus),
    );
  }
}

TripEvidenceSummary _evidenceFromChunks(List<TripChunk> chunks) {
  var bytes = 0;
  var gnss = 0;
  var accelerometer = 0;
  var gyroscope = 0;

  for (final chunk in chunks) {
    final counts = _decodeObject(chunk.channelSampleCountsJson);
    bytes += chunk.byteLength;
    gnss += _requiredNonNegativeInt(counts, 'gnss');
    accelerometer += _requiredNonNegativeInt(counts, 'accelerometer');
    gyroscope += _requiredNonNegativeInt(counts, 'gyroscope');
  }

  return TripEvidenceSummary(
    chunkCount: chunks.length,
    byteCount: bytes,
    gnssSampleCount: gnss,
    accelerometerSampleCount: accelerometer,
    gyroscopeSampleCount: gyroscope,
  );
}

TripFinalizationSummary? _finalizationFromJson(
  String? source, {
  required int indexedChunkCount,
}) {
  if (source == null) return null;
  final value = _decodeObject(source);
  final validChunkCount = _requiredNonNegativeInt(value, 'validChunkCount');
  if (validChunkCount != indexedChunkCount) {
    throw const FormatException(
      'Finalization summary does not match the indexed chunk count.',
    );
  }
  final flagsValue = value['qualityFlags'];
  if (flagsValue is! List || flagsValue.any((flag) => flag is! String)) {
    throw const FormatException('Finalization quality flags are malformed.');
  }

  return TripFinalizationSummary(
    logicVersion: _requiredPositiveInt(value, 'finalizationLogicVersion'),
    recoveryCount: _requiredNonNegativeInt(value, 'recoveryCount'),
    corruptChunkCount: _requiredNonNegativeInt(value, 'corruptChunkCount'),
    orphanedWriteCount: _requiredNonNegativeInt(value, 'orphanedWriteCount'),
    orderingViolationCount: _requiredNonNegativeInt(
      value,
      'orderingViolationCount',
    ),
    qualityFlags: List.unmodifiable(flagsValue.cast<String>()),
  );
}

TripScoreSummary _scoreFromRow(TripScore score) {
  return TripScoreSummary(
    overallScore: score.overallScore,
    eligibilityState: _scoreEligibilityState(score.eligibilityState),
    scoringVersion: score.scoringVersion,
    confidenceRecorded: score.confidence != null,
  );
}

Map<String, Object?> _decodeObject(String source) {
  final value = jsonDecode(source);
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

int _requiredNonNegativeInt(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! int || field < 0) {
    throw FormatException('$key must be a non-negative integer.');
  }
  return field;
}

int _requiredPositiveInt(Map<String, Object?> value, String key) {
  final field = _requiredNonNegativeInt(value, key);
  if (field == 0) {
    throw FormatException('$key must be positive.');
  }
  return field;
}

TripEvidenceState _completionState(String value) => switch (value) {
  'completed' => TripEvidenceState.verified,
  'incomplete' => TripEvidenceState.reviewRequired,
  _ => TripEvidenceState.notAssessed,
};

TripEvidenceState _recoveryState(String value) => switch (value) {
  'not_needed' => TripEvidenceState.verified,
  'recovered' => TripEvidenceState.limited,
  _ => TripEvidenceState.notAssessed,
};

TripEvidenceState _integrityState(String value) => switch (value) {
  'verified' => TripEvidenceState.verified,
  'limited' || 'questionable' => TripEvidenceState.limited,
  'review_required' || 'unranked' => TripEvidenceState.reviewRequired,
  'unavailable' => TripEvidenceState.unavailable,
  'unassessed' => TripEvidenceState.notAssessed,
  _ => TripEvidenceState.notAssessed,
};

TripEvidenceState _scoreEligibilityState(String value) => switch (value) {
  'full' || 'eligible' || 'rankable' => TripEvidenceState.verified,
  'provisional' || 'limited' || 'partial' => TripEvidenceState.limited,
  'unavailable' || 'insufficient_evidence' => TripEvidenceState.unavailable,
  'review_required' || 'unranked' => TripEvidenceState.reviewRequired,
  _ => TripEvidenceState.notAssessed,
};
