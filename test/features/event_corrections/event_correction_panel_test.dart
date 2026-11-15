import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/event_corrections/application/event_correction_service.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/presentation/event_correction_panel.dart';

import 'correction_fixture.dart';

void main() {
  late AppDatabase db;
  late EventCorrectionRepository repo;
  late _Exporter exporter;
  late EventCorrectionService service;
  var idle = true;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedCorrectionTrip(db);
    repo = EventCorrectionRepository(db, now: () => 100);
    exporter = _Exporter();
    idle = true;
    service = EventCorrectionService(
      repository: repo,
      isRecorderIdle: () async => idle,
      exporter: exporter,
    );
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventCorrectionServiceProvider.overrideWithValue(service)],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: TraelyxTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
                accessibleNavigation: true,
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: EventCorrectionPanel(tripId: 'private-trip'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('review-detections')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('correction-parked')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('correction-parked')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('correction-event')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('correction-event')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('1. Strong braking').last);
    await tester.pumpAndSettle();
  }

  testWidgets('active or unknown recorder never opens a labeling prompt', (
    tester,
  ) async {
    idle = false;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('review-detections')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('correction-parked')), findsNothing);
    expect(find.textContaining('Finish driving before'), findsOneWidget);
    expect(await db.select(db.tripEventCorrections).get(), isEmpty);
  });

  testWidgets(
    'local note needs parked acknowledgment and defaults to no contribution',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('review-detections')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('save-correction')), findsNothing);
      expect(find.byKey(const ValueKey('correction-event')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('correction-parked')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('correction-event')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1. Strong braking').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Not this event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not this event'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('correction-consent')),
            )
            .value,
        false,
      );
      await reveal(tester, find.byKey(const ValueKey('save-correction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-correction')));
      await tester.pumpAndSettle();
      final note = (await repo.load('private-trip')).notes.single;
      expect(note.choice.wireName, 'not_this_event');
      expect(note.contributionAllowed, false);
      expect(exporter.payloads, isEmpty);
      expect((await db.select(db.tripScores).getSingle()).overallScore, 50);
    },
  );

  testWidgets(
    'separate opt-in and exact review precede the contribution picker',
    (tester) async {
      await pump(tester);
      await open(tester);
      await reveal(tester, find.byKey(const ValueKey('correction-consent')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('correction-consent')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('save-correction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-correction')));
      await tester.pumpAndSettle();
      expect(exporter.payloads, isEmpty);
      await reveal(tester, find.byKey(const ValueKey('export-corrections')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-corrections')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('save-contribution-file')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('No routes'), findsOneWidget);
      await reveal(
        tester,
        find.byKey(const ValueKey('confirm-contribution-copy')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-contribution-copy')));
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('save-contribution-file')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-contribution-file')));
      await tester.pumpAndSettle();
      expect(exporter.payloads.single['trainingUse'], 'quarantine_only');
      expect(exporter.payloads.single.keys, isNot(contains('tripId')));
      expect(find.text('Contribution export cancelled.'), findsOneWidget);
      expect(
        (await repo.load('private-trip')).notes.single.contributionAllowed,
        true,
      );
    },
  );

  testWidgets(
    'large text and reduced motion retain usable choices; leaving app resets confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await pump(tester, scale: 1.7, boundary: boundary);
      await open(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('correction-consent')),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.environment['TRAELYX_CORRECTION_SCREENSHOT'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            '.dart_tool/m7-correction-widget.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('correction-parked')),
            )
            .value,
        false,
      );
      expect(find.byKey(const ValueKey('save-correction')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Exporter implements CorrectionExporter {
  final payloads = <Map<String, Object?>>[];
  @override
  Future<CorrectionExportResult> export(
    Map<String, Object?> payload, {
    required Future<bool> Function() authorize,
  }) async {
    payloads.add(payload);
    return const CorrectionExportResult(
      exported: false,
      errorCode: 'export_cancelled',
    );
  }
}
