import 'package:traelyx/core/settings/non_secret_setting.dart';

abstract interface class NonSecretSettingsRepository {
  Future<T> read<T>(NonSecretSetting<T> setting);

  Stream<T> watch<T>(NonSecretSetting<T> setting);

  Future<void> write<T>(NonSecretSetting<T> setting, T value);

  Future<void> reset<T>(NonSecretSetting<T> setting);
}
