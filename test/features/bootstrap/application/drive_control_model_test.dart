import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/features/bootstrap/application/drive_control_model.dart';

import '../../../core/platform/recorder_bridge_test.dart'
    show permissionStatusMap, statusMap, tripId;

void main() {
  test('requests precise location without silently accepting approximate', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.approximateOnly,
        coarse: true,
        canRequestLocation: true,
      ),
      recorder: _recorder(),
    );

    expect(model.action, DrivePrimaryAction.requestPreciseLocation);
    expect(model.actionLabel, 'Use precise location');
  });

  test('routes exhausted location denial to app settings', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.settingsRequired,
        canRequestLocation: false,
      ),
      recorder: _recorder(),
    );

    expect(model.action, DrivePrimaryAction.openAppSettings);
  });

  test('routes a disabled GPS provider to location settings', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        gps: false,
      ),
      recorder: _recorder(),
    );

    expect(model.action, DrivePrimaryAction.openLocationSettings);
  });

  test('starts only when precise location and GPS are ready', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        gps: true,
        recordingReady: true,
      ),
      recorder: _recorder(),
    );

    expect(model.action, DrivePrimaryAction.startTrip);
    expect(model.actionLabel, 'Start drive');
    expect(model.mode, DrivePresentationMode.ready);
    expect(model.eyebrow, 'READY TO DRIVE');
    expect(
      model.health
          .singleWhere((item) => item.kind == DriveHealthKind.location)
          .value,
      'Precise',
    );
    expect(
      model.health
          .singleWhere((item) => item.kind == DriveHealthKind.motion)
          .value,
      'On Start',
    );
  });

  test('notification denial does not block a ready recorder', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        notificationState: RecorderPermissionState.settingsRequired,
        fine: true,
        coarse: true,
        gps: true,
        recordingReady: true,
        foregroundNotificationVisible: false,
      ),
      recorder: _recorder(),
    );

    expect(model.action, DrivePrimaryAction.startTrip);
  });

  test('an active recorder always exposes stop', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.settingsRequired,
      ),
      recorder: _recorder(active: true, state: 'recording'),
    );

    expect(model.action, DrivePrimaryAction.stopTrip);
    expect(model.actionLabel, 'Stop drive');
    expect(model.isLive, isTrue);
  });

  test(
    'an active recorder reports GPS acquisition before claiming samples',
    () {
      final model = DriveControlModel.from(
        permissions: _permissions(
          locationState: RecorderPermissionState.granted,
        ),
        recorder: _recorder(active: true, state: 'recording', gnssSamples: 0),
      );

      expect(model.title, 'Recording started — finding GPS');
      expect(model.action, DrivePrimaryAction.stopTrip);
      expect(
        model.health
            .singleWhere((item) => item.kind == DriveHealthKind.gps)
            .value,
        'Finding fix',
      );
    },
  );

  test('an active recorder reports missing motion streams', () {
    final model = DriveControlModel.from(
      permissions: _permissions(locationState: RecorderPermissionState.granted),
      recorder: _recorder(
        active: true,
        state: 'recording',
        accelerometerSamples: 0,
      ),
    );

    expect(model.title, 'Recording started — checking motion sensors');
    expect(model.action, DrivePrimaryAction.stopTrip);
  });

  test('an active recorder propagates unreliable motion accuracy', () {
    final model = DriveControlModel.from(
      permissions: _permissions(locationState: RecorderPermissionState.granted),
      recorder: _recorder(
        active: true,
        state: 'recording',
        accelerometerSamples: 200,
        gyroscopeSamples: 200,
        unreliableSamples: 100,
      ),
    );

    expect(model.title, 'Recording active with limited motion confidence');
    expect(model.action, DrivePrimaryAction.stopTrip);
    expect(
      model.health
          .singleWhere((item) => item.kind == DriveHealthKind.motion)
          .tone,
      DriveStatusTone.caution,
    );
  });

  test('a transient unreliable sample does not become a permanent warning', () {
    final model = DriveControlModel.from(
      permissions: _permissions(locationState: RecorderPermissionState.granted),
      recorder: _recorder(
        active: true,
        state: 'recording',
        unreliableSamples: 1,
      ),
    );

    // The shared bridge fixture includes one low-accuracy GPS fix.
    expect(model.title, 'Recording includes limited GPS evidence');
    expect(
      model.health
          .singleWhere((item) => item.kind == DriveHealthKind.motion)
          .value,
      'Recording',
    );
  });

  test('a recorder error can finalize only verified preserved evidence', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        gps: true,
        recordingReady: true,
      ),
      recorder: _recorder(state: 'error'),
    );

    expect(model.action, DrivePrimaryAction.stopTrip);
    expect(model.actionLabel, 'Finalize drive');
  });

  test('a stopping recorder disables repeated commands', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        gps: true,
        recordingReady: true,
      ),
      recorder: _recorder(active: true, state: 'stopping'),
    );

    expect(model.action, DrivePrimaryAction.none);
    expect(model.actionLabel, 'Stopping…');
    expect(model.mode, DrivePresentationMode.stopping);
  });

  test('active storage failures remain visible in compact health', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        gps: true,
        recordingReady: true,
      ),
      recorder: _recorder(active: true, state: 'recording', writeFailures: 1),
    );

    final storage = model.health.singleWhere(
      (item) => item.kind == DriveHealthKind.storage,
    );
    expect(storage.value, 'Needs attention');
    expect(storage.tone, DriveStatusTone.critical);
    expect(model.title, 'Local saving needs attention');
    expect(model.tone, DriveStatusTone.critical);
    expect(model.action, DrivePrimaryAction.stopTrip);
  });

  test(
    'low accuracy stays cumulative and does not claim current reception',
    () {
      final model = DriveControlModel.from(
        permissions: _permissions(
          locationState: RecorderPermissionState.granted,
        ),
        recorder: _recorder(active: true, state: 'recording'),
      );
      expect(model.title, 'Recording includes limited GPS evidence');
      expect(model.tone, DriveStatusTone.caution);
      final gps = model.health.singleWhere(
        (item) => item.kind == DriveHealthKind.gps,
      );
      expect(gps.value, 'Limited evidence');
      expect(gps.detail, contains('1 low-accuracy fix recorded'));
      expect(model.detail, contains('Current GPS accuracy is not available'));
      expect(model.action, DrivePrimaryAction.stopTrip);
    },
  );

  test('GPS switched off after fixes cannot leave a healthy live headline', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        gps: false,
      ),
      recorder: _recorder(active: true, state: 'recording'),
    );
    expect(model.title, 'Recording with GPS interruptions');
    expect(model.detail, contains('safely parked'));
    expect(model.tone, DriveStatusTone.caution);
    expect(model.action, DrivePrimaryAction.stopTrip);
  });

  test('reported GPS failure remains visible after earlier fixes', () {
    final model = DriveControlModel.from(
      permissions: _permissions(locationState: RecorderPermissionState.granted),
      recorder: _recorder(
        active: true,
        state: 'recording',
        gpsError: 'gnss_registration_failed',
      ),
    );
    expect(model.title, 'Recording with GPS interruptions');
    expect(
      model.health.singleWhere((item) => item.kind == DriveHealthKind.gps).tone,
      DriveStatusTone.caution,
    );
  });

  test(
    'a clean active snapshot remains healthy without inventing accuracy',
    () {
      final model = DriveControlModel.from(
        permissions: _permissions(
          locationState: RecorderPermissionState.granted,
        ),
        recorder: _recorder(
          active: true,
          state: 'recording',
          lowAccuracySamples: 0,
        ),
      );
      expect(model.title, 'Drive recording is active');
      expect(model.tone, DriveStatusTone.positive);
      expect(
        model.health
            .singleWhere((item) => item.kind == DriveHealthKind.gps)
            .value,
        'Recording',
      );
    },
  );

  test('live local-save health pluralizes one completed chunk', () {
    final model = DriveControlModel.from(
      permissions: _permissions(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        gps: true,
        recordingReady: true,
      ),
      recorder: _recorder(active: true, state: 'recording', completedChunks: 1),
    );

    expect(
      model.health
          .singleWhere((item) => item.kind == DriveHealthKind.storage)
          .detail,
      '1 chunk completed',
    );
  });
}

