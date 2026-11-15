import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;

void main() {
  test(
    'v3 to v4 adds empty default-off corrections and preserves all existing rows',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      await old.customStatement(
        "INSERT INTO app_settings VALUES ('privacy.accountless','true',7)",
      );
      await old.customStatement(
        "INSERT INTO vehicles (id,owner_namespace,display_name,vehicle_type,created_at_micros,updated_at_micros) VALUES ('v','local:anonymous','Original','motorcycle',1,1)",
      );
      await old.customStatement(
        "INSERT INTO trips (id,vehicle_id,start_wall_time_micros,end_wall_time_micros,start_elapsed_nanos,completion_state,recovery_state,telemetry_schema_version,integrity_status,cloud_sync_state,created_at_micros,updated_at_micros) VALUES ('t','v',1,100,1,'completed','clean',1,'limited','local_only',1,2)",
      );
      await old.customStatement(
        "INSERT INTO trip_events VALUES ('e','t','EVT_BRAKE_STRONG',1,2,3,0.5,'activation-ratio-cap2-v1',0.5,'[]','{}','{}',NULL,'[]','1',2)",
      );
      await old.customStatement(
        "INSERT INTO trip_scores (id,trip_id,score_schema_version,scoring_version,dimension_values_json,eligibility_state,audit_contributions_json,created_at_micros) VALUES ('s','t',1,'1','{}','limited','{\"preserved\":true}',2)",
      );
      await old.customStatement(
        "INSERT INTO trip_account_links VALUES ('t','owner',17,1)",
      );
      await old.customStatement(
        "INSERT INTO account_metadata_cache VALUES ('owner','profile','owner','{\"original\":true}',2,NULL)",
      );
      await old.customStatement(
        "INSERT INTO sync_queue (operation_id,idempotency_key,entity_type,entity_id,entity_version,operation_type,state,attempt_count,created_at_micros,updated_at_micros) VALUES ('pending','stable-key','trip_summary_v1','t',1,'insert_snapshot','retry',3,1,2)",
      );
      const tables = [
        'app_settings',
        'vehicles',
        'trips',
        'trip_chunks',
        'trip_events',
        'trip_scores',
        'driver_baselines',
        'sync_queue',
        'trip_account_links',
        'account_metadata_cache',
      ];
      final before = <String, Object?>{};
      for (final table in tables) {
        before[table] = (await old.customSelect('SELECT * FROM $table').get())
            .map((row) => row.data)
            .toList();
      }
      await old.close();
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(
        db,
        4,
        options: const ValidationOptions(validateDropped: true),
      );
      for (final table in tables) {
        expect(
          (await db.customSelect('SELECT * FROM $table').get())
              .map((row) => row.data)
              .toList(),
          before[table],
          reason: table,
        );
      }
      expect(await db.select(db.tripEventCorrections).get(), isEmpty);
      final repo = EventCorrectionRepository(db, now: () => 100);
      final target = (await repo.load('t')).targets.single;
      await repo.save(target, CorrectionChoice.unsure, expectedRevision: 0);
      expect((await repo.load('t')).notes.single.contributionAllowed, false);
      expect(
        (await db.select(db.tripScores).getSingle()).auditContributionsJson,
        '{"preserved":true}',
      );
      await db.close();
      schema.close();
    },
  );
}
