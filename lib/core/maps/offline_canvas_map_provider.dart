import 'dart:async';

import 'package:traelyx/core/maps/map_contract.dart';

class OfflineCanvasMapProvider implements TraelyxMapProvider {
  const OfflineCanvasMapProvider();

  @override
  String get providerId => 'offline_canvas_v1';

  @override
  bool get requiresNetwork => false;

  @override
  Future<TraelyxMapController> createController() async {
    return OfflineCanvasMapController();
  }
}

class OfflineCanvasMapController implements TraelyxMapController {
  static const cacheStatus = MapCacheStatus(bytesUsed: 0, isAvailable: false);

  List<MapCoordinate> route = const [];
  MapCoordinate? marker;
  String? selectedEventId;
  MapCameraIntent cameraIntent = MapCameraIntent.fitRoute;
  Duration tripOffset = Duration.zero;

  @override
  Future<void> clearCache() async {
    // The local canvas has no tile store. This is intentionally a safe no-op.
  }

  @override
  Future<void> scrubTo(Duration tripOffset) async {
    if (tripOffset.isNegative) throw ArgumentError.value(tripOffset);
    this.tripOffset = tripOffset;
  }

  @override
  Future<void> selectEvent(String? eventId) async {
    selectedEventId = eventId;
  }

  @override
  Future<void> setCameraIntent(MapCameraIntent intent) async {
    cameraIntent = intent;
  }

  @override
  Future<void> showCurrentMarker(MapCoordinate? marker) async {
    this.marker = marker;
  }

  @override
  Future<void> showRoute(List<MapCoordinate> route) async {
    this.route = List.unmodifiable(route);
  }

  @override
  Stream<MapCacheStatus> watchCacheStatus() => Stream.value(cacheStatus);
}
