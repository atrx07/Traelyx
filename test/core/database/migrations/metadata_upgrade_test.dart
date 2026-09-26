import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;

void main() {
  test(
    'v2 upgrade preserves summary consent, pending payload, and local trip ownership',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await old
          .into(old.vehicles)
          .insert(
            v2.VehiclesCompanion.insert(
              id: 'original',
              ownerNamespace: 'local:anonymous',
              displayName: 'Original',
              vehicleType: 'unspecified',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      await old
          .into(old.trips)
          .insert(
            v2.TripsCompanion.insert(
              id: 'trip',
              vehicleId: 'original',
              startWallTimeMicros: 1,
              startElapsedNanos: 1,
              completionState: 'completed',
              recoveryState: 'clean',
              telemetrySchemaVersion: 1,
              integrityStatus: 'unknown',
              cloudSyncState: 'summary_pending',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      await old
          .into(old.tripAccountLinks)
          .insert(
            v2.TripAccountLinksCompanion.insert(
              tripId: 'trip',
              userId: 'owner',
              consentedAtMicros: 17,
              summaryVersion: 1,
            ),
          );
      await old
          .into(old.syncQueue)
          .insert(
            v2.SyncQueueCompanion.insert(
              operationId: 'existing',
              idempotencyKey: 'original-key',
              entityType: 'trip_summary_v1',
              entityId: 'trip',
              entityVersion: 1,
              operationType: 'insert_snapshot',
              state: 'retry',
              payloadJson: const Value('{"preserve":"exact bytes"}'),
              attemptCount: 3,
              nextAttemptAtMicros: const Value(9000),
              createdAtMicros: 1,
              updatedAtMicros: 2,
            ),
          );
      const tables = ['vehicles', 'trips', 'trip_account_links', 'sync_queue'];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = (await old.customSelect('SELECT * FROM $table').get())
            .map((r) => r.data)
            .toList();
      }
      await old.close();
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(
        db,
        3,
        options: const ValidationOptions(validateDropped: true),
      );
      for (final table in tables) {
        expect(
          (await db.customSelect('SELECT * FROM $table').get())
              .map((r) => r.data)
              .toList(),
          before[table],
        );
      }
      expect(await db.select(db.accountMetadataCache).get(), isEmpty);
      await db.close();
      schema.close();
    },
  );
}
