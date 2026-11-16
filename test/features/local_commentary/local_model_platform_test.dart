import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/local_commentary/data/local_model_platform.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(LocalModelPlatform.channel, null),
  );
  test(
    'metadata contract reads only no-backup root and capabilities',
    () async {
      messenger.setMockMethodCallHandler(LocalModelPlatform.channel, (
        call,
      ) async {
        expect(call.method, 'device');
        expect(call.arguments, null);
        return {
          'version': 1,
          'root': '/app/no_backup/local_commentary/v1',
          'api': 37,
          'abis': ['x86_64'],
          'freeBytes': 123456,
        };
      });
      final device = await const LocalModelPlatform().device();
      expect(device.androidApi, 37);
      expect(device.abis, ['x86_64']);
      expect(device.freeBytes, 123456);
    },
  );
  test(
    'missing plugin and malformed metadata expose no native/private detail',
    () async {
      for (final value in [
        null,
        {'version': 2},
        {
          'version': 1,
          'root': '/private',
          'api': 37,
          'abis': ['x86_64'],
          'freeBytes': -1,
        },
      ]) {
        messenger.setMockMethodCallHandler(
          LocalModelPlatform.channel,
          (_) async => value,
        );
        await expectLater(
          const LocalModelPlatform().device(),
          throwsA(
            isA<LocalCommentaryException>().having(
              (e) => e.toString(),
              'message',
              isNot(contains('private')),
            ),
          ),
        );
      }
      messenger.setMockMethodCallHandler(
        LocalModelPlatform.channel,
        (_) async => throw PlatformException(code: 'private secret'),
      );
      await expectLater(
        const LocalModelPlatform().device(),
        throwsA(
          isA<LocalCommentaryException>().having(
            (e) => e.failure,
            'failure',
            LocalFailure.storage,
          ),
        ),
      );
    },
  );
}
