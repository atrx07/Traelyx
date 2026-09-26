import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/features/trip_analysis/local_trip_analysis.dart';

import '../../core/platform/recorder_bridge_test.dart'
    show finalizationBatchMap, tripId;

void main() {
  late AppDatabase db;
  late FakeAnalysis gateway;
  late LocalAnalysisService service;
  final finalization = RecorderFinalizationBatch.fromMap(
    finalizationBatchMap,
  ).finalizations.single;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DriftRecorderFinalizationRepository(db).reconcile(finalization);
    gateway = FakeAnalysis();
    service = LocalAnalysisService(db, gateway);
  });
  tearDown(() => db.close());

  test(
    'atomic local analysis preserves trip, chunks and cloud consent',
    () async {
      await service.analyze(tripId, 'top');
      final score = await db.select(db.tripScores).getSingle();
      final trip = await db.select(db.trips).getSingle();
      expect(score.overallScore, isNull);
      expect(score.eligibilityState, 'unavailable');
      expect(score.confidence, isNull);
      expect(trip.distanceMeters, 0);
      expect(trip.scoringVersion, '1');
      expect(trip.integrityStatus, 'limited_confidence');
      expect(await db.select(db.tripChunks).get(), hasLength(1));
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
      expect(await db.select(db.syncQueue).get(), isEmpty);
      expect(jsonDecode(score.auditContributionsJson)['forwardAxis'], 'top');
      await expectLater(service.analyze(tripId, 'right'), throwsStateError);
      expect(gateway.calls, 1);
      await DriftRecorderFinalizationRepository(db).reconcile(finalization);
      final replay = await db.select(db.trips).getSingle();
      expect(replay.integrityStatus, 'limited_confidence');
      expect(replay.scoringVersion, '1');
      expect(replay.distanceMeters, 0);
    },
  );

  test('missing raw evidence never invokes native analysis', () async {
    await db.delete(db.tripChunks).go();
    await expectLater(service.analyze(tripId, 'top'), throwsStateError);
    expect(gateway.calls, 0);
  });

  test('deletion while native analysis runs never resurrects a trip', () async {
    gateway.wait = Completer<void>();
    final operation = service.analyze(tripId, 'top');
    await gateway.started.future;
    await db.delete(db.trips).go();
    gateway.wait!.complete();
    await expectLater(operation, throwsStateError);
    expect(await db.select(db.tripScores).get(), isEmpty);
  });

  test(
    'changed chunk index and identity mismatch fail without partial writes',
    () async {
      gateway.payload['sourceChunkCount'] = 2;
      await expectLater(service.analyze(tripId, 'top'), throwsFormatException);
      expect(await db.select(db.tripScores).get(), isEmpty);
      expect((await db.select(db.trips).getSingle()).scoringVersion, isNull);
      gateway.payload = analysisFixture();
      await service.analyze(tripId, 'top');
      expect(await db.select(db.tripScores).get(), hasLength(1));
    },
  );

  test('invalid event rolls back score and trip changes', () async {
    gateway.payload['events'] = [
      {
        'id': 'bad',
        'type': 'EVT_BRAKE_STRONG',
        'startNanos': 10,
        'peakNanos': 5,
        'endNanos': 20,
        'confidence': 'SUPPORTED',
        'activationRatio': 1.0,
      },
    ];
    await expectLater(service.analyze(tripId, 'top'), throwsFormatException);
    expect(await db.select(db.tripScores).get(), isEmpty);
    expect(await db.select(db.tripEvents).get(), isEmpty);
  });

  test(
    'concurrent local requests are rejected and existing historic scores preserved',
    () async {
      gateway.wait = Completer<void>();
      final first = service.analyze(tripId, 'top');
      await gateway.started.future;
      await expectLater(service.analyze(tripId, 'top'), throwsStateError);
      await db
          .into(db.tripScores)
          .insert(
            TripScoresCompanion.insert(
              id: 'historic',
              tripId: tripId,
              scoreSchemaVersion: 1,
              scoringVersion: 'historic',
              dimensionValuesJson: '{}',
              eligibilityState: 'unavailable',
              auditContributionsJson: '{}',
              createdAtMicros: 1,
            ),
          );
      gateway.wait!.complete();
      await expectLater(first, throwsStateError);
      expect((await db.select(db.tripScores).getSingle()).id, 'historic');
    },
  );
}

Map<String, dynamic> analysisFixture() => {
  'analysisVersion': 1,
  'tripId': tripId,
  'forwardAxis': 'top',
  'sourceDigest': 'a' * 64,
  'sourceChunkCount': 1,
  'sourceChunks': [
    [
      0,
      0,
      100000000,
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      1024,
      1,
      10,
      10,
      1786200001000,
    ],
  ],
  'sourceStartNanos': 0,
  'sourceEndNanos': 100000000,
  'distanceMeters': 0,
  'events': <dynamic>[],
  'score': {
    'scoringVersion': 1,
    'state': 'unavailable',
    'overallMilliPoints': null,
    'integrity': {
      'version': 1,
      'state': 'limited_confidence',
      'findings': <Object?>[],
    },
    'dimensions': {
      for (final d in [
        'SCORE_SMOOTHNESS',
        'SCORE_BRAKING_CONTROL',
        'SCORE_ACCELERATION_CONTROL',
        'SCORE_CORNERING_CONTROL',
        'SCORE_CONSISTENCY',
      ])
        d: {
          'state': 'unavailable',
          'movingNanos': 0,
          'opportunityNanos': 0,
          'usableNanos': 0,
          'fullyEligibleNanos': 0,
        },
    },
  },
};

class FakeAnalysis implements LocalAnalysisGateway {
  Map<String, dynamic> payload = analysisFixture();
  int calls = 0;
  Completer<void>? wait;
  final started = Completer<void>();
  @override
  Future<Map<String, dynamic>> analyze(
    String tripId,
    String forwardAxis,
  ) async {
    calls++;
    if (!started.isCompleted) started.complete();
    await wait?.future;
    return payload;
  }
}
