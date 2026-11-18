import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';

import 'upgrade_rehearsal_fixture.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final reports = <Map<String, Object?>>[];
  tearDownAll(() {
    final output = File('build/reports/database-upgrade-rehearsal-v1.json');
    output.parent.createSync(recursive: true);
    final report = {
      'contract_version': 1,
      'rehearsal_version': 1,
      'migration_policy_version': localDatabaseUpgradePolicyVersion,
      'previous_build_commit': 'de3c3aff75787ce29b3ba580e589a2fe1ed846fa',
      'target_schema_version': rehearsalTargetVersion,
      'platform': Platform.operatingSystem,
      'mode':
          'host file-backed SQLite using frozen schema writers and current production migration',
      'expected_cases': 23,
      'completed_cases': reports.length,
      'passed': reports.length == 23,
      'real_telemetry_or_credentials_used': false,
      'network_requested': false,
      'signed_apk_install_or_physical_power_failure_tested': false,
      'cases': reports,
    };
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  });
  for (final journal in ['delete', 'wal']) {
    for (final version in [1, 2, 3, 4]) {
      test(
        'populated schema $version to4 in $journal preserves every row and reopens',
        () async {
          final fixture = await UpgradeFixture.create(
            version,
            journal: journal,
          );
          try {
            final before = await upgradeImage(fixture.file);
            final sidecars = await fixture.sidecarDigests();
            await _verify(fixture);
            final after = await upgradeImage(fixture.file);
            _oldRowsUnchanged(before, after);
            for (final entry in (after['rows'] as Map).entries) {
              if (!(before['rows'] as Map).containsKey(entry.key)) {
                expect(entry.value, isEmpty);
              }
            }
            if (version == 4) expect(after, before);
            for (var reopen = 0; reopen < 2; reopen++) {
              await _verify(fixture);
              expect(await upgradeImage(fixture.file), after);
            }
            expect(await fixture.sidecarDigests(), sidecars);
            reports.add({
              'case': 'schema_${version}_to4_$journal',
              'source_version': version,
              'trip_count': fixture.tripCount,
              'journal': journal,
              'historical_table_digests': upgradeDigests(before),
              'all_historical_rows_exact': true,
              'reopens': 2,
              'opaque_sidecar_sentinels_unchanged': sidecars.length,
              'raw_codec_validated': false,
              'snapshot_sha256': sha256
                  .convert(
                    File(
                      'drift_schemas/app_database/drift_schema_v$version.json',
                    ).readAsBytesSync(),
                  )
                  .toString(),
            });
          } finally {
            await fixture.dispose();
          }
        },
      );
    }
    for (final version in [1, 2, 3]) {
      for (final afterCallback in [false, true]) {
        test(
          'schema $version $journal failure afterCallback=$afterCallback is atomic and retryable',
          () async {
            final fixture = await UpgradeFixture.create(
              version,
              trips: 6,
              journal: journal,
            );
            try {
              final before = await upgradeImage(fixture.file);
              final sidecars = await fixture.sidecarDigests();
              final fault = _MigrationFault(
                afterCallback: afterCallback,
                failTable: version == 1
                    ? 'account_metadata_cache'
                    : 'trip_event_corrections',
              );
              final db = AppDatabase(
                NativeDatabase(fixture.file).interceptWith(fault),
              );
              try {
                await expectLater(
                  db.customSelect('SELECT 1').get(),
                  throwsStateError,
                );
                expect(fault.thrown, true);
                if (!afterCallback && version < 3) {
                  expect(
                    fault.createdBeforeFailure,
                    contains(
                      version == 1
                          ? 'trip_account_links'
                          : 'account_metadata_cache',
                    ),
                  );
                }
              } finally {
                await db.close();
              }
              final after = await upgradeImage(fixture.file);
              if (!afterCallback || after['user_version'] == version) {
                expect(after, before);
              } else {
                expect(after['user_version'], rehearsalTargetVersion);
                _oldRowsUnchanged(before, after);
              }
              await _verify(fixture);
              expect(await fixture.sidecarDigests(), sidecars);
              reports.add({
                'case':
                    'failure_v${version}_${journal}_afterCallback_$afterCallback',
                'source_version': version,
                'journal': journal,
                'version_after_failure': after['user_version'],
                'atomic_image': true,
                'retry_and_integrity_passed': true,
                'all_historical_rows_exact': true,
              });
            } finally {
              await fixture.dispose();
            }
          },
        );
      }
    }
  }

  test(
    'settings-only development bootstrap preserves settings and creates canonical v4',
    () async {
      final fixture = await UpgradeFixture.create(1, bootstrap: true);
      try {
        final before = await upgradeImage(fixture.file);
        await _verify(fixture);
        _oldRowsUnchanged(before, await upgradeImage(fixture.file));
        reports.add({
          'case': 'settings_only_bootstrap1_to4',
          'settings_rows_exact': true,
        });
      } finally {
        await fixture.dispose();
      }
    },
  );

  for (final future in [false, true]) {
    test(
      '${future ? 'future version' : 'unrecognized v1 shape'} is refused without alteration',
      () async {
        final fixture = await UpgradeFixture.create(future ? 4 : 1, trips: 6);
        try {
          final editor = AppDatabase(
            NativeDatabase(fixture.file, enableMigrations: false),
          );
          try {
            if (future) {
              await editor.customStatement('PRAGMA user_version = 5');
            } else {
              await editor.customStatement(
                'CREATE TABLE unexpected_partial_table (id INTEGER PRIMARY KEY)',
              );
              await editor.customStatement(
                'INSERT INTO unexpected_partial_table VALUES (7)',
              );
            }
          } finally {
            await editor.close();
          }
          final before = await upgradeImage(fixture.file);
          final sidecars = await fixture.sidecarDigests();
          final db = AppDatabase(NativeDatabase(fixture.file));
          try {
            await expectLater(
              db.customSelect('SELECT 1').get(),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'explicit refusal',
                  contains(
                    future
                        ? 'Unsupported local database upgrade'
                        : 'Refusing an implicit repair',
                  ),
                ),
              ),
            );
          } finally {
            await db.close();
          }
          expect(await upgradeImage(fixture.file), before);
          expect(await fixture.sidecarDigests(), sidecars);
          reports.add({
            'case': future
                ? 'future_version5_refused'
                : 'unknown_v1_shape_refused',
            'schema_version_and_rows_unchanged': true,
            'implicit_reset': false,
          });
        } finally {
          await fixture.dispose();
        }
      },
    );
  }
}

