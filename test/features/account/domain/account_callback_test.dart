import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/domain/account_callback.dart';

void main() {
  test('recognizes only the dedicated account callback path', () {
    expect(
      isAccountCallback(
        Uri.parse('io.github.atrx07.traelyx://auth-callback/?code=opaque'),
      ),
      isTrue,
    );
    expect(
      isAccountCallback(
        Uri.parse('io.github.atrx07.traelyx://other/?code=opaque'),
      ),
      isFalse,
    );
    expect(
      isAccountCallback(Uri.parse('https://auth-callback/?code=opaque')),
      isFalse,
    );
    expect(
      isAccountCallback(
        Uri.parse('io.github.atrx07.traelyx://auth-callback/other'),
      ),
      isFalse,
    );
  });
  test(
    'rejects callback authorities with user information or explicit ports',
    () {
      for (final authority in [
        'person@auth-callback',
        'auth-callback:443',
        'person@auth-callback:443',
      ]) {
        expect(
          isAccountCallback(
            Uri.parse('io.github.atrx07.traelyx://$authority/?code=opaque'),
          ),
          isFalse,
        );
      }
    },
  );
}
