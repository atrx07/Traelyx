import 'package:flutter/services.dart';
import 'package:traelyx/core/maps/map_contract.dart';

const _mapDataContractVersion = 1;
const _maximumDisplayPoints = 4096;

enum TripRouteState { available, unavailable, invalid }

class TripRouteResult {
  const TripRouteResult._({required this.state, this.geometry});

  const TripRouteResult.available(MapRouteGeometry geometry)
    : this._(state: TripRouteState.available, geometry: geometry);

  const TripRouteResult.unavailable()
    : this._(state: TripRouteState.unavailable);

  const TripRouteResult.invalid() : this._(state: TripRouteState.invalid);

  final TripRouteState state;
  final MapRouteGeometry? geometry;
}

abstract interface class TripRouteRepository {
  Future<TripRouteResult> load(String tripId);
}

class NativeTripRouteRepository implements TripRouteRepository {
  const NativeTripRouteRepository({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('io.github.atrx07.traelyx/map-data/v1');

  final MethodChannel _channel;

  @override
  Future<TripRouteResult> load(String tripId) async {
    final value = await _channel.invokeMethod<Object?>('loadTripRoute', {
      'tripId': tripId,
    });
    return parse(value);
  }

  static TripRouteResult parse(Object? value) {
    final map = _strictMap(value, _responseKeys, 'route response');
    if (map['contractVersion'] != _mapDataContractVersion) {
      throw const FormatException('Unsupported map-data contract.');
    }
    final state = switch (map['state']) {
      'available' => TripRouteState.available,
      'unavailable' => TripRouteState.unavailable,
      'invalid' => TripRouteState.invalid,
      _ => throw const FormatException('Unknown route state.'),
    };
    final processingVersion = map['processingVersion'];
    final sourceGnssCount = map['sourceGnssCount'];
    final displayedPointCount = map['displayedPointCount'];
    final reduced = map['reduced'];
    final rawPoints = map['points'];
    if (sourceGnssCount is! int ||
        displayedPointCount is! int ||
        reduced is! bool ||
        rawPoints is! List<Object?>) {
      throw const FormatException('Malformed route summary.');
    }
    if (state != TripRouteState.available) {
      if (processingVersion != null ||
          sourceGnssCount != 0 ||
          displayedPointCount != 0 ||
          reduced ||
          rawPoints.isNotEmpty) {
        throw const FormatException('Non-available route exposed evidence.');
      }
      return state == TripRouteState.unavailable
          ? const TripRouteResult.unavailable()
          : const TripRouteResult.invalid();
    }
    if (processingVersion is! int ||
        processingVersion <= 0 ||
        sourceGnssCount < displayedPointCount ||
        displayedPointCount < 2 ||
        displayedPointCount > _maximumDisplayPoints ||
        rawPoints.length != displayedPointCount) {
      throw const FormatException('Malformed available route.');
    }

    final points = <MapRoutePoint>[];
    for (final rawPoint in rawPoints) {
      final point = _strictMap(rawPoint, _pointKeys, 'route point');
      final elapsedNanos = point['tripElapsedNanos'];
      final latitude = point['latitude'];
      final longitude = point['longitude'];
      final startsNewSegment = point['startsNewSegment'];
      if (elapsedNanos is! int ||
          elapsedNanos < 0 ||
          latitude is! num ||
          longitude is! num ||
          startsNewSegment is! bool) {
        throw const FormatException('Malformed route point.');
      }
      try {
        points.add(
          MapRoutePoint(
            coordinate: MapCoordinate(
              latitude: latitude.toDouble(),
              longitude: longitude.toDouble(),
            ),
            tripOffset: Duration(microseconds: elapsedNanos ~/ 1000),
            startsNewSegment: startsNewSegment,
          ),
        );
      } on ArgumentError {
        throw const FormatException('Route point outside contract bounds.');
      }
    }
    try {
      return TripRouteResult.available(
        MapRouteGeometry(
          processingVersion: processingVersion,
          sourceGnssCount: sourceGnssCount,
          points: List.unmodifiable(points),
          reduced: reduced,
        ),
      );
    } on ArgumentError {
      throw const FormatException('Route geometry outside contract bounds.');
    }
  }

  static Map<Object?, Object?> _strictMap(
    Object? value,
    Set<String> expectedKeys,
    String label,
  ) {
    if (value is! Map<Object?, Object?> ||
        value.keys.any((key) => key is! String) ||
        value.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(value.keys.toSet()).isNotEmpty) {
      throw FormatException('Malformed $label.');
    }
    return value;
  }

  static const _responseKeys = {
    'contractVersion',
    'state',
    'processingVersion',
    'sourceGnssCount',
    'displayedPointCount',
    'reduced',
    'points',
  };

  static const _pointKeys = {
    'tripElapsedNanos',
    'latitude',
    'longitude',
    'startsNewSegment',
  };
}
