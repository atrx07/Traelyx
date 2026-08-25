import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class OfflineRouteMap extends StatelessWidget {
  const OfflineRouteMap({
    required this.geometry,
    this.replayMarker,
    this.replayMarkerAfterPointIndex,
    this.replayPosition,
    this.cameraFollow = 0,
    this.activeEventMarkers = const [],
    this.eventPulsePhase = 0,
    super.key,
  }) : assert((replayMarker == null) == (replayMarkerAfterPointIndex == null)),
       assert(cameraFollow >= 0 && cameraFollow <= 1),
       assert(eventPulsePhase >= 0 && eventPulsePhase <= 1);

  final MapRouteGeometry geometry;
  final MapCoordinate? replayMarker;
  final int? replayMarkerAfterPointIndex;
  final Duration? replayPosition;
  final double cameraFollow;
  final List<RouteReplayPoint> activeEventMarkers;
  final double eventPulsePhase;

  @override
  Widget build(BuildContext context) {
    final gaps = geometry.segmentCount - 1;
    return Semantics(
      container: true,
      image: true,
      label:
          'Offline route view. ${geometry.points.length} verified display points across ${geometry.segmentCount} ${geometry.segmentCount == 1 ? 'segment' : 'segments'}. Start and end are marked${gaps == 0 ? '' : ', with $gaps ${gaps == 1 ? 'gap' : 'gaps'}'}.${replayMarker == null || replayPosition == null ? ' No verified replay position at the selected time.' : ' Replay marker shown at ${_formatMapOffset(replayPosition!)}.'}${cameraFollow > 0 && replayMarker != null ? ' Camera follows the verified marker.' : ' Route overview is shown.'}${activeEventMarkers.isEmpty ? '' : ' ${activeEventMarkers.length} active ${activeEventMarkers.length == 1 ? 'event point is' : 'event points are'} emphasized.'}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 1.55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.traelyxColors.canvas,
                borderRadius: BorderRadius.circular(TraelyxRadii.card),
                border: Border.all(color: context.traelyxColors.outline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TraelyxRadii.card),
                child: CustomPaint(
                  key: const ValueKey('offline-route-map-canvas'),
                  painter: OfflineRoutePainter(
                    geometry: geometry,
                    colors: context.traelyxColors,
                    replayMarker: replayMarker,
                    replayMarkerAfterPointIndex: replayMarkerAfterPointIndex,
                    replayPosition: replayPosition,
                    cameraFollow: cameraFollow,
                    activeEventMarkers: activeEventMarkers,
                    eventPulsePhase: eventPulsePhase,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RouteReplayPoint {
  const RouteReplayPoint({
    required this.coordinate,
    required this.afterPointIndex,
  });

  final MapCoordinate coordinate;
  final int afterPointIndex;
}

@visibleForTesting
abstract final class RouteProjector {
  static List<Offset> project(
    List<MapRoutePoint> points,
    Size size, {
    double padding = 28,
  }) {
    if (points.isEmpty || size.isEmpty) return const [];
    final unwrappedLongitudes = <double>[points.first.coordinate.longitude];
    for (var index = 1; index < points.length; index++) {
      var longitude = points[index].coordinate.longitude;
      final previous = unwrappedLongitudes.last;
      while (longitude - previous > 180) {
        longitude -= 360;
      }
      while (longitude - previous < -180) {
        longitude += 360;
      }
      unwrappedLongitudes.add(longitude);
    }
    final latitudes = points.map((point) => point.coordinate.latitude);
    var minimumLatitude = latitudes.reduce(math.min);
    var maximumLatitude = latitudes.reduce(math.max);
    var minimumLongitude = unwrappedLongitudes.reduce(math.min);
    var maximumLongitude = unwrappedLongitudes.reduce(math.max);
    if ((maximumLatitude - minimumLatitude).abs() < 1e-9) {
      minimumLatitude -= 0.00001;
      maximumLatitude += 0.00001;
    }
    if ((maximumLongitude - minimumLongitude).abs() < 1e-9) {
      minimumLongitude -= 0.00001;
      maximumLongitude += 0.00001;
    }
    final availableWidth = math.max(1.0, size.width - padding * 2);
    final availableHeight = math.max(1.0, size.height - padding * 2);
    final longitudeSpan = maximumLongitude - minimumLongitude;
    final latitudeSpan = maximumLatitude - minimumLatitude;
    final scale = math.min(
      availableWidth / longitudeSpan,
      availableHeight / latitudeSpan,
    );
    final drawnWidth = longitudeSpan * scale;
    final drawnHeight = latitudeSpan * scale;
    final left = (size.width - drawnWidth) / 2;
    final top = (size.height - drawnHeight) / 2;
    return List.generate(points.length, (index) {
      return Offset(
        left + (unwrappedLongitudes[index] - minimumLongitude) * scale,
        top + (maximumLatitude - points[index].coordinate.latitude) * scale,
      );
    });
  }

  static List<Offset> frameForFollow(
    List<Offset> points,
    Size size, {
    required Offset focus,
    required double progress,
    double followScale = 2.35,
  }) {
    if (points.isEmpty || progress <= 0) return points;
    final boundedProgress = progress.clamp(0.0, 1.0);
    final scale = 1 + (followScale - 1) * boundedProgress;
    final center = Offset(size.width / 2, size.height / 2);
    final translation = (center - focus) * boundedProgress;
    return [
      for (final point in points) focus + (point - focus) * scale + translation,
    ];
  }
}

class OfflineRoutePainter extends CustomPainter {
  OfflineRoutePainter({
    required this.geometry,
    required this.colors,
    this.replayMarker,
    this.replayMarkerAfterPointIndex,
    this.replayPosition,
    this.cameraFollow = 0,
    this.activeEventMarkers = const [],
    this.eventPulsePhase = 0,
  });

  final MapRouteGeometry geometry;
  final TraelyxSemanticColors colors;
  final MapCoordinate? replayMarker;
  final int? replayMarkerAfterPointIndex;
  final Duration? replayPosition;
  final double cameraFollow;
  final List<RouteReplayPoint> activeEventMarkers;
  final double eventPulsePhase;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final overviewRoute = RouteProjector.project(geometry.points, size);
    if (overviewRoute.length < 2) return;
    final markerPoint =
        replayMarker == null || replayMarkerAfterPointIndex == null
        ? null
        : RouteReplayPoint(
            coordinate: replayMarker!,
            afterPointIndex: replayMarkerAfterPointIndex!,
          );
    final overviewMarker = markerPoint == null
        ? null
        : _projectReplayPoint(markerPoint, size);
    final overviewEvents = [
      for (final event in activeEventMarkers) _projectReplayPoint(event, size),
    ];
    final combined = <Offset>[
      ...overviewRoute,
      ?overviewMarker,
      ...overviewEvents,
    ];
    final framed = overviewMarker == null
        ? combined
        : RouteProjector.frameForFollow(
            combined,
            size,
            focus: overviewMarker,
            progress: cameraFollow,
          );
    final projected = framed.sublist(0, overviewRoute.length);
    var nextOffsetIndex = overviewRoute.length;
    final markerOffset = overviewMarker == null
        ? null
        : framed[nextOffsetIndex++];
    final eventOffsets = framed.sublist(nextOffsetIndex);

    final casing = Paint()
      ..color = colors.canvas
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final futureRoute = Paint()
      ..color = colors.textSecondary.withValues(alpha: 0.66)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _paintRoutePaths(canvas, projected, casing);
    _paintRoutePaths(canvas, projected, futureRoute);
    final selectedPosition = replayPosition;
    if (selectedPosition == null) {
      _paintRoutePaths(canvas, projected, _completedRoutePaint());
    } else {
      _paintCompletedRoute(
        canvas,
        projected,
        markerOffset: markerOffset,
        selectedPosition: selectedPosition,
      );
    }
    for (var index = 1; index < projected.length; index++) {
      if (geometry.points[index].startsNewSegment) {
        _paintGap(canvas, projected[index]);
      }
    }
    _paintStart(canvas, projected.first);
    _paintEnd(canvas, projected.last);
    for (final eventOffset in eventOffsets) {
      _paintEventPulse(canvas, eventOffset);
    }
    if (markerOffset != null) _paintReplayMarker(canvas, markerOffset);
    _paintNorth(canvas, size);
  }

  Offset _projectReplayPoint(RouteReplayPoint point, Size size) {
    final points = geometry.points.toList()
      ..insert(
        point.afterPointIndex + 1,
        MapRoutePoint(
          coordinate: point.coordinate,
          tripOffset: Duration.zero,
          startsNewSegment: false,
        ),
      );
    return RouteProjector.project(points, size)[point.afterPointIndex + 1];
  }

  void _paintRoutePaths(Canvas canvas, List<Offset> projected, Paint paint) {
    Path? path;
    for (var index = 0; index < projected.length; index++) {
      if (index == 0 || geometry.points[index].startsNewSegment) {
        if (path != null) canvas.drawPath(path, paint);
        path = Path()..moveTo(projected[index].dx, projected[index].dy);
      } else {
        path!.lineTo(projected[index].dx, projected[index].dy);
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  Paint _completedRoutePaint() => Paint()
    ..color = colors.accent
    ..strokeWidth = 4.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _paintCompletedRoute(
    Canvas canvas,
    List<Offset> projected, {
    required Offset? markerOffset,
    required Duration selectedPosition,
  }) {
    final paint = _completedRoutePaint();
    Path? path;
    for (var index = 0; index < projected.length; index++) {
      final point = geometry.points[index];
      if (point.tripOffset > selectedPosition) {
        if (path != null &&
            markerOffset != null &&
            replayMarkerAfterPointIndex == index - 1) {
          path.lineTo(markerOffset.dx, markerOffset.dy);
        }
        if (path != null) canvas.drawPath(path, paint);
        return;
      }
      if (index == 0 || point.startsNewSegment) {
        if (path != null) canvas.drawPath(path, paint);
        path = Path()..moveTo(projected[index].dx, projected[index].dy);
      } else {
        path!.lineTo(projected[index].dx, projected[index].dy);
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.outline.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    for (var fraction = 0.2; fraction < 1; fraction += 0.2) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        paint,
      );
    }
  }

  void _paintStart(Canvas canvas, Offset point) {
    canvas.drawCircle(point, 8, Paint()..color = colors.positive);
    canvas.drawCircle(
      point,
      8,
      Paint()
        ..color = colors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(point, 2.5, Paint()..color = colors.canvas);
  }

  void _paintEnd(Canvas canvas, Offset point) {
    final path = Path()
      ..moveTo(point.dx, point.dy - 9)
      ..lineTo(point.dx + 9, point.dy)
      ..lineTo(point.dx, point.dy + 9)
      ..lineTo(point.dx - 9, point.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = colors.caution);
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintGap(Canvas canvas, Offset point) {
    final paint = Paint()
      ..color = colors.textPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      point + const Offset(-7, -5),
      point + const Offset(-2, 5),
      paint,
    );
    canvas.drawLine(
      point + const Offset(2, -5),
      point + const Offset(7, 5),
      paint,
    );
  }

  void _paintReplayMarker(Canvas canvas, Offset point) {
    canvas.drawCircle(point, 10, Paint()..color = colors.textPrimary);
    canvas.drawCircle(point, 7, Paint()..color = colors.accent);
    canvas.drawCircle(point, 2.5, Paint()..color = colors.canvas);
  }

  void _paintEventPulse(Canvas canvas, Offset point) {
    final phase = eventPulsePhase.clamp(0.0, 1.0);
    canvas.drawCircle(point, 5, Paint()..color = colors.caution);
    canvas.drawCircle(
      point,
      10 + phase * 9,
      Paint()
        ..color = colors.caution.withValues(alpha: 0.72 * (1 - phase))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _paintNorth(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width - 24, 10));
    canvas.drawLine(
      Offset(size.width - 18, 28),
      Offset(size.width - 18, 41),
      Paint()
        ..color = colors.textSecondary
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant OfflineRoutePainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.colors != colors ||
        oldDelegate.replayMarker != replayMarker ||
        oldDelegate.replayMarkerAfterPointIndex !=
            replayMarkerAfterPointIndex ||
        oldDelegate.replayPosition != replayPosition ||
        oldDelegate.cameraFollow != cameraFollow ||
        !listEquals(oldDelegate.activeEventMarkers, activeEventMarkers) ||
        oldDelegate.eventPulsePhase != eventPulsePhase;
  }
}

String _formatMapOffset(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes minutes $seconds seconds';
}
