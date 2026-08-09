import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/settings/non_secret_setting.dart';
import 'package:traelyx/core/settings/non_secret_settings_repository.dart';

typedef SettingsClock = DateTime Function();

final class DriftNonSecretSettingsRepository
    implements NonSecretSettingsRepository {
  DriftNonSecretSettingsRepository(this._database, {SettingsClock? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final SettingsClock _clock;

  @override
  Future<T> read<T>(NonSecretSetting<T> setting) async {
    final row = await _query(setting.key).getSingleOrNull();
    return _decode(setting, row);
  }

  @override
  Stream<T> watch<T>(NonSecretSetting<T> setting) {
    return _query(
      setting.key,
    ).watchSingleOrNull().map((row) => _decode(setting, row));
  }

  @override
  Future<void> write<T>(NonSecretSetting<T> setting, T value) async {
    final encoded = setting.encode(value);
    final updatedAtMicros = _clock().microsecondsSinceEpoch;

    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: setting.key,
            value: encoded,
            updatedAtMicros: updatedAtMicros,
          ),
        );
  }

  @override
  Future<void> reset<T>(NonSecretSetting<T> setting) async {
    await (_database.delete(
      _database.appSettings,
    )..where((row) => row.key.equals(setting.key))).go();
  }

  SimpleSelectStatement<$AppSettingsTable, AppSetting> _query(String key) {
    return _database.select(_database.appSettings)
      ..where((row) => row.key.equals(key));
  }

  T _decode<T>(NonSecretSetting<T> setting, AppSetting? row) {
    if (row == null) {
      return setting.defaultValue;
    }
    return setting.decode(row.value);
  }
}
