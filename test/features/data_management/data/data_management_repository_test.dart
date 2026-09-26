import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/platform/data_management_bridge.dart';
import 'package:traelyx/features/data_management/data/data_management_repository.dart';
import 'package:traelyx/features/data_management/domain/data_management_models.dart';

void main() {
  late AppDatabase database;
  late _FakeDataManagementPlatform platform;
  late DriftDataManagementRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    platform = _FakeDataManagementPlatform();
    repository = DriftDataManagementRepository(database, platform);
    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'vehicle-one',
            ownerNamespace: 'local:anonymous',
            displayName: 'Synthetic test vehicle',
            vehicleType: 'motorcycle',
            createdAtMicros: 1,
            updatedAtMicros: 1,
          ),
        );
  });

  tearDown(() => database.close());

  test('storage inventory aggregates finalized synthetic trips only', () async {
    await _insertTrip(database, oldTripId, DateTime.utc(2026, 1, 1));
    await _insertTrip(database, newTripId, DateTime.utc(2026, 2, 1));
    await _insertTrip(
      database,
      activeTripId,
      DateTime.utc(2026, 2, 2),
      finalized: false,
    );
    await _insertChunk(database, oldTripId, 0, 100);
    await _insertChunk(database, oldTripId, 1, 250);

    final trips = await repository.watchStoredTrips().first;

    expect(trips.map((trip) => trip.id), [newTripId, oldTripId]);
    expect(trips.last.chunkCount, 2);
    expect(trips.last.indexedRawBytes, 350);
    expect(trips.first.hasRawTelemetry, isFalse);
  });

  test('retention preview is inert and uses the exact UTC cutoff', () async {
    await _insertTrip(database, oldTripId, DateTime.utc(2026, 1, 1));
    await _insertTrip(database, newTripId, DateTime.utc(2026, 1, 28));
    await _insertChunk(database, oldTripId, 0, 100);
    await _insertChunk(database, newTripId, 0, 200);

    final manual = await repository.planCleanup(
      RawRetentionPolicy.manual,
      DateTime.utc(2026, 2, 1),
    );
    final sevenDays = await repository.planCleanup(
      RawRetentionPolicy.sevenDays,
      DateTime.utc(2026, 2, 1),
    );

    expect(manual.candidates, isEmpty);
    expect(sevenDays.candidates.map((trip) => trip.id), [oldTripId]);
    expect(sevenDays.indexedRawBytes, 100);
    expect(platform.deletedTripIds, isEmpty);
  });

  test(
    'raw cleanup removes only the selected chunk index after native success',
    () async {
      await _insertTrip(database, oldTripId, DateTime.utc(2026, 1, 1));
      await _insertTrip(database, newTripId, DateTime.utc(2026, 1, 28));
      await _insertChunk(database, oldTripId, 0, 100);
      await _insertChunk(database, newTripId, 0, 200);
      platform.bytesByTrip[oldTripId] = 123;

      final result = await repository.executeCleanup(
        RawRetentionPolicy.sevenDays,
        DateTime.utc(2026, 2, 1),
      );

      expect(result.deletedTripCount, 1);
      expect(result.bytesDeleted, 123);
      expect(result.failureCount, 0);
      expect(platform.deletedTripIds, [oldTripId]);
      expect(await _tripCount(database), 2);
      expect(await _chunkCount(database, oldTripId), 0);
      expect(await _chunkCount(database, newTripId), 1);
    },
  );

  test('native failure preserves trip and indexed raw evidence', () async {
    await _insertTrip(database, oldTripId, DateTime.utc(2026, 1, 1));
    await _insertChunk(database, oldTripId, 0, 100);
    platform.failures[oldTripId] = 'raw_delete_failed';

    await expectLater(
      repository.deleteRawForTrip(oldTripId),
      throwsA(
        isA<DataManagementFailure>().having(
          (failure) => failure.code,
          'code',
          'raw_delete_failed',
        ),
      ),
    );

    expect(await _tripCount(database), 1);
    expect(await _chunkCount(database, oldTripId), 1);
  });

  test(
    'whole-trip deletion cascades only the isolated selected trip',
    () async {
      await _insertTrip(database, oldTripId, DateTime.utc(2026, 1, 1));
      await _insertTrip(database, newTripId, DateTime.utc(2026, 1, 28));
      await _insertChunk(database, oldTripId, 0, 100);
      await _insertChunk(database, newTripId, 0, 200);

      await database
          .into(database.tripAccountLinks)
          .insert(
            TripAccountLinksCompanion.insert(
              tripId: oldTripId,
              userId: '11111111-1111-4111-8111-111111111111',
              consentedAtMicros: 1,
              summaryVersion: 1,
            ),
          );
      await database
          .into(database.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              operationId: 'summary-operation',
              idempotencyKey: 'summary-key',
              entityType: 'trip_summary_v1',
              entityId: oldTripId,
              entityVersion: 1,
              operationType: 'insert_snapshot',
              state: 'pending',
              payloadJson: const Value('{}'),
              attemptCount: 0,
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      expect(await repository.deleteTrip(oldTripId), isTrue);

      expect(platform.deletedTripIds, [oldTripId]);
      expect(await _tripCount(database), 1);
      expect(await _chunkCount(database, oldTripId), 0);
      expect(await _chunkCount(database, newTripId), 1);
      expect(await database.select(database.tripAccountLinks).get(), isEmpty);
      expect(await database.select(database.syncQueue).get(), isEmpty);
    },
  );

  test('active synthetic trip cannot be deleted', () async {
    await _insertTrip(
      database,
      activeTripId,
      DateTime.utc(2026, 2, 2),
      finalized: false,
    );

    await expectLater(
      repository.deleteTrip(activeTripId),
      throwsA(isA<DataManagementFailure>()),
    );
    expect(platform.deletedTripIds, isEmpty);
    expect(await _tripCount(database), 1);
  });
}

