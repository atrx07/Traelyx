import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

const metadataQueueType = 'account_metadata_v1';

class MetadataEntry {
  const MetadataEntry(this.data, {this.pending, this.sourceLocalVehicleId});
  final AccountMetadata data;
  final SyncQueueData? pending;
  final String? sourceLocalVehicleId;
}

class MetadataRepository {
  const MetadataRepository(this.database);
  final AppDatabase database;

  Future<List<SyncQueueData>> queued(String userId) =>
      (database.select(database.syncQueue)
            ..where(
              (q) =>
                  q.entityType.equals(metadataQueueType) &
                  q.operationId.like('metadata:$userId:%'),
            )
            ..orderBy([(q) => OrderingTerm.asc(q.createdAtMicros)]))
          .get();

  Future<List<MetadataEntry>> entries(String userId) async {
    final cache = await (database.select(
      database.accountMetadataCache,
    )..where((c) => c.userId.equals(userId))).get();
    final pending = {for (final q in await queued(userId)) q.operationId: q};
    return cache.map((row) {
      final data = AccountMetadata.fromJson(
        (jsonDecode(row.payloadJson) as Map).cast<String, Object?>(),
      );
      if (data.userId != userId ||
          data.kind.name != row.entityType ||
          data.id != row.entityId ||
          data.revision != row.revision) {
        throw const MetadataException(MetadataFailure.invalidData);
      }
      final q = pending[_operation(data)];
      final draft = q == null ? data : decode(q, userId).data;
      return MetadataEntry(
        draft,
        pending: q,
        sourceLocalVehicleId: row.sourceLocalVehicleId,
      );
    }).toList();
  }

  Future<List<Vehicle>> localVehicles() => (database.select(
    database.vehicles,
  )..where((v) => v.ownerNamespace.like('local:%'))).get();

