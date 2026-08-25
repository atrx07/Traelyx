import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/drive_dna/application/drive_dna_providers.dart';
import 'package:traelyx/features/drive_dna/data/drive_dna_repository.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';
import 'package:traelyx/features/drive_dna/presentation/drive_dna_screen.dart';

void main() {
  testWidgets('empty state is truthful and contains no synthetic values', (
    tester,
  ) async {
    await _pumpDna(tester, repository: const _FakeRepository(snapshot: null));

    expect(find.byKey(const ValueKey('drive-dna-screen')), findsOneWidget);
    expect(find.text('Your driving signature'), findsOneWidget);
    expect(find.text('Your signature is still forming'), findsOneWidget);
    expect(
      find.textContaining('No governed Drive DNA snapshot'),
      findsOneWidget,
    );
    expect(find.text('0 / 10'), findsOneWidget);
    expect(find.textContaining('76'), findsNothing);
    expect(
      find.byKey(const ValueKey('drive-dna-signature-painter')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('complete profile renders signature, trends, and provenance', (
    tester,
  ) async {
    await _pumpDna(
      tester,
      repository: const _FakeRepository(snapshot: _completeSnapshot),
    );

    expect(find.text('Complete signature'), findsOneWidget);
    expect(find.text('Established · Local bike'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Smoothness'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('76 / 100'), findsWidgets);
    expect(find.textContaining('Recent +2'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('BASELINE LIFECYCLE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Established'), findsOneWidget);
    expect(find.text('12 eligible'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PROVENANCE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('DNA v1'), findsOneWidget);
    expect(find.textContaining('percentage hidden'), findsOneWidget);
    expect(find.textContaining('private-owner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial emerging profile keeps missing dimensions explicit', (
    tester,
  ) async {
    await _pumpDna(
      tester,
      repository: const _FakeRepository(snapshot: _partialSnapshot),
    );

    expect(find.text('Partial signature'), findsOneWidget);
    expect(find.text('Emerging · Local bike'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Acceleration control'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Insufficient data'), findsWidgets);
    expect(find.textContaining('value withheld'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable profile remains distinct from recalibrating lifecycle',
    (tester) async {
      await _pumpDna(
        tester,
        repository: const _FakeRepository(snapshot: _recalibratingSnapshot),
      );

      expect(find.text('Unavailable signature'), findsOneWidget);
      expect(find.text('Recalibrating · Local bike'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('BASELINE LIFECYCLE'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recalibrating'), findsOneWidget);
      expect(find.textContaining('fresh evidence window'), findsOneWidget);
      expect(find.text('Insufficient data'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading and malformed states remain claim-free and retryable', (
    tester,
  ) async {
    await _pumpDna(
      tester,
      repository: _FakeRepository(stream: const Stream.empty()),
      settle: false,
    );
    expect(find.bySemanticsLabel('Loading local Drive DNA'), findsOneWidget);

    await _pumpDna(
      tester,
      repository: _FakeRepository(
        stream: Stream.error(const FormatException('bad snapshot')),
      ),
    );
    expect(find.text('Drive DNA could not be verified'), findsOneWidget);
    expect(find.textContaining('No profile claim is shown'), findsOneWidget);
    expect(find.text('Retry local baseline'), findsOneWidget);
  });

  testWidgets('disabled animations remove signature and lifecycle motion', (
    tester,
  ) async {
    await _pumpDna(
      tester,
      repository: const _FakeRepository(snapshot: _completeSnapshot),
      disableAnimations: true,
    );

    final animations = tester.widgetList<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(animations, isNotEmpty);
    expect(
      animations.every((animation) => animation.duration == Duration.zero),
      isTrue,
    );
  });

  testWidgets('large text remains scrollable without overflow', (tester) async {
    await _pumpDna(
      tester,
      repository: const _FakeRepository(snapshot: _completeSnapshot),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Local-only · Observed patterns'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('universal competence').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDna(
  WidgetTester tester, {
  required DriveDnaRepository repository,
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
      overrides: [driveDnaRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: TraelyxTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: const Scaffold(body: DriveDnaScreen()),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _FakeRepository implements DriveDnaRepository {
  const _FakeRepository({this.snapshot, this.stream});

  final DriveDnaSnapshot? snapshot;
  final Stream<DriveDnaSnapshot?>? stream;

  @override
  Stream<DriveDnaSnapshot?> watchLatest() => stream ?? Stream.value(snapshot);
}

const _completeSnapshot = DriveDnaSnapshot(
  vehicleLabel: 'Local bike',
  lifecycleState: DriveDnaLifecycleState.established,
  validTripCount: 12,
  windowStartUtc: null,
  windowEndUtc: null,
  baselineSchemaVersion: 1,
  driveDnaVersion: 1,
  scoringVersion: 'scoring-v1',
  confidenceRecorded: true,
  dimensions: [
    DriveDnaDimension(
      type: DriveDnaDimensionType.smoothness,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 76000,
      eligibleTripCount: 12,
      recentDeltaMilliPoints: 2000,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.brakingControl,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 81000,
      eligibleTripCount: 11,
      recentDeltaMilliPoints: -1000,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.accelerationControl,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 76000,
      eligibleTripCount: 10,
      recentDeltaMilliPoints: 0,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.corneringControl,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 72000,
      eligibleTripCount: 9,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.consistency,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 88000,
      eligibleTripCount: 12,
      recentDeltaMilliPoints: 2000,
    ),
  ],
);

const _partialSnapshot = DriveDnaSnapshot(
  vehicleLabel: 'Local bike',
  lifecycleState: DriveDnaLifecycleState.emerging,
  validTripCount: 4,
  windowStartUtc: null,
  windowEndUtc: null,
  baselineSchemaVersion: 1,
  driveDnaVersion: 1,
  scoringVersion: 'scoring-v1',
  confidenceRecorded: false,
  dimensions: [
    DriveDnaDimension(
      type: DriveDnaDimensionType.smoothness,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 76000,
      eligibleTripCount: 4,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.brakingControl,
      state: DriveDnaDimensionState.available,
      valueMilliPoints: 70000,
      eligibleTripCount: 4,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.accelerationControl,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 2,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.corneringControl,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 1,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.consistency,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 2,
      recentDeltaMilliPoints: null,
    ),
  ],
);

const _recalibratingSnapshot = DriveDnaSnapshot(
  vehicleLabel: 'Local bike',
  lifecycleState: DriveDnaLifecycleState.recalibrating,
  validTripCount: 2,
  windowStartUtc: null,
  windowEndUtc: null,
  baselineSchemaVersion: 1,
  driveDnaVersion: 1,
  scoringVersion: 'scoring-v1',
  confidenceRecorded: false,
  dimensions: [
    DriveDnaDimension(
      type: DriveDnaDimensionType.smoothness,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 2,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.brakingControl,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 2,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.accelerationControl,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 1,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.corneringControl,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 1,
      recentDeltaMilliPoints: null,
    ),
    DriveDnaDimension(
      type: DriveDnaDimensionType.consistency,
      state: DriveDnaDimensionState.insufficientData,
      valueMilliPoints: null,
      eligibleTripCount: 0,
      recentDeltaMilliPoints: null,
    ),
  ],
);
