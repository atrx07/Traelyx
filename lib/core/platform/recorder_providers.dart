import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

final recorderBridgeProvider = Provider<RecorderBridge>(
  (ref) => const RecorderBridge(),
);

final recorderCapabilitiesProvider = FutureProvider<RecorderCapabilities>((
  ref,
) {
  return ref.watch(recorderBridgeProvider).getCapabilities();
});

final recorderStatusProvider = FutureProvider<RecorderStatus>((ref) {
  return ref.watch(recorderBridgeProvider).getStatus();
});

final recorderPermissionStatusProvider =
    FutureProvider<RecorderPermissionStatus>((ref) {
      return ref.watch(recorderBridgeProvider).getPermissionStatus();
    });

final recorderCommandControllerProvider = Provider<RecorderCommands>((ref) {
  return RecorderCommandController(ref);
});

abstract interface class RecorderCommands {
  Future<RecorderStatus> startTrip();

  Future<RecorderStatus> stopTrip();

  Future<RecorderStatus> recoverTrip();
}

class RecorderCommandController implements RecorderCommands {
  const RecorderCommandController(this._ref);

  final Ref _ref;

  @override
  Future<RecorderStatus> startTrip() =>
      _run(_ref.read(recorderBridgeProvider).startTrip);

  @override
  Future<RecorderStatus> stopTrip() =>
      _run(_ref.read(recorderBridgeProvider).stopTrip);

  @override
  Future<RecorderStatus> recoverTrip() =>
      _run(_ref.read(recorderBridgeProvider).recoverTrip);

  Future<RecorderStatus> _run(Future<RecorderStatus> Function() command) async {
    final status = await command();
    _ref.invalidate(recorderStatusProvider);
    return status;
  }
}

final recorderPermissionControllerProvider =
    Provider<RecorderPermissionActions>((ref) {
      return RecorderPermissionController(ref);
    });

abstract interface class RecorderPermissionActions {
  Future<RecorderPermissionStatus> requestLocation();

  Future<RecorderPermissionStatus> requestNotification();

  Future<RecorderPermissionStatus> openAppSettings();

  Future<RecorderPermissionStatus> openLocationSettings();

  void refresh();
}

class RecorderPermissionController implements RecorderPermissionActions {
  const RecorderPermissionController(this._ref);

  final Ref _ref;

  @override
  Future<RecorderPermissionStatus> requestLocation() =>
      _run(_ref.read(recorderBridgeProvider).requestLocationPermission);

  @override
  Future<RecorderPermissionStatus> requestNotification() =>
      _run(_ref.read(recorderBridgeProvider).requestNotificationPermission);

  @override
  Future<RecorderPermissionStatus> openAppSettings() =>
      _run(_ref.read(recorderBridgeProvider).openAppSettings);

  @override
  Future<RecorderPermissionStatus> openLocationSettings() =>
      _run(_ref.read(recorderBridgeProvider).openLocationSettings);

  @override
  void refresh() {
    _ref.invalidate(recorderPermissionStatusProvider);
    _ref.invalidate(recorderCapabilitiesProvider);
    _ref.invalidate(recorderStatusProvider);
  }

  Future<RecorderPermissionStatus> _run(
    Future<RecorderPermissionStatus> Function() action,
  ) async {
    final status = await action();
    refresh();
    return status;
  }
}
