import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(RecorderBridge.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('capability parser defaults to unavailable conservatively', () {
    final capabilities = RecorderCapabilities.fromMap(const {
      'implementationState': 7,
      'recordingAvailable': 'yes',
      'commandsAvailable': 1,
    });

    expect(capabilities.bridgeVersion, 0);
    expect(capabilities.statusContractVersion, 0);
    expect(capabilities.implementationState, 'unknown');
    expect(capabilities.recordingAvailable, isFalse);
    expect(capabilities.serviceRegistered, isFalse);
    expect(capabilities.commandsAvailable, isFalse);
    expect(capabilities.healthAvailable, isFalse);
    expect(capabilities.permissionOnboardingAvailable, isFalse);
  });

  test('capability parser preserves the versioned native response', () {
    final capabilities = RecorderCapabilities.fromMap(const {
      'bridgeVersion': 1,
      'statusContractVersion': 1,
      'implementationState': 'bridge_ready',
      'recordingAvailable': false,
      'serviceRegistered': true,
      'commandsAvailable': true,
      'healthAvailable': true,
      'permissionOnboardingAvailable': true,
    });

    expect(capabilities.bridgeVersion, 1);
    expect(capabilities.statusContractVersion, 1);
    expect(capabilities.implementationState, 'bridge_ready');
    expect(capabilities.recordingAvailable, isFalse);
    expect(capabilities.commandsAvailable, isTrue);
    expect(capabilities.healthAvailable, isTrue);
    expect(capabilities.permissionOnboardingAvailable, isTrue);
  });

  test('permission parser preserves the bounded onboarding state', () {
    final status = RecorderPermissionStatus.fromMap(permissionStatusMap);

    expect(status.contractVersion, 1);
    expect(status.platformApiLevel, 35);
    expect(status.locationState, RecorderPermissionState.requestable);
    expect(status.notificationState, RecorderPermissionState.requestable);
    expect(status.backgroundLocationRequired, isFalse);
    expect(status.recordingReady, isFalse);
  });

  test('permission parser rejects unknown, missing, and mistyped values', () {
    expect(
      () => RecorderPermissionStatus.fromMap(const {}),
      throwsA(isA<FormatException>()),
    );

    final unknownState = Map<Object?, Object?>.from(permissionStatusMap);
    unknownState['locationState'] = 'always_allow';
    expect(
      () => RecorderPermissionStatus.fromMap(unknownState),
      throwsA(isA<FormatException>()),
    );

    final unknownVersion = Map<Object?, Object?>.from(permissionStatusMap);
    unknownVersion['contractVersion'] = 2;
    expect(
      () => RecorderPermissionStatus.fromMap(unknownVersion),
      throwsA(isA<FormatException>()),
    );

    final unsafeFlag = Map<Object?, Object?>.from(permissionStatusMap);
    unsafeFlag['backgroundLocationRequired'] = 'no';
    expect(
      () => RecorderPermissionStatus.fromMap(unsafeFlag),
      throwsA(isA<FormatException>()),
    );
  });

  test('status parser preserves aggregate versioned health', () {
    final status = RecorderStatus.fromMap(statusMap);

    expect(status.contractVersion, 1);
    expect(status.lifecycle.state, 'recording');
    expect(status.lifecycle.tripId, tripId);
    expect(status.gnss.acceptedSampleCount, 3);
    expect(status.imu.accelerometerAcceptedSampleCount, 20);
    expect(status.buffer.completedChunkCount, 2);
    expect(status.buffer.persistedByteCount, 4096);
  });

  test('status parser rejects missing, mistyped, and negative evidence', () {
    expect(
      () => RecorderStatus.fromMap(const {}),
      throwsA(isA<FormatException>()),
    );
    final malformed = Map<Object?, Object?>.from(statusMap);
    malformed['gnss'] = <Object?, Object?>{
      ...statusMap['gnss']! as Map<Object?, Object?>,
      'acceptedSampleCount': -1,
    };
    expect(
      () => RecorderStatus.fromMap(malformed),
      throwsA(isA<FormatException>()),
    );

    final unknownVersion = Map<Object?, Object?>.from(statusMap);
    unknownVersion['contractVersion'] = 2;
    expect(
      () => RecorderStatus.fromMap(unknownVersion),
      throwsA(isA<FormatException>()),
    );

    final unsafeError = Map<Object?, Object?>.from(statusMap);
    unsafeError['lifecycle'] = <Object?, Object?>{
      ...statusMap['lifecycle']! as Map<Object?, Object?>,
      'errorCode': 'java.lang.IllegalStateException: raw details',
    };
    expect(
      () => RecorderStatus.fromMap(unsafeError),
      throwsA(isA<FormatException>()),
    );
  });

  test('bridge invokes every versioned status and command method', () async {
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
              'permissionOnboardingAvailable': false,
            };
          }
          if (call.method.contains('Permission') ||
              call.method.contains('Settings')) {
            return permissionStatusMap;
          }
          return statusMap;
        });
    const bridge = RecorderBridge(channel: channel);

    await bridge.getCapabilities();
    await bridge.getStatus();
    await bridge.getPermissionStatus();
    await bridge.requestLocationPermission();
    await bridge.requestNotificationPermission();
    await bridge.openAppSettings();
    await bridge.openLocationSettings();
    await bridge.startTrip();
    await bridge.recoverTrip();
    await bridge.stopTrip();

    expect(methods, [
      'getCapabilities',
      'getStatus',
      'getPermissionStatus',
      'requestLocationPermission',
      'requestNotificationPermission',
      'openAppSettings',
      'openLocationSettings',
      'startTrip',
      'recoverTrip',
      'stopTrip',
    ]);
  });

  test('bridge rejects null status responses', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(
      const RecorderBridge(channel: channel).getStatus(),
      throwsA(isA<FormatException>()),
    );
  });

  test('bridge rejects null permission responses', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(
      const RecorderBridge(channel: channel).getPermissionStatus(),
      throwsA(isA<FormatException>()),
    );
  });
}

