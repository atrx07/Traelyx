import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/settings/secure_value_store.dart';
import 'package:traelyx/core/settings/settings_providers.dart';

void main() {
  final apiKey = SecureValueKey('commentary.api_key');

  test('default secure store refuses to retain secret material', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(secureValueStoreProvider);

    expect(store, isA<UnavailableSecureValueStore>());

    await expectLater(
      store.write(apiKey, 'do-not-store'),
      throwsA(isA<SecureStorageUnavailableException>()),
    );
    await expectLater(
      store.read(apiKey),
      throwsA(isA<SecureStorageUnavailableException>()),
    );
    await expectLater(
      store.delete(apiKey),
      throwsA(isA<SecureStorageUnavailableException>()),
    );
  });

  test('secure provider can be replaced without changing callers', () async {
    final fake = _MemorySecureValueStore();
    final container = ProviderContainer(
      overrides: [secureValueStoreProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final store = container.read(secureValueStoreProvider);
    await store.write(apiKey, 'test-only');

    expect(await store.read(apiKey), 'test-only');
    await store.delete(apiKey);
    expect(await store.read(apiKey), isNull);
  });
}

final class _MemorySecureValueStore implements SecureValueStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(SecureValueKey key) async {
    _values.remove(key.name);
  }

  @override
  Future<String?> read(SecureValueKey key) async => _values[key.name];

  @override
  Future<void> write(SecureValueKey key, String value) async {
    _values[key.name] = value;
  }
}
