import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';

void main() {
  test('platform snapshot accepts only the allowlisted aggregate contract', () {
    final snapshot = PlatformDiagnosticsSnapshot.fromMap(const {
      'contractVersion': 1,
      'packageName': 'io.github.atrx07.traelyx',
      'versionName': '0.1.0',
      'versionCode': 1,
      'buildMode': 'debug',
      'appBytes': 1024,
      'databaseBytes': 512,
      'rawTelemetryBytes': 0,
      'mapCacheBytes': 0,
      'localModelBytes': 0,
      'apiKey': 'must-not-be-retained',
      'rawTelemetryPath': '/private/precise-route.tripdebug',
    });

    expect(snapshot.contractVersion, 1);
    expect(snapshot.packageName, 'io.github.atrx07.traelyx');
    expect(snapshot.storage.totalBytes, 1536);
  });

  test('platform snapshot rejects missing or negative aggregate values', () {
    expect(
      () => PlatformDiagnosticsSnapshot.fromMap(const {}),
      throwsFormatException,
    );
    expect(
      () => PlatformDiagnosticsSnapshot.fromMap(const {
        'contractVersion': 1,
        'packageName': 'io.github.atrx07.traelyx',
        'versionName': '0.1.0',
        'versionCode': 1,
        'buildMode': 'debug',
        'appBytes': -1,
        'databaseBytes': 0,
        'rawTelemetryBytes': 0,
        'mapCacheBytes': 0,
        'localModelBytes': 0,
      }),
      throwsFormatException,
    );
  });

  test('byte formatter uses deterministic binary units', () {
    expect(formatDiagnosticBytes(0), '0 B');
    expect(formatDiagnosticBytes(1023), '1023 B');
    expect(formatDiagnosticBytes(1024), '1.0 KiB');
    expect(formatDiagnosticBytes(1536), '1.5 KiB');
    expect(formatDiagnosticBytes(1024 * 1024), '1.0 MiB');
  });
}