RecorderPermissionStatus _permissions({
  required RecorderPermissionState locationState,
  RecorderPermissionState notificationState = RecorderPermissionState.granted,
  bool fine = false,
  bool coarse = false,
  bool gps = true,
  bool canRequestLocation = false,
  bool recordingReady = false,
  bool foregroundNotificationVisible = true,
}) {
  return RecorderPermissionStatus.fromMap(<Object?, Object?>{
    ...permissionStatusMap,
    'locationState': locationState.wireName,
    'notificationState': notificationState.wireName,
    'fineLocationGranted': fine,
    'coarseLocationGranted': coarse,
    'gpsProviderEnabled': gps,
    'canRequestLocation': canRequestLocation,
    'canRequestNotification':
        notificationState == RecorderPermissionState.requestable,
    'recordingReady': recordingReady,
    'foregroundNotificationVisible': foregroundNotificationVisible,
  });
}

RecorderStatus _recorder({
  bool active = false,
  String state = 'idle',
  int gnssSamples = 3,
  int? lowAccuracySamples,
  String? gpsError,
  int accelerometerSamples = 20,
  int gyroscopeSamples = 19,
  int unreliableSamples = 0,
  int writeFailures = 0,
  int completedChunks = 2,
}) {
  return RecorderStatus.fromMap(<Object?, Object?>{
    ...statusMap,
    'lifecycle': <Object?, Object?>{
      ...statusMap['lifecycle']! as Map<Object?, Object?>,
      'state': state,
      'active': active,
      'tripId': active ? tripId : null,
      'errorCode': state == 'error' ? 'recorder_error' : null,
    },
    'gnss': <Object?, Object?>{
      ...statusMap['gnss']! as Map<Object?, Object?>,
      'acceptedSampleCount': gnssSamples,
      'lowAccuracySampleCount': ?lowAccuracySamples,
      'errorCode': gpsError,
    },
    'imu': <Object?, Object?>{
      ...statusMap['imu']! as Map<Object?, Object?>,
      'accelerometerAcceptedSampleCount': accelerometerSamples,
      'gyroscopeAcceptedSampleCount': gyroscopeSamples,
      'unreliableAccuracySampleCount': unreliableSamples,
    },
    'buffer': <Object?, Object?>{
      ...statusMap['buffer']! as Map<Object?, Object?>,
      'writeFailureCount': writeFailures,
      'completedChunkCount': completedChunks,
    },
  });
}
