import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_app.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';
import 'package:traelyx/features/drive_dna/application/drive_dna_providers.dart';
import 'package:traelyx/features/drive_dna/data/drive_dna_repository.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/application/trip_route_providers.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
import 'package:traelyx/features/trips/data/trip_route_repository.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

import '../core/platform/recorder_bridge_test.dart'
    show permissionStatusMap, statusMap;

void main() {
  testWidgets('root redirects to Drive and exposes five primary destinations', (
    tester,
  ) async {
    final router = createTraelyxRouter();
    addTearDown(router.dispose);

    await _pumpApp(tester, router);

    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.drive);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('DNA'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.byKey(const ValueKey('ready-drive-view')), findsOneWidget);
  });

  testWidgets('active Drive suppresses primary navigation distractions', (
    tester,
  ) async {
    final router = createTraelyxRouter();
    addTearDown(router.dispose);
    final activeRecorder = RecorderStatus.fromMap(<Object?, Object?>{
      ...statusMap,
      'lifecycle': <Object?, Object?>{
        ...statusMap['lifecycle']! as Map<Object?, Object?>,
        'state': 'recording',
        'active': true,
      },
    });
    final grantedPermissions =
        RecorderPermissionStatus.fromMap(<Object?, Object?>{
          ...permissionStatusMap,
          'locationState': RecorderPermissionState.granted.wireName,
          'fineLocationGranted': true,
          'coarseLocationGranted': true,
          'gpsProviderEnabled': true,
          'recordingReady': true,
        });

    await _pumpApp(
      tester,
      router,
      recorderStatus: activeRecorder,
      permissionStatus: grantedPermissions,
    );

    expect(find.byKey(const ValueKey('live-drive-view')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const ValueKey('drive-end-action')), findsOneWidget);
  });

  testWidgets('selecting a destination updates content and route location', (
    tester,
  ) async {
    final router = createTraelyxRouter();
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('navigation-trips')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.trips);
    expect(find.byKey(const ValueKey('trips-history-screen')), findsOneWidget);
    expect(find.text('No drives yet'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  for (final deepLink in _deepLinks) {
    testWidgets('deep link ${deepLink.path} selects ${deepLink.label}', (
      tester,
    ) async {
      final router = createTraelyxRouter(initialLocation: deepLink.path);
      addTearDown(router.dispose);

      await _pumpApp(tester, router);

      expect(router.routeInformationProvider.value.uri.path, deepLink.path);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        deepLink.index,
      );
      expect(find.byKey(ValueKey(deepLink.contentKey)), findsOneWidget);
    });
  }

  testWidgets('unknown deep link fails safely without product claims', (
    tester,
  ) async {
    final router = createTraelyxRouter(initialLocation: '/not-a-route');
    addTearDown(router.dispose);

    await _pumpApp(tester, router);

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('/not-a-route'), findsOneWidget);
  });

  testWidgets('trip result deep link stays inside the Trips branch', (
    tester,
  ) async {
    final router = createTraelyxRouter(
      initialLocation: TraelyxRoutes.tripResult('trip-one'),
    );
    addTearDown(router.dispose);

    await _pumpApp(
      tester,
      router,
      tripRepository: _FakeTripRepository(
        history: [_routeTrip],
        result: _routeResult,
      ),
    );

    expect(
      router.routeInformationProvider.value.uri.path,
      TraelyxRoutes.tripResult('trip-one'),
    );
    expect(find.byKey(const ValueKey('trip-result-screen')), findsOneWidget);
    expect(find.text('Analysis not available'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.byKey(const ValueKey('trip-result-back')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.trips);
    expect(find.byKey(const ValueKey('trips-history-screen')), findsOneWidget);
  });

  testWidgets('wide layouts use a navigation rail with deep-link selection', (
    tester,
  ) async {
    final router = createTraelyxRouter(initialLocation: TraelyxRoutes.social);
    addTearDown(router.dispose);

    await _pumpApp(tester, router, size: const Size(900, 700));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      3,
    );
    expect(find.byKey(const ValueKey('destination-Social')), findsOneWidget);
  });

  testWidgets('You opens diagnostics as a deep-link-safe nested route', (
    tester,
  ) async {
    final router = createTraelyxRouter(initialLocation: TraelyxRoutes.you);
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('open-diagnostics')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      TraelyxRoutes.youDiagnostics,
    );
    expect(find.byKey(const ValueKey('diagnostics-screen')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );

    await tester.tap(find.byTooltip('Back to You'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.you);
    expect(find.byKey(const ValueKey('destination-You')), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  GoRouter router, {
  Size size = const Size(390, 844),
  RecorderStatus? recorderStatus,
  RecorderPermissionStatus? permissionStatus,
  TripHistoryRepository tripRepository = const _FakeTripRepository(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapReadinessProvider.overrideWith(
          (ref) async => const BootstrapReadiness(
            databaseReady: true,
            bridgeVersion: 1,
            recorderState: 'skeleton',
            recordingAvailable: false,
          ),
        ),
        diagnosticsReportProvider.overrideWith((ref) async => _report),
        recorderFinalizationSyncProvider.overrideWith(
          (ref) async => const RecorderFinalizationSyncResult(
            reconciledTripIds: [],
            invalidNativeRecordCount: 0,
          ),
        ),
        latestTripDebugExportTripIdProvider.overrideWith((ref) async => null),
        tripHistoryRepositoryProvider.overrideWithValue(tripRepository),
        tripRouteRepositoryProvider.overrideWithValue(
          const _FakeTripRouteRepository(),
        ),
        driveDnaRepositoryProvider.overrideWithValue(
          const _FakeDriveDnaRepository(),
        ),
        if (recorderStatus != null)
          recorderStatusProvider.overrideWith((ref) async => recorderStatus),
        if (permissionStatus != null)
          recorderPermissionStatusProvider.overrideWith(
            (ref) async => permissionStatus,
          ),
      ],
      child: TraelyxApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeDriveDnaRepository implements DriveDnaRepository {
  const _FakeDriveDnaRepository();

  @override
  Stream<DriveDnaSnapshot?> watchLatest() => Stream.value(null);
}

class _DeepLinkCase {
  const _DeepLinkCase({
    required this.path,
    required this.label,
    required this.index,
    required this.contentKey,
  });

  final String path;
  final String label;
  final int index;
  final String contentKey;
}

const _deepLinks = [
  _DeepLinkCase(
    path: TraelyxRoutes.drive,
    label: 'Drive',
    index: 0,
    contentKey: 'bootstrap-drive',
  ),
  _DeepLinkCase(
    path: TraelyxRoutes.trips,
    label: 'Trips',
    index: 1,
    contentKey: 'trips-history-screen',
  ),
  _DeepLinkCase(
    path: TraelyxRoutes.dna,
    label: 'DNA',
    index: 2,
    contentKey: 'destination-DNA',
  ),
  _DeepLinkCase(
    path: TraelyxRoutes.social,
    label: 'Social',
    index: 3,
    contentKey: 'destination-Social',
  ),
  _DeepLinkCase(
    path: TraelyxRoutes.you,
    label: 'You',
    index: 4,
    contentKey: 'destination-You',
  ),
];

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

class _FakeTripRepository implements TripHistoryRepository {
  const _FakeTripRepository({this.history = const [], this.result});

  final List<TripHistoryItem> history;
  final TripResult? result;

  @override
  Future<TripResult?> loadResult(String tripId) async => result;

  @override
  Stream<List<TripHistoryItem>> watchHistory() => Stream.value(history);
}

class _FakeTripRouteRepository implements TripRouteRepository {
  const _FakeTripRouteRepository();

  @override
  Future<TripRouteResult> load(String tripId) async {
    return const TripRouteResult.unavailable();
  }
}

final _routeTrip = TripHistoryItem(
  id: 'trip-one',
  vehicleName: 'Local vehicle',
  startedAtUtc: DateTime.utc(2026, 8, 25),
  duration: const Duration(minutes: 1),
  distanceMeters: null,
  completionState: TripEvidenceState.verified,
  recoveryState: TripEvidenceState.verified,
  integrityState: TripEvidenceState.notAssessed,
);

final _routeResult = TripResult(
  trip: _routeTrip,
  telemetrySchemaVersion: 1,
  telemetryConfidenceRecorded: false,
  evidence: const TripEvidenceSummary(
    chunkCount: 1,
    byteCount: 100,
    gnssSampleCount: 1,
    accelerometerSampleCount: 2,
    gyroscopeSampleCount: 2,
  ),
  finalization: null,
  events: const [],
  score: null,
);
