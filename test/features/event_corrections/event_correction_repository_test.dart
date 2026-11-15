import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

import 'correction_fixture.dart';

void main() {
  late AppDatabase db;
  late EventCorrectionRepository repo;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedCorrectionTrip(db);
    repo = EventCorrectionRepository(db, now: () => 100);
  });
  tearDown(() => db.close());

  test(
    'local correction preserves source evidence, score and default-off consent',
    () async {
      final before = await evidence(db);
      final target = (await repo.load('private-trip')).targets.single;
      expect(target.qualityDescription, contains('limited'));
      await repo.save(
        target,
        CorrectionChoice.notThisEvent,
        expectedRevision: 0,
      );
      final note = (await repo.load('private-trip')).notes.single;
      expect(note.choice, CorrectionChoice.notThisEvent);
      expect(note.revision, 1);
      expect(note.contributionAllowed, false);
      expect(await evidence(db), before);
      await expectLater(repo.prepare('private-trip'), throwsStateError);
    },
  );

  test(
    'consent exports only categorical fields; edits default back to no permission',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.unsure,
        expectedRevision: 0,
        contribute: true,
      );
      final preview = await repo.prepare('private-trip');
      expect(preview.count, 1);
      expect(preview.payload['trainingUse'], 'quarantine_only');
      expect((preview.payload['labels'] as List).single, {
        'detectedEvent': 'EVT_BRAKE_STRONG',
        'reportedLabel': 'unsure',
        'eventEngineVersion': 1,
        'telemetrySchemaVersion': 1,
      });
      final encoded = jsonEncode(preview.payload);
      for (final value in [
        'private-trip',
        'private-event',
        'private-vehicle',
        '12.345',
        '9000000000',
        '1000000',
        'sourceSnapshot',
      ]) {
        expect(encoded, isNot(contains(value)));
      }
      await repo.save(target, CorrectionChoice.correct, expectedRevision: 1);
      expect(
        (await repo.load('private-trip')).notes.single.contributionAllowed,
        false,
      );
      await expectLater(repo.prepare('private-trip'), throwsStateError);
    },
  );

  test(
    'stale revisions cannot restore permission or replace a newer note',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.correct,
        expectedRevision: 0,
        contribute: true,
      );
      await repo.save(target, CorrectionChoice.correct, expectedRevision: 1);
      await expectLater(
        repo.save(
          target,
          CorrectionChoice.roadImpact,
          expectedRevision: 1,
          contribute: true,
        ),
        throwsStateError,
      );
      final note = (await repo.load('private-trip')).notes.single;
      expect(note.revision, 2);
      expect(note.contributionAllowed, false);
    },
  );

  test('a wall-clock rollback cannot prevent consent withdrawal', () async {
    final target = (await repo.load('private-trip')).targets.single;
    await repo.save(
      target,
      CorrectionChoice.unsure,
      expectedRevision: 0,
      contribute: true,
    );
    final afterClockChange = EventCorrectionRepository(db, now: () => 50);
    await afterClockChange.save(
      target,
      CorrectionChoice.unsure,
      expectedRevision: 1,
    );
    final note = (await afterClockChange.load('private-trip')).notes.single;
    expect(note.revision, 2);
    expect(note.createdAtMicros, 100);
    expect(note.updatedAtMicros, 50);
    expect(note.contributionAllowed, false);
    await expectLater(
      afterClockChange.prepare('private-trip'),
      throwsStateError,
    );
  });

  test(
    'changed or replaced evidence retains a stale note without rebinding or exporting',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.correct,
        expectedRevision: 0,
        contribute: true,
      );
      await (db.update(
        db.tripEvents,
      )..where((row) => row.id.equals(target.eventId))).write(
        const TripEventsCompanion(
          primaryMeasurementsJson: Value('{"changed":true}'),
        ),
      );
      final changed = await repo.load('private-trip');
      expect(changed.staleCount, 1);
      expect(changed.noteFor(changed.targets.single), isNull);
      await expectLater(
        repo.save(target, CorrectionChoice.unsure, expectedRevision: 1),
        throwsStateError,
      );
      await expectLater(repo.prepare('private-trip'), throwsStateError);
      await repo.save(
        changed.targets.single,
        CorrectionChoice.unsure,
        expectedRevision: 0,
      );
      expect((await repo.load('private-trip')).notes.length, 2);
      await db.delete(db.tripEvents).go();
      expect((await repo.load('private-trip')).staleCount, 2);
      await repo.clear('private-trip');
      expect((await repo.load('private-trip')).notes, isEmpty);
    },
  );

  test(
    'whole-trip deletion cascades notes; unrelated raw-index cleanup does not',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(target, CorrectionChoice.unsure, expectedRevision: 0);
      await db.delete(db.tripChunks).go();
      expect((await repo.load('private-trip')).notes.length, 1);
      await (db.delete(
        db.trips,
      )..where((row) => row.id.equals('private-trip'))).go();
      expect(await db.select(db.tripEventCorrections).get(), isEmpty);
    },
  );

  test(
    'unknown versions, unfinished trips and corrupt notes fail closed',
    () async {
      await (db.update(db.trips)..where((row) => row.id.equals('private-trip')))
          .write(const TripsCompanion(endWallTimeMicros: Value(null)));
      await expectLater(repo.load('private-trip'), throwsStateError);
      await (db.update(db.trips)..where((row) => row.id.equals('private-trip')))
          .write(const TripsCompanion(endWallTimeMicros: Value(91000000)));
      await (db.update(db.tripEvents)
            ..where((row) => row.id.equals('private-event')))
          .write(const TripEventsCompanion(algorithmVersion: Value('2')));
      expect((await repo.load('private-trip')).targets, isEmpty);
      await (db.update(
        db.tripEvents,
      )..where((row) => row.id.equals('private-event'))).write(
        const TripEventsCompanion(
          algorithmVersion: Value('1'),
          mlEvidenceJson: Value('{"status":"experiment"}'),
        ),
      );
      expect((await repo.load('private-trip')).targets, isEmpty);
      await db
          .into(db.tripEventCorrections)
          .insert(
            TripEventCorrectionsCompanion.insert(
              tripId: 'private-trip',
              eventId: 'private-event',
              sourceSnapshotJson: '{"bad":true}',
              reportedLabel: 'unsure',
              revision: 1,
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      await expectLater(repo.load('private-trip'), throwsFormatException);
    },
  );

  test(
    '128-note bound includes retained evidence and can be freed by explicit removal',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      final source = jsonDecode(target.snapshot) as Map<String, dynamic>;
      await db.batch(
        (batch) => batch.insertAll(db.tripEventCorrections, [
          for (var i = 0; i < 128; i++)
            TripEventCorrectionsCompanion.insert(
              tripId: 'private-trip',
              eventId: 'retained-$i',
              sourceSnapshotJson: jsonEncode({
                ...source,
                'eventId': 'retained-$i',
              }),
              reportedLabel: 'unsure',
              revision: 1,
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
        ]),
      );
      await expectLater(
        repo.save(target, CorrectionChoice.unsure, expectedRevision: 0),
        throwsStateError,
      );
      await repo.remove((await repo.load('private-trip')).notes.first);
      await repo.save(target, CorrectionChoice.unsure, expectedRevision: 0);
      expect((await repo.load('private-trip')).notes.length, 128);
    },
  );

  test(
    'contribution validator rejects hidden fields and unsupported consent without mutating input',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.deviceMoved,
        expectedRevision: 0,
        contribute: true,
      );
      final payload = (await repo.prepare('private-trip')).payload;
      for (final key in [
        'tripId',
        'timestamp',
        'features',
        'route',
        'rawTelemetry',
      ]) {
        expect(
          () => validateCorrectionContribution({...payload, key: 'private'}),
          throwsFormatException,
        );
        expect(
          () => validateCorrectionContribution({
            ...payload,
            'labels': [
              {
                ...(payload['labels'] as List).first as Map<String, Object?>,
                key: 'private',
              },
            ],
          }),
          throwsFormatException,
        );
      }
      expect(
        () => validateCorrectionContribution({
          ...payload,
          'consentDeclared': false,
        }),
        throwsFormatException,
      );
      expect(
        () => validateCorrectionContribution({
          ...payload,
          'trainingUse': 'eligible',
        }),
        throwsFormatException,
      );
      expect(
        () => (payload['labels'] as List).add(<String, Object?>{}),
        throwsUnsupportedError,
      );
    },
  );
}

Future<List<Object?>> evidence(AppDatabase db) async => [
  (await db.customSelect('SELECT * FROM trip_events').get())
      .map((row) => row.data)
      .toList(),
  (await db.customSelect('SELECT * FROM trip_scores').get())
      .map((row) => row.data)
      .toList(),
  (await db.customSelect('SELECT * FROM trips').get())
      .map((row) => row.data)
      .toList(),
];
