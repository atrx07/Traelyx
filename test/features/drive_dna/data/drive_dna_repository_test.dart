import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/drive_dna/data/drive_dna_repository.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';

void main() {
  late AppDatabase database;
  late DriftDriveDnaRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftDriveDnaRepository(database);
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

  test('empty baseline table is a truthful unavailable state', () async {
    expect(await repository.watchLatest().first, isNull);
  });

  test('latest snapshot maps governed dimensions without opaque IDs', () async {
    await _insertBaseline(
      database,
      id: 'older-private-id',
      updatedAtMicros: 10,
      lifecycleState: 'emerging',
      validTripCount: 4,
      dimensionJson: _dimensionPayload(availableCount: 1),
    );
    await _insertBaseline(
      database,
      id: 'newer-private-id',
      updatedAtMicros: 20,
      lifecycleState: 'established',
      validTripCount: 12,
      dimensionJson: _dimensionPayload(availableCount: 5),
      confidence: 0.8,
      windowStartMicros: 1000000,
      windowEndMicros: 2000000,
    );

    final snapshot = await repository.watchLatest().first;

    expect(snapshot, isNotNull);
    expect(snapshot!.vehicleLabel, 'Local bike');
    expect(snapshot.lifecycleState, DriveDnaLifecycleState.established);
    expect(snapshot.profileState, DriveDnaProfileState.complete);
    expect(snapshot.validTripCount, 12);
    expect(snapshot.driveDnaVersion, 1);
    expect(snapshot.baselineSchemaVersion, 1);
    expect(snapshot.scoringVersion, 'scoring-v1');
    expect(snapshot.confidenceRecorded, isTrue);
    expect(snapshot.dimensions, hasLength(5));
    expect(snapshot.dimensions.first.valueMilliPoints, 76000);
    expect(snapshot.dimensions.first.recentDeltaMilliPoints, 2000);
    expect(
      snapshot.windowStartUtc,
      DateTime.fromMicrosecondsSinceEpoch(1000000, isUtc: true),
    );
    expect(
      snapshot.windowEndUtc,
      DateTime.fromMicrosecondsSinceEpoch(2000000, isUtc: true),
    );
  });

  test('partial snapshot keeps insufficient dimensions unavailable', () async {
    await _insertBaseline(
      database,
      id: 'partial',
      updatedAtMicros: 10,
      lifecycleState: 'emerging',
      validTripCount: 6,
      dimensionJson: _dimensionPayload(availableCount: 2),
    );

    final snapshot = await repository.watchLatest().first;

    expect(snapshot!.profileState, DriveDnaProfileState.partial);
    expect(snapshot.dimensions[1].state, DriveDnaDimensionState.available);
    expect(
      snapshot.dimensions[2].state,
      DriveDnaDimensionState.insufficientData,
    );
    expect(snapshot.dimensions[2].value, isNull);
    expect(snapshot.confidenceRecorded, isFalse);
  });

  test('malformed and unknown evidence fails closed', () async {
    final malformedPayloads = [
      '{not-json',
      jsonEncode({'driveDnaVersion': 1, 'dimensions': <String, Object?>{}}),
      _dimensionPayload(availableCount: 5, unknownTopField: true),
      _dimensionPayload(availableCount: 5, scoreOutOfRange: true),
      _dimensionPayload(availableCount: 2, unavailableHasValue: true),
      _dimensionPayload(availableCount: 5, unknownDimensionState: true),
    ];

    for (var index = 0; index < malformedPayloads.length; index++) {
      await database.delete(database.driverBaselines).go();
      await _insertBaseline(
        database,
        id: 'bad-$index',
        updatedAtMicros: index,
        lifecycleState: 'emerging',
        validTripCount: 8,
        dimensionJson: malformedPayloads[index],
      );
      await expectLater(
        repository.watchLatest().first,
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('unknown lifecycle and partial history window fail closed', () async {
    await _insertBaseline(
      database,
      id: 'bad-lifecycle',
      updatedAtMicros: 1,
      lifecycleState: 'confident',
      validTripCount: 5,
      dimensionJson: _dimensionPayload(availableCount: 1),
    );
    await expectLater(
      repository.watchLatest().first,
      throwsA(isA<FormatException>()),
    );

    await database.delete(database.driverBaselines).go();
    await _insertBaseline(
      database,
      id: 'bad-window',
      updatedAtMicros: 2,
      lifecycleState: 'emerging',
      validTripCount: 5,
      dimensionJson: _dimensionPayload(availableCount: 1),
      windowStartMicros: 1000000,
    );
    await expectLater(
      repository.watchLatest().first,
      throwsA(isA<FormatException>()),
    );
  });

  test('governed evidence and lifecycle contradictions fail closed', () async {
    final contradictions = [
      (
        id: 'established-too-early',
        lifecycle: 'established',
        validTrips: 6,
        availableDimensions: 5,
      ),
      (
        id: 'emerging-with-established-profile',
        lifecycle: 'emerging',
        validTrips: 10,
        availableDimensions: 5,
      ),
      (
        id: 'uncalibrated-with-evidence',
        lifecycle: 'uncalibrated',
        validTrips: 1,
        availableDimensions: 0,
      ),
      (
        id: 'cohort-over-limit',
        lifecycle: 'emerging',
        validTrips: 31,
        availableDimensions: 1,
      ),
      (
        id: 'consistency-without-three-direct-dimensions',
        lifecycle: 'emerging',
        validTrips: 6,
        availableDimensions: 1,
      ),
    ];

    for (final contradiction in contradictions) {
      await database.delete(database.driverBaselines).go();
      await _insertBaseline(
        database,
        id: contradiction.id,
        updatedAtMicros: 1,
        lifecycleState: contradiction.lifecycle,
        validTripCount: contradiction.validTrips,
        dimensionJson: _dimensionPayload(
          availableCount: contradiction.availableDimensions,
          consistencyAvailable:
              contradiction.id == 'consistency-without-three-direct-dimensions',
        ),
      );
      await expectLater(
        repository.watchLatest().first,
        throwsA(isA<FormatException>()),
      );
    }
  });
}

Future<void> _insertBaseline(
  AppDatabase database, {
  required String id,
  required int updatedAtMicros,
  required String lifecycleState,
  required int validTripCount,
  required String dimensionJson,
  double? confidence,
  int? windowStartMicros,
  int? windowEndMicros,
}) {
  return database
      .into(database.driverBaselines)
      .insert(
        DriverBaselinesCompanion.insert(
          id: id,
          ownerNamespace: 'local:private-owner',
          vehicleId: const Value('vehicle-one'),
          lifecycleState: lifecycleState,
          dimensionStatisticsJson: dimensionJson,
          baselineSchemaVersion: 1,
          scoringVersion: 'scoring-v1',
          validTripCount: validTripCount,
          windowStartWallTimeMicros: Value(windowStartMicros),
          windowEndWallTimeMicros: Value(windowEndMicros),
          confidence: Value(confidence),
          createdAtMicros: 1,
          updatedAtMicros: updatedAtMicros,
        ),
      );
}

String _dimensionPayload({
  required int availableCount,
  bool unknownTopField = false,
  bool scoreOutOfRange = false,
  bool unavailableHasValue = false,
  bool unknownDimensionState = false,
  bool consistencyAvailable = false,
}) {
  const keys = [
    'smoothness',
    'braking_control',
    'acceleration_control',
    'cornering_control',
    'consistency',
  ];
  final dimensions = <String, Object?>{};
  for (var index = 0; index < keys.length; index++) {
    final available =
        index < availableCount || (consistencyAvailable && index == 4);
    dimensions[keys[index]] = <String, Object?>{
      'state': unknownDimensionState && index == 0
          ? 'estimated'
          : available
          ? 'available'
          : 'insufficient_data',
      'eligibleTripCount': available ? 6 : 2,
      if (available || (unavailableHasValue && index == availableCount))
        'valueMilliPoints': scoreOutOfRange && index == 0 ? 100001 : 76000,
      if (available) 'recentDeltaMilliPoints': 2000,
    };
  }
  final payload = <String, Object?>{
    'driveDnaVersion': 1,
    'dimensions': dimensions,
    if (unknownTopField) 'owner': 'must-not-be-accepted',
  };
  return jsonEncode(payload);
}