const permissionStatusMap = <Object?, Object?>{
  'contractVersion': 1,
  'platformApiLevel': 35,
  'locationState': 'requestable',
  'notificationState': 'requestable',
  'fineLocationGranted': false,
  'coarseLocationGranted': false,
  'gpsProviderEnabled': true,
  'canRequestLocation': true,
  'canRequestNotification': true,
  'backgroundLocationRequired': false,
  'recordingReady': false,
  'foregroundNotificationVisible': false,
};

const tripId = 'd181f268-f3ef-4a43-a142-8bf0671dcd49';

const statusMap = <Object?, Object?>{
  'contractVersion': 1,
  'bridgeVersion': 1,
  'lifecycle': <Object?, Object?>{
    'contractVersion': 1,
    'state': 'recording',
    'active': true,
    'tripId': tripId,
    'recoveryCount': 1,
    'errorCode': null,
  },
  'gnss': <Object?, Object?>{
    'contractVersion': 1,
    'state': 'active',
    'provider': 'gps',
    'requestedIntervalMillis': 1000,
    'acceptedSampleCount': 3,
    'rejectedSampleCount': 0,
    'lowAccuracySampleCount': 1,
    'clockDiscontinuityCount': 0,
    'mockSignalCount': 0,
    'providerDisabledCount': 0,
    'registrationFailureCount': 0,
    'lastFixHadSpeed': true,
    'lastFixHadBearing': false,
    'errorCode': null,
  },
  'imu': <Object?, Object?>{
    'contractVersion': 1,
    'state': 'active',
    'accelerometerAvailable': true,
    'gyroscopeAvailable': true,
    'accelerometerBatchingAvailable': true,
    'gyroscopeBatchingAvailable': true,
    'accelerometerAcceptedSampleCount': 20,
    'gyroscopeAcceptedSampleCount': 19,
    'rejectedSampleCount': 0,
    'unreliableAccuracySampleCount': 0,
    'clockDiscontinuityCount': 0,
    'dropoutCount': 0,
    'accuracyChangeCount': 0,
    'registrationFailureCount': 0,
    'errorCode': null,
  },
  'buffer': <Object?, Object?>{
    'contractVersion': 1,
    'state': 'active',
    'queueCapacity': 1024,
    'reorderBufferCapacity': 1024,
    'queueDepth': 0,
    'bufferedSampleCount': 4,
    'completedChunkCount': 2,
    'persistedGnssSampleCount': 3,
    'persistedAccelerometerSampleCount': 20,
    'persistedGyroscopeSampleCount': 19,
    'persistedByteCount': 4096,
    'recoveredValidChunkCount': 1,
    'corruptChunkCount': 0,
    'orphanedWriteCount': 0,
    'orderingViolationCount': 0,
    'overflowCount': 0,
    'invalidTripTimeCount': 0,
    'lateSampleCount': 0,
    'writeFailureCount': 0,
    'lastCompletedSequence': 1,
    'hasCommittedElapsedBoundary': true,
    'errorCode': null,
  },
};
