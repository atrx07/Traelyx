import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent_review.dart';

const owner = '11111111-1111-4111-8111-111111111111';

void main() {
  testWidgets('review stays cancellable and needs every explicit choice', (
    tester,
  ) async {
    GuardianDriverConsent? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result =
                  await showGuardianDriverConsentReview(context, owner),
              child: const Text('Review setup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Review setup'));
    await tester.pumpAndSettle();
    FilledButton confirm() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('guardian-confirm-review')),
    );
    expect(confirm().onPressed, isNull);
    expect(find.textContaining('not emergency assistance'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.text('Review setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian-forward-axis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top edge').last);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);

    for (final key in [
      'guardian-rigid-mount',
      'guardian-safety-limits',
      'guardian-recipient-sharing',
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('guardian-confirm-review')));
    await tester.pumpAndSettle();
    expect(result?.ownerId, owner);
    expect(result?.forwardAxis, '+y');
    expect(result?.isFreshAt(DateTime.now().toUtc()), isTrue);
  });
}
