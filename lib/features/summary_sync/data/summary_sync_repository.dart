import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

const summaryQueueEntity = 'trip_summary_v1';

class SummarySyncRepository {
  const SummarySyncRepository(this.database);
  final AppDatabase database;

  Future<SummarySyncPreview> preview(String userId) async {
    if (!CompactTripSummary.isUuid(userId)) {
      throw const SummarySyncException(SummaryFailure.accountChanged);
    }
    final links = {
      for (final link in await database.select(database.tripAccountLinks).get())
        link.tripId: link,
    };
    final queue = await (database.select(
      database.syncQueue,
    )..where((q) => q.entityType.equals(summaryQueueEntity))).get();
    final byTrip = {for (final item in queue) item.entityId: item};
    final trips =
        await (database.select(database.trips)..where(
              (t) =>
                  t.completionState.equals('completed') &
                  t.endWallTimeMicros.isNotNull(),
            ))
            .get();
    final candidates = <CompactTripSummary>[];
    var pending = 0;
    var synced = 0;
    var otherAccount = 0;
    int? nextRetry;
    for (final trip in trips) {
      final link = links[trip.id];
      if (link != null && link.userId != userId) {
        otherAccount++;
        continue;
      }
      final item = byTrip[trip.id];
      if (item != null) {
        if (link == null) continue; // Orphaned/unknown queue data fails closed.
        if (item.state == 'synced') {
          synced++;
        } else {
          pending++;
          final next = item.nextAttemptAtMicros;
          if (next != null && (nextRetry == null || next < nextRetry)) {
            nextRetry = next;
          }
        }
        continue;
      }
      final summary = await _summaryFor(trip, userId);
      if (summary != null) candidates.add(summary);
    }
    return SummarySyncPreview(
      userId: userId,
      candidates: candidates,
      pending: pending,
      synced: synced,
      otherAccount: otherAccount,
      nextRetryAt: nextRetry == null
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(nextRetry, isUtc: true),
    );
  }

