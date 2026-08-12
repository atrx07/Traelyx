import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';

import 'bootstrap_v1_database.dart' as bootstrap;
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('runtime schema matches the committed version 1 snapshot', () async {
    final schema = await verifier.schemaAt(1);
    final fixture = v1.DatabaseAtV1(schema.newConnection());
    await fixture
        .into(fixture.appSettings)
        .insert(
          v1.AppSettingsCompanion.insert(
            key: 'privacy.accountless',
            value: 'true',
            updatedAtMicros: 7,
          ),
        );
    await fixture.close();

    final database = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(
      database,
      1,
      options: const ValidationOptions(validateDropped: true),
    );
    final setting = await database.select(database.appSettings).getSingle();
    expect(setting.key, 'privacy.accountless');
    expect(setting.value, 'true');
    await database.close();
    schema.close();
  });

  test('settings-only development v1 upgrades transactionally', () async {
    final fixture = await _createBootstrapV1Fixture();

    final database = AppDatabase(NativeDatabase(fixture.file));
    final setting = await database.select(database.appSettings).getSingle();
    expect(setting.key, 'privacy.accountless');
    expect(setting.value, 'true');
    expect(await _tableNames(database), [
      'app_settings',
      'driver_baselines',
      'sync_queue',
      'trip_chunks',
      'trip_events',
      'trip_scores',
      'trips',
      'vehicles',
    ]);
    await database.validateDatabaseSchema(
      options: const ValidationOptions(validateDropped: true),
    );
    await database.close();

    final reopened = AppDatabase(NativeDatabase(fixture.file));
    expect(
      (await reopened.select(reopened.appSettings).getSingle()).value,
      'true',
    );
    await reopened.close();
    await fixture.dispose();
  });

  test(
    'Android metadata table does not invalidate a recognized schema',
    () async {
      final fixture = await _createBootstrapV1Fixture(
        mutate: (database) async {
          await database.customStatement(
            'CREATE TABLE android_metadata (locale TEXT)',
          );
          await database.customStatement(
            "INSERT INTO android_metadata (locale) VALUES ('en_IN')",
          );
        },
      );

      final database = AppDatabase(NativeDatabase(fixture.file));
      expect(
        (await database.select(database.appSettings).getSingle()).value,
        'true',
      );
      expect(
        await database
            .customSelect('SELECT locale FROM android_metadata')
            .map((row) => row.read<String>('locale'))
            .getSingle(),
        'en_IN',
      );
      expect(
        await _tableNames(database),
        containsAll(<String>[
          'android_metadata',
          'app_settings',
          'trips',
          'vehicles',
        ]),
      );
      await database.close();
      await fixture.dispose();
    },
  );

  test(
    'unrecognized version 1 shape fails instead of implicit repair',
    () async {
      final fixture = await _createBootstrapV1Fixture(
        mutate: (database) => database.customStatement(
          'CREATE TABLE unexpected_partial_table (id INTEGER PRIMARY KEY)',
        ),
      );
      final database = AppDatabase(NativeDatabase(fixture.file));

      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Refusing an implicit repair'),
          ),
        ),
      );
      await database.close();
      await fixture.dispose();
    },
  );
}

Future<_BootstrapFixture> _createBootstrapV1Fixture({
  Future<void> Function(bootstrap.BootstrapV1Database database)? mutate,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'traelyx-bootstrap-v1-',
  );
  final file = File('${directory.path}${Platform.pathSeparator}traelyx.sqlite');
  final database = bootstrap.BootstrapV1Database(NativeDatabase(file));
  await database
      .into(database.appSettings)
      .insert(
        bootstrap.AppSettingsCompanion.insert(
          key: 'privacy.accountless',
          value: 'true',
          updatedAtMicros: 7,
        ),
      );
  await mutate?.call(database);
  await database.close();
  return _BootstrapFixture(directory, file);
}

Future<List<String>> _tableNames(AppDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toList();
}

class _BootstrapFixture {
  const _BootstrapFixture(this.directory, this.file);

  final Directory directory;
  final File file;

  Future<void> dispose() => directory.delete(recursive: true);
}
