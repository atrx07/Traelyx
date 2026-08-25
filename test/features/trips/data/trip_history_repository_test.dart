import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

void main() {
  late AppDatabase database;
  late DriftTripHistoryRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTripHistoryRepository(database);
    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'vehicle-one',
            ownerNamespace: 'local:anonymous',
            displayName: 'Local bike',
            vehicleType: 'motorcycle',
            createdAtMicros: 1,
            updatedAtMicros: 1,
          ),
        );
  });

  tearDown(() => database.close());

  test(
    'history streams newest trips first with honest missing metrics',
    () async {
      await _insertTrip(database, id: 'older', startMicros: 1000000);
      await _insertTrip(
        database,
        id: 'newer',
        startMicros: 2000000,
        durationMillis: 62500,
        distanceMeters: 1450,
      );

      final history = await repository.watchHistory().first;

      expect(history.map((trip) => trip.id), ['newer', 'older']);
      expect(history.first.vehicleName, 'Local bike');
      expect(history.first.duration, const Duration(milliseconds: 62500));
      expect(history.first.distanceMeters, 1450);
      expect(history.last.duration, isNull);
      expect(history.last.distanceMeters, isNull);
      expect(history.last.integrityState, TripEvidenceState.notAssessed);
    },
  );

  test(
    'result aggregates allowlisted local evidence and latest analysis',
    () async {
      await _insertTrip(
        database,
        id: 'trip-one',
        startMicros: 1000000,
        durationMillis: 90000,
        qualitySummary: _qualitySummary(validChunkCount: 2),
      );
      await _insertChunk(
        database,
        tripId: 'trip-one',
        sequence: 0,
        counts: const {'gnss': 4, 'accelerometer': 20, 'gyroscope': 19},
        bytes: 300,
      );
      await _insertChunk(
        database,
        tripId: 'trip-one',
        sequence: 1,
        counts: const {'gnss': 6, 'accelerometer': 22, 'gyroscope': 21},
        bytes: 500,
      );
      await database
          .into(database.tripEvents)
          .insert(
            TripEventsCompanion.insert(
              id: 'event-one',
              tripId: 'trip-one',
              eventType: 'strong_braking',
              startElapsedNanos: 2000000000,
              peakElapsedNanos: 2500000000,
              endElapsedNanos: 3000000000,
              severity: 0.5,
              severityCalibrationVersion: 'event-v1',
              confidence: 0.8,
              qualityFlagsJson: '[]',
              primaryMeasurementsJson: '{}',
              ruleEvidenceJson: '{}',
              contextTagsJson: '[]',
              algorithmVersion: 'event-v1',
              createdAtMicros: 4,
            ),
          );
      await _insertScore(
        database,
        id: 'older-score',
        createdAtMicros: 4,
        value: 72,
        scoringVersion: 'scoring-v0',
      );
      await _insertScore(
        database,
        id: 'newer-score',
        createdAtMicros: 5,
        value: 81,
      );

      final result = await repository.loadResult('trip-one');

      expect(result, isNotNull);
      expect(result!.evidence.chunkCount, 2);
      expect(result.evidence.byteCount, 800);
      expect(result.evidence.gnssSampleCount, 10);
      expect(result.evidence.accelerometerSampleCount, 42);
      expect(result.evidence.gyroscopeSampleCount, 40);
      expect(result.finalization!.logicVersion, 1);
      expect(result.events.single.type, 'strong_braking');
      expect(result.score!.overallScore, 81);
      expect(result.score!.scoringVersion, 'scoring-v1');
    },
  );

  test('missing trip returns no result', () async {
    expect(await repository.loadResult('missing'), isNull);
    expect(await repository.loadResult(''), isNull);
  });

  test('malformed chunk aggregates fail closed', () async {
    await _insertTrip(
      database,
      id: 'trip-one',
      startMicros: 1000000,
      qualitySummary: _qualitySummary(validChunkCount: 1),
    );
    await _insertChunk(
      database,
      tripId: 'trip-one',
      sequence: 0,
      countsJson: '{"gnss":-1,"accelerometer":2,"gyroscope":2}',
    );

    await expectLater(
      repository.loadResult('trip-one'),
      throwsA(isA<FormatException>()),
    );
  });

  test('finalization and indexed chunk counts must agree', () async {
    await _insertTrip(
      database,
      id: 'trip-one',
      startMicros: 1000000,
      qualitySummary: _qualitySummary(validChunkCount: 2),
    );
    await _insertChunk(database, tripId: 'trip-one', sequence: 0);

    await expectLater(
      repository.loadResult('trip-one'),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<void> _insertTrip(
  AppDatabase database, {
  required String id,
  required int startMicros,
  int? durationMillis,
  double? distanceMeters,
  String? qualitySummary,
}) {
  return database
      .into(database.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          vehicleId: 'vehicle-one',
          startWallTimeMicros: startMicros,
          endWallTimeMicros: Value(
            durationMillis == null ? null : startMicros + durationMillis * 1000,
          ),
          startElapsedNanos: 1000000000,
          endElapsedNanos: Value(
            durationMillis == null
                ? null
                : 1000000000 + durationMillis * 1000000,
          ),
          durationMillis: Value(durationMillis),
          distanceMeters: Value(distanceMeters),
          completionState: 'completed',
          recoveryState: 'not_needed',
          telemetrySchemaVersion: 1,
          integrityStatus: 'unassessed',
          telemetryQualitySummaryJson: Value(qualitySummary),
          cloudSyncState: 'local_only',
          createdAtMicros: startMicros,
          updatedAtMicros: startMicros,
        ),
      );
}

Future<void> _insertChunk(
  AppDatabase database, {
  required String tripId,
  required int sequence,
  Map<String, int> counts = const {
    'gnss': 1,
    'accelerometer': 2,
    'gyroscope': 2,
  },
  String? countsJson,
  int bytes = 100,
}) {
  return database
      .into(database.tripChunks)
      .insert(
        TripChunksCompanion.insert(
          tripId: tripId,
          sequence: sequence,
          storageReference:
              'recorder/trips/$tripId/chunks/${sequence.toString().padLeft(10, '0')}.tlxc',
          encodingVersion: 1,
          startElapsedNanos: sequence * 1000000000,
          endElapsedNanos: (sequence + 1) * 1000000000,
          channelSampleCountsJson: countsJson ?? jsonEncode(counts),
          compression: 'deflate',
          atomicWriteStrategy: 'android_atomic_file',
          checksumAlgorithm: 'sha256',
          checksum: List.filled(64, 'a').join(),
          byteLength: bytes,
          writeState: 'complete',
          createdAtMicros: sequence + 1,
        ),
      );
}

Future<void> _insertScore(
  AppDatabase database, {
  required String id,
  required int createdAtMicros,
  required double value,
  String scoringVersion = 'scoring-v1',
}) {
  return database
      .into(database.tripScores)
      .insert(
        TripScoresCompanion.insert(
          id: id,
          tripId: 'trip-one',
          scoreSchemaVersion: 1,
          scoringVersion: scoringVersion,
          dimensionValuesJson: '{}',
          overallScore: Value(value),
          confidence: const Value(0.8),
          eligibilityState: 'full',
          auditContributionsJson: '{}',
          createdAtMicros: createdAtMicros,
        ),
      );
}

String _qualitySummary({required int validChunkCount}) {
  return jsonEncode({
    'finalizationLogicVersion': 1,
    'recoveryCount': 0,
    'validChunkCount': validChunkCount,
    'corruptChunkCount': 0,
    'orphanedWriteCount': 0,
    'orderingViolationCount': 0,
    'qualityFlags': <String>[],
  });
}
