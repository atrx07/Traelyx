abstract interface class SecureValueStore {
  Future<String?> read(SecureValueKey key);

  Future<void> write(SecureValueKey key, String value);

  Future<void> delete(SecureValueKey key);
}

final class SecureValueKey {
  factory SecureValueKey(String name) {
    if (!_secureKeyPattern.hasMatch(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Use a lowercase namespaced key such as provider.api_key.',
      );
    }
    return SecureValueKey._(name);
  }

  const SecureValueKey._(this.name);

  final String name;
}

/// Refuses secret persistence until a reviewed platform-backed provider is
/// installed. It must never fall back to Drift, shared preferences, or logs.
final class UnavailableSecureValueStore implements SecureValueStore {
  const UnavailableSecureValueStore();

  @override
  Future<void> delete(SecureValueKey key) => _unavailable();

  @override
  Future<String?> read(SecureValueKey key) => _unavailable();

  @override
  Future<void> write(SecureValueKey key, String value) => _unavailable();

  Future<Never> _unavailable() {
    return Future<Never>.error(const SecureStorageUnavailableException());
  }
}

final class SecureStorageUnavailableException implements Exception {
  const SecureStorageUnavailableException();

  @override
  String toString() {
    return 'SecureStorageUnavailableException: no secure provider installed';
  }
}

final _secureKeyPattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
