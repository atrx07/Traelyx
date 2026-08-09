import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/settings/drift_non_secret_settings_repository.dart';
import 'package:traelyx/core/settings/non_secret_settings_repository.dart';
import 'package:traelyx/core/settings/secure_value_store.dart';

final nonSecretSettingsRepositoryProvider =
    Provider<NonSecretSettingsRepository>((ref) {
      return DriftNonSecretSettingsRepository(ref.watch(appDatabaseProvider));
    });

final secureValueStoreProvider = Provider<SecureValueStore>((ref) {
  return const UnavailableSecureValueStore();
});
