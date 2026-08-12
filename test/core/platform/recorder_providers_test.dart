import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/database/trip_debug_export_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';
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

  test('failed stop still refreshes the pull-based status provider', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'stopTrip') {
            throw PlatformException(code: 'stop_failed');
          }
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
    await expectLater(
      container.read(recorderCommandControllerProvider).stopTrip(),
      throwsA(isA<PlatformException>()),
    );
    await container.read(recorderStatusProvider.future);

    expect(methods, ['getStatus', 'getStatus', 'stopTrip', 'getStatus']);
  });

  test('failed stop refreshes watched finalization attention state', () async {
    var finalizationReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'stopTrip') {
            throw PlatformException(code: 'stop_failed');
          }
          return statusMap;
        });
    final container = ProviderContainer(
      overrides: [
        recorderBridgeProvider.overrideWithValue(
          const RecorderBridge(channel: channel),
        ),
        recorderFinalizationSyncProvider.overrideWith((ref) async {
          finalizationReads += 1;
          return const RecorderFinalizationSyncResult(
            reconciledTripIds: <String>[],
            invalidNativeRecordCount: 0,
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(recorderFinalizationSyncProvider.future);
    await expectLater(
      container.read(recorderCommandControllerProvider).stopTrip(),
      throwsA(isA<PlatformException>()),
    );
    await container.read(recorderFinalizationSyncProvider.future);

    expect(finalizationReads, 2);
  });

  test('latest export waits for startup finalization reconciliation', () async {
    final reconciliation = Completer<RecorderFinalizationSyncResult>();
    final repository = _FakeTripDebugExportRepository();
    final container = ProviderContainer(
      overrides: [
        recorderFinalizationSyncProvider.overrideWith(
          (ref) => reconciliation.future,
        ),
        tripDebugExportRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final latestTrip = container.read(
      latestTripDebugExportTripIdProvider.future,
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.readCount, 0);

    reconciliation.complete(
      const RecorderFinalizationSyncResult(
        reconciledTripIds: <String>[],
        invalidNativeRecordCount: 0,
      ),
    );

    expect(await latestTrip, tripId);
    expect(repository.readCount, 1);
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

class _FakeTripDebugExportRepository implements TripDebugExportRepository {
  int readCount = 0;

  @override
  Future<String?> latestFinalizedTripId() async {
    readCount += 1;
    return tripId;
  }
}
