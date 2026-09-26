import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/rankings/ranking_models.dart';
import 'package:traelyx/features/rankings/ranking_screen.dart';
import 'package:traelyx/features/rankings/ranking_service.dart';
import '../summary_sync/summary_sync_test.dart'
    show TestAccount, userA, userB, tripA, seedTrip;

Map<String, dynamic> eligibleAudit() => {
  'analysisVersion': 1,
  'versions': rankingVersions,
  'sourceDigest': 'a' * 64,
  'calibrationState': 'CALIBRATED',
  'subsequentCalibrationState': 'CALIBRATED',
  'comparisonState': 'CONSISTENT',
  'completionState': 'completed',
  'recoveryState': 'not_needed',
  'finalizationQuality': {
    'recoveryCount': 0,
    'corruptChunkCount': 0,
    'orphanedWriteCount': 0,
    'orderingViolationCount': 0,
    'qualityFlags': <Object?>[],
  },
  'score': {
    'scoringVersion': 1,
    'state': 'full',
    'rankingStatus': 'ELIGIBLE',
    'integrity': {'version': 1, 'state': 'verified', 'findings': <Object?>[]},
    'dimensions': {
      for (final name in rankingDimensions)
        name: {
          'state': 'full',
          'movingNanos': 90000000000,
          'opportunityNanos': name == rankingDimensions.first
              ? 90000000000
              : 2000000000,
          'usableNanos': name == rankingDimensions.first
              ? 90000000000
              : 2000000000,
          'fullyEligibleNanos': name == rankingDimensions.first
              ? 90000000000
              : 2000000000,
          'provisionalReasons': <Object?>[],
          'unavailableReasons': <Object?>[],
        },
    },
  },
  'events': <Map<String, dynamic>>[],
};

class FakeRankings implements RankingGateway {
  int reads = 0, writes = 0, withdrawals = 0;
  final ids = <String>{};
  final payloads = <String>[];
  bool loseReply = false;
  Future<void> Function()? onLoad;
  Future<void> Function()? onSubmit;
  @override
  Future<RankingSnapshot> load(String owner) async {
    reads++;
    await onLoad?.call();
    return RankingSnapshot(
      rows: [],
      submittedIds: {...ids},
      username: 'rank_alice',
      displayName: 'Alice',
      vehicleClasses: ['car'],
    );
  }

  @override
  Future<void> submit(
    String owner,
    String username,
    String displayName,
    RankingCandidate candidate,
  ) async {
    writes++;
    ids.add(candidate.tripId);
    payloads.add(candidate.encodedEvidence);
    await onSubmit?.call();
    if (loseReply) {
      loseReply = false;
      throw StateError('sensitive provider data');
    }
  }

  @override
  Future<void> withdraw(String owner) async {
    withdrawals++;
    ids.clear();
  }
}

