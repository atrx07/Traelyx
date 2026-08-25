class MapCoordinate {
  MapCoordinate({required this.latitude, required this.longitude}) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be within -90..90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be within -180..180.',
      );
    }
  }

  final double latitude;
  final double longitude;
}

class MapRoutePoint {
  MapRoutePoint({
    required this.coordinate,
    required this.tripOffset,
    required this.startsNewSegment,
  }) {
    if (tripOffset.isNegative) {
      throw ArgumentError.value(
        tripOffset,
        'tripOffset',
        'Must not be negative.',
      );
    }
  }

  final MapCoordinate coordinate;
  final Duration tripOffset;
  final bool startsNewSegment;
}

class MapRouteGeometry {
  MapRouteGeometry({
    required this.processingVersion,
    required this.sourceGnssCount,
    required this.points,
    required this.reduced,
  }) {
    if (processingVersion <= 0) {
      throw ArgumentError.value(processingVersion, 'processingVersion');
    }
    if (sourceGnssCount < points.length || points.length < 2) {
      throw ArgumentError.value(sourceGnssCount, 'sourceGnssCount');
    }
    if (!points.first.startsNewSegment) {
      throw ArgumentError.value(
        points,
        'points',
        'First point must start a segment.',
      );
    }
    for (var index = 1; index < points.length; index++) {
      if (points[index].tripOffset <= points[index - 1].tripOffset) {
        throw ArgumentError.value(points, 'points', 'Offsets must increase.');
      }
    }
  }

  final int processingVersion;
  final int sourceGnssCount;
  final List<MapRoutePoint> points;
  final bool reduced;

  int get segmentCount =>
      points.where((point) => point.startsNewSegment).length;
}

enum MapCameraIntent { followCurrentMarker, fitRoute }

class MapCacheStatus {
  const MapCacheStatus({required this.bytesUsed, required this.isAvailable})
    : assert(bytesUsed >= 0);

  final int bytesUsed;
  final bool isAvailable;
}

/// Project-level map operations that keep provider SDK types out of features.
abstract interface class TraelyxMapController {
  Future<void> showRoute(List<MapCoordinate> route);

  Future<void> showCurrentMarker(MapCoordinate? marker);

  Future<void> selectEvent(String? eventId);

  Future<void> setCameraIntent(MapCameraIntent intent);

  Future<void> scrubTo(Duration tripOffset);

  Stream<MapCacheStatus> watchCacheStatus();

  Future<void> clearCache();
}

/// Replaceable boundary for a future local-first map renderer.
abstract interface class TraelyxMapProvider {
  String get providerId;

  bool get requiresNetwork;

  Future<TraelyxMapController> createController();
}
