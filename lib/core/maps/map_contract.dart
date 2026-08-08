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

enum MapCameraIntent { followCurrentMarker, fitRoute }

class MapCacheStatus {
  const MapCacheStatus({required this.bytesUsed, required this.isAvailable});

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
