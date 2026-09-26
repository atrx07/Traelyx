import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/data/secure_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'session and PKCE verifier use distinct keys and can be cleared',
    () async {
      const storage = FlutterSecureStorage();
      const session = SecureAuthStorage(storage);
      const pkce = SecurePkceStorage(storage);

      await session.initialize();
      expect(await session.hasAccessToken(), isFalse);
      await session.persistSession('session-json');
      await pkce.setItem(key: 'flow.verifier', value: 'pkce-verifier');
      expect(await session.hasAccessToken(), isTrue);
      expect(await session.accessToken(), 'session-json');
      expect(await pkce.getItem(key: 'flow.verifier'), 'pkce-verifier');

      await session.removePersistedSession();
      expect(await session.hasAccessToken(), isFalse);
      expect(await pkce.getItem(key: 'flow.verifier'), 'pkce-verifier');
      await pkce.removeItem(key: 'flow.verifier');
      expect(await pkce.getItem(key: 'flow.verifier'), isNull);
    },
  );
}
