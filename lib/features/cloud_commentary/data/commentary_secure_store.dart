import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:traelyx/core/settings/secure_value_store.dart';

/// Separate Android no-backup namespace; never falls back to plaintext storage.
class CommentarySecureStore implements SecureValueStore {
  const CommentarySecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              sharedPreferencesName: 'TraelyxCommentary',
              resetOnError: false,
            ),
          );
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(SecureValueKey key) => _storage.read(key: key.name);
  @override
  Future<void> write(SecureValueKey key, String value) =>
      _storage.write(key: key.name, value: value);
  @override
  Future<void> delete(SecureValueKey key) => _storage.delete(key: key.name);
}
