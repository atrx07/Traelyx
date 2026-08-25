import 'dart:math' as math;

import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

class ReplayEventRange {
  const ReplayEventRange({
    required this.type,
    required this.start,
    required this.end,
  });

  final String type;
  final Duration start;
  final Duration end;

  Duration get midpoint => Duration(
    microseconds:
        start.inMicroseconds + (end.inMicroseconds - start.inMicroseconds) ~/ 2,
  );
}

class ReplayEvidenceSpan {
  const ReplayEvidenceSpan({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

class ReplayRouteMarker {
  const ReplayRouteMarker({
    required this.coordinate,
    required this.afterPointIndex,
  });

  final MapCoordinate coordinate;
  final int afterPointIndex;
}

class ReplayTimelineSnapshot {
  const ReplayTimelineSnapshot({
    required this.position,
    required this.routeMarker,
    required this.activeEventIndexes,
  });

  final Duration position;
  final ReplayRouteMarker? routeMarker;
  final List<int> activeEventIndexes;
}

sealed class ReplayTimelineBuildResult {
  const ReplayTimelineBuildResult();
}

class ReplayTimelineAvailable extends ReplayTimelineBuildResult {
  const ReplayTimelineAvailable(this.timeline);

  final ReplayTimeline timeline;
}

class ReplayTimelineUnavailable extends ReplayTimelineBuildResult {
  const ReplayTimelineUnavailable();
}

class ReplayTimeline {
  ReplayTimeline._({
    required this.duration,
    required this.route,
    required this.events,
    required this.routeSpans,
    required this.discardedEventCount,
  });

  final Duration duration;
  final MapRouteGeometry? route;
  final List<ReplayEventRange> events;
  final List<ReplayEvidenceSpan> routeSpans;
  final int discardedEventCount;

  static ReplayTimelineBuildResult build({
    required Duration? recordedDuration,
    required MapRouteGeometry? route,
    required List<TripEventSummary> events,
  }) {
    var maximumMicros = recordedDuration?.inMicroseconds ?? 0;
    if (maximumMicros < 0) maximumMicros = 0;
    if (route != null) {
      maximumMicros = math.max(
        maximumMicros,
        route.points.last.tripOffset.inMicroseconds,
      );
    }
    final hasIndependentExtent = maximumMicros > 0;

    var discardedEventCount = 0;
    final acceptedEvents = <ReplayEventRange>[];
    for (final event in events) {
      if (event.startElapsedNanos < 0 ||
          event.endElapsedNanos < event.startElapsedNanos) {
        discardedEventCount += 1;
        continue;
      }
      final replayEvent = ReplayEventRange(
        type: event.type,
        start: Duration(microseconds: event.startElapsedNanos ~/ 1000),
        end: Duration(microseconds: event.endElapsedNanos ~/ 1000),
      );
      if (hasIndependentExtent &&
          replayEvent.end.inMicroseconds > maximumMicros) {
        discardedEventCount += 1;
        continue;
      }
      acceptedEvents.add(replayEvent);
      if (!hasIndependentExtent) {
        maximumMicros = math.max(maximumMicros, replayEvent.end.inMicroseconds);
      }
    }
    if (maximumMicros <= 0) return const ReplayTimelineUnavailable();

    acceptedEvents.sort((left, right) {
      final start = left.start.compareTo(right.start);
      return start != 0 ? start : left.end.compareTo(right.end);
    });
    return ReplayTimelineAvailable(
      ReplayTimeline._(
        duration: Duration(microseconds: maximumMicros),
        route: route,
        events: List.unmodifiable(acceptedEvents),
        routeSpans: List.unmodifiable(_routeSpans(route)),
        discardedEventCount: discardedEventCount,
      ),
    );
  }

  ReplayTimelineSnapshot at(Duration position) {
    if (position.isNegative || position > duration) {
      throw RangeError.range(
        position.inMicroseconds,
        0,
        duration.inMicroseconds,
        'position',
      );
    }
    return ReplayTimelineSnapshot(
      position: position,
      routeMarker: _routeMarkerAt(position),
      activeEventIndexes: List.unmodifiable([
        for (var index = 0; index < events.length; index++)
          if (events[index].start <= position && events[index].end >= position)
            index,
      ]),
    );
  }

  ReplayRouteMarker? _routeMarkerAt(Duration position) {
    final points = route?.points;
    if (points == null ||
        position < points.first.tripOffset ||
        position > points.last.tripOffset) {
      return null;
    }

    var low = 0;
    var high = points.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final comparison = points[middle].tripOffset.compareTo(position);
      if (comparison == 0) {
        return ReplayRouteMarker(
          coordinate: points[middle].coordinate,
          afterPointIndex: middle,
        );
      }
      if (comparison < 0) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    final beforeIndex = high;
    final afterIndex = low;
    if (beforeIndex < 0 ||
        afterIndex >= points.length ||
        points[afterIndex].startsNewSegment) {
      return null;
    }
    final before = points[beforeIndex];
    final after = points[afterIndex];
    final intervalMicros =
        after.tripOffset.inMicroseconds - before.tripOffset.inMicroseconds;
    if (intervalMicros <= 0) return null;
    final fraction =
        (position.inMicroseconds - before.tripOffset.inMicroseconds) /
        intervalMicros;
    var longitudeDelta =
        after.coordinate.longitude - before.coordinate.longitude;
    if (longitudeDelta > 180) longitudeDelta -= 360;
    if (longitudeDelta < -180) longitudeDelta += 360;
    var longitude = before.coordinate.longitude + longitudeDelta * fraction;
    if (longitude > 180) longitude -= 360;
    if (longitude < -180) longitude += 360;
    return ReplayRouteMarker(
      coordinate: MapCoordinate(
        latitude:
            before.coordinate.latitude +
            (after.coordinate.latitude - before.coordinate.latitude) * fraction,
        longitude: longitude,
      ),
      afterPointIndex: beforeIndex,
    );
  }

  static List<ReplayEvidenceSpan> _routeSpans(MapRouteGeometry? route) {
    if (route == null) return const [];
    final spans = <ReplayEvidenceSpan>[];
    var start = route.points.first.tripOffset;
    for (var index = 1; index < route.points.length; index++) {
      if (route.points[index].startsNewSegment) {
        spans.add(
          ReplayEvidenceSpan(
            start: start,
            end: route.points[index - 1].tripOffset,
          ),
        );
        start = route.points[index].tripOffset;
      }
    }
    spans.add(
      ReplayEvidenceSpan(start: start, end: route.points.last.tripOffset),
    );
    return spans;
  }
}
