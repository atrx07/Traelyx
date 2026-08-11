import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';

import 'recorder_bridge_test.dart'
    show finalizationBatchMap, permissionStatusMap, statusMap, tripId;

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

  test('stop waits for transactional finalization before refreshing', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'getPendingFinalizations') {
            return finalizationBatchMap;
          }
          if (call.method == 'acknowledgeTripFinalization') {
            return <Object?, Object?>{
              'contractVersion': 1,
              'tripId': tripId,
              'acknowledged': true,
              'errorCode': null,
            };
          }
          return statusMap;
        });
    final container = ProviderContainer(
      overrides: [
        recorderBridgeProvider.overrideWithValue(
          const RecorderBridge(channel: channel),
        ),
        recorderFinalizationRepositoryProvider.overrideWithValue(
          _FakeFinalizationRepository(calls),
        ),
      ],
    );
    addTearDown(container.dispose);

    final status = await container
        .read(recorderCommandControllerProvider)
        .stopTrip();

    expect(status.lifecycle.tripId, tripId);
    expect(calls.take(6), [
      'getStatus',
      'stopTrip',
      'getPendingFinalizations',
      'repository:$tripId',
      'acknowledgeTripFinalization',
      'getStatus',
    ]);
    expect(calls.skip(6), everyElement('getStatus'));
  });
}

class _FakeFinalizationRepository implements RecorderFinalizationRepository {
  const _FakeFinalizationRepository(this.calls);

  final List<String> calls;

  @override
  Future<void> reconcile(RecorderTripFinalization finalization) async {
    calls.add('repository:${finalization.tripId}');
  }
}
