import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/settings/secure_value_store.dart';
import 'package:traelyx/features/cloud_commentary/data/commentary_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'commentary key lifecycle preserves unrelated account storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'traelyx.auth.session.v1': 'unrelated-session',
      });
      const store = CommentarySecureStore();
      final key = SecureValueKey('traelyx.commentary.groq.v1');
      await store.write(key, 'fixture-placeholder');
      expect(await store.read(key), 'fixture-placeholder');
      await store.delete(key);
      expect(await store.read(key), null);
      expect(
        await const FlutterSecureStorage().read(key: 'traelyx.auth.session.v1'),
        'unrelated-session',
      );
    },
  );
  test(
    'Android backup and device transfer exclude the separate commentary credential namespace',
    () {
      final legacy = File(
        'android/app/src/main/res/xml/backup_rules.xml',
      ).readAsStringSync();
      final modern = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      expect('TraelyxCommentary.xml'.allMatches(legacy).length, 1);
      expect('TraelyxCommentary.xml'.allMatches(modern).length, 2);
      expect('FlutterSecureKeyStorage.xml'.allMatches(legacy).length, 1);
      expect('FlutterSecureKeyStorage.xml'.allMatches(modern).length, 2);
      expect(modern, contains('TraelyxAuth.xml'));
      expect(modern, contains('FlutterSecureStorageConfiguration.xml'));
    },
  );
}
