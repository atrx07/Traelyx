import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/diagnostics/presentation/diagnostics_screen.dart';

void main() {
  testWidgets('renders only redacted build, recorder, and storage aggregates', (
    tester,
  ) async {
    await _pumpDiagnostics(tester, report: _report);

    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Redacted by design'), findsOneWidget);
    expect(find.text('0.1.0 (1)'), findsOneWidget);
    expect(find.text('io.github.atrx07.traelyx'), findsOneWidget);
    expect(find.text('skeleton'), findsOneWidget);
    expect(find.text('1.5 KiB'), findsOneWidget);
    expect(find.text('2.0 KiB'), findsOneWidget);
    expect(find.textContaining('must-not-be-retained'), findsNothing);
    expect(find.textContaining('/private/'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Local AI models'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Local AI models'), findsOneWidget);
    expect(find.textContaining('cache controls and export'), findsOneWidget);
  });

  testWidgets('error state redacts the underlying exception', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticsReportProvider.overrideWith(
            (ref) async => throw StateError(
              'apiKey=must-not-be-retained path=/private/route',
            ),
          ),
        ],
        child: MaterialApp(
          theme: TraelyxTheme.dark,
          home: const DiagnosticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics unavailable'), findsOneWidget);
    expect(find.textContaining('must-not-be-retained'), findsNothing);
    expect(find.textContaining('/private/route'), findsNothing);
  });
}

Future<void> _pumpDiagnostics(
  WidgetTester tester, {
  required DiagnosticsReport report,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diagnosticsReportProvider.overrideWith((ref) async => report),
      ],
      child: MaterialApp(
        theme: TraelyxTheme.dark,
        home: const DiagnosticsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _report = DiagnosticsReport(
  platform: PlatformDiagnosticsSnapshot(
    contractVersion: 1,
    packageName: 'io.github.atrx07.traelyx',
    versionName: '0.1.0',
    versionCode: 1,
    buildMode: 'debug',
    storage: DiagnosticsStorageBreakdown(
      appBytes: 1536,
      databaseBytes: 512,
      rawTelemetryBytes: 0,
      mapCacheBytes: 0,
      localModelBytes: 0,
    ),
  ),
  databaseSchemaVersion: 1,
  recorder: RecorderCapabilities(
    bridgeVersion: 1,
    implementationState: 'skeleton',
    recordingAvailable: false,
    serviceRegistered: true,
  ),
);
