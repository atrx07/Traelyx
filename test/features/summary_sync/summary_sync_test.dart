import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_service.dart';
import 'package:traelyx/features/summary_sync/data/summary_sync_repository.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

const userA = '11111111-1111-4111-8111-111111111111';
const userB = '22222222-2222-4222-8222-222222222222';
const tripA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const tripB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  late AppDatabase db;
  late SummarySyncRepository repository;
  late TestAccount account;
  late TestCloud cloud;
  late SummarySyncService service;
  late DateTime now;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = SummarySyncRepository(db);
    account = TestAccount();
    cloud = TestCloud();
    now = DateTime.utc(2026, 9, 26);
    service = SummarySyncService(repository, cloud, account, clock: () => now);
    await seedTrip(db, tripA);
  });
  tearDown(() => db.close());

  test(
    'review is local; payload is allowlisted and absent evidence stays null',
    () async {
      final preview = await service.preview(userA);
      expect(cloud.calls, isEmpty);
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
      final json = preview.candidates.single.toJson();
      expect(json.keys.toSet(), {
        'user_id',
        'source_trip_id',
        'summary_version',
        'duration_seconds',
        'distance_m',
        'score_overall',
        'scoring_version',
        'event_count',
      });
      expect(json['duration_seconds'], 12);
      expect(json['score_overall'], isNull);
      expect(json['event_count'], isNull);
      expect(jsonEncode(json), isNot(contains('precise-private')));
      expect(
        () => CompactTripSummary.fromJson({...json, 'route': []}),
        throwsFormatException,
      );
      expect(
        () => CompactTripSummary(
          userId: userA,
          tripId: tripA,
          distanceMeters: double.nan,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'known score/version and active event count remain bounded and paired',
    () async {
      await (db.update(db.trips)..where((t) => t.id.equals(tripA))).write(
        const TripsCompanion(
          eventEngineVersion: Value('events-v1'),
          distanceMeters: Value(1234.56),
        ),
      );
      await db
          .into(db.tripScores)
          .insert(
            TripScoresCompanion.insert(
              id: 'score-one',
              tripId: tripA,
              scoreSchemaVersion: 1,
              scoringVersion: 'score-v1',
              dimensionValuesJson: '{"private":"excluded"}',
              overallScore: const Value(83.257),
              eligibilityState: 'provisional',
              auditContributionsJson: '{"private":"excluded"}',
              createdAtMicros: 1,
            ),
          );
      for (final version in ['events-v1', 'events-v0']) {
        await db
            .into(db.tripEvents)
            .insert(
              TripEventsCompanion.insert(
                id: version,
                tripId: tripA,
                eventType: 'event',
                startElapsedNanos: 1,
                peakElapsedNanos: 2,
                endElapsedNanos: 3,
                severity: 0.5,
                severityCalibrationVersion: 'severity-v1',
                confidence: 0.5,
                qualityFlagsJson: '[]',
                primaryMeasurementsJson: '{"private":"excluded"}',
                ruleEvidenceJson: '{}',
                contextTagsJson: '[]',
                algorithmVersion: version,
                createdAtMicros: 1,
              ),
            );
      }
      final summary = (await service.preview(userA)).candidates.single;
      expect(summary.overallScore, 83.26);
      expect(summary.scoringVersion, 'score-v1');
      expect(summary.distanceMeters, 1234.6);
      expect(summary.eventCount, 1);
      expect(jsonEncode(summary.toJson()), isNot(contains('private')));
    },
  );

  test(
    'an old in-flight acknowledgement cannot complete a newly reviewed queue item',
    () async {
      await service.consent(await service.preview(userA));
      cloud.onUpload = () async {
        await service.cancelPending(userA);
        await (db.update(db.trips)..where((t) => t.id.equals(tripA))).write(
          const TripsCompanion(durationMillis: Value(9000)),
        );
        await service.consent(await service.preview(userA));
      };
      await service.syncPending(userA);
      final pending = await db.select(db.syncQueue).getSingle();
      expect(pending.state, 'pending');
      expect(jsonDecode(pending.payloadJson!)['duration_seconds'], 9);
      expect(
        (await db.select(db.trips).getSingle()).cloudSyncState,
        'summary_pending',
      );
    },
  );

  test(
    'consent links and queues atomically; repeated consent is idempotent',
    () async {
      final reviewed = await service.preview(userA);
      await service.consent(reviewed);
      await service.consent(reviewed);
      await seedTrip(db, tripB);
      expect(await db.select(db.syncQueue).get(), hasLength(1));
      expect(await db.select(db.tripAccountLinks).get(), hasLength(1));
      expect((await service.preview(userA)).candidates.single.tripId, tripB);
      expect(
        (await db.select(db.vehicles).getSingle()).ownerNamespace,
        'local:anonymous',
      );
      final states = {
        for (final trip in await db.select(db.trips).get())
          trip.id: trip.cloudSyncState,
      };
      expect(states, {tripA: 'summary_pending', tripB: 'local_only'});
    },
  );

  test(
    'a changed reviewed trip rolls back the entire consent transaction',
    () async {
      await seedTrip(db, tripB);
      final reviewed = await service.preview(userA);
      await (db.update(db.trips)..where((t) => t.id.equals(tripB))).write(
        const TripsCompanion(durationMillis: Value(20000)),
      );
      await expectLater(
        service.consent(reviewed),
        throwsA(isA<SummarySyncException>()),
      );
      expect(await db.select(db.syncQueue).get(), isEmpty);
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
    },
  );

  test(
    'account switching cannot claim or upload another account queue',
    () async {
      final reviewed = await service.preview(userA);
      account.user = userB;
      await expectLater(
        service.consent(reviewed),
        throwsA(isA<SummarySyncException>()),
      );
      account.user = userA;
      await service.consent(reviewed);
      account.user = userB;
      final other = await service.preview(userB);
      expect(other.candidates, isEmpty);
      expect(other.otherAccount, 1);
      await service.syncPending(userB);
      expect(cloud.calls, isEmpty);
      account.user = userA;
      expect((await service.syncPending(userA)).uploaded, 1);
    },
  );

  test(
    'lost acknowledgement survives restart and backoff without duplicate',
    () async {
      await service.consent(await service.preview(userA));
      cloud.loseAcknowledgement = true;
      expect((await service.syncPending(userA)).failed, 1);
      expect(cloud.rows, hasLength(1));
      await service.syncPending(userA);
      expect(cloud.calls, hasLength(1));
      service = SummarySyncService(
        SummarySyncRepository(db),
        cloud,
        account,
        clock: () => now,
      );
      now = now.add(const Duration(seconds: 31));
      expect((await service.syncPending(userA)).uploaded, 1);
      expect(cloud.rows, hasLength(1));
      expect((await repository.preview(userA)).synced, 1);
    },
  );

  test(
    'account change during an upload stops later requests and preserves retry',
    () async {
      await seedTrip(db, tripB);
      await service.consent(await service.preview(userA));
      cloud.onUpload = () async {
        account.user = userB;
      };
      await expectLater(
        service.syncPending(userA),
        throwsA(isA<SummarySyncException>()),
      );
      expect(cloud.calls, hasLength(1));
      expect(
        (await db.select(db.syncQueue).get()).every(
          (q) => q.state == 'pending',
        ),
        isTrue,
      );
    },
  );

  test(
    'partial failure is durable and repeated presses respect backoff',
    () async {
      await seedTrip(db, tripB);
      await service.consent(await service.preview(userA));
      cloud.fail = true;
      final result = await service.syncPending(userA);
      expect(result.failed, 1);
      final queued = await db.select(db.syncQueue).get();
      expect(queued.where((q) => q.attemptCount == 1), hasLength(1));
      expect(queued.where((q) => q.attemptCount == 0), hasLength(1));
      expect(
        queued.firstWhere((q) => q.attemptCount == 1).nextAttemptAtMicros,
        now.add(const Duration(seconds: 30)).microsecondsSinceEpoch,
      );
    },
  );

  test(
    'cancel removes pending payloads but preserves account ownership',
    () async {
      await service.consent(await service.preview(userA));
      await service.cancelPending(userA);
      await service.syncPending(userA);
      expect(cloud.calls, isEmpty);
      expect(await db.select(db.syncQueue).get(), isEmpty);
      expect((await db.select(db.tripAccountLinks).getSingle()).userId, userA);
      account.user = userB;
      expect((await service.preview(userB)).candidates, isEmpty);
    },
  );

  test(
    'deleted trip or malformed payload can never reach cloud gateway',
    () async {
      await service.consent(await service.preview(userA));
      final row = await db.select(db.syncQueue).getSingle();
      final payload = jsonDecode(row.payloadJson!) as Map<String, dynamic>;
      payload['precise_route'] = <Object>[];
      await (db.update(db.syncQueue)
            ..where((q) => q.operationId.equals(row.operationId)))
          .write(SyncQueueCompanion(payloadJson: Value(jsonEncode(payload))));
      expect((await service.syncPending(userA)).failed, 1);
      expect(cloud.calls, isEmpty);
      expect((await db.select(db.syncQueue).getSingle()).state, 'blocked');
      await service.cancelPending(userA);
      await service.consent(await service.preview(userA));
      await (db.delete(db.trips)..where((t) => t.id.equals(tripA))).go();
      await service.syncPending(userA);
      expect(cloud.calls, isEmpty);
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
    },
  );

  test(
    'queued summaries survive closing and reopening the SQLite file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'traelyx-summary-sync-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/state.sqlite');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      await seedTrip(db, tripA);
      service = SummarySyncService(
        SummarySyncRepository(db),
        cloud,
        account,
        clock: () => now,
      );
      await service.consent(await service.preview(userA));
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final restored = SummarySyncService(
        SummarySyncRepository(db),
        cloud,
        account,
        clock: () => now,
      );
      expect((await restored.preview(userA)).pending, 1);
      expect((await restored.syncPending(userA)).uploaded, 1);
      expect((await db.select(db.trips).getSingle()).id, tripA);
      await db.close();
    },
  );
}

Future<void> seedTrip(AppDatabase db, String id) async {
  await db
      .into(db.vehicles)
      .insert(
        VehiclesCompanion.insert(
          id: 'local-vehicle',
          ownerNamespace: 'local:anonymous',
          displayName: 'precise-private label',
          vehicleType: 'unspecified',
          createdAtMicros: 1,
          updatedAtMicros: 1,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          vehicleId: 'local-vehicle',
          startWallTimeMicros: 1,
          endWallTimeMicros: const Value(12345001),
          startElapsedNanos: 1,
          endElapsedNanos: const Value(12345000001),
          durationMillis: const Value(12345),
          completionState: 'completed',
          recoveryState: 'clean',
          telemetrySchemaVersion: 1,
          integrityStatus: 'unknown',
          telemetryQualitySummaryJson: const Value(
            '{"precise-private":"do not upload"}',
          ),
          cloudSyncState: 'local_only',
          createdAtMicros: 1,
          updatedAtMicros: 2,
        ),
      );
}

class TestAccount implements AccountGateway {
  String? user = userA;
  @override
  bool get isAvailable => true;
  @override
  AccountIdentity? get currentIdentity => user == null
      ? null
      : AccountIdentity(userId: user!, email: 'driver@example.com');
  @override
  Stream<AccountIdentity?> get identityChanges => const Stream.empty();
  @override
  Future<void> sendSignInLink(String email) async {}
  @override
  Future<void> refreshSession() async {}
  @override
  Future<void> signOut() async {
    user = null;
  }
}

class TestCloud implements SummaryCloudGateway {
  final calls = <CompactTripSummary>[];
  final rows = <String, CompactTripSummary>{};
  bool fail = false;
  bool loseAcknowledgement = false;
  Future<void> Function()? onUpload;
  @override
  Future<void> upload(CompactTripSummary summary) async {
    calls.add(summary);
    if (fail) throw const SummarySyncException(SummaryFailure.connection);
    final key = '${summary.userId}:${summary.tripId}';
    rows.putIfAbsent(key, () => summary);
    if (!rows[key]!.sameContent(summary)) {
      throw const SummarySyncException(SummaryFailure.conflict);
    }
    await onUpload?.call();
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw const SummarySyncException(SummaryFailure.connection);
    }
  }
}
