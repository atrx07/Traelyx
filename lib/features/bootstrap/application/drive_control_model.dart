import 'package:traelyx/core/platform/recorder_bridge.dart';

enum DrivePrimaryAction {
  requestPreciseLocation,
  openAppSettings,
  openLocationSettings,
  startTrip,
  stopTrip,
  none,
}

class DriveControlModel {
  const DriveControlModel({
    required this.title,
    required this.detail,
    required this.action,
    required this.actionLabel,
  });

  factory DriveControlModel.from({
    required RecorderPermissionStatus permissions,
    required RecorderStatus recorder,
  }) {
    if (recorder.lifecycle.state == 'stopping') {
      return const DriveControlModel(
        title: 'Stopping drive',
        detail: 'Traelyx is flushing the remaining local evidence safely.',
        action: DrivePrimaryAction.none,
        actionLabel: 'Stopping…',
      );
    }

    if (recorder.lifecycle.active) {
      return const DriveControlModel(
        title: 'Drive recording is active',
        detail: 'Location and motion samples are being stored on this phone.',
        action: DrivePrimaryAction.stopTrip,
        actionLabel: 'Stop drive',
      );
    }

    if (recorder.lifecycle.state == 'error') {
      return const DriveControlModel(
        title: 'Recorder needs attention',
        detail: 'Recording cannot start until the recorder error is cleared.',
        action: DrivePrimaryAction.none,
        actionLabel: 'Start unavailable',
      );
    }

    switch (permissions.locationState) {
      case RecorderPermissionState.requestable:
        return const DriveControlModel(
          title: 'Allow precise location',
          detail:
              'Traelyx needs precise location only while you record a drive.',
          action: DrivePrimaryAction.requestPreciseLocation,
          actionLabel: 'Allow precise location',
        );
      case RecorderPermissionState.approximateOnly:
        if (permissions.canRequestLocation) {
          return const DriveControlModel(
            title: 'Precise location is required',
            detail:
                'Approximate location is not accurate enough for honest trip telemetry.',
            action: DrivePrimaryAction.requestPreciseLocation,
            actionLabel: 'Use precise location',
          );
        }
        return const DriveControlModel(
          title: 'Choose precise location in Settings',
          detail:
              'Approximate location is not accurate enough for honest trip telemetry.',
          action: DrivePrimaryAction.openAppSettings,
          actionLabel: 'Open app settings',
        );
      case RecorderPermissionState.settingsRequired:
        return const DriveControlModel(
          title: 'Location permission is off',
          detail:
              'Open app settings and allow precise location while using Traelyx.',
          action: DrivePrimaryAction.openAppSettings,
          actionLabel: 'Open app settings',
        );
      case RecorderPermissionState.granted:
        break;
      case RecorderPermissionState.notRequired:
        return const DriveControlModel(
          title: 'Location support is unavailable',
          detail:
              'This device did not expose the location access needed to record.',
          action: DrivePrimaryAction.none,
          actionLabel: 'Start unavailable',
        );
    }

    if (!permissions.gpsProviderEnabled) {
      return const DriveControlModel(
        title: 'Turn on GPS location',
        detail:
            'Precise permission is ready, but the device location service is off.',
        action: DrivePrimaryAction.openLocationSettings,
        actionLabel: 'Open location settings',
      );
    }

    if (permissions.recordingReady) {
      return const DriveControlModel(
        title: 'Ready to record',
        detail:
            'Precise location and GPS are ready. Recording starts only when you tap below.',
        action: DrivePrimaryAction.startTrip,
        actionLabel: 'Start drive',
      );
    }

    return const DriveControlModel(
      title: 'Recorder is not ready',
      detail: 'Check location access before starting a drive.',
      action: DrivePrimaryAction.none,
      actionLabel: 'Start unavailable',
    );
  }

  final String title;
  final String detail;
  final DrivePrimaryAction action;
  final String actionLabel;
}
