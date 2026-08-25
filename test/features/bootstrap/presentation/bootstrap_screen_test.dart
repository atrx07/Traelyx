import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';
import 'package:traelyx/features/bootstrap/presentation/bootstrap_screen.dart';

import '../../../core/platform/recorder_bridge_test.dart'
    show permissionStatusMap, statusMap;

void main() {
  testWidgets('checking Drive never requests a permission automatically', (
    tester,
  ) async {
    final permissions = _FakePermissionActions(_permissionStatus());
    await _pumpDrive(tester, permissions: permissions);

    expect(find.text('Allow precise location'), findsWidgets);
    expect(permissions.calls, isEmpty);

    final primaryAction = find.byKey(const ValueKey('drive-primary-action'));
    expect(primaryAction, findsOneWidget);
    expect(primaryAction.hitTestable(), findsOneWidget);
    await tester.tap(primaryAction);
    await tester.pumpAndSettle();

    expect(permissions.calls, ['requestLocation']);
  });

  testWidgets('ready Drive starts even when notification access is denied', (
    tester,
  ) async {
    final readyPermissions = _permissionStatus(
      locationState: RecorderPermissionState.granted,
      notificationState: RecorderPermissionState.settingsRequired,
      fine: true,
      coarse: true,
      recordingReady: true,
      canRequestLocation: false,
      canRequestNotification: false,
    );
    final permissions = _FakePermissionActions(readyPermissions);
    final commands = _FakeRecorderCommands(_recorderStatus());
    await _pumpDrive(
      tester,
      permissionStatus: readyPermissions,
      permissions: permissions,
      commands: commands,
    );

    expect(find.text('Ready to record'), findsOneWidget);
    expect(find.text('Keep the recording notice visible'), findsOneWidget);
    expect(find.text('Start drive'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drive-primary-action')).hitTestable(),
      findsOneWidget,
    );
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Start drive'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }

    await tester.tap(find.byKey(const ValueKey('drive-primary-action')));
    await tester.pumpAndSettle();

    expect(commands.calls, ['startTrip']);
  });

  testWidgets('ready action is visible before precise-private local tools', (
    tester,
  ) async {
    await _pumpDrive(
      tester,
      permissionStatus: _permissionStatus(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        recordingReady: true,
        canRequestLocation: false,
      ),
      latestExportTripId: 'd181f268-f3ef-4a43-a142-8bf0671dcd49',
    );

    expect(find.text('READY TO DRIVE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drive-primary-action')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tripdebug-export-action')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('ready Start fails closed when local foundation fails', (
    tester,
  ) async {
    await _pumpDrive(
      tester,
      permissionStatus: _permissionStatus(
        locationState: RecorderPermissionState.granted,
        fine: true,
        coarse: true,
        recordingReady: true,
        canRequestLocation: false,
      ),
      readinessFuture: () async => throw StateError('database unavailable'),
    );

    expect(find.text('Local foundation check failed'), findsOneWidget);
    expect(find.text('Start unavailable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('drive-primary-action')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('active Drive requires confirmation before ending', (
    tester,
  ) async {
    final commands = _FakeRecorderCommands(
      _recorderStatus(active: true, state: 'recording'),
    );
    await _pumpDrive(
      tester,
      recorderStatus: _recorderStatus(active: true, state: 'recording'),
      commands: commands,
    );

    expect(find.text('Drive recording is active'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-drive-view')), findsOneWidget);
    expect(find.text('End drive'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('MOTION'), findsOneWidget);
    expect(find.text('LOCAL SAVE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drive-end-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('end-drive-confirm-dialog')),
      findsOneWidget,
    );
    expect(commands.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('continue-recording-action')));
    await tester.pumpAndSettle();
    expect(commands.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('drive-end-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-end-drive-action')));
    await tester.pumpAndSettle();

    expect(commands.calls, ['stopTrip']);
    expect(
      find.text('Drive finalized and indexed in local history.'),
      findsOneWidget,
    );
  });

  testWidgets('stopping Drive disables repeated commands', (tester) async {
    await _pumpDrive(
      tester,
      recorderStatus: _recorderStatus(active: true, state: 'stopping'),
    );

    expect(find.text('Stopping drive'), findsOneWidget);
    expect(find.text('Saving drive…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('drive-end-action')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('live Drive exposes persistent motion limitations', (
    tester,
  ) async {
    await _pumpDrive(
      tester,
      recorderStatus: _recorderStatus(
        active: true,
        state: 'recording',
        unreliableSamples: 100,
      ),
    );

    expect(
      find.text('Recording active with limited motion confidence'),
      findsOneWidget,
    );
    expect(find.text('Limited'), findsOneWidget);
    expect(find.text('Android accuracy unreliable'), findsOneWidget);
  });

  testWidgets('large text keeps critical Drive controls reachable', (
    tester,
  ) async {
    await _pumpDrive(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-primary-action')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('drive-primary-action')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('drive-primary-action')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'Drive transition duration is zero when animations are disabled',
    (tester) async {
      await _pumpDrive(tester, disableAnimations: true);

      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
    },
  );

  for (final stateCase
      in <({String expected, RecorderPermissionStatus permissions})>[
        (
          expected: 'Precise location is required',
          permissions: _permissionStatus(
            locationState: RecorderPermissionState.approximateOnly,
            coarse: true,
          ),
        ),
        (
          expected: 'Location permission is off',
          permissions: _permissionStatus(
            locationState: RecorderPermissionState.settingsRequired,
            canRequestLocation: false,
          ),
        ),
        (
          expected: 'Turn on GPS location',
          permissions: _permissionStatus(
            locationState: RecorderPermissionState.granted,
            fine: true,
            coarse: true,
            gps: false,
            canRequestLocation: false,
          ),
        ),
      ]) {
    testWidgets('Drive renders ${stateCase.expected}', (tester) async {
      await _pumpDrive(tester, permissionStatus: stateCase.permissions);
      expect(find.text(stateCase.expected), findsOneWidget);
    });
  }

  testWidgets('Drive fails closed while permission state is loading', (
    tester,
  ) async {
    final pending = Completer<RecorderPermissionStatus>();
    await _pumpDriveWithPermissionFuture(tester, () => pending.future);

    expect(find.text('Checking recording access'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('drive-primary-action')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Drive fails closed when permission state cannot be read', (
    tester,
  ) async {
    await _pumpDriveWithPermissionFuture(
      tester,
      () async => throw StateError('unavailable'),
      settle: true,
    );

    expect(find.text('Could not check recorder state'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('drive-primary-action')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Drive surfaces preserved finalization failures', (tester) async {
    await _pumpDrive(
      tester,
      finalizationFuture: () async => throw StateError('index failed'),
    );

    expect(find.text('A stopped drive needs attention'), findsOneWidget);
    expect(find.textContaining('evidence remains preserved'), findsOneWidget);
  });

  testWidgets('Drive confirms recovered native evidence was indexed locally', (
    tester,
  ) async {
    await _pumpDrive(
      tester,
      finalizationFuture: () async => const RecorderFinalizationSyncResult(
        reconciledTripIds: ['d181f268-f3ef-4a43-a142-8bf0671dcd49'],
        invalidNativeRecordCount: 0,
      ),
    );

    expect(find.text('Recovered drive saved locally'), findsOneWidget);
    expect(find.textContaining('without uploading telemetry'), findsOneWidget);
  });

  testWidgets('finalized drive offers explicit precise-private export', (
    tester,
  ) async {
    final exporter = _FakeTripDebugExporter();
    await _pumpDrive(
      tester,
      latestExportTripId: 'd181f268-f3ef-4a43-a142-8bf0671dcd49',
      exporter: exporter,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tripdebug-export-action')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('Export private drive fixture'), findsOneWidget);
    expect(find.textContaining('exact route and raw motion'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tripdebug-export-action')));
    await tester.pumpAndSettle();

    expect(exporter.tripIds, ['d181f268-f3ef-4a43-a142-8bf0671dcd49']);
    expect(
      find.textContaining('Private fixture exported and verified'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpDrive(
  WidgetTester tester, {
  RecorderPermissionStatus? permissionStatus,
  RecorderStatus? recorderStatus,
  _FakePermissionActions? permissions,
  _FakeRecorderCommands? commands,
  String? latestExportTripId,
  _FakeTripDebugExporter? exporter,
  Future<RecorderFinalizationSyncResult> Function()? finalizationFuture,
  Future<BootstrapReadiness> Function()? readinessFuture,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final effectivePermissionStatus = permissionStatus ?? _permissionStatus();
  final effectiveRecorderStatus = recorderStatus ?? _recorderStatus();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapReadinessProvider.overrideWith(
          (ref) =>
              readinessFuture?.call() ??
              Future.value(
                const BootstrapReadiness(
                  databaseReady: true,
                  bridgeVersion: 1,
                  recorderState: 'bridge_ready',
                  recordingAvailable: false,
                ),
              ),
        ),
        recorderPermissionStatusProvider.overrideWith(
          (ref) async => effectivePermissionStatus,
        ),
        recorderStatusProvider.overrideWith(
          (ref) async => effectiveRecorderStatus,
        ),
        recorderFinalizationSyncProvider.overrideWith(
          (ref) =>
              finalizationFuture?.call() ??
              Future.value(
                const RecorderFinalizationSyncResult(
                  reconciledTripIds: [],
                  invalidNativeRecordCount: 0,
                ),
              ),
        ),
        latestTripDebugExportTripIdProvider.overrideWith(
          (ref) async => latestExportTripId,
        ),
        recorderTripDebugExporterProvider.overrideWithValue(
          exporter ?? _FakeTripDebugExporter(),
        ),
        recorderPermissionControllerProvider.overrideWithValue(
          permissions ?? _FakePermissionActions(effectivePermissionStatus),
        ),
        recorderCommandControllerProvider.overrideWithValue(
          commands ?? _FakeRecorderCommands(effectiveRecorderStatus),
        ),
      ],
      child: MaterialApp(
        theme: TraelyxTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: const Scaffold(body: BootstrapScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDriveWithPermissionFuture(
  WidgetTester tester,
  Future<RecorderPermissionStatus> Function() permissionFuture, {
  bool settle = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final recorderStatus = _recorderStatus();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapReadinessProvider.overrideWith(
          (ref) async => const BootstrapReadiness(
            databaseReady: true,
            bridgeVersion: 1,
            recorderState: 'bridge_ready',
            recordingAvailable: false,
          ),
        ),
        recorderPermissionStatusProvider.overrideWith(
          (ref) => permissionFuture(),
        ),
        recorderStatusProvider.overrideWith((ref) async => recorderStatus),
        recorderFinalizationSyncProvider.overrideWith(
          (ref) async => const RecorderFinalizationSyncResult(
            reconciledTripIds: [],
            invalidNativeRecordCount: 0,
          ),
        ),
        latestTripDebugExportTripIdProvider.overrideWith((ref) async => null),
        recorderTripDebugExporterProvider.overrideWithValue(
          _FakeTripDebugExporter(),
        ),
        recorderPermissionControllerProvider.overrideWithValue(
          _FakePermissionActions(_permissionStatus()),
        ),
        recorderCommandControllerProvider.overrideWithValue(
          _FakeRecorderCommands(recorderStatus),
        ),
      ],
      child: MaterialApp(
        theme: TraelyxTheme.dark,
        home: const Scaffold(body: BootstrapScreen()),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

RecorderPermissionStatus _permissionStatus({
  RecorderPermissionState locationState = RecorderPermissionState.requestable,
  RecorderPermissionState notificationState = RecorderPermissionState.granted,
  bool fine = false,
  bool coarse = false,
  bool gps = true,
  bool recordingReady = false,
  bool canRequestLocation = true,
  bool canRequestNotification = false,
}) {
  return RecorderPermissionStatus.fromMap(<Object?, Object?>{
    ...permissionStatusMap,
    'locationState': locationState.wireName,
    'notificationState': notificationState.wireName,
    'fineLocationGranted': fine,
    'coarseLocationGranted': coarse,
    'gpsProviderEnabled': gps,
    'canRequestLocation': canRequestLocation,
    'canRequestNotification': canRequestNotification,
    'recordingReady': recordingReady,
  });
}

RecorderStatus _recorderStatus({
  bool active = false,
  String state = 'idle',
  int unreliableSamples = 0,
}) {
  return RecorderStatus.fromMap(<Object?, Object?>{
    ...statusMap,
    'lifecycle': <Object?, Object?>{
      ...statusMap['lifecycle']! as Map<Object?, Object?>,
      'state': state,
      'active': active,
      'tripId': active ? 'd181f268-f3ef-4a43-a142-8bf0671dcd49' : null,
      'errorCode': null,
    },
    'imu': <Object?, Object?>{
      ...statusMap['imu']! as Map<Object?, Object?>,
      'unreliableAccuracySampleCount': unreliableSamples,
    },
  });
}

class _FakePermissionActions implements RecorderPermissionActions {
  _FakePermissionActions(this.status);

  final RecorderPermissionStatus status;
  final calls = <String>[];

  @override
  Future<RecorderPermissionStatus> openAppSettings() async {
    calls.add('openAppSettings');
    return status;
  }

  @override
  Future<RecorderPermissionStatus> openLocationSettings() async {
    calls.add('openLocationSettings');
    return status;
  }

  @override
  void refresh() {
    calls.add('refresh');
  }

  @override
  Future<RecorderPermissionStatus> requestLocation() async {
    calls.add('requestLocation');
    return status;
  }

  @override
  Future<RecorderPermissionStatus> requestNotification() async {
    calls.add('requestNotification');
    return status;
  }
}

class _FakeRecorderCommands implements RecorderCommands {
  _FakeRecorderCommands(this.status);

  final RecorderStatus status;
  final calls = <String>[];

  @override
  Future<RecorderStatus> recoverTrip() async {
    calls.add('recoverTrip');
    return status;
  }

  @override
  Future<RecorderStatus> startTrip() async {
    calls.add('startTrip');
    return status;
  }

  @override
  Future<RecorderStatus> stopTrip() async {
    calls.add('stopTrip');
    return status;
  }
}

class _FakeTripDebugExporter implements RecorderTripDebugExporter {
  final tripIds = <String>[];

  @override
  Future<TripDebugExportResult> exportTrip(String tripId) async {
    tripIds.add(tripId);
    return TripDebugExportResult.fromMap(<Object?, Object?>{
      'contractVersion': 1,
      'archiveVersion': 1,
      'tripId': tripId,
      'exported': true,
      'containsPreciseLocation': true,
      'privacyClass': 'precise_private',
      'chunkCount': 12,
      'gnssSampleCount': 10,
      'accelerometerSampleCount': 100,
      'gyroscopeSampleCount': 100,
      'durationNanos': 10000000000,
      'archiveByteLength': 40960,
      'maxChunkGapNanos': 1000000,
      'maxGnssGapNanos': 1100000000,
      'maxAccelerometerGapNanos': 12000000,
      'maxGyroscopeGapNanos': 12000000,
      'errorCode': null,
    });
  }
}