  Future<void> enqueue(
    AccountMetadata data,
    String mutationId,
    DateTime now,
    bool Function() currentAccount, {
    String? sourceLocalVehicleId,
  }) => database.transaction(() async {
    if (!currentAccount()) {
      throw const MetadataException(MetadataFailure.accountChanged);
    }
    final current =
        await (database.select(database.accountMetadataCache)..where(
              (c) =>
                  c.userId.equals(data.userId) &
                  c.entityType.equals(data.kind.name) &
                  c.entityId.equals(data.id),
            ))
            .getSingleOrNull();
    if ((current?.revision ?? 0) != data.revision) {
      throw const MetadataException(MetadataFailure.conflict);
    }
    if (await (database.select(database.syncQueue)
              ..where((q) => q.operationId.equals(_operation(data))))
            .getSingleOrNull() !=
        null) {
      throw const MetadataException(MetadataFailure.conflict);
    }
    if (sourceLocalVehicleId != null) {
      if (data.kind != MetadataKind.vehicle ||
          await (database.select(database.vehicles)
                    ..where((v) => v.id.equals(sourceLocalVehicleId)))
                  .getSingleOrNull() ==
              null) {
        throw const MetadataException(MetadataFailure.invalidData);
      }
      final linked =
          await (database.select(database.accountMetadataCache)..where(
                (c) =>
                    c.userId.equals(data.userId) &
                    c.sourceLocalVehicleId.equals(sourceLocalVehicleId),
              ))
              .get();
      if (linked.any((c) => c.entityId != data.id)) {
        throw const MetadataException(MetadataFailure.conflict);
      }
    }
    if (current == null) await _write(data, sourceLocalVehicleId);
    final mutation = MetadataMutation(data, mutationId);
    await database
        .into(database.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            operationId: _operation(data),
            idempotencyKey: mutationId,
            entityType: metadataQueueType,
            entityId: data.id,
            entityVersion: 1,
            operationType: data.kind.name,
            state: 'pending',
            payloadJson: Value(jsonEncode(mutation.toJson())),
            attemptCount: 0,
            createdAtMicros: now.microsecondsSinceEpoch,
            updatedAtMicros: now.microsecondsSinceEpoch,
          ),
        );
    if (!currentAccount()) {
      throw const MetadataException(MetadataFailure.accountChanged);
    }
  });

  MetadataMutation decode(SyncQueueData row, String userId) {
    try {
      final result = MetadataMutation.fromJson(
        (jsonDecode(row.payloadJson!) as Map).cast<String, Object?>(),
      );
      if (result.data.userId != userId ||
          result.data.id != row.entityId ||
          result.data.kind.name != row.operationType ||
          result.mutationId != row.idempotencyKey ||
          row.entityVersion != 1 ||
          row.entityType != metadataQueueType ||
          _operation(result.data) != row.operationId) {
        throw const FormatException();
      }
      return result;
    } catch (_) {
      throw const MetadataException(MetadataFailure.invalidData);
    }
  }

  Future<bool> stillPending(SyncQueueData row) async =>
      await (database.select(
        database.syncQueue,
      )..where((q) => _same(q, row))).getSingleOrNull() !=
      null;

  Future<void> acknowledge(SyncQueueData row, AccountMetadata result) =>
      database.transaction(() async {
        if (!await stillPending(row)) return;
        final old =
            await (database.select(database.accountMetadataCache)..where(
                  (c) =>
                      c.userId.equals(result.userId) &
                      c.entityType.equals(result.kind.name) &
                      c.entityId.equals(result.id),
                ))
                .getSingle();
        await _write(result, old.sourceLocalVehicleId);
        await (database.delete(
          database.syncQueue,
        )..where((q) => _same(q, row))).go();
      });

  Future<void> fail(
    SyncQueueData row,
    MetadataFailure reason,
    DateTime now,
  ) async {
    final retry =
        reason == MetadataFailure.connection ||
        reason == MetadataFailure.accessDenied;
    final seconds = math
        .min(3600, 30 * math.pow(2, math.min(row.attemptCount, 7)))
        .toInt();
    await (database.update(
      database.syncQueue,
    )..where((q) => _same(q, row))).write(
      SyncQueueCompanion(
        state: Value(retry ? 'retry' : 'blocked'),
        attemptCount: Value(row.attemptCount + 1),
        lastErrorCode: Value(reason.name),
        nextAttemptAtMicros: Value(
          retry
              ? now.add(Duration(seconds: seconds)).microsecondsSinceEpoch
              : null,
        ),
        updatedAtMicros: Value(now.microsecondsSinceEpoch),
      ),
    );
  }

  Future<void> replaceFromCloud(
    String userId,
    List<AccountMetadata> rows,
    bool Function() currentAccount,
  ) => database.transaction(() async {
    if (!currentAccount()) {
      throw const MetadataException(MetadataFailure.accountChanged);
    }
    if ((await queued(userId)).isNotEmpty) {
      throw const MetadataException(MetadataFailure.conflict);
    }
    final existing = await (database.select(
      database.accountMetadataCache,
    )..where((c) => c.userId.equals(userId))).get();
    final sources = {
      for (final c in existing) c.entityId: c.sourceLocalVehicleId,
    };
    final identities = <String>{};
    for (final row in rows) {
      if (row.userId != userId ||
          row.revision <= 0 ||
          !identities.add('${row.kind.name}:${row.id}')) {
        throw const MetadataException(MetadataFailure.invalidData);
      }
    }
    await (database.delete(
      database.accountMetadataCache,
    )..where((c) => c.userId.equals(userId))).go();
    for (final row in rows) {
      await _write(row, sources[row.id]);
    }
    if (!currentAccount()) {
      throw const MetadataException(MetadataFailure.accountChanged);
    }
  });

  Future<void> discard(String userId) => database.transaction(() async {
    for (final row in await queued(userId)) {
      await (database.delete(
        database.syncQueue,
      )..where((q) => _same(q, row))).go();
    }
    await (database.delete(
      database.accountMetadataCache,
    )..where((c) => c.userId.equals(userId) & c.revision.equals(0))).go();
  });

  Future<void> _write(AccountMetadata data, String? source) => database
      .into(database.accountMetadataCache)
      .insertOnConflictUpdate(
        AccountMetadataCacheCompanion.insert(
          userId: data.userId,
          entityType: data.kind.name,
          entityId: data.id,
          payloadJson: jsonEncode(data.toJson()),
          revision: data.revision,
          sourceLocalVehicleId: Value(source),
        ),
      );
  static String _operation(AccountMetadata data) =>
      'metadata:${data.userId}:${data.kind.name}:${data.id}';
  static Expression<bool> _same($SyncQueueTable q, SyncQueueData row) =>
      q.operationId.equals(row.operationId) &
      q.idempotencyKey.equals(row.idempotencyKey);
}