class _FakeDataManagementPlatform implements DataManagementPlatform {
  final Map<String, int> bytesByTrip = {};
  final Map<String, String> failures = {};
  final List<String> deletedTripIds = [];

  @override
  Future<RawTelemetryDeletionResult> deleteRawTelemetry(String tripId) async {
    deletedTripIds.add(tripId);
    final error = failures[tripId];
    return RawTelemetryDeletionResult(
      tripId: tripId,
      deleted: error == null,
      bytesDeleted: error == null ? (bytesByTrip[tripId] ?? 0) : 0,
      errorCode: error,
    );
  }

  @override
  Future<RedactedTripExportResult> exportRedactedTripSummary(
    RedactedTripExportPayload payload,
  ) {
    throw UnimplementedError();
  }
}

Future<void> _insertTrip(
  AppDatabase database,
  String id,
  DateTime startedAtUtc, {
  bool finalized = true,
}) {
  final startMicros = startedAtUtc.microsecondsSinceEpoch;
  return database
      .into(database.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          vehicleId: 'vehicle-one',
          startWallTimeMicros: startMicros,
          endWallTimeMicros: Value(finalized ? startMicros + 60000000 : null),
          startElapsedNanos: 1000000000,
          endElapsedNanos: Value(finalized ? 61000000000 : null),
          durationMillis: Value(finalized ? 60000 : null),
          completionState: finalized ? 'completed' : 'recording',
          recoveryState: 'not_needed',
          telemetrySchemaVersion: 1,
          integrityStatus: 'unassessed',
          cloudSyncState: 'local_only',
          createdAtMicros: startMicros,
          updatedAtMicros: startMicros,
        ),
      );
}

Future<void> _insertChunk(
  AppDatabase database,
  String tripId,
  int sequence,
  int bytes,
) {
  return database
      .into(database.tripChunks)
      .insert(
        TripChunksCompanion.insert(
          tripId: tripId,
          sequence: sequence,
          storageReference: 'recorder/trips/$tripId/chunks/$sequence.tlxc',
          encodingVersion: 1,
          startElapsedNanos: sequence * 1000000000,
          endElapsedNanos: (sequence + 1) * 1000000000,
          channelSampleCountsJson: jsonEncode({
            'gnss': 1,
            'accelerometer': 2,
            'gyroscope': 2,
          }),
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

Future<int> _tripCount(AppDatabase database) async =>
    (await database.select(database.trips).get()).length;

Future<int> _chunkCount(AppDatabase database, String tripId) async =>
    (await (database.select(
      database.tripChunks,
    )..where((row) => row.tripId.equals(tripId))).get()).length;

const oldTripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const newTripId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const activeTripId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
