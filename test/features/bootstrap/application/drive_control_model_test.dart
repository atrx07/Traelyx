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
  });

  test('a recorder error fails closed', () {
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

    expect(model.action, DrivePrimaryAction.none);
    expect(model.actionLabel, 'Start unavailable');
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

RecorderStatus _recorder({bool active = false, String state = 'idle'}) {
  return RecorderStatus.fromMap(<Object?, Object?>{
    ...statusMap,
    'lifecycle': <Object?, Object?>{
      ...statusMap['lifecycle']! as Map<Object?, Object?>,
      'state': state,
      'active': active,
      'tripId': active ? tripId : null,
      'errorCode': state == 'error' ? 'recorder_error' : null,
    },
  });
}
