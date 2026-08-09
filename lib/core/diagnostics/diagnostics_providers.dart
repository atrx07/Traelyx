import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_bridge.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';

class DiagnosticsService {
  const DiagnosticsService(
    this._database,
    this._diagnosticsBridge,
    this._recorderBridge,
  );

  final AppDatabase _database;
  final DiagnosticsBridge _diagnosticsBridge;
  final RecorderBridge _recorderBridge;

  Future<DiagnosticsReport> collect() async {
    await _database.customSelect('SELECT 1').getSingle();
    final platform = await _diagnosticsBridge.getSnapshot();
    final recorder = await _recorderBridge.getCapabilities();
    return DiagnosticsReport(
      platform: platform,
      databaseSchemaVersion: _database.schemaVersion,
      recorder: recorder,
    );
  }
}

final diagnosticsBridgeProvider = Provider<DiagnosticsBridge>(
  (ref) => const DiagnosticsBridge(),
);

final diagnosticsServiceProvider = Provider<DiagnosticsService>((ref) {
  return DiagnosticsService(
    ref.watch(appDatabaseProvider),
    ref.watch(diagnosticsBridgeProvider),
    ref.watch(recorderBridgeProvider),
  );
});

final diagnosticsReportProvider = FutureProvider<DiagnosticsReport>((ref) {
  return ref.watch(diagnosticsServiceProvider).collect();
});
