import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/trips/data/trip_route_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strict parser accepts bounded available geometry', () {
    final result = NativeTripRouteRepository.parse(_availableResponse());

    expect(result.state, TripRouteState.available);
    expect(result.geometry!.processingVersion, 1);
    expect(result.geometry!.sourceGnssCount, 3);
    expect(result.geometry!.points, hasLength(3));
    expect(result.geometry!.segmentCount, 2);
    expect(result.geometry!.reduced, isFalse);
  });

  test('strict parser keeps unavailable and invalid states evidence-free', () {
    for (final state in ['unavailable', 'invalid']) {
      final response = _emptyResponse(state);
      final result = NativeTripRouteRepository.parse(response);

      expect(result.state.name, state);
      expect(result.geometry, isNull);
    }
  });

  test(
    'strict parser rejects unknown fields, partial evidence, and bad shape',
    () {
      expect(
        () => NativeTripRouteRepository.parse({
          ..._availableResponse(),
          'tripId': 'must-not-cross',
        }),
        throwsFormatException,
      );
      expect(
        () => NativeTripRouteRepository.parse({
          ..._emptyResponse('invalid'),
          'sourceGnssCount': 1,
        }),
        throwsFormatException,
      );
      final reversed = _availableResponse();
      final points = reversed['points']! as List<Object?>;
      reversed['points'] = [points[1], points[0], points[2]];
      expect(
        () => NativeTripRouteRepository.parse(reversed),
        throwsFormatException,
      );
      final outOfBounds = _availableResponse();
      final badPoints = outOfBounds['points']! as List<Object?>;
      outOfBounds['points'] = [
        {...badPoints[0]! as Map<Object?, Object?>, 'latitude': 91.0},
        badPoints[1],
        badPoints[2],
      ];
      expect(
        () => NativeTripRouteRepository.parse(outOfBounds),
        throwsFormatException,
      );
    },
  );

  testWidgets('native repository sends only the selected trip id', (
    tester,
  ) async {
    const channel = MethodChannel('test/map-data');
    Object? arguments;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'loadTripRoute');
      arguments = call.arguments;
      return _emptyResponse('unavailable');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final result = await const NativeTripRouteRepository(
      channel: channel,
    ).load('trip-one');

    expect(result.state, TripRouteState.unavailable);
    expect(arguments, {'tripId': 'trip-one'});
  });
}

Map<Object?, Object?> _availableResponse() => <Object?, Object?>{
  'contractVersion': 1,
  'state': 'available',
  'processingVersion': 1,
  'sourceGnssCount': 3,
  'displayedPointCount': 3,
  'reduced': false,
  'points': <Object?>[
    _point(0, 12.9716, 77.5946, true),
    _point(1000000000, 12.9720, 77.5950, false),
    _point(7000000000, 12.9730, 77.5960, true),
  ],
};

Map<Object?, Object?> _emptyResponse(String state) => <Object?, Object?>{
  'contractVersion': 1,
  'state': state,
  'processingVersion': null,
  'sourceGnssCount': 0,
  'displayedPointCount': 0,
  'reduced': false,
  'points': <Object?>[],
};

Map<Object?, Object?> _point(
  int elapsed,
  double latitude,
  double longitude,
  bool startsNewSegment,
) => <Object?, Object?>{
  'tripElapsedNanos': elapsed,
  'latitude': latitude,
  'longitude': longitude,
  'startsNewSegment': startsNewSegment,
};
