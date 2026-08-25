import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/maps/offline_canvas_map_provider.dart';
import 'package:traelyx/core/maps/offline_route_map.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

void main() {
  test('map coordinates accept valid geographic bounds', () {
    final coordinate = MapCoordinate(latitude: 12.9716, longitude: 77.5946);

    expect(coordinate.latitude, 12.9716);
    expect(coordinate.longitude, 77.5946);
  });

  test('map coordinates reject unsupported precision domains', () {
    expect(
      () => MapCoordinate(latitude: 91, longitude: 0),
      throwsArgumentError,
    );
    expect(
      () => MapCoordinate(latitude: 0, longitude: double.nan),
      throwsArgumentError,
    );
  });

  test('route geometry requires ordered segments and reports their count', () {
    final geometry = _geometry();

    expect(geometry.segmentCount, 2);
    expect(
      () => MapRouteGeometry(
        processingVersion: 1,
        sourceGnssCount: 2,
        points: [geometry.points[1], geometry.points[0]],
        reduced: false,
      ),
      throwsArgumentError,
    );
  });

  test('offline provider has no network or tile cache dependency', () async {
    const provider = OfflineCanvasMapProvider();
    final controller = await provider.createController();

    expect(provider.requiresNetwork, isFalse);
    expect(provider.providerId, 'offline_canvas_v1');
    expect(
      await controller.watchCacheStatus().first,
      isA<MapCacheStatus>()
          .having((status) => status.bytesUsed, 'bytes', 0)
          .having((status) => status.isAvailable, 'available', isFalse),
    );
    await controller.clearCache();
    await controller.showRoute([
      MapCoordinate(latitude: 0, longitude: 0),
      MapCoordinate(latitude: 1, longitude: 1),
    ]);
  });

  test('projection takes the short ordered path across the antimeridian', () {
    final points = [
      _point(0, 0, 179.8, true),
      _point(1, 0, 179.9, false),
      _point(2, 0, -179.9, false),
    ];

    final projected = RouteProjector.project(points, const Size(300, 180));

    expect(projected[0].dx, lessThan(projected[1].dx));
    expect(projected[1].dx, lessThan(projected[2].dx));
    expect(
      projected.every((point) => point.dx >= 0 && point.dx <= 300),
      isTrue,
    );
  });

  testWidgets('offline route semantics describe shape without coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TraelyxTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: OfflineRouteMap(geometry: _geometry())),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('offline-route-map-canvas')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Offline route view. 3 verified display points across 2 segments. Start and end are marked, with 1 gap.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('12.97'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

MapRouteGeometry _geometry() => MapRouteGeometry(
  processingVersion: 1,
  sourceGnssCount: 3,
  points: [
    _point(0, 12.9716, 77.5946, true),
    _point(1, 12.9720, 77.5950, false),
    _point(7, 12.9730, 77.5960, true),
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
