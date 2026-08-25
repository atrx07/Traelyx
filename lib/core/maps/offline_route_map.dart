import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class OfflineRouteMap extends StatelessWidget {
  const OfflineRouteMap({required this.geometry, super.key});

  final MapRouteGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final gaps = geometry.segmentCount - 1;
    return Semantics(
      image: true,
      label:
          'Offline route view. ${geometry.points.length} verified display points across ${geometry.segmentCount} ${geometry.segmentCount == 1 ? 'segment' : 'segments'}. Start and end are marked${gaps == 0 ? '' : ', with $gaps ${gaps == 1 ? 'gap' : 'gaps'}'}.',
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
}

class OfflineRoutePainter extends CustomPainter {
  OfflineRoutePainter({required this.geometry, required this.colors});

  final MapRouteGeometry geometry;
  final TraelyxSemanticColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final projected = RouteProjector.project(geometry.points, size);
    if (projected.length < 2) return;
    final casing = Paint()
      ..color = colors.canvas
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final route = Paint()
      ..color = colors.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final paint in [casing, route]) {
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
    for (var index = 1; index < projected.length; index++) {
      if (geometry.points[index].startsNewSegment) {
        _paintGap(canvas, projected[index]);
      }
    }
    _paintStart(canvas, projected.first);
    _paintEnd(canvas, projected.last);
    _paintNorth(canvas, size);
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
    return oldDelegate.geometry != geometry || oldDelegate.colors != colors;
  }
}
