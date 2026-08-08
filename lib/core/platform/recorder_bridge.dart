import 'package:flutter/services.dart';

class RecorderCapabilities {
  const RecorderCapabilities({
    required this.bridgeVersion,
    required this.implementationState,
    required this.recordingAvailable,
    required this.serviceRegistered,
  });

  factory RecorderCapabilities.fromMap(Map<Object?, Object?> value) {
    return RecorderCapabilities(
      bridgeVersion: value['bridgeVersion'] as int? ?? 0,
      implementationState: value['implementationState'] as String? ?? 'unknown',
      recordingAvailable: value['recordingAvailable'] as bool? ?? false,
      serviceRegistered: value['serviceRegistered'] as bool? ?? false,
    );
  }

  final int bridgeVersion;
  final String implementationState;
  final bool recordingAvailable;
  final bool serviceRegistered;
}

class RecorderBridge {
  const RecorderBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'io.github.atrx07.traelyx/recorder/v1';

  final MethodChannel _channel;

  Future<RecorderCapabilities> getCapabilities() async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'getCapabilities',
    );
    if (value == null) {
      throw const FormatException('Recorder bridge returned no capabilities.');
    }
    return RecorderCapabilities.fromMap(value);
  }
}
