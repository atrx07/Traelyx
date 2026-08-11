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

final recorderCommandControllerProvider = Provider<RecorderCommandController>((
  ref,
) {
  return RecorderCommandController(ref);
});

class RecorderCommandController {
  const RecorderCommandController(this._ref);

  final Ref _ref;

  Future<RecorderStatus> startTrip() =>
      _run(_ref.read(recorderBridgeProvider).startTrip);

  Future<RecorderStatus> stopTrip() =>
      _run(_ref.read(recorderBridgeProvider).stopTrip);

  Future<RecorderStatus> recoverTrip() =>
      _run(_ref.read(recorderBridgeProvider).recoverTrip);

  Future<RecorderStatus> _run(Future<RecorderStatus> Function() command) async {
    final status = await command();
    _ref.invalidate(recorderStatusProvider);
    return status;
  }
}
