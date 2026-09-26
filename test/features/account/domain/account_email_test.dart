import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/domain/account_email.dart';

void main() {
  test('email input is trimmed without changing the local part', () {
    expect(
      normalizeAccountEmail('  Driver@Example.com  '),
      'Driver@Example.com',
    );
  });

  test('empty, malformed, and oversized addresses are rejected', () {
    expect(normalizeAccountEmail(''), isNull);
    expect(normalizeAccountEmail('driver@'), isNull);
    expect(normalizeAccountEmail('driver example@test.com'), isNull);
    expect(normalizeAccountEmail('${'a' * 250}@test.com'), isNull);
  });
}
