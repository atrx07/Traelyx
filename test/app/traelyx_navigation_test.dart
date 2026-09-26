import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_app.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/account/domain/account_link_failure.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';
import 'package:traelyx/features/data_management/application/data_management_providers.dart';
import 'package:traelyx/features/data_management/domain/data_management_models.dart';
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
    await tester.ensureVisible(find.byKey(const ValueKey('open-diagnostics')));
    await tester.drag(find.byType(ListView).first, const Offset(0, -160));
    await tester.pumpAndSettle();
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
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('destination-You')), findsOneWidget);
  });

  testWidgets('You opens data controls as a deep-link-safe nested route', (
    tester,
  ) async {
    final router = createTraelyxRouter(initialLocation: TraelyxRoutes.you);
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('open-data-export')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      TraelyxRoutes.youDataExport,
    );
    expect(find.byKey(const ValueKey('data-export-screen')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );

    await tester.tap(find.byTooltip('Back to You'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.you);
    expect(find.byKey(const ValueKey('destination-You')), findsOneWidget);
  });

  testWidgets('You opens Account and returns to local Drive without sign-in', (
    tester,
  ) async {
    final router = createTraelyxRouter(initialLocation: TraelyxRoutes.you);
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      TraelyxRoutes.youAccount,
    );
    expect(find.byKey(const ValueKey('account-screen')), findsOneWidget);
    expect(find.textContaining('unavailable in this build'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-continue-locally')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.drive);
    expect(find.byKey(const ValueKey('ready-drive-view')), findsOneWidget);
  });

  test('cold callback selects Account only when the provider is available', () {
    final callback = Uri.parse(
      'io.github.atrx07.traelyx://auth-callback/?code=opaque',
    );
    expect(
      initialLocationForAccountLink(callback, accountEnabled: true),
      TraelyxRoutes.youAccount,
    );
    expect(
      initialLocationForAccountLink(callback, accountEnabled: false),
      TraelyxRoutes.root,
    );
    expect(
      initialLocationForAccountLink(null, accountEnabled: true),
      TraelyxRoutes.root,
    );
  });

  testWidgets('warm callback opens Account from a local screen', (
    tester,
  ) async {
    final router = createTraelyxRouter();
    addTearDown(router.dispose);
    final accountLinks = StreamController<Uri>.broadcast();
    addTearDown(accountLinks.close);

    await _pumpApp(tester, router, accountLinks: accountLinks.stream);
    accountLinks.add(Uri.parse('https://example.com/other'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, TraelyxRoutes.drive);

    accountLinks.add(
      Uri.parse('io.github.atrx07.traelyx://auth-callback/?code=opaque'),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      TraelyxRoutes.youAccount,
    );
    expect(find.byKey(const ValueKey('account-screen')), findsOneWidget);
  });

  testWidgets(
    'Account sends a link and signs out without touching local trips',
    (tester) async {
      final router = createTraelyxRouter(
        initialLocation: TraelyxRoutes.youAccount,
      );
      addTearDown(router.dispose);
      final accountGateway = _FakeAccountGateway();
      addTearDown(accountGateway.dispose);

      await _pumpApp(tester, router, accountGateway: accountGateway);
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        ' Driver@Example.com ',
      );
      await tester.tap(find.byKey(const ValueKey('account-send-link')));
      await tester.pumpAndSettle();

      expect(accountGateway.sentEmails, ['Driver@Example.com']);
      expect(find.textContaining('Check your email'), findsOneWidget);

      accountGateway.emit(
        const AccountIdentity(userId: 'user-one', email: 'Driver@Example.com'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Signed in'), findsOneWidget);
      expect(find.textContaining('does not upload'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-refresh')));
      await tester.pumpAndSettle();
      expect(accountGateway.refreshCount, 1);
      await tester.drag(
        find.byKey(const ValueKey('account-screen')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign-in refreshed on this device.'), findsOneWidget);

      accountGateway.failRefresh = true;
      await tester.tap(find.byKey(const ValueKey('account-refresh')));
      await tester.pumpAndSettle();
      expect(accountGateway.refreshCount, 2);
      expect(find.textContaining('Could not refresh sign-in'), findsOneWidget);
      expect(find.text('Signed in'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-sign-out')));
      await tester.pumpAndSettle();
      expect(accountGateway.signOutCount, 1);
      expect(find.textContaining('Local trips are still here'), findsOneWidget);
    },
  );

  for (final failure in AccountLinkFailure.values) {
    testWidgets('Account explains $failure and permits a successful retry', (
      tester,
    ) async {
      final router = createTraelyxRouter(
        initialLocation: TraelyxRoutes.youAccount,
      );
      addTearDown(router.dispose);
      final gateway = _FakeAccountGateway()
        ..sendFailure = AccountLinkException(failure);
      addTearDown(gateway.dispose);
      await _pumpApp(tester, router, accountGateway: gateway);
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'driver@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('account-send-link')));
      await tester.pumpAndSettle();
      final expected = switch (failure) {
        AccountLinkFailure.network => 'Could not reach the sign-in service.',
        AccountLinkFailure.rateLimited => 'temporarily limited email requests',
        AccountLinkFailure.service => 'temporarily unavailable',
        AccountLinkFailure.rejected => 'could not accept this email request',
        AccountLinkFailure.unknown => 'Could not send a sign-in link.',
      };
      expect(find.textContaining(expected), findsOneWidget);
      if (failure != AccountLinkFailure.network) {
        expect(find.textContaining('Check your connection'), findsNothing);
      }
      gateway.sendFailure = null;
      await tester.tap(find.byKey(const ValueKey('account-send-link')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check your email for the sign-in link'),
        findsOneWidget,
      );
    });
  }

  testWidgets('Account rejects invalid email and handles link failure', (
    tester,
  ) async {
    final router = createTraelyxRouter(
      initialLocation: TraelyxRoutes.youAccount,
    );
    addTearDown(router.dispose);
    final accountGateway = _FakeAccountGateway()..failSend = true;
    addTearDown(accountGateway.dispose);

    await _pumpApp(tester, router, accountGateway: accountGateway);
    await tester.enterText(
      find.byKey(const ValueKey('account-email')),
      'not-an-email',
    );
    await tester.tap(find.byKey(const ValueKey('account-send-link')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(accountGateway.sentEmails, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('account-email')),
      'driver@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('account-send-link')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not send a sign-in link'),
      findsOneWidget,
    );
    expect(
      router.routeInformationProvider.value.uri.path,
      TraelyxRoutes.youAccount,
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  GoRouter router, {
  Size size = const Size(390, 844),
  RecorderStatus? recorderStatus,
  RecorderPermissionStatus? permissionStatus,
  TripHistoryRepository tripRepository = const _FakeTripRepository(),
  AccountGateway? accountGateway,
  Stream<Uri>? accountLinks,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (accountGateway != null)
          accountGatewayProvider.overrideWithValue(accountGateway),
        bootstrapReadinessProvider.overrideWith(
          (ref) async => const BootstrapReadiness(
            databaseReady: true,
            bridgeVersion: 1,
            recorderState: 'skeleton',
            recordingAvailable: false,
          ),
        ),
        diagnosticsReportProvider.overrideWith((ref) async => _report),
        storedTripsProvider.overrideWith((ref) => const Stream.empty()),
        rawRetentionPolicyProvider.overrideWith(
          (ref) => Stream.value(RawRetentionPolicy.manual),
        ),
        tripMapCacheStatusProvider.overrideWith(
          (ref) => Stream.value(
            const MapCacheStatus(bytesUsed: 0, isAvailable: false),
          ),
        ),
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
      child: TraelyxApp(router: router, accountLinks: accountLinks),
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
  _DeepLinkCase(
    path: TraelyxRoutes.youAccount,
    label: 'You',
    index: 4,
    contentKey: 'account-screen',
  ),
  _DeepLinkCase(
    path: TraelyxRoutes.youSummarySync,
    label: 'You',
    index: 4,
    contentKey: 'summary-sync-screen',
  ),
  _DeepLinkCase(
    path: TraelyxRoutes.youMetadata,
    label: 'You',
    index: 4,
    contentKey: 'account-metadata-screen',
  ),
];

class _FakeAccountGateway implements AccountGateway {
  final _changes = StreamController<AccountIdentity?>.broadcast();
  AccountIdentity? _identity;
  final sentEmails = <String>[];
  int signOutCount = 0;
  int refreshCount = 0;
  bool failSend = false;
  Object? sendFailure;
  bool failRefresh = false;

  void emit(AccountIdentity? identity) {
    _identity = identity;
    _changes.add(identity);
  }

  void dispose() => _changes.close();

  @override
  bool get isAvailable => true;

  @override
  AccountIdentity? get currentIdentity => _identity;

  @override
  Stream<AccountIdentity?> get identityChanges => _changes.stream;

  @override
  Future<void> sendSignInLink(String email) async {
    if (sendFailure != null) throw sendFailure!;
    if (failSend) throw StateError('network unavailable');
    sentEmails.add(email);
  }

  @override
  Future<void> refreshSession() async {
    refreshCount++;
    if (failRefresh) throw StateError('network unavailable');
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    emit(null);
  }
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
