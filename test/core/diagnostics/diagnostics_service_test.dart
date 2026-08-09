import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/diagnostics/diagnostics_bridge.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const diagnosticsChannel = MethodChannel(DiagnosticsBridge.channelName);
  const recorderChannel = MethodChannel(RecorderBridge.channelName);
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(diagnosticsChannel, (call) async {
          expect(call.method, 'getSnapshot');
          return const {
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
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorderChannel, (call) async {
          expect(call.method, 'getCapabilities');
          return const {
            'bridgeVersion': 1,
            'implementationState': 'skeleton',
            'recordingAvailable': false,
            'serviceRegistered': true,
          };
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(diagnosticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorderChannel, null);
    await database.close();
  });

  test(
    'service opens local DB and combines allowlisted platform contracts',
    () async {
      final service = DiagnosticsService(
        database,
        const DiagnosticsBridge(channel: diagnosticsChannel),
        const RecorderBridge(channel: recorderChannel),
      );

      final report = await service.collect();

      expect(report.databaseSchemaVersion, 1);
      expect(report.platform.storage.totalBytes, 1536);
      expect(report.recorder.implementationState, 'skeleton');
      expect(report.recorder.recordingAvailable, isFalse);
    },
  );
}
