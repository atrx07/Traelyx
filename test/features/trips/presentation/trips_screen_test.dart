import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
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
    );

    expect(find.byKey(const ValueKey('trip-result-screen')), findsOneWidget);
    expect(find.text('LOCAL DRIVE RESULT'), findsOneWidget);
    expect(find.text('Analysis not available'), findsOneWidget);
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
      find.textContaining('Routes and raw samples are not shown'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Routes and raw samples are not shown'),
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
      find.textContaining('Routes and raw samples are not shown'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Routes and raw samples are not shown').hitTestable(),
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
  double textScale = 1,
}) async {
  await _pump(
    tester,
    repository: repository,
    home: const TripResultScreen(tripId: 'trip-one'),
    textScale: textScale,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required TripHistoryRepository repository,
  required Widget home,
  bool settle = true,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [tripHistoryRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: TraelyxTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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
