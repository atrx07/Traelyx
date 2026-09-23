import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/platform/data_management_bridge.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/data_management/application/data_management_providers.dart';
import 'package:traelyx/features/data_management/domain/data_management_models.dart';
import 'package:traelyx/features/data_management/presentation/data_export_screen.dart';
import 'package:traelyx/features/trips/application/trip_route_providers.dart';

void main() {
  testWidgets('renders measured storage and explicit privacy boundaries', (
    tester,
  ) async {
    final actions = _FakeDataManagementActions();
    await _pumpScreen(tester, actions);

    expect(find.byKey(const ValueKey('data-export-screen')), findsOneWidget);
    expect(find.text('Data & Export'), findsOneWidget);
    expect(find.text('Raw telemetry'), findsOneWidget);
    expect(find.text('3.0 KiB'), findsWidgets);
    expect(find.text('Local and user-directed'), findsOneWidget);
    expect(
      find.textContaining('runs cleanup in the background'),
      findsOneWidget,
    );
    await _scrollDown(tester, 2);
    expect(find.textContaining('not an anonymity guarantee'), findsOneWidget);
  });

  testWidgets('destructive trip controls require confirmation and can cancel', (
    tester,
  ) async {
    final actions = _FakeDataManagementActions();
    await _pumpScreen(tester, actions);

    await _scrollDown(tester, 4);
    final deleteRaw = find.byKey(const ValueKey('delete-raw-$tripId'));
    await tester.ensureVisible(deleteRaw);
    await tester.pumpAndSettle();
    await tester.tap(deleteRaw);
    await tester.pumpAndSettle();

    expect(find.text('Delete raw telemetry?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.text('Keep raw telemetry'));
    await tester.pumpAndSettle();

    expect(actions.rawDeletionCount, 0);

    final deleteTrip = find.byKey(const ValueKey('delete-trip-$tripId'));
    await tester.ensureVisible(deleteTrip);
    await tester.pumpAndSettle();
    await tester.tap(deleteTrip);
    await tester.pumpAndSettle();
    expect(find.text('Delete entire trip?'), findsOneWidget);
    await tester.tap(find.text('Keep trip'));
    await tester.pumpAndSettle();

    expect(actions.tripDeletionCount, 0);
  });

  testWidgets(
    'precise export warns before picker and redacted export is direct',
    (tester) async {
      final actions = _FakeDataManagementActions();
      await _pumpScreen(tester, actions);

      await _scrollDown(tester, 4);
      final precise = find.byKey(const ValueKey('export-precise-$tripId'));
      await tester.ensureVisible(precise);
      await tester.pumpAndSettle();
      await tester.tap(precise);
      await tester.pumpAndSettle();

      expect(find.text('Export precise private archive?'), findsOneWidget);
      expect(
        find.textContaining('exact route and raw device motion'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(actions.preciseExportCount, 0);

      final redacted = find.byKey(const ValueKey('export-redacted-$tripId'));
      await tester.ensureVisible(redacted);
      await tester.pumpAndSettle();
      await tester.tap(redacted);
      await tester.pumpAndSettle();

      expect(actions.redactedExportCount, 1);
      await _scrollUp(tester, 4);
      expect(
        find.textContaining('No route or raw telemetry was included'),
        findsOneWidget,
      );
    },
  );

  testWidgets('narrow layout remains usable at large text scale', (
    tester,
  ) async {
    final actions = _FakeDataManagementActions();
    await _pumpScreen(tester, actions, textScaler: const TextScaler.linear(2));

    await _scrollDown(tester, 8);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('delete-trip-$tripId')), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeDataManagementActions actions, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diagnosticsReportProvider.overrideWith((ref) async => report),
        storedTripsProvider.overrideWith((ref) => Stream.value([trip])),
        rawRetentionPolicyProvider.overrideWith(
          (ref) => Stream.value(RawRetentionPolicy.manual),
        ),
        tripMapCacheStatusProvider.overrideWith(
          (ref) => Stream.value(
            const MapCacheStatus(bytesUsed: 0, isAvailable: false),
          ),
        ),
        dataManagementServiceProvider.overrideWithValue(actions),
      ],
      child: MaterialApp(
        theme: TraelyxTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const Scaffold(body: DataExportScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollDown(WidgetTester tester, int times) async {
  for (var index = 0; index < times; index++) {
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollUp(WidgetTester tester, int times) async {
  for (var index = 0; index < times; index++) {
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
  }
}

class _FakeDataManagementActions implements DataManagementActions {
  int rawDeletionCount = 0;
  int tripDeletionCount = 0;
  int preciseExportCount = 0;
  int redactedExportCount = 0;

  @override
  Future<bool> deleteTrip(String tripId) async {
    tripDeletionCount += 1;
    return true;
  }

  @override
  Future<int> deleteRawForTrip(String tripId) async {
    rawDeletionCount += 1;
    return 3072;
  }

  @override
  Future<RawCleanupResult> executeCleanup(RawRetentionPolicy policy) async {
    return const RawCleanupResult(
      deletedTripCount: 0,
      bytesDeleted: 0,
      failureCount: 0,
    );
  }

  @override
  Future<TripDebugExportResult> exportPrecise(String tripId) async {
    preciseExportCount += 1;
    throw UnimplementedError();
  }

  @override
  Future<RedactedTripExportResult> exportRedacted(String tripId) async {
    redactedExportCount += 1;
    return const RedactedTripExportResult(
      exported: true,
      byteLength: 420,
      errorCode: null,
    );
  }

  @override
  Future<RawCleanupPlan> planCleanup(RawRetentionPolicy policy) async {
    return RawCleanupPlan(policy: policy, candidates: const []);
  }

  @override
  Future<void> setRetentionPolicy(RawRetentionPolicy policy) async {}
}

const tripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

final trip = StoredTripData(
  id: tripId,
  startedAtUtc: DateTime.utc(2026, 8, 25, 10),
  endedAtUtc: DateTime.utc(2026, 8, 25, 10, 1),
  duration: const Duration(minutes: 1),
  chunkCount: 3,
  indexedRawBytes: 3072,
);

const report = DiagnosticsReport(
  platform: PlatformDiagnosticsSnapshot(
    contractVersion: 1,
    packageName: 'io.github.atrx07.traelyx',
    versionName: '0.1.0',
    versionCode: 1,
    buildMode: 'debug',
    storage: DiagnosticsStorageBreakdown(
      appBytes: 4096,
      databaseBytes: 2048,
      rawTelemetryBytes: 3072,
      mapCacheBytes: 0,
      localModelBytes: 0,
    ),
  ),
  databaseSchemaVersion: 1,
  recorder: RecorderCapabilities(
    bridgeVersion: 1,
    implementationState: 'available',
    recordingAvailable: true,
    serviceRegistered: true,
  ),
);
