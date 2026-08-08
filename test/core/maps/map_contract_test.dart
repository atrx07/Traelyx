import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/maps/map_contract.dart';

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
}
