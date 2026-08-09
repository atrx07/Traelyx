import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/settings/drift_non_secret_settings_repository.dart';
import 'package:traelyx/core/settings/non_secret_setting.dart';
import 'package:traelyx/core/settings/settings_providers.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late DriftNonSecretSettingsRepository repository;

  final reducedMotion = NonSecretSetting<bool>(
    key: 'accessibility.reduced_motion',
    defaultValue: false,
    encode: SettingCodecs.encodeBool,
    decode: SettingCodecs.decodeBool,
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 8, 9, 12);
    repository = DriftNonSecretSettingsRepository(database, clock: () => now);
  });

  tearDown(() async {
    await database.close();
  });

  test('reads defaults, upserts typed values, and resets to default', () async {
    expect(await repository.read(reducedMotion), isFalse);

    await repository.write(reducedMotion, true);
    expect(await repository.read(reducedMotion), isTrue);

    now = now.add(const Duration(minutes: 1));
    await repository.write(reducedMotion, false);

    final rows = await database.select(database.appSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.key, reducedMotion.key);
    expect(rows.single.value, 'false');
    expect(rows.single.updatedAtMicros, now.microsecondsSinceEpoch);

    await repository.reset(reducedMotion);
    expect(await repository.read(reducedMotion), isFalse);
    expect(await database.select(database.appSettings).get(), isEmpty);
  });

  test('watch emits the default and subsequent persisted value', () async {
    final expectation = expectLater(
      repository.watch(reducedMotion),
      emitsInOrder([false, true]),
    );

    await Future<void>.delayed(Duration.zero);
    await repository.write(reducedMotion, true);
    await expectation;
  });

  test('malformed persisted values fail visibly', () async {
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: reducedMotion.key,
            value: 'sometimes',
            updatedAtMicros: 0,
          ),
        );

    await expectLater(
      repository.read(reducedMotion),
      throwsA(isA<FormatException>()),
    );
  });

  test('non-secret definitions reject sensitive and malformed keys', () {
    expect(
      () => NonSecretSetting<String>(
        key: 'commentary.api_key',
        defaultValue: '',
        encode: SettingCodecs.encodeString,
        decode: SettingCodecs.decodeString,
      ),
      throwsArgumentError,
    );
    expect(
      () => NonSecretSetting<String>(
        key: 'auth.refresh_token',
        defaultValue: '',
        encode: SettingCodecs.encodeString,
        decode: SettingCodecs.decodeString,
      ),
      throwsArgumentError,
    );
    expect(
      () => NonSecretSetting<String>(
        key: 'not_namespaced',
        defaultValue: '',
        encode: SettingCodecs.encodeString,
        decode: SettingCodecs.decodeString,
      ),
      throwsArgumentError,
    );
  });

  test('repository provider uses the injected database boundary', () async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final providedRepository = container.read(
      nonSecretSettingsRepositoryProvider,
    );
    await providedRepository.write(reducedMotion, true);

    expect(await repository.read(reducedMotion), isTrue);
  });
}
