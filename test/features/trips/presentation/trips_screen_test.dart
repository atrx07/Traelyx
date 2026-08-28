import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/application/trip_route_providers.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
import 'package:traelyx/features/trips/data/trip_route_repository.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';
import 'package:traelyx/features/trips/presentation/trip_result_screen.dart';
import 'package:traelyx/features/trips/presentation/trips_screen.dart';

void main() {
  testWidgets('history renders a local-first empty state', (tester) async {
    await _pumpHistory(tester, repository: _FakeRepository(history: const []));

    expect(find.byKey(const ValueKey('trips-history-screen')), findsOneWidget);
    expect(find.text('No drives yet'), findsOneWidget);
    expect(find.textContaining('without an account'), findsOneWidget);
  });

  testWidgets('history renders recorded facts and honest missing distance', (
    tester,
  ) async {
    await _pumpHistory(tester, repository: _FakeRepository(history: [_trip]));

    expect(find.text('Your drives'), findsOneWidget);
    expect(find.text('Local bike'), findsOneWidget);
    expect(find.text('1m 30s'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-history-trip-one')), findsOneWidget);
  });

  testWidgets('history exposes loading and fail-closed read errors', (
    tester,
  ) async {
    final pending = StreamController<List<TripHistoryItem>>();
    addTearDown(pending.close);
    await _pumpHistory(
      tester,
      repository: _FakeRepository(historyStream: pending.stream),
      settle: false,
    );
    expect(find.bySemanticsLabel('Loading local trip history'), findsOneWidget);

    await _pumpHistory(
      tester,
      repository: _FakeRepository(
        historyStream: Stream.error(const FormatException('bad history')),
      ),
    );
    expect(find.text('Local history could not be read'), findsOneWidget);
    expect(find.textContaining('No trip data was changed'), findsOneWidget);
  });

  testWidgets('result hierarchy distinguishes recorded and absent analysis', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: _result),
      routeRepository: _FakeRouteRepository(result: _availableRoute),
    );

    expect(find.byKey(const ValueKey('trip-result-screen')), findsOneWidget);
    expect(find.text('LOCAL DRIVE RESULT'), findsOneWidget);
    expect(find.text('Analysis not available'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OFFLINE ROUTE'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('trip-route-available')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('offline-route-map-canvas')),
      findsOneWidget,
    );
    expect(find.text('2 display points · GNSS processing v1'), findsOneWidget);
    expect(find.text('Tile cache unavailable · 0 B'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Completed')).dy,
      greaterThan(tester.getBottomLeft(find.text('1m 30s')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('CONFIDENCE & INTEGRITY'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Not assessed'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('LOCAL EVIDENCE'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('NOTABLE MOMENTS'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Not available'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('Route geometry stays on this phone'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Route geometry stays on this phone'),
      findsOneWidget,
    );
    expect(find.textContaining('recorder/trips'), findsNothing);
  });

  testWidgets('result presents a persisted score and governed event', (
    tester,
  ) async {
    final scored = TripResult(
      trip: _result.trip,
      telemetrySchemaVersion: 1,
      telemetryConfidenceRecorded: true,
      evidence: _result.evidence,
      finalization: _result.finalization,
      events: const [
        TripEventSummary(
          type: 'strong_braking',
          startElapsedNanos: 2000000000,
          endElapsedNanos: 3000000000,
        ),
      ],
      score: const TripScoreSummary(
        overallScore: 81,
        eligibilityState: TripEvidenceState.verified,
        scoringVersion: 'scoring-v1',
        confidenceRecorded: true,
      ),
    );
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: scored),
    );

    expect(find.text('81'), findsOneWidget);
    expect(find.text('Overall synthesis'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Summary recorded'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Summary recorded'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Strong Braking'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Strong Braking'), findsOneWidget);
  });

  testWidgets('one replay clock synchronizes marker graph and event seeking', (
    tester,
  ) async {
    final replayResult = TripResult(
      trip: _result.trip,
      telemetrySchemaVersion: _result.telemetrySchemaVersion,
      telemetryConfidenceRecorded: false,
      evidence: _result.evidence,
      finalization: _result.finalization,
      events: const [
        TripEventSummary(
          type: 'strong_braking',
          startElapsedNanos: 40_000_000_000,
          endElapsedNanos: 50_000_000_000,
        ),
      ],
      score: null,
    );
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: replayResult),
      routeRepository: _FakeRouteRepository(result: _availableRoute),
    );
    await tester.scrollUntilVisible(
      find.text('Replay playback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('replay-timeline-slider')),
    );
    final semantics = tester.ensureSemantics();
    try {
      final sliderSemantics = tester
          .getSemantics(find.byKey(const ValueKey('replay-timeline-semantics')))
          .getSemanticsData();
      expect(sliderSemantics.hasAction(ui.SemanticsAction.increase), isTrue);
      expect(sliderSemantics.hasAction(ui.SemanticsAction.decrease), isTrue);
      expect(sliderSemantics.label, contains('Replay timeline position'));
      expect(sliderSemantics.value, contains('0:00 of 1:30'));
    } finally {
      semantics.dispose();
    }
    slider.onChanged!(0.5);
    await tester.pump();

    expect(find.text('0:45'), findsOneWidget);
    expect(find.byKey(const ValueKey('replay-evidence-graph')), findsOneWidget);
    expect(
      find.text('Verified route position available at this time.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Replay evidence timeline. 1 verified route span and 1 persisted event. Cursor at 0:45 of 1:30.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('12.97'), findsNothing);

    final event = find.byKey(const ValueKey('replay-event-0'));
    await tester.ensureVisible(event);
    await tester.tap(event);
    await tester.pumpAndSettle();
    expect(find.text('0:45'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Camera follows the verified marker\. 1 active event point is emphasized\.',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('play pause speed end and lifecycle use the same clock', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(
        history: [_trip],
        result: _replayResultWithEvent(),
      ),
      routeRepository: _FakeRouteRepository(result: _availableRoute),
    );
    await tester.scrollUntilVisible(
      find.text('Replay playback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final speedControl = find.byKey(const ValueKey('replay-speed-doubleSpeed'));
    final playbackToggle = find.byKey(const ValueKey('replay-playback-toggle'));
    await tester.ensureVisible(speedControl);
    await tester.pumpAndSettle();
    await tester.tap(speedControl);
    await tester.ensureVisible(playbackToggle);
    await tester.pumpAndSettle();
    await tester.tap(playbackToggle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Playing at 2×'), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Camera follows the verified marker\.')),
      findsOneWidget,
    );

    await tester.tap(playbackToggle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Paused · 2×'), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);

    await tester.tap(playbackToggle);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Paused · 2×'), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    final sliderFinder = find.byKey(const ValueKey('replay-timeline-slider'));
    await tester.ensureVisible(sliderFinder);
    await tester.pumpAndSettle();
    tester.widget<Slider>(sliderFinder).onChanged!(0.99);
    await tester.pump();
    await tester.ensureVisible(playbackToggle);
    await tester.pumpAndSettle();
    await tester.tap(playbackToggle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Replay complete · 2×'), findsOneWidget);
    expect(find.text('1:30'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'procedural commentary tone anchor and evidence use persisted replay state',
    (tester) async {
      await _pumpResult(
        tester,
        repository: _FakeRepository(
          history: [_trip],
          result: _replayResultWithEvent(),
        ),
        routeRepository: _FakeRouteRepository(result: _availableRoute),
      );
      await tester.scrollUntilVisible(
        find.text('Road commentary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('commentary-tone-chill')),
            )
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('commentary-ready-state')),
        findsOneWidget,
      );

      final event = find.byKey(const ValueKey('replay-event-0'));
      await tester.scrollUntilVisible(
        event,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(event);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commentary-active-bubble')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Chill road commentary\..*Anchored to a verified persisted event point\.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Commentary: .*Anchored to a verified persisted event point\.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('12.97'), findsNothing);

      final evidenceToggle = find.byKey(
        const ValueKey('commentary-evidence-toggle'),
      );
      await tester.scrollUntilVisible(
        evidenceToggle,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(evidenceToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commentary-recorded-evidence')),
        findsOneWidget,
      );
      expect(find.textContaining('0:40–0:50'), findsOneWidget);
      expect(find.textContaining('Commentary does not alter'), findsOneWidget);

      final roast = find.byKey(const ValueKey('commentary-tone-roast'));
      await tester.scrollUntilVisible(
        roast,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(roast);
      await tester.pumpAndSettle();
      expect(find.text('ROAST'), findsOneWidget);
      expect(find.textContaining('brake pedal'), findsOneWidget);

      final silent = find.byKey(const ValueKey('commentary-tone-silent'));
      await tester.scrollUntilVisible(
        silent,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(silent);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commentary-silent-state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('commentary-active-bubble')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'commentary remains timeline-only without verified route anchor',
    (tester) async {
      await _pumpResult(
        tester,
        repository: _FakeRepository(
          history: [_trip],
          result: _replayResultWithEvent(),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Replay playback'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      tester
          .widget<Slider>(find.byKey(const ValueKey('replay-timeline-slider')))
          .onChanged!(0.5);
      await tester.pump();

      expect(find.byKey(const ValueKey('trip-route-available')), findsNothing);
      expect(
        find.byKey(const ValueKey('commentary-active-bubble')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Timeline-only: no verified route anchor exists at this event time.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'No verified map anchor is available for this event time\.'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled animations preserve manual replay without autoplay', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(
        history: [_trip],
        result: _replayResultWithEvent(),
      ),
      routeRepository: _FakeRouteRepository(result: _availableRoute),
      disableAnimations: true,
    );
    await tester.scrollUntilVisible(
      find.text('Replay playback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('replay-playback-toggle')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('replay-speed-doubleSpeed')),
          )
          .onSelected,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('replay-reduced-motion-note')),
      findsOneWidget,
    );

    tester
        .widget<Slider>(find.byKey(const ValueKey('replay-timeline-slider')))
        .onChanged!(0.5);
    await tester.pump();
    expect(find.text('0:45'), findsOneWidget);
    expect(find.text('Paused · 1×'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('commentary-active-bubble')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Commentary: .*Anchored to a verified persisted event point\.'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing and malformed results fail clearly', (tester) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: const [], result: null),
    );
    expect(find.text('Drive not found'), findsOneWidget);

    await _pumpResult(
      tester,
      repository: _FakeRepository(
        history: const [],
        resultError: const FormatException('bad result'),
      ),
    );
    expect(find.text('Drive result could not be verified'), findsOneWidget);
    expect(find.textContaining('No trip data was changed'), findsOneWidget);
  });

  testWidgets('route states fail closed and cache clear is an honest no-op', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: _result),
      routeRepository: const _FakeRouteRepository(
        result: TripRouteResult.invalid(),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Route could not be verified'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('trip-route-invalid')), findsOneWidget);
    expect(find.textContaining('no partial path is shown'), findsOneWidget);

    final clearCache = find.byKey(const ValueKey('clear-map-cache'));
    await tester.ensureVisible(clearCache);
    await tester.pumpAndSettle();
    await tester.tap(clearCache);
    await tester.pumpAndSettle();
    expect(find.text('No offline map tiles were stored.'), findsOneWidget);

    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: _result),
      routeRepository: const _FakeRouteRepository(
        result: TripRouteResult.unavailable(),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Route not available'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('trip-route-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('route read errors remain retryable and claim-free', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: _result),
      routeRepository: const _FakeRouteRepository(
        error: FormatException('channel payload'),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Route could not be read'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('trip-route-error')), findsOneWidget);
    expect(find.textContaining('No partial route is shown'), findsOneWidget);
    expect(find.text('Retry route'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester
            .getSemantics(find.text('Retry route'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'route loading remains explicit while local decoding is pending',
    (tester) async {
      final pending = Completer<TripRouteResult>();
      await _pumpResult(
        tester,
        repository: _FakeRepository(history: [_trip], result: _result),
        routeRepository: _FakeRouteRepository(pending: pending),
        settle: false,
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.scrollUntilVisible(
        find.text('OFFLINE ROUTE'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pump();

      expect(find.byKey(const ValueKey('trip-route-loading')), findsOneWidget);
      expect(find.text('Reading verified route'), findsOneWidget);

      pending.complete(const TripRouteResult.unavailable());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('large text keeps the result scrollable without overflow', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      repository: _FakeRepository(history: [_trip], result: _result),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Route geometry stays on this phone'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Route geometry stays on this phone'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  required TripHistoryRepository repository,
  bool settle = true,
}) async {
  await _pump(
    tester,
    repository: repository,
    home: const TripsScreen(),
    settle: settle,
  );
}

Future<void> _pumpResult(
  WidgetTester tester, {
  required TripHistoryRepository repository,
  TripRouteRepository routeRepository = const _FakeRouteRepository(),
  double textScale = 1,
  bool disableAnimations = false,
  bool settle = true,
}) async {
  await _pump(
    tester,
    repository: repository,
    routeRepository: routeRepository,
    home: const TripResultScreen(tripId: 'trip-one'),
    textScale: textScale,
    disableAnimations: disableAnimations,
    settle: settle,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required TripHistoryRepository repository,
  TripRouteRepository routeRepository = const _FakeRouteRepository(),
  required Widget home,
  bool settle = true,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripHistoryRepositoryProvider.overrideWithValue(repository),
        tripRouteRepositoryProvider.overrideWithValue(routeRepository),
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
        home: Scaffold(body: home),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _FakeRepository implements TripHistoryRepository {
  const _FakeRepository({
    this.history,
    this.historyStream,
    this.result,
    this.resultError,
  });

  final List<TripHistoryItem>? history;
  final Stream<List<TripHistoryItem>>? historyStream;
  final TripResult? result;
  final Object? resultError;

  @override
  Future<TripResult?> loadResult(String tripId) async {
    if (resultError != null) throw resultError!;
    return result;
  }

  @override
  Stream<List<TripHistoryItem>> watchHistory() {
    return historyStream ?? Stream.value(history ?? const []);
  }
}

class _FakeRouteRepository implements TripRouteRepository {
  const _FakeRouteRepository({
    this.result = const TripRouteResult.unavailable(),
    this.error,
    this.pending,
  });

  final TripRouteResult result;
  final Object? error;
  final Completer<TripRouteResult>? pending;

  @override
  Future<TripRouteResult> load(String tripId) async {
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return result;
  }
}

final _trip = TripHistoryItem(
  id: 'trip-one',
  vehicleName: 'Local bike',
  startedAtUtc: DateTime.utc(2026, 8, 25, 6, 30),
  duration: const Duration(seconds: 90),
  distanceMeters: null,
  completionState: TripEvidenceState.verified,
  recoveryState: TripEvidenceState.limited,
  integrityState: TripEvidenceState.notAssessed,
);

final _result = TripResult(
  trip: _trip,
  telemetrySchemaVersion: 1,
  telemetryConfidenceRecorded: false,
  evidence: const TripEvidenceSummary(
    chunkCount: 2,
    byteCount: 800,
    gnssSampleCount: 10,
    accelerometerSampleCount: 42,
    gyroscopeSampleCount: 40,
  ),
  finalization: const TripFinalizationSummary(
    logicVersion: 1,
    recoveryCount: 1,
    corruptChunkCount: 0,
    orphanedWriteCount: 0,
    orderingViolationCount: 0,
    qualityFlags: ['recorder_recovered'],
  ),
  events: const [],
  score: null,
);

TripResult _replayResultWithEvent() => TripResult(
  trip: _result.trip,
  telemetrySchemaVersion: _result.telemetrySchemaVersion,
  telemetryConfidenceRecorded: false,
  evidence: _result.evidence,
  finalization: _result.finalization,
  events: const [
    TripEventSummary(
      type: 'strong_braking',
      startElapsedNanos: 40_000_000_000,
      endElapsedNanos: 50_000_000_000,
    ),
  ],
  score: null,
);

final _availableRoute = TripRouteResult.available(
  MapRouteGeometry(
    processingVersion: 1,
    sourceGnssCount: 2,
    points: [
      MapRoutePoint(
        coordinate: MapCoordinate(latitude: 12.9716, longitude: 77.5946),
        tripOffset: Duration.zero,
        startsNewSegment: true,
      ),
      MapRoutePoint(
        coordinate: MapCoordinate(latitude: 12.9720, longitude: 77.5950),
        tripOffset: const Duration(seconds: 90),
        startsNewSegment: false,
      ),
    ],
    reduced: false,
  ),
);
