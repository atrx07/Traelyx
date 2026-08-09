import 'package:traelyx/core/platform/recorder_bridge.dart';

class PlatformDiagnosticsSnapshot {
  const PlatformDiagnosticsSnapshot({
    required this.contractVersion,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.buildMode,
    required this.storage,
  });

  factory PlatformDiagnosticsSnapshot.fromMap(Map<Object?, Object?> value) {
    return PlatformDiagnosticsSnapshot(
      contractVersion: _requiredNonNegativeInt(value, 'contractVersion'),
      packageName: _requiredString(value, 'packageName'),
      versionName: _requiredString(value, 'versionName'),
      versionCode: _requiredNonNegativeInt(value, 'versionCode'),
      buildMode: _requiredString(value, 'buildMode'),
      storage: DiagnosticsStorageBreakdown(
        appBytes: _requiredNonNegativeInt(value, 'appBytes'),
        databaseBytes: _requiredNonNegativeInt(value, 'databaseBytes'),
        rawTelemetryBytes: _requiredNonNegativeInt(value, 'rawTelemetryBytes'),
        mapCacheBytes: _requiredNonNegativeInt(value, 'mapCacheBytes'),
        localModelBytes: _requiredNonNegativeInt(value, 'localModelBytes'),
      ),
    );
  }

  final int contractVersion;
  final String packageName;
  final String versionName;
  final int versionCode;
  final String buildMode;
  final DiagnosticsStorageBreakdown storage;
}

class DiagnosticsStorageBreakdown {
  const DiagnosticsStorageBreakdown({
    required this.appBytes,
    required this.databaseBytes,
    required this.rawTelemetryBytes,
    required this.mapCacheBytes,
    required this.localModelBytes,
  });

  final int appBytes;
  final int databaseBytes;
  final int rawTelemetryBytes;
  final int mapCacheBytes;
  final int localModelBytes;

  int get totalBytes =>
      appBytes +
      databaseBytes +
      rawTelemetryBytes +
      mapCacheBytes +
      localModelBytes;
}

class DiagnosticsReport {
  const DiagnosticsReport({
    required this.platform,
    required this.databaseSchemaVersion,
    required this.recorder,
  });

  final PlatformDiagnosticsSnapshot platform;
  final int databaseSchemaVersion;
  final RecorderCapabilities recorder;
}

String formatDiagnosticBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

String _requiredString(Map<Object?, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw FormatException('Diagnostics field $key is missing or invalid.');
  }
  return field;
}

int _requiredNonNegativeInt(Map<Object?, Object?> value, String key) {
  final field = value[key];
  if (field is! int || field < 0) {
    throw FormatException('Diagnostics field $key is missing or invalid.');
  }
  return field;
}
