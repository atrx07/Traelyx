import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

import 'bootstrap_v1_database.dart' as bootstrap_schema;
import 'generated/schema.dart';

const rehearsalTargetVersion = 4;
String rehearsalId(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
double? rehearsalScore(int index) =>
    index % 7 == 0 ? null : 75 + index % 20 + .5;

/// Test-owned data only. Sidecars are opaque sentinels, not encoded telemetry.
class UpgradeFixture {
  UpgradeFixture._(
    this.root,
    this.directory,
    this.file,
    this.tripCount,
    this.sourceVersion,
    this.journal,
  );
  final Directory root;
  final Directory directory;
  final File file;
  final int tripCount;
  final int sourceVersion;
  final String journal;

  static Future<UpgradeFixture> create(
    int version, {
    int trips = 1000,
    String journal = 'delete',
    bool bootstrap = false,
  }) async {
    if (!const {1, 2, 3, 4}.contains(version) ||
        !const {'delete', 'wal'}.contains(journal) ||
        trips < 2) {
      throw ArgumentError('Invalid fixture request');
    }
    final root = Directory('.dart_tool/m8-upgrade-fixtures')
      ..createSync(recursive: true);
    final directory = await root.createTemp('synthetic-');
    final fixture = UpgradeFixture._(
      root,
      directory,
      File('${directory.path}/traelyx.sqlite'),
      bootstrap ? 0 : trips,
      version,
      journal,
    );
    final old = bootstrap
        ? bootstrap_schema.BootstrapV1Database(NativeDatabase(fixture.file))
        : GeneratedHelper().databaseForVersion(
            NativeDatabase(fixture.file),
            version,
          );
    try {
      try {
        await old.customSelect('PRAGMA journal_mode = $journal').get();
        await old.customStatement('PRAGMA foreign_keys = ON');
        await old.transaction(() async {
          await insertFixture(old, 'app_settings', {
            'key': 'privacy.cloud.enabled',
            'value': 'false',
            'updated_at_micros': 7,
          });
          await insertFixture(old, 'app_settings', {
            'key': 'fixture.json.preserved',
            'value':
                '{ "version": 1, "label": "Synthetic 🚗", "allow": false }',
            'updated_at_micros': 8,
          });
          await insertFixture(old, 'app_settings', {
            'key': 'map.provider',
            'value': 'offline_canvas',
            'updated_at_micros': 9,
          });
          if (!bootstrap) await fixture._seed(old, version);
        });
      } finally {
        await old.close();
      }
      if (version == 4 && !bootstrap) {
        // Same-schema repository write creates valid existing consented/off notes.
        final db = AppDatabase(NativeDatabase(fixture.file));
        try {
          if (db.schemaVersion != rehearsalTargetVersion) {
            throw StateError(
              'Update the versioned rehearsal before changing target schema',
            );
          }
          final corrections = EventCorrectionRepository(
            db,
            now: () => 1893456000000000,
          );
          for (var index = 0; index < 2; index++) {
            final target = (await corrections.load(
              rehearsalId(index + 1),
            )).targets.first;
            await corrections.save(
              target,
              CorrectionChoice.unsure,
              expectedRevision: 0,
              contribute: index == 1,
            );
          }
        } finally {
          await db.close();
        }
      }
      return fixture;
    } catch (_) {
      await fixture.dispose();
      rethrow;
    }
  }

  Future<void> _seed(GeneratedDatabase old, int version) async {
    for (var index = 0; index < 3; index++) {
      await insertFixture(old, 'vehicles', {
        'id': rehearsalId(2000 + index),
        'owner_namespace': 'local:synthetic-${index % 2}',
        'display_name': 'Synthetic vehicle $index',
        'vehicle_type': index == 0 ? 'motorcycle' : 'car',
        'calibration_metadata_json': '{ "fixtureCalibration": 1 }',
        'created_at_micros': 1,
        'updated_at_micros': 2,
      });
      await insertFixture(old, 'driver_baselines', {
        'id': rehearsalId(3000 + index),
        'owner_namespace': 'local:synthetic-${index % 2}',
        'vehicle_id': rehearsalId(2000 + index),
        'lifecycle_state': 'eligible',
        'dimension_statistics_json': '{ "preserved": [0.1, 0.2] }',
        'baseline_schema_version': 1,
        'scoring_version': 'fixture-score-v1',
        'valid_trip_count': 12,
        'confidence': .6,
        'created_at_micros': 1,
        'updated_at_micros': 2,
      });
    }
    for (var index = 0; index < tripCount; index++) {
      final id = rehearsalId(index + 1);
      final start = 1577836800000000 + index * 3600000000;
      await insertFixture(old, 'trips', {
        'id': id,
        'vehicle_id': rehearsalId(2000 + index % 3),
        'start_wall_time_micros': start,
        'end_wall_time_micros': start + 600000000,
        'start_elapsed_nanos': 0,
        'end_elapsed_nanos': 600000000000,
        'duration_millis': 600000,
        'distance_meters': index % 3 == 0 ? null : 1000.0 + index,
        'completion_state': index % 4 == 0 ? 'incomplete' : 'completed',
        'recovery_state': index % 5 == 0 ? 'recovered' : 'not_needed',
        'telemetry_schema_version': 1,
        'scoring_version': 'fixture-score-v2',
        'event_engine_version': '1',
        'ml_model_refs_json': '["fixture-disabled-model-v1"]',
        'integrity_status': index % 3 == 0 ? 'limited' : 'unassessed',
        'telemetry_confidence': index % 4 == 0 ? null : .75,
        'telemetry_quality_summary_json': jsonEncode({
          'finalizationLogicVersion': 1,
          'validChunkCount': 3,
          'recoveryCount': index % 5 == 0 ? 1 : 0,
          'corruptChunkCount': 0,
          'orphanedWriteCount': 0,
          'orderingViolationCount': 0,
          'qualityFlags': ['synthetic_fixture'],
        }),
        'cloud_sync_state': version >= 2 && index % 4 == 0
            ? 'summary_pending'
            : 'local_only',
        'created_at_micros': start,
        'updated_at_micros': start + 600000001,
      });
      for (var chunk = 0; chunk < 3; chunk++) {
        final bytes = utf8.encode(
          'opaque synthetic sidecar v1/$index/$chunk; not raw telemetry',
        );
        final reference =
            'recorder/trips/$id/chunks/${chunk.toString().padLeft(10, '0')}.tlxc';
        if (index < 3) {
          final sentinel = File('${directory.path}/no_backup/$reference');
          await sentinel.parent.create(recursive: true);
          await sentinel.writeAsBytes(bytes, flush: true);
        }
        await insertFixture(old, 'trip_chunks', {
          'trip_id': id,
          'sequence': chunk,
          'storage_reference': reference,
          'encoding_version': 1,
          'start_elapsed_nanos': chunk * 1000000000,
          'end_elapsed_nanos': (chunk + 1) * 1000000000 - 1,
          'channel_sample_counts_json':
              '{"gnss":1,"accelerometer":100,"gyroscope":100}',
          'compression': 'deflate',
          'atomic_write_strategy': 'android_atomic_file',
          'checksum_algorithm': 'sha256',
          'checksum': sha256.convert(bytes).toString(),
          'byte_length': bytes.length,
          'write_state': 'complete',
          'created_at_micros': start,
        });
      }
      for (var event = 0; event < 2; event++) {
        await insertFixture(old, 'trip_events', {
          'id': 'synthetic-event-$index-$event',
          'trip_id': id,
          'event_type': event == 0 ? 'EVT_BRAKE_STRONG' : 'EVT_ROAD_IMPACT',
          'start_elapsed_nanos': event * 1000000000,
          'peak_elapsed_nanos': event * 1000000000 + 1000000,
          'end_elapsed_nanos': event * 1000000000 + 2000000,
          'severity': .4,
          'severity_calibration_version': 'activation-ratio-cap2-v1',
          'confidence': .75,
          'quality_flags_json': '["SYNTHETIC"]',
          'primary_measurements_json': '{ "fixture": 0.4 }',
          'rule_evidence_json': '{ "thresholdVersion": 1 }',
          'context_tags_json': '[]',
          'algorithm_version': '1',
          'created_at_micros': start,
        });
      }
      for (var score = 1; score <= 2; score++) {
        await insertFixture(old, 'trip_scores', {
          'id': 'synthetic-score-$index-$score',
          'trip_id': id,
          'score_schema_version': 1,
          'scoring_version': 'fixture-score-v$score',
          'dimension_values_json': '{ "smoothness": 0.7 }',
          'overall_score': score == 1 ? 65.0 : rehearsalScore(index),
          'confidence': index % 4 == 0 ? null : .75,
          'eligibility_state': index % 7 == 0 && score == 2
              ? 'insufficient_evidence'
              : 'provisional',
          'audit_contributions_json':
              '{ "fixtureAudit": [1, 2], "raw": false }',
          'baseline_id': rehearsalId(3000 + index % 3),
          'model_versions_json': '["fixture-disabled-model-v1"]',
          'created_at_micros': start + score,
        });
      }
      if (index % 4 == 0) {
        final owner = rehearsalId(5000 + (index ~/ 4) % 2);
        final payload = jsonEncode({
          'user_id': owner,
          'source_trip_id': id,
          'summary_version': 1,
          'duration_seconds': 600,
          'distance_m': index % 3 == 0 ? null : 1000.0 + index,
          'score_overall': rehearsalScore(index),
          'scoring_version': rehearsalScore(index) == null
              ? null
              : 'fixture-score-v2',
          'event_count': 2,
        });
        await insertFixture(old, 'sync_queue', {
          'operation_id': 'fixture-operation-$index',
          'idempotency_key': 'fixture-key-$index',
          'entity_type': version >= 2
              ? 'trip_summary_v1'
              : 'legacy_fixture_operation',
          'entity_id': id,
          'entity_version': 1,
          'operation_type': 'insert_snapshot',
          'state': index % 8 == 0 ? 'retry' : 'pending',
          'payload_json': payload,
          'attempt_count': index % 8 == 0 ? 3 : 0,
          'next_attempt_at_micros': start + 1000000000,
          'last_error_code': index % 8 == 0 ? 'connection' : null,
          'created_at_micros': start,
          'updated_at_micros': start + 1,
        });
        if (version >= 2) {
          await insertFixture(old, 'trip_account_links', {
            'trip_id': id,
            'user_id': owner,
            'consented_at_micros': start + 1,
            'summary_version': 1,
          });
        }
      }
    }
    if (version >= 3) {
      for (var index = 0; index < 2; index++) {
        final owner = rehearsalId(5000 + index);
        await insertFixture(old, 'account_metadata_cache', {
          'user_id': owner,
          'entity_type': 'profile',
          'entity_id': owner,
          'payload_json': '{ "fixtureMetadata": true, "version": 1 }',
          'revision': index + 1,
          'source_local_vehicle_id': null,
        });
      }
    }
  }

  Future<Map<String, String>> sidecarDigests() async {
    final noBackup = Directory('${directory.path}/no_backup');
    if (!await noBackup.exists()) return {};
    final result = <String, String>{};
    await for (final entry in noBackup.list(recursive: true)) {
      if (entry is File) {
        result[entry.path.substring(noBackup.path.length)] = sha256
            .convert(await entry.readAsBytes())
            .toString();
      }
    }
    return result;
  }

  Future<void> dispose() async {
    if (await directory.parent.resolveSymbolicLinks() !=
        await root.resolveSymbolicLinks()) {
      throw StateError('Unexpected owned fixture cleanup target');
    }
    await directory.delete(recursive: true);
  }
}

Future<void> insertFixture(
  GeneratedDatabase database,
  String table,
  Map<String, Object?> values,
) => database.customStatement(
  'INSERT INTO $table (${values.keys.join(',')}) VALUES (${List.filled(values.length, '?').join(',')})',
  values.values.toList(),
);

Future<Map<String, Object?>> upgradeImage(File file) async {
  final db = AppDatabase(NativeDatabase(file, enableMigrations: false));
  try {
    final schema = await db
        .customSelect(
          "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name",
        )
        .get();
    final rows = <String, List<String>>{};
    for (final table in schema.where(
      (row) => row.read<String>('type') == 'table',
    )) {
      final name = table.read<String>('name');
      if (!RegExp(r'^[a-z_]+$').hasMatch(name)) {
        throw StateError('Unexpected synthetic table');
      }
      rows[name] = (await db.customSelect('SELECT * FROM $name').get()).map((
        row,
      ) {
        final keys = row.data.keys.toList()..sort();
        return jsonEncode({for (final key in keys) key: row.data[key]});
      }).toList()..sort();
    }
    return {
      'user_version': (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      'schema': schema.map((row) => row.data).toList(),
      'rows': rows,
    };
  } finally {
    await db.close();
  }
}

Map<String, Object> upgradeDigests(Map<String, Object?> image) => {
  for (final entry in (image['rows'] as Map<String, List<String>>).entries)
    entry.key: {
      'rows': entry.value.length,
      'sha256': sha256.convert(utf8.encode(jsonEncode(entry.value))).toString(),
    },
};
