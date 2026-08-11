import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';

import 'recorder_bridge_test.dart' show statusMap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'io.github.atrx07.traelyx/recorder/provider-test',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('command controller refreshes the pull-based status provider', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return statusMap;
        });
    final container = ProviderContainer(
      overrides: [
        recorderBridgeProvider.overrideWithValue(
          const RecorderBridge(channel: channel),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(recorderStatusProvider.future);
    final commandStatus = await container
        .read(recorderCommandControllerProvider)
        .startTrip();
    final refreshedStatus = await container.read(recorderStatusProvider.future);

    expect(commandStatus.lifecycle.active, isTrue);
    expect(refreshedStatus.buffer.completedChunkCount, 2);
    expect(methods, ['getStatus', 'startTrip', 'getStatus']);
  });
}
