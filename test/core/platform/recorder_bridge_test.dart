import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

void main() {
  test('capability parser defaults to unavailable conservatively', () {
    final capabilities = RecorderCapabilities.fromMap(const {});

    expect(capabilities.bridgeVersion, 0);
    expect(capabilities.implementationState, 'unknown');
    expect(capabilities.recordingAvailable, isFalse);
    expect(capabilities.serviceRegistered, isFalse);
  });

  test('capability parser preserves the versioned native response', () {
    final capabilities = RecorderCapabilities.fromMap(const {
      'bridgeVersion': 1,
      'implementationState': 'skeleton',
      'recordingAvailable': false,
      'serviceRegistered': true,
    });

    expect(capabilities.bridgeVersion, 1);
    expect(capabilities.implementationState, 'skeleton');
    expect(capabilities.recordingAvailable, isFalse);
    expect(capabilities.serviceRegistered, isTrue);
  });
}
