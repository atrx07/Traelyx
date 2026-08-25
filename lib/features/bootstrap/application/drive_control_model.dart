import 'package:traelyx/core/platform/recorder_bridge.dart';

enum DrivePrimaryAction {
  requestPreciseLocation,
  openAppSettings,
  openLocationSettings,
  startTrip,
  stopTrip,
  none,
}

enum DrivePresentationMode { ready, attention, live, stopping }

enum DriveStatusTone { positive, caution, critical, information, neutral }

enum DriveHealthKind { location, gps, motion, storage }

class DriveHealthItem {
  const DriveHealthItem({
    required this.kind,
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final DriveHealthKind kind;
  final String label;
  final String value;
  final String detail;
  final DriveStatusTone tone;
}

class DriveControlModel {
  const DriveControlModel({
    required this.mode,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.action,
    required this.actionLabel,
    required this.tone,
    required this.health,
  });

  factory DriveControlModel.from({
    required RecorderPermissionStatus permissions,
    required RecorderStatus recorder,
  }) {
    if (recorder.lifecycle.state == 'stopping') {
      return DriveControlModel(
        mode: DrivePresentationMode.stopping,
        eyebrow: 'SAVING DRIVE',
        title: 'Stopping drive',
        detail: 'Traelyx is flushing the remaining local evidence safely.',
        action: DrivePrimaryAction.none,
        actionLabel: 'Stopping…',
        tone: DriveStatusTone.information,
        health: _healthItems(permissions: permissions, recorder: recorder),
      );
    }

    if (recorder.lifecycle.active) {
      if (recorder.gnss.acceptedSampleCount == 0) {
        return DriveControlModel(
          mode: DrivePresentationMode.live,
          eyebrow: 'DRIVE IN PROGRESS',
          title: 'Recording started — finding GPS',
          detail:
              'Keep the phone exposed and remain stationary until Traelyx confirms GPS is recording.',
          action: DrivePrimaryAction.stopTrip,
          actionLabel: 'Stop drive',
          tone: DriveStatusTone.caution,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
      }
      if (recorder.imu.accelerometerAcceptedSampleCount == 0 ||
          recorder.imu.gyroscopeAcceptedSampleCount == 0) {
        return DriveControlModel(
          mode: DrivePresentationMode.live,
          eyebrow: 'DRIVE IN PROGRESS',
          title: 'Recording started — checking motion sensors',
          detail:
              'Keep the phone still briefly while Traelyx confirms both motion sensors.',
          action: DrivePrimaryAction.stopTrip,
          actionLabel: 'Stop drive',
          tone: DriveStatusTone.caution,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
      }
      if (_hasPersistentUnreliableMotion(recorder)) {
        return DriveControlModel(
          mode: DrivePresentationMode.live,
          eyebrow: 'DRIVE IN PROGRESS',
          title: 'Recording active with limited motion confidence',
          detail:
              'GPS and motion evidence are stored, but Android reports persistently unreliable motion-sensor accuracy.',
          action: DrivePrimaryAction.stopTrip,
          actionLabel: 'Stop drive',
          tone: DriveStatusTone.caution,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
      }
      return DriveControlModel(
        mode: DrivePresentationMode.live,
        eyebrow: 'DRIVE IN PROGRESS',
        title: 'Drive recording is active',
        detail: 'GPS and motion samples are being stored on this phone.',
        action: DrivePrimaryAction.stopTrip,
        actionLabel: 'Stop drive',
        tone: DriveStatusTone.positive,
        health: _healthItems(permissions: permissions, recorder: recorder),
      );
    }

    if (recorder.lifecycle.state == 'error') {
      return DriveControlModel(
        mode: DrivePresentationMode.attention,
        eyebrow: 'RECOVERY NEEDED',
        title: 'Finalize interrupted drive',
        detail:
            'Traelyx preserved the recorder error and will index only verified local evidence.',
        action: DrivePrimaryAction.stopTrip,
        actionLabel: 'Finalize drive',
        tone: DriveStatusTone.critical,
        health: _healthItems(permissions: permissions, recorder: recorder),
      );
    }

    switch (permissions.locationState) {
      case RecorderPermissionState.requestable:
        return DriveControlModel(
          mode: DrivePresentationMode.attention,
          eyebrow: 'SETUP NEEDED',
          title: 'Allow precise location',
          detail:
              'Traelyx needs precise location only while you record a drive.',
          action: DrivePrimaryAction.requestPreciseLocation,
          actionLabel: 'Allow precise location',
          tone: DriveStatusTone.caution,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
      case RecorderPermissionState.approximateOnly:
        if (permissions.canRequestLocation) {
          return DriveControlModel(
            mode: DrivePresentationMode.attention,
            eyebrow: 'SETUP NEEDED',
            title: 'Precise location is required',
            detail:
                'Approximate location is not accurate enough for honest trip telemetry.',
            action: DrivePrimaryAction.requestPreciseLocation,
            actionLabel: 'Use precise location',
            tone: DriveStatusTone.caution,
            health: _healthItems(permissions: permissions, recorder: recorder),
          );
        }
        return DriveControlModel(
          mode: DrivePresentationMode.attention,
          eyebrow: 'SETUP NEEDED',
          title: 'Choose precise location in Settings',
          detail:
              'Approximate location is not accurate enough for honest trip telemetry.',
          action: DrivePrimaryAction.openAppSettings,
          actionLabel: 'Open app settings',
          tone: DriveStatusTone.caution,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
      case RecorderPermissionState.settingsRequired:
        return DriveControlModel(
          mode: DrivePresentationMode.attention,
          eyebrow: 'SETUP NEEDED',
          title: 'Location permission is off',
          detail:
              'Open app settings and allow precise location while using Traelyx.',
          action: DrivePrimaryAction.openAppSettings,
          actionLabel: 'Open app settings',
          tone: DriveStatusTone.caution,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
      case RecorderPermissionState.granted:
        break;
      case RecorderPermissionState.notRequired:
        return DriveControlModel(
          mode: DrivePresentationMode.attention,
          eyebrow: 'UNAVAILABLE',
          title: 'Location support is unavailable',
          detail:
              'This device did not expose the location access needed to record.',
          action: DrivePrimaryAction.none,
          actionLabel: 'Start unavailable',
          tone: DriveStatusTone.critical,
          health: _healthItems(permissions: permissions, recorder: recorder),
        );
    }

    if (!permissions.gpsProviderEnabled) {
      return DriveControlModel(
        mode: DrivePresentationMode.attention,
        eyebrow: 'SETUP NEEDED',
        title: 'Turn on GPS location',
        detail:
            'Precise permission is ready, but the device location service is off.',
        action: DrivePrimaryAction.openLocationSettings,
        actionLabel: 'Open location settings',
        tone: DriveStatusTone.caution,
        health: _healthItems(permissions: permissions, recorder: recorder),
      );
    }

    if (permissions.recordingReady) {
      return DriveControlModel(
        mode: DrivePresentationMode.ready,
        eyebrow: 'READY TO DRIVE',
        title: 'Ready to record',
        detail:
            'Precise location and GPS are ready. Recording starts only when you tap below.',
        action: DrivePrimaryAction.startTrip,
        actionLabel: 'Start drive',
        tone: DriveStatusTone.positive,
        health: _healthItems(permissions: permissions, recorder: recorder),
      );
    }

    return DriveControlModel(
      mode: DrivePresentationMode.attention,
      eyebrow: 'NOT READY',
      title: 'Recorder is not ready',
      detail: 'Check location access before starting a drive.',
      action: DrivePrimaryAction.none,
      actionLabel: 'Start unavailable',
      tone: DriveStatusTone.critical,
      health: _healthItems(permissions: permissions, recorder: recorder),
    );
  }

  final DrivePresentationMode mode;
  final String eyebrow;
  final String title;
  final String detail;
  final DrivePrimaryAction action;
  final String actionLabel;
  final DriveStatusTone tone;
  final List<DriveHealthItem> health;

  bool get isLive =>
      mode == DrivePresentationMode.live ||
      mode == DrivePresentationMode.stopping;
}

bool _hasPersistentUnreliableMotion(RecorderStatus recorder) {
  final motionSampleCount =
      recorder.imu.accelerometerAcceptedSampleCount +
      recorder.imu.gyroscopeAcceptedSampleCount;
  return recorder.imu.unreliableAccuracySampleCount >= 100 &&
      recorder.imu.unreliableAccuracySampleCount * 4 >= motionSampleCount;
}

List<DriveHealthItem> _healthItems({
  required RecorderPermissionStatus permissions,
  required RecorderStatus recorder,
}) {
  final active = recorder.lifecycle.active;
  final hasGpsFailure =
      recorder.gnss.errorCode != null ||
      recorder.gnss.registrationFailureCount > 0 ||
      recorder.gnss.providerDisabledCount > 0;
  final hasMotionFailure =
      recorder.imu.errorCode != null ||
      recorder.imu.registrationFailureCount > 0 ||
      !recorder.imu.accelerometerAvailable ||
      !recorder.imu.gyroscopeAvailable;
  final hasStorageFailure =
      recorder.buffer.errorCode != null ||
      recorder.buffer.writeFailureCount > 0 ||
      recorder.buffer.overflowCount > 0 ||
      recorder.buffer.corruptChunkCount > 0 ||
      recorder.buffer.orderingViolationCount > 0;

  final location = switch (permissions.locationState) {
    RecorderPermissionState.granted => const DriveHealthItem(
      kind: DriveHealthKind.location,
      label: 'Location',
      value: 'Precise',
      detail: 'While recording only',
      tone: DriveStatusTone.positive,
    ),
    RecorderPermissionState.approximateOnly => const DriveHealthItem(
      kind: DriveHealthKind.location,
      label: 'Location',
      value: 'Approximate',
      detail: 'Precise access needed',
      tone: DriveStatusTone.caution,
    ),
    RecorderPermissionState.requestable => const DriveHealthItem(
      kind: DriveHealthKind.location,
      label: 'Location',
      value: 'Not allowed',
      detail: 'Tap to choose access',
      tone: DriveStatusTone.caution,
    ),
    RecorderPermissionState.settingsRequired => const DriveHealthItem(
      kind: DriveHealthKind.location,
      label: 'Location',
      value: 'Off',
      detail: 'Change in app settings',
      tone: DriveStatusTone.critical,
    ),
    RecorderPermissionState.notRequired => const DriveHealthItem(
      kind: DriveHealthKind.location,
      label: 'Location',
      value: 'Unavailable',
      detail: 'Not exposed by device',
      tone: DriveStatusTone.critical,
    ),
  };

  final gps = !permissions.gpsProviderEnabled
      ? const DriveHealthItem(
          kind: DriveHealthKind.gps,
          label: 'GPS',
          value: 'Off',
          detail: 'Turn on device location',
          tone: DriveStatusTone.critical,
        )
      : hasGpsFailure
      ? const DriveHealthItem(
          kind: DriveHealthKind.gps,
          label: 'GPS',
          value: 'Limited',
          detail: 'Recorder reported a problem',
          tone: DriveStatusTone.caution,
        )
      : active && recorder.gnss.acceptedSampleCount == 0
      ? const DriveHealthItem(
          kind: DriveHealthKind.gps,
          label: 'GPS',
          value: 'Finding fix',
          detail: 'No accepted fix yet',
          tone: DriveStatusTone.caution,
        )
      : active
      ? DriveHealthItem(
          kind: DriveHealthKind.gps,
          label: 'GPS',
          value: 'Recording',
          detail: '${recorder.gnss.acceptedSampleCount} accepted fixes',
          tone: DriveStatusTone.positive,
        )
      : const DriveHealthItem(
          kind: DriveHealthKind.gps,
          label: 'GPS',
          value: 'On',
          detail: 'Fix checked after Start',
          tone: DriveStatusTone.positive,
        );

  final motion = !active
      ? const DriveHealthItem(
          kind: DriveHealthKind.motion,
          label: 'Motion',
          value: 'On Start',
          detail: 'Checked when recording begins',
          tone: DriveStatusTone.neutral,
        )
      : hasMotionFailure
      ? const DriveHealthItem(
          kind: DriveHealthKind.motion,
          label: 'Motion',
          value: 'Unavailable',
          detail: 'Both sensors are required',
          tone: DriveStatusTone.critical,
        )
      : recorder.imu.accelerometerAcceptedSampleCount == 0 ||
            recorder.imu.gyroscopeAcceptedSampleCount == 0
      ? const DriveHealthItem(
          kind: DriveHealthKind.motion,
          label: 'Motion',
          value: 'Checking',
          detail: 'Waiting for both streams',
          tone: DriveStatusTone.caution,
        )
      : _hasPersistentUnreliableMotion(recorder)
      ? const DriveHealthItem(
          kind: DriveHealthKind.motion,
          label: 'Motion',
          value: 'Limited',
          detail: 'Android accuracy unreliable',
          tone: DriveStatusTone.caution,
        )
      : const DriveHealthItem(
          kind: DriveHealthKind.motion,
          label: 'Motion',
          value: 'Recording',
          detail: 'Both streams active',
          tone: DriveStatusTone.positive,
        );

  final storage = hasStorageFailure
      ? const DriveHealthItem(
          kind: DriveHealthKind.storage,
          label: 'Local save',
          value: 'Needs attention',
          detail: 'Recorder storage warning',
          tone: DriveStatusTone.critical,
        )
      : active && recorder.buffer.completedChunkCount > 0
      ? DriveHealthItem(
          kind: DriveHealthKind.storage,
          label: 'Local save',
          value: 'Protected',
          detail:
              '${recorder.buffer.completedChunkCount} ${recorder.buffer.completedChunkCount == 1 ? 'chunk' : 'chunks'} completed',
          tone: DriveStatusTone.positive,
        )
      : active
      ? const DriveHealthItem(
          kind: DriveHealthKind.storage,
          label: 'Local save',
          value: 'Buffering',
          detail: 'First verified chunk pending',
          tone: DriveStatusTone.information,
        )
      : const DriveHealthItem(
          kind: DriveHealthKind.storage,
          label: 'Storage',
          value: 'On device',
          detail: 'No telemetry upload',
          tone: DriveStatusTone.neutral,
        );

  return List.unmodifiable([location, gps, motion, storage]);
}
