import 'package:flutter/services.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';

class DiagnosticsBridge {
  const DiagnosticsBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'io.github.atrx07.traelyx/diagnostics/v1';

  final MethodChannel _channel;

  Future<PlatformDiagnosticsSnapshot> getSnapshot() async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'getSnapshot',
    );
    if (value == null) {
      throw const FormatException('Diagnostics bridge returned no snapshot.');
    }
    return PlatformDiagnosticsSnapshot.fromMap(value);
  }
}
