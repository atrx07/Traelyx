import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session JSON and PKCE verifiers use Android Keystore-backed encrypted
/// storage. Keep both out of preferences, logs, and Android backups.
final class SecureAuthStorage extends LocalStorage {
  const SecureAuthStorage(this.storage);

  static const _sessionKey = 'traelyx.auth.session.v1';

  final FlutterSecureStorage storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => storage.delete(key: _sessionKey);
}

final class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage(this.storage);

  final FlutterSecureStorage storage;

  String _key(String key) => 'traelyx.auth.pkce.${Uri.encodeComponent(key)}';

  @override
  Future<String?> getItem({required String key}) =>
      storage.read(key: _key(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      storage.write(key: _key(key), value: value);

  @override
  Future<void> removeItem({required String key}) =>
      storage.delete(key: _key(key));
}
