import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';

import 'recorder_bridge_test.dart' show permissionStatusMap, statusMap;

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

  test(
    'permission actions refresh the pull-based permission provider',
    () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'getCapabilities') {
              return const {
                'bridgeVersion': 1,
                'statusContractVersion': 1,
                'implementationState': 'bridge_ready',
                'recordingAvailable': false,
                'serviceRegistered': true,
                'commandsAvailable': true,
                'healthAvailable': true,
                'permissionOnboardingAvailable': true,
              };
            }
            if (call.method == 'getStatus') return statusMap;
            return permissionStatusMap;
          });
      final container = ProviderContainer(
        overrides: [
          recorderBridgeProvider.overrideWithValue(
            const RecorderBridge(channel: channel),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recorderPermissionStatusProvider.future);
      final actionStatus = await container
          .read(recorderPermissionControllerProvider)
          .requestLocation();
      final refreshedStatus = await container.read(
        recorderPermissionStatusProvider.future,
      );

      expect(actionStatus.canRequestLocation, isTrue);
      expect(refreshedStatus.backgroundLocationRequired, isFalse);
      expect(methods, [
        'getPermissionStatus',
        'requestLocationPermission',
        'getCapabilities',
        'getStatus',
        'getPermissionStatus',
      ]);
    },
  );
}
