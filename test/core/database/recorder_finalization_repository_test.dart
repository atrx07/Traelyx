import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

import '../platform/recorder_bridge_test.dart' show finalizationBatchMap;

void main() {
  late AppDatabase database;
  late DriftRecorderFinalizationRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftRecorderFinalizationRepository(database);
  });

  tearDown(() => database.close());

  test(
    'reconciles trip and verified chunks atomically and idempotently',
    () async {
      final finalization = _finalization();

      await repository.reconcile(finalization);
      await repository.reconcile(finalization);

      final vehicle = await database.select(database.vehicles).getSingle();
      final trip = await database.select(database.trips).getSingle();
      final chunk = await database.select(database.tripChunks).getSingle();
      final quality =
          jsonDecode(trip.telemetryQualitySummaryJson!) as Map<String, Object?>;

      expect(vehicle.id, recorderPlaceholderVehicleId);
      expect(vehicle.ownerNamespace, recorderPlaceholderOwnerNamespace);
      expect(trip.id, finalization.tripId);
      expect(trip.completionState, 'completed');
      expect(trip.recoveryState, 'recovered');
      expect(trip.durationMillis, 100);
      expect(quality['finalizationLogicVersion'], 1);
      expect(quality['validChunkCount'], 1);
      expect(chunk.sequence, 0);
      expect(chunk.writeState, 'complete');
      expect(
        chunk.channelSampleCountsJson,
        '{"gnss":1,"accelerometer":10,"gyroscope":10}',
      );
    },
  );

  test('replay preserves a later user vehicle assignment', () async {
    final finalization = _finalization();
    await repository.reconcile(finalization);
    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'user-vehicle',
            ownerNamespace: 'local:user',
            displayName: 'My bike',
            vehicleType: 'motorcycle',
            createdAtMicros: 1,
            updatedAtMicros: 1,
          ),
        );
    await (database.update(database.trips)
          ..where((row) => row.id.equals(finalization.tripId)))
        .write(const TripsCompanion(vehicleId: Value('user-vehicle')));

    await repository.reconcile(finalization);

    expect(
      (await database.select(database.trips).getSingle()).vehicleId,
      'user-vehicle',
    );
  });

  test('validation failure leaves no partially indexed trip', () async {
    final base =
        (finalizationBatchMap['finalizations']! as List<Object?>).single
            as Map<Object?, Object?>;
    final first =
        (base['chunks']! as List<Object?>).single as Map<Object?, Object?>;
    final second = <Object?, Object?>{
      ...first,
      'sequence': 1,
      'storageReference':
          'recorder/trips/${base['tripId']}/chunks/0000000001.tlxc',
      'startElapsedNanos': 100000001,
      'endElapsedNanos': 200000000,
      'telemetrySchemaVersion': 2,
    };
    final malformed = <Object?, Object?>{
      ...base,
      'endElapsedRealtimeNanos': 1187654321,
      'durationMillis': 200,
      'chunks': <Object?>[first, second],
    };
    final finalization = RecorderTripFinalization.fromMap(malformed);

    await expectLater(
      repository.reconcile(finalization),
      throwsA(isA<FormatException>()),
    );

    expect(await database.select(database.vehicles).get(), isEmpty);
    expect(await database.select(database.trips).get(), isEmpty);
    expect(await database.select(database.tripChunks).get(), isEmpty);
  });
}

RecorderTripFinalization _finalization() {
  return RecorderFinalizationBatch.fromMap(
    finalizationBatchMap,
  ).finalizations.single;
}
