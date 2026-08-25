import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';
import 'package:traelyx/features/trips/presentation/replay_evidence_timeline.dart';

void main() {
  testWidgets('instant terminal events remain visible and coordinate-free', (
    tester,
  ) async {
    final timeline =
        (ReplayTimeline.build(
                  recordedDuration: const Duration(seconds: 30),
                  route: null,
                  events: const [
                    TripEventSummary(
                      type: 'road_impact',
                      startElapsedNanos: 30_000_000_000,
                      endElapsedNanos: 30_000_000_000,
                    ),
                  ],
                )
                as ReplayTimelineAvailable)
            .timeline;

    await tester.pumpWidget(
      MaterialApp(
        theme: TraelyxTheme.dark,
        home: Scaffold(
          body: ReplayEvidenceTimeline(
            timeline: timeline,
            snapshot: timeline.at(const Duration(seconds: 30)),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('replay-evidence-graph')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Replay evidence timeline. 0 verified route spans and 1 persisted event. Cursor at 0:30 of 0:30.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('latitude'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
