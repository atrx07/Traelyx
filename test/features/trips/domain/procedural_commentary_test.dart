import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

void main() {
  test('all six tones are deterministic and Silent emits no moments', () {
    final timeline = _timeline([
      _event('EVT_BRAKE_STRONG', 20, 24),
      _event('EVT_ROAD_IMPACT', 50, 51),
    ]);

    for (final tone in CommentaryTone.values) {
      final first = ProceduralCommentaryPlan.build(
        timeline: timeline,
        tone: tone,
        seed: 17,
      );
      final second = ProceduralCommentaryPlan.build(
        timeline: timeline,
        tone: tone,
        seed: 17,
      );
      expect(
        first.moments.map((moment) => moment.text),
        second.moments.map((moment) => moment.text),
      );
      if (tone == CommentaryTone.silent) {
        expect(first.moments, isEmpty);
      } else {
        expect(first.moments, hasLength(2));
      }
    }
  });

  test('seed controls bounded variation without changing selection', () {
    final timeline = _timeline([_event('strong_braking', 20, 24)]);
    final first = ProceduralCommentaryPlan.build(
      timeline: timeline,
      tone: CommentaryTone.chill,
      seed: 0,
    );
    final second = ProceduralCommentaryPlan.build(
      timeline: timeline,
      tone: CommentaryTone.chill,
      seed: 1,
    );

    expect(first.moments.single.eventIndex, second.moments.single.eventIndex);
    expect(
      first.moments.single.variantIndex,
      isNot(second.moments.single.variantIndex),
    );
    expect(first.moments.single.text, isNot(second.moments.single.text));
  });

  test('cooldown keeps the more interesting nearby event and audits skips', () {
    final timeline = _timeline([
      _event('strong_braking', 10, 11),
      _event('road_impact', 15, 16),
      _event('strong_braking', 30, 31),
    ]);
    final plan = ProceduralCommentaryPlan.build(
      timeline: timeline,
      tone: CommentaryTone.analyst,
    );

    expect(plan.supportedEventCount, 3);
    expect(plan.cooldownSuppressedCount, 1);
    expect(plan.moments.map((moment) => moment.eventIndex), [1, 2]);
    expect(plan.moments.last.contextOrdinal, 1);
  });

  test('recent same-family moments receive explicit continuity', () {
    final timeline = _timeline([
      _event('EVT_BRAKE_STRONG', 10, 11),
      _event('EVT_BRAKE_ABRUPT_TRANSITION', 25, 26),
    ]);
    final plan = ProceduralCommentaryPlan.build(
      timeline: timeline,
      tone: CommentaryTone.supportive,
      seed: 4,
    );

    expect(plan.moments, hasLength(2));
    expect(plan.moments.last.contextOrdinal, 2);
    expect(plan.moments.last.text.toLowerCase(), contains('another'));
  });

  test('interestingness cap is bounded and auditable', () {
    final events = <TripEventSummary>[
      for (var index = 0; index < 8; index++)
        _event(
          index.isEven ? 'EVT_ROAD_IMPACT' : 'EVT_BRAKE_STRONG',
          10 + index * 15,
          11 + index * 15,
        ),
    ];
    final plan = ProceduralCommentaryPlan.build(
      timeline: _timeline(events, durationSeconds: 150),
      tone: CommentaryTone.analyst,
    );

    expect(plan.moments, hasLength(ProceduralCommentaryPlan.maximumMoments));
    expect(plan.limitSuppressedCount, 2);
    expect(plan.suppressedEventCount, 2);
    expect(
      plan.moments.map((moment) => moment.anchorTime.inSeconds),
      orderedEquals(
        [...plan.moments.map((moment) => moment.anchorTime.inSeconds)]..sort(),
      ),
    );
  });

  test('unknown event types fail closed and are never echoed', () {
    final timeline = _timeline([
      _event('private_raw_type_12.9716_77.5946', 20, 21),
    ]);
    final plan = ProceduralCommentaryPlan.build(
      timeline: timeline,
      tone: CommentaryTone.unhinged,
    );

    expect(plan.moments, isEmpty);
    expect(plan.unsupportedEventCount, 1);
    expect(plan.toString(), isNot(contains('12.9716')));
  });

  test('bubble visibility and reveal derive only from replay position', () {
    final timeline = _timeline([_event('EVT_CORNER_ABRUPT_ENTRY', 20, 30)]);
    final moment = ProceduralCommentaryPlan.build(
      timeline: timeline,
      tone: CommentaryTone.roast,
    ).moments.single;

    expect(moment.anchorTime, const Duration(seconds: 25));
    expect(moment.visibleFrom, const Duration(seconds: 24));
    expect(moment.visibleUntil, const Duration(seconds: 29));
    expect(moment.isVisibleAt(const Duration(seconds: 23)), isFalse);
    expect(moment.isVisibleAt(const Duration(seconds: 25)), isTrue);
    expect(moment.revealProgressAt(moment.visibleFrom), 0);
    expect(
      moment.revealProgressAt(moment.visibleFrom + const Duration(seconds: 1)),
      1,
    );
  });

  test('bundled tone output avoids unsafe encouragement and injury claims', () {
    final timeline = _timeline([
      _event('EVT_ACCEL_STRONG', 10, 11),
      _event('EVT_ACCEL_ABRUPT_TRANSITION', 25, 26),
      _event('EVT_BRAKE_STRONG', 40, 41),
      _event('EVT_BRAKE_ABRUPT_TRANSITION', 55, 56),
      _event('EVT_CORNER_HIGH_LOAD_LEFT', 70, 71),
      _event('EVT_CORNER_HIGH_LOAD_RIGHT', 85, 86),
      _event('EVT_CORNER_ABRUPT_ENTRY', 100, 101),
      _event('EVT_CORNER_ABRUPT_EXIT', 115, 116),
      _event('EVT_ROAD_IMPACT', 130, 131),
      _event('EVT_PHONE_MOVED', 145, 146),
    ], durationSeconds: 180);
    const blockedPhrases = [
      'do it again',
      'go faster',
      'speed up',
      'you are dead',
      'you died',
      'achievement unlocked',
    ];

    for (final tone in CommentaryTone.values) {
      final plan = ProceduralCommentaryPlan.build(
        timeline: timeline,
        tone: tone,
        seed: 9,
      );
      for (final moment in plan.moments) {
        final lower = moment.text.toLowerCase();
        for (final phrase in blockedPhrases) {
          expect(lower, isNot(contains(phrase)));
        }
      }
    }
  });
}

ReplayTimeline _timeline(
  List<TripEventSummary> events, {
  int durationSeconds = 120,
}) =>
    (ReplayTimeline.build(
              recordedDuration: Duration(seconds: durationSeconds),
              route: null,
              events: events,
            )
            as ReplayTimelineAvailable)
        .timeline;

TripEventSummary _event(String type, int startSeconds, int endSeconds) =>
    TripEventSummary(
      type: type,
      startElapsedNanos: startSeconds * 1000000000,
      endElapsedNanos: endSeconds * 1000000000,
    );
