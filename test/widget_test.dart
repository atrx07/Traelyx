import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/main.dart';

void main() {
  testWidgets('bootstrap application launches with Traelyx identity', (
    tester,
  ) async {
    await tester.pumpWidget(const TraelyxBootstrapApp());

    expect(find.text('Traelyx bootstrap'), findsOneWidget);
  });
}
