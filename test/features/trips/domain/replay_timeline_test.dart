import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/features/trips/application/replay_clock_controller.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

void main() {
  test(
    'timeline uses recorded extent, spans, and rejects contradictory events',
    () {
      final result =
          ReplayTimeline.build(
                recordedDuration: const Duration(seconds: 8),
                route: _route(),
                events: const [
                  TripEventSummary(
                    type: 'strong_braking',
                    startElapsedNanos: 25_000_000_000,
                    endElapsedNanos: 35_000_000_000,
                  ),
                  TripEventSummary(
                    type: 'invalid',
                    startElapsedNanos: -1,
                    endElapsedNanos: 1,
                  ),
                ],
              )
              as ReplayTimelineAvailable;

      expect(result.timeline.duration, const Duration(seconds: 30));
      expect(result.timeline.routeSpans, hasLength(2));
      expect(result.timeline.routeSpans.first.start, Duration.zero);
      expect(result.timeline.routeSpans.first.end, const Duration(seconds: 10));
      expect(
        result.timeline.routeSpans.last.start,
        const Duration(seconds: 20),
      );
      expect(result.timeline.routeSpans.last.end, const Duration(seconds: 30));
      expect(result.timeline.events, isEmpty);
      expect(result.timeline.discardedEventCount, 2);
    },
  );

  test(
    'marker interpolation takes the antimeridian short path and not gaps',
    () {
      final timeline =
          (ReplayTimeline.build(
                    recordedDuration: const Duration(seconds: 30),
                    route: _route(),
                    events: const [],
                  )
                  as ReplayTimelineAvailable)
              .timeline;

      final middle = timeline.at(const Duration(seconds: 5)).routeMarker!;
      expect(middle.coordinate.latitude, closeTo(0, 1e-9));
      expect(middle.coordinate.longitude.abs(), closeTo(180, 1e-9));
      expect(middle.afterPointIndex, 0);
      expect(timeline.at(const Duration(seconds: 15)).routeMarker, isNull);
      expect(
        timeline.at(const Duration(seconds: 20)).routeMarker!.afterPointIndex,
        2,
      );
      expect(timeline.at(const Duration(seconds: 30)).routeMarker, isNotNull);
    },
  );

  test('clock clamps seeks and activates persisted event ranges', () {
    final timeline =
        (ReplayTimeline.build(
                  recordedDuration: const Duration(seconds: 30),
                  route: _route(),
                  events: const [
                    TripEventSummary(
                      type: 'road_impact',
                      startElapsedNanos: 4_000_000_000,
                      endElapsedNanos: 6_000_000_000,
                    ),
                  ],
                )
                as ReplayTimelineAvailable)
            .timeline;
    final clock = ReplayClockController(timeline);
    addTearDown(clock.dispose);

    clock.seekFraction(0.5);
    expect(clock.snapshot.position, const Duration(seconds: 15));
    expect(clock.snapshot.activeEventIndexes, isEmpty);
    clock.seekToEvent(0);
    expect(clock.snapshot.position, const Duration(seconds: 5));
    expect(clock.snapshot.activeEventIndexes, [0]);
    clock.seek(const Duration(minutes: 5));
    expect(clock.snapshot.position, const Duration(seconds: 30));
    clock.seek(const Duration(seconds: -1));
    expect(clock.snapshot.position, Duration.zero);
    expect(() => clock.seekFraction(double.nan), throwsArgumentError);
    expect(() => clock.seekToEvent(2), throwsRangeError);
  });

  test(
    'timeline remains available without a map and fails only with no extent',
    () {
      final eventOnly =
          ReplayTimeline.build(
                recordedDuration: null,
                route: null,
                events: const [
                  TripEventSummary(
                    type: 'phone_moved',
                    startElapsedNanos: 0,
                    endElapsedNanos: 2_000_000_000,
                  ),
                ],
              )
              as ReplayTimelineAvailable;

      expect(eventOnly.timeline.route, isNull);
      expect(eventOnly.timeline.duration, const Duration(seconds: 2));
      expect(
        eventOnly.timeline.at(const Duration(seconds: 1)).routeMarker,
        isNull,
      );
      expect(
        ReplayTimeline.build(
          recordedDuration: null,
          route: null,
          events: const [],
        ),
        isA<ReplayTimelineUnavailable>(),
      );
    },
  );
}

MapRouteGeometry _route() => MapRouteGeometry(
  processingVersion: 1,
  sourceGnssCount: 4,
  points: [
    _point(0, 0, 179, true),
    _point(10, 0, -179, false),
    _point(20, 1, -178, true),
    _point(30, 2, -177, false),
  ],
  reduced: false,
);

MapRoutePoint _point(
  int seconds,
  double latitude,
  double longitude,
  bool startsNewSegment,
) => MapRoutePoint(
  coordinate: MapCoordinate(latitude: latitude, longitude: longitude),
  tripOffset: Duration(seconds: seconds),
  startsNewSegment: startsNewSegment,
);
