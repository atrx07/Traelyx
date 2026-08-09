import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'schema version 1 creates the canonical local-first structure',
    () async {
      expect(database.schemaVersion, 1);

      final tableNames = await _schemaObjectNames(database, 'table');
      expect(tableNames, [
        'app_settings',
        'driver_baselines',
        'sync_queue',
        'trip_chunks',
        'trip_events',
        'trip_scores',
        'trips',
        'vehicles',
      ]);

      final indexNames = await _schemaObjectNames(database, 'index');
      expect(indexNames, [
        'driver_baselines_owner_vehicle',
        'sync_queue_idempotency_key',
        'sync_queue_state_next_attempt',
        'trip_events_trip_start',
        'trip_scores_trip_version',
        'trips_start_time',
        'trips_vehicle_start',
        'vehicles_owner_namespace',
      ]);

      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);
    },
  );

  test('settings remain part of schema version 1', () async {
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'privacy.accountless',
            value: 'true',
            updatedAtMicros: 0,
          ),
        );

    final row = await database.select(database.appSettings).getSingle();
    expect(row.key, 'privacy.accountless');
    expect(row.value, 'true');
  });

  test(
    'foreign keys, ranges, uniqueness, and cascades protect trip data',
    () async {
      await database
          .into(database.vehicles)
          .insert(
            VehiclesCompanion.insert(
              id: 'vehicle-1',
              ownerNamespace: 'local:device-1',
              displayName: 'Pova test vehicle',
              vehicleType: 'motorcycle',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );

      await expectLater(
        database
            .into(database.trips)
            .insert(_trip(id: 'missing-vehicle-trip', vehicleId: 'missing')),
        throwsA(anything),
      );
      await expectLater(
        database
            .into(database.trips)
            .insert(
              _trip(
                id: 'invalid-confidence-trip',
                vehicleId: 'vehicle-1',
                telemetryConfidence: const Value(1.01),
              ),
            ),
        throwsA(anything),
      );

      await database
          .into(database.trips)
          .insert(_trip(id: 'trip-1', vehicleId: 'vehicle-1'));
      await database
          .into(database.tripChunks)
          .insert(
            TripChunksCompanion.insert(
              tripId: 'trip-1',
              sequence: 0,
              storageReference: 'trips/trip-1/chunk-0.bin',
              encodingVersion: 1,
              startElapsedNanos: 100,
              endElapsedNanos: 200,
              channelSampleCountsJson: '{"gnss":1,"imu":10}',
              compression: 'none',
              atomicWriteStrategy: 'temp_then_rename',
              checksumAlgorithm: 'sha256',
              checksum: 'fixture-checksum',
              byteLength: 128,
              writeState: 'complete',
              createdAtMicros: 2,
            ),
          );
      await expectLater(
        database
            .into(database.tripChunks)
            .insert(
              TripChunksCompanion.insert(
                tripId: 'trip-1',
                sequence: 0,
                storageReference: 'duplicate',
                encodingVersion: 1,
                startElapsedNanos: 200,
                endElapsedNanos: 300,
                channelSampleCountsJson: '{}',
                compression: 'none',
                atomicWriteStrategy: 'temp_then_rename',
                checksumAlgorithm: 'sha256',
                checksum: 'duplicate',
                byteLength: 1,
                writeState: 'complete',
                createdAtMicros: 3,
              ),
            ),
        throwsA(anything),
      );

      await database
          .into(database.tripEvents)
          .insert(
            TripEventsCompanion.insert(
              id: 'event-1',
              tripId: 'trip-1',
              eventType: 'STRONG_BRAKING',
              startElapsedNanos: 110,
              peakElapsedNanos: 130,
              endElapsedNanos: 160,
              severity: 0.6,
              severityCalibrationVersion: 'severity-v1',
              confidence: 0.8,
              qualityFlagsJson: '[]',
              primaryMeasurementsJson: '{"peak_mps2":-3.5}',
              ruleEvidenceJson: '{"rule":"fixture"}',
              contextTagsJson: '[]',
              algorithmVersion: 'events-v1',
              createdAtMicros: 2,
            ),
          );
      await database
          .into(database.driverBaselines)
          .insert(
            DriverBaselinesCompanion.insert(
              id: 'baseline-1',
              ownerNamespace: 'local:device-1',
              vehicleId: const Value('vehicle-1'),
              lifecycleState: 'emerging',
              dimensionStatisticsJson: '{"smoothness":{"count":1}}',
              baselineSchemaVersion: 1,
              scoringVersion: 'score-v1',
              validTripCount: 1,
              confidence: const Value(0.4),
              createdAtMicros: 2,
              updatedAtMicros: 2,
            ),
          );
      await database
          .into(database.tripScores)
          .insert(
            TripScoresCompanion.insert(
              id: 'score-1',
              tripId: 'trip-1',
              scoreSchemaVersion: 1,
              scoringVersion: 'score-v1',
              dimensionValuesJson: '{"smoothness":78}',
              overallScore: const Value(78),
              confidence: const Value(0.8),
              eligibilityState: 'provisional',
              auditContributionsJson: '[{"id":"fixture","amount":-2}]',
              baselineId: const Value('baseline-1'),
              createdAtMicros: 2,
            ),
          );

      await expectLater(
        (database.delete(
          database.vehicles,
        )..where((row) => row.id.equals('vehicle-1'))).go(),
        throwsA(anything),
      );

      await (database.delete(
        database.trips,
      )..where((row) => row.id.equals('trip-1'))).go();
      expect(await database.select(database.tripChunks).get(), isEmpty);
      expect(await database.select(database.tripEvents).get(), isEmpty);
      expect(await database.select(database.tripScores).get(), isEmpty);
      expect(
        await database.select(database.driverBaselines).get(),
        hasLength(1),
      );

      await (database.delete(
        database.vehicles,
      )..where((row) => row.id.equals('vehicle-1'))).go();
      final baseline = await database
          .select(database.driverBaselines)
          .getSingle();
      expect(baseline.vehicleId, isNull);
    },
  );

  test('sync operations require stable unique idempotency keys', () async {
    final first = SyncQueueCompanion.insert(
      operationId: 'operation-1',
      idempotencyKey: 'trip-1:summary:1',
      entityType: 'trip_summary',
      entityId: 'trip-1',
      entityVersion: 1,
      operationType: 'upsert',
      state: 'pending',
      attemptCount: 0,
      createdAtMicros: 1,
      updatedAtMicros: 1,
    );
    await database.into(database.syncQueue).insert(first);

    await expectLater(
      database
          .into(database.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              operationId: 'operation-2',
              idempotencyKey: 'trip-1:summary:1',
              entityType: 'trip_summary',
              entityId: 'trip-1',
              entityVersion: 1,
              operationType: 'upsert',
              state: 'pending',
              attemptCount: 0,
              createdAtMicros: 2,
              updatedAtMicros: 2,
            ),
          ),
      throwsA(anything),
    );
  });

  test(
    'structured schema does not store raw samples or route geometry',
    () async {
      final schemaSql = await database
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();
      final normalized = schemaSql
          .map((row) => row.readNullable<String>('sql') ?? '')
          .join('\n')
          .toLowerCase();

      expect(normalized, isNot(contains('latitude')));
      expect(normalized, isNot(contains('longitude')));
      expect(normalized, isNot(contains('route_geometry')));
      expect(normalized, isNot(contains('raw_sample')));
      expect(normalized, contains('storage_reference'));
      expect(normalized, contains('channel_sample_counts_json'));
    },
  );
}

TripsCompanion _trip({
  required String id,
  required String vehicleId,
  Value<double?> telemetryConfidence = const Value(0.9),
}) {
  return TripsCompanion.insert(
    id: id,
    vehicleId: vehicleId,
    startWallTimeMicros: 1,
    startElapsedNanos: 100,
    completionState: 'completed',
    recoveryState: 'not_needed',
    telemetrySchemaVersion: 1,
    eventEngineVersion: const Value('events-v1'),
    integrityStatus: 'eligible',
    telemetryConfidence: telemetryConfidence,
    cloudSyncState: 'local_only',
    createdAtMicros: 1,
    updatedAtMicros: 1,
  );
}

Future<List<String>> _schemaObjectNames(
  AppDatabase database,
  String type,
) async {
  final rows = await database
      .customSelect(
        'SELECT name FROM sqlite_master '
        'WHERE type = ? AND name NOT LIKE ? ORDER BY name',
        variables: [Variable.withString(type), Variable.withString('sqlite_%')],
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toList();
}