void main() {
  late AppDatabase db;
  late TestAccount account;
  late FakeRankings cloud;
  late RankingService service;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    account = TestAccount();
    cloud = FakeRankings();
    service = RankingService(db, account, cloud);
    await seedTrip(db, tripA);
    await (db.update(db.trips)..where((t) => t.id.equals(tripA))).write(
      const TripsCompanion(
        durationMillis: Value(120000),
        recoveryState: Value('not_needed'),
        integrityStatus: Value('verified'),
        scoringVersion: Value('1'),
        eventEngineVersion: Value('1'),
      ),
    );
    await db
        .into(db.tripScores)
        .insert(
          TripScoresCompanion.insert(
            id: 'analysis-v1-$tripA',
            tripId: tripA,
            scoreSchemaVersion: 1,
            scoringVersion: '1',
            dimensionValuesJson: '{}',
            eligibilityState: 'full',
            auditContributionsJson: jsonEncode(eligibleAudit()),
            createdAtMicros: 1,
          ),
        );
  });
  tearDown(() => db.close());

  test(
    'dossier excludes private audit, event identifiers, positions and dates',
    () {
      final a = eligibleAudit()
        ..addAll({
          'latitude': 12,
          'email': 'private',
          'referenceCalibration': 'private',
        });
      a['events'] = [
        {
          'id': 'private-event-id',
          'type': 'EVT_BRAKE_ABRUPT_TRANSITION',
          'startNanos': 5,
          'activationRatio': 1.2345,
          'confidence': 'SUPPORTED',
          'measurements': 'private',
        },
      ];
      final d = RankingCandidate.fromAudit(a, 120000);
      expect(d.keys.toSet(), {
        'versions',
        'source_digest',
        'duration_ms',
        'moving_ms',
        'calibration',
        'integrity_counts',
        'dimensions',
        'events',
      });
      expect(d['events'], [
        [3, 1235, 1000],
      ]);
      expect(jsonEncode(d), isNot(contains('private')));
      expect(jsonEncode(d), isNot(contains('latitude')));
    },
  );
  test(
    'weak integrity, calibration, partial scores, recovery and future versions excluded',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (a) => a['score']['state'] = 'provisional',
        (a) => a['score']['integrity']['state'] = 'questionable',
        (a) => a['comparisonState'] = 'INDETERMINATE',
        (a) => a['recoveryState'] = 'recovered',
        (a) => a['versions'] = {...rankingVersions, 'scoring': 2},
        (a) =>
            a['score']['dimensions'][rankingDimensions
                    .first]['fullyEligibleNanos'] =
                0,
      ];
      for (final change in mutations) {
        final a = eligibleAudit();
        change(a);
        expect(
          () => RankingCandidate.fromAudit(a, 120000),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'local review never uploads; explicit consent binds account without summary queue',
    () async {
      final candidate = (await service.candidates(userA)).single;
      expect(cloud.writes, 0);
      expect(cloud.reads, 0);
      final snapshot = await service.load(userA);
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
      await service.submit(userA, snapshot, candidate, vehicleClass: 'car');
      expect(cloud.writes, 1);
      expect(jsonDecode(cloud.payloads.single)['vehicle_class'], 'car');
      expect((await db.select(db.tripAccountLinks).getSingle()).userId, userA);
      expect(await db.select(db.syncQueue).get(), isEmpty);
      account.user = userB;
      expect(await service.candidates(userB), isEmpty);
      await expectLater(
        service.submit(userA, snapshot, candidate, vehicleClass: 'car'),
        throwsStateError,
      );
      expect(cloud.writes, 1);
    },
  );
  test(
    'uncertain request preserves snapshot and explicit retry is identical',
    () async {
      final c = (await service.candidates(userA)).single;
      final s = await service.load(userA);
      cloud.loseReply = true;
      await expectLater(
        service.submit(userA, s, c, vehicleClass: 'car'),
        throwsStateError,
      );
      expect((await service.load(userA)).submittedIds, contains(tripA));
      await service.submit(userA, s, c, vehicleClass: 'car');
      expect(cloud.payloads[0], cloud.payloads[1]);
      await service.withdraw(userA);
      expect((await service.load(userA)).submittedIds, isEmpty);
      expect(await db.select(db.tripScores).get(), hasLength(1));
      expect(await db.select(db.tripAccountLinks).get(), hasLength(1));
    },
  );
  test(
    'changed account after read cannot return stale owner projection',
    () async {
      cloud.onLoad = () async {
        account.user = userB;
      };
      await expectLater(service.load(userA), throwsStateError);
    },
  );
  test('deleted local evidence cannot be submitted from old review', () async {
    final c = (await service.candidates(userA)).single;
    final s = await service.load(userA);
    await db.delete(db.trips).go();
    await expectLater(
      service.submit(userA, s, c, vehicleClass: 'car'),
      throwsStateError,
    );
    expect(cloud.writes, 0);
  });
  test('withdrawal cannot race a submission', () async {
    final c = (await service.candidates(userA)).single;
    final s = await service.load(userA);
    final started = Completer<void>(), finish = Completer<void>();
    cloud.onSubmit = () async {
      started.complete();
      await finish.future;
    };
    final pending = service.submit(userA, s, c, vehicleClass: 'car');
    await started.future;
    await expectLater(service.withdraw(userA), throwsStateError);
    finish.complete();
    await pending;
  });
  test(
    'projection rejects extra fields and impossible small-cohort scores',
    () {
      final row = {
        'username': 'driver',
        'display_name': 'Driver',
        'is_self': true,
        'sample_count': 3,
        'vehicle_class': 'car',
        'smoothness': 99,
        'consistency': 99,
        'improvement': 1,
      };
      expect(() => RankingRow.fromJson(row), throwsFormatException);
      expect(
        () => RankingRow.fromJson({
          ...row,
          'sample_count': 10,
          'email': 'private',
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'opening is inert; cancellation never submits; explicit confirmation submits',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            accountGatewayProvider.overrideWithValue(account),
            rankingGatewayProvider.overrideWithValue(cloud),
          ],
          child: const MaterialApp(home: Scaffold(body: RankingScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(cloud.reads, 0);
      expect(cloud.writes, 0);
      await tester.tap(find.text('Reload comparisons'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('car'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('current and future accepted friends'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep unchanged'));
      await tester.pumpAndSettle();
      expect(cloud.writes, 0);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('car'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share selected trip'));
      await tester.pumpAndSettle();
      expect(cloud.writes, 1);
      expect(find.text('Submission accepted.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
