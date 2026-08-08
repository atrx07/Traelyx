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