  Future<CompactTripSummary?> _summaryFor(Trip trip, String userId) async {
    if (!CompactTripSummary.isUuid(trip.id)) return null;
    final scores =
        await (database.select(database.tripScores)
              ..where((s) => s.tripId.equals(trip.id))
              ..orderBy([
                (s) => OrderingTerm.desc(s.createdAtMicros),
                (s) => OrderingTerm.asc(s.id),
              ])
              ..limit(1))
            .get();
    final score = scores.firstOrNull;
    final countExpression = database.tripEvents.id.count();
    final eventCount = trip.eventEngineVersion == null
        ? null
        : await (database.selectOnly(database.tripEvents)
                ..addColumns([countExpression])
                ..where(
                  database.tripEvents.tripId.equals(trip.id) &
                      database.tripEvents.algorithmVersion.equals(
                        trip.eventEngineVersion!,
                      ),
                ))
              .map((r) => r.read(countExpression))
              .getSingle();
    try {
      return CompactTripSummary(
        userId: userId,
        tripId: trip.id,
        durationSeconds: trip.durationMillis == null
            ? null
            : (trip.durationMillis! / 1000).round(),
        distanceMeters: trip.distanceMeters == null
            ? null
            : (trip.distanceMeters! * 10).round() / 10,
        overallScore: score?.overallScore == null
            ? null
            : (score!.overallScore! * 100).round() / 100,
        scoringVersion: score?.overallScore == null
            ? null
            : score!.scoringVersion,
        eventCount: eventCount,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> enqueue(
    SummarySyncPreview reviewed,
    DateTime now,
    bool Function() currentAccount,
  ) => database.transaction(() async {
    final fresh = await preview(reviewed.userId);
    final available = {for (final item in fresh.candidates) item.tripId: item};
    for (final summary in reviewed.candidates) {
      if (!currentAccount()) {
        throw const SummarySyncException(SummaryFailure.accountChanged);
      }
      final existing = await (database.select(
        database.tripAccountLinks,
      )..where((l) => l.tripId.equals(summary.tripId))).getSingleOrNull();
      if (existing != null && existing.userId != reviewed.userId) {
        throw const SummarySyncException(SummaryFailure.accountChanged);
      }
      final queued =
          await (database.select(
                database.syncQueue,
              )..where((q) => q.operationId.equals(_operation(summary.tripId))))
              .getSingleOrNull();
      if (queued != null && existing?.userId == reviewed.userId) continue;
      if (available[summary.tripId]?.sameContent(summary) != true) {
        throw const SummarySyncException(SummaryFailure.invalidData);
      }
      await database
          .into(database.tripAccountLinks)
          .insert(
            TripAccountLinksCompanion.insert(
              tripId: summary.tripId,
              userId: summary.userId,
              consentedAtMicros: now.microsecondsSinceEpoch,
              summaryVersion: 1,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await database
          .into(database.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              operationId: _operation(summary.tripId),
              idempotencyKey:
                  '$summaryQueueEntity:${summary.userId}:${summary.tripId}',
              entityType: summaryQueueEntity,
              entityId: summary.tripId,
              entityVersion: 1,
              operationType: 'insert_snapshot',
              state: 'pending',
              payloadJson: Value(jsonEncode(summary.toJson())),
              attemptCount: 0,
              createdAtMicros: now.microsecondsSinceEpoch,
              updatedAtMicros: now.microsecondsSinceEpoch,
            ),
          );
      await (database.update(
        database.trips,
      )..where((t) => t.id.equals(summary.tripId))).write(
        const TripsCompanion(cloudSyncState: Value('summary_pending')),
      );
    }
    if (!currentAccount()) {
      throw const SummarySyncException(SummaryFailure.accountChanged);
    }
  });

  Future<List<SyncQueueData>> due(String userId, DateTime now) async {
    final rows =
        await (database.select(database.syncQueue)
              ..where(
                (q) =>
                    q.entityType.equals(summaryQueueEntity) &
                    q.state.isIn(['pending', 'retry']) &
                    (q.nextAttemptAtMicros.isNull() |
                        q.nextAttemptAtMicros.isSmallerOrEqualValue(
                          now.microsecondsSinceEpoch,
                        )),
              )
              ..orderBy([(q) => OrderingTerm.asc(q.createdAtMicros)]))
            .get();
    final result = <SyncQueueData>[];
    for (final row in rows) {
      final link = await (database.select(
        database.tripAccountLinks,
      )..where((l) => l.tripId.equals(row.entityId))).getSingleOrNull();
      if (link?.userId == userId) result.add(row);
      if (result.length == 50) break;
    }
    return result;
  }

  Future<CompactTripSummary?> readyPayload(
    SyncQueueData row,
    String userId,
  ) async {
    final current = await (database.select(
      database.syncQueue,
    )..where((q) => q.operationId.equals(row.operationId))).getSingleOrNull();
    final link = await (database.select(
      database.tripAccountLinks,
    )..where((l) => l.tripId.equals(row.entityId))).getSingleOrNull();
    if (current == null ||
        current.payloadJson != row.payloadJson ||
        current.createdAtMicros != row.createdAtMicros ||
        !['pending', 'retry'].contains(current.state) ||
        link?.userId != userId) {
      return null;
    }
    try {
      final summary = CompactTripSummary.fromJson(
        (jsonDecode(current.payloadJson!) as Map).cast<String, Object?>(),
      );
      if (summary.userId != userId ||
          summary.tripId != row.entityId ||
          current.entityVersion != 1 ||
          current.operationType != 'insert_snapshot') {
        throw const FormatException();
      }
      return summary;
    } catch (_) {
      throw const SummarySyncException(SummaryFailure.invalidData);
    }
  }

  Future<void> markSynced(SyncQueueData row, DateTime now) =>
      database.transaction(() async {
        final updated =
            await (database.update(
              database.syncQueue,
            )..where((q) => _sameOperation(q, row))).write(
              SyncQueueCompanion(
                state: const Value('synced'),
                nextAttemptAtMicros: const Value(null),
                lastErrorCode: const Value(null),
                updatedAtMicros: Value(now.microsecondsSinceEpoch),
              ),
            );
        if (updated > 0) {
          await (database.update(
            database.trips,
          )..where((t) => t.id.equals(row.entityId))).write(
            const TripsCompanion(cloudSyncState: Value('summary_synced')),
          );
        }
      });

  Future<void> markFailure(
    SyncQueueData row,
    SummaryFailure reason,
    DateTime now,
  ) async {
    final attempt = row.attemptCount + 1;
    final delaySeconds = math
        .min(3600, 30 * math.pow(2, math.min(attempt - 1, 7)))
        .toInt();
    await (database.update(
      database.syncQueue,
    )..where((q) => _sameOperation(q, row))).write(
      SyncQueueCompanion(
        state: Value(
          reason == SummaryFailure.invalidData ||
                  reason == SummaryFailure.conflict
              ? 'blocked'
              : 'retry',
        ),
        attemptCount: Value(attempt),
        nextAttemptAtMicros: Value(
          now.add(Duration(seconds: delaySeconds)).microsecondsSinceEpoch,
        ),
        lastErrorCode: Value(reason.name),
        updatedAtMicros: Value(now.microsecondsSinceEpoch),
      ),
    );
  }

  Future<void> cancelPending(String userId) => database.transaction(() async {
    final links = await (database.select(
      database.tripAccountLinks,
    )..where((l) => l.userId.equals(userId))).get();
    for (final link in links) {
      final deleted =
          await (database.delete(database.syncQueue)..where(
                (q) =>
                    q.operationId.equals(_operation(link.tripId)) &
                    q.state.equals('synced').not(),
              ))
              .go();
      if (deleted > 0) {
        await (database.update(
          database.trips,
        )..where((t) => t.id.equals(link.tripId))).write(
          const TripsCompanion(cloudSyncState: Value('summary_linked')),
        );
      }
    }
  });

  static String _operation(String tripId) => '$summaryQueueEntity:$tripId';

  static Expression<bool> _sameOperation(
    $SyncQueueTable q,
    SyncQueueData row,
  ) =>
      q.operationId.equals(row.operationId) &
      q.createdAtMicros.equals(row.createdAtMicros) &
      (row.payloadJson == null
          ? q.payloadJson.isNull()
          : q.payloadJson.equals(row.payloadJson!));
}