void _oldRowsUnchanged(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  for (final entry in (before['rows'] as Map).entries) {
    expect(
      (after['rows'] as Map)[entry.key],
      entry.value,
      reason: entry.key as String,
    );
  }
}

Future<void> _verify(UpgradeFixture fixture) async {
  final db = AppDatabase(NativeDatabase(fixture.file));
  try {
    expect(db.schemaVersion, rehearsalTargetVersion);
    await db.validateDatabaseSchema(
      options: const ValidationOptions(validateDropped: true),
    );
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      rehearsalTargetVersion,
    );
    expect(
      (await db.customSelect('PRAGMA foreign_keys').getSingle())
          .data
          .values
          .single,
      1,
    );
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(
      (await db.customSelect('PRAGMA journal_mode').getSingle())
          .data
          .values
          .single,
      fixture.journal,
    );
    expect(
      (await (db.select(
            db.appSettings,
          )..where((r) => r.key.equals('privacy.cloud.enabled'))).getSingle())
          .value,
      'false',
    );
    final repository = DriftTripHistoryRepository(db);
    final history = await repository.watchHistory().first;
    expect(history, hasLength(fixture.tripCount));
    if (fixture.tripCount > 0) {
      expect(history.first.id, rehearsalId(fixture.tripCount));
      for (final index in {0, fixture.tripCount ~/ 2, fixture.tripCount - 1}) {
        final result = await repository.loadResult(rehearsalId(index + 1));
        expect(result, isNotNull);
        expect(result!.events, hasLength(2));
        expect(result.evidence.chunkCount, 3);
        expect(result.evidence.accelerometerSampleCount, 300);
        expect(result.evidence.gyroscopeSampleCount, 300);
        expect(result.evidence.gnssSampleCount, 3);
        expect(result.score!.scoringVersion, 'fixture-score-v2');
        expect(result.score!.overallScore, rehearsalScore(index));
        expect(result.trip.duration, const Duration(minutes: 10));
      }
      if (fixture.sourceVersion == 4) {
        final corrections = EventCorrectionRepository(db);
        expect(
          (await corrections.load(
            rehearsalId(1),
          )).notes.single.contributionAllowed,
          false,
        );
        expect(
          (await corrections.load(
            rehearsalId(2),
          )).notes.single.contributionAllowed,
          true,
        );
      } else {
        expect(await db.select(db.tripEventCorrections).get(), isEmpty);
      }
    }
  } finally {
    await db.close();
  }
}

class _MigrationFault extends QueryInterceptor {
  _MigrationFault({required this.failTable, this.afterCallback = false});
  final bool afterCallback;
  final String failTable;
  bool thrown = false;
  final createdBeforeFailure = <String>[];
  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      executor.ensureOpen(_FaultUser(user, this));
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.startsWith('CREATE TABLE')) {
      if (!afterCallback && statement.contains('"$failTable"')) {
        thrown = true;
        throw StateError('injected_upgrade_failure');
      }
      await executor.runCustom(statement, args);
      for (final table in ['trip_account_links', 'account_metadata_cache']) {
        if (statement.contains('"$table"')) createdBeforeFailure.add(table);
      }
    } else {
      await executor.runCustom(statement, args);
    }
  }
}

class _FaultUser implements QueryExecutorUser {
  _FaultUser(this.inner, this.fault);
  final QueryExecutorUser inner;
  final _MigrationFault fault;
  @override
  int get schemaVersion => inner.schemaVersion;
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    await inner.beforeOpen(executor.interceptWith(fault), details);
    if (fault.afterCallback && details.hadUpgrade) {
      fault.thrown = true;
      throw StateError('injected_before_framework_version_publication');
    }
  }
}
