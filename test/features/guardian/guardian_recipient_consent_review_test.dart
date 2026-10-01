import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/guardian/guardian_recipient_consent.dart';
import 'package:traelyx/features/guardian/guardian_recipient_consent_review.dart';

const owner = '11111111-1111-4111-8111-111111111111';

void main() {
  testWidgets('recipient review needs both disclosures and can be cancelled', (
    tester,
  ) async {
    GuardianRecipientConsent? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result =
                  await showGuardianRecipientConsentReview(context, owner),
              child: const Text('Review notifications'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Review notifications'));
    await tester.pumpAndSettle();
    FilledButton confirm() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('guardian-recipient-confirm-review')),
    );
    expect(confirm().onPressed, isNull);
    expect(find.textContaining('not emergency assistance'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.text('Review notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian-recipient-limits')));
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('guardian-recipient-provider')),
    );
    await tester.tap(find.byKey(const ValueKey('guardian-recipient-provider')));
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(
      find.byKey(const ValueKey('guardian-recipient-confirm-review')),
    );
    await tester.pumpAndSettle();
    expect(result?.ownerId, owner);
    expect(result?.isFreshAt(DateTime.now().toUtc()), isTrue);
  });

  test('consent rejects stale, future and incomplete reviews', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    GuardianRecipientConsent consent(
      DateTime reviewedAt, {
      bool provider = true,
    }) => GuardianRecipientConsent(
      ownerId: owner,
      deliveryLimitsAcknowledged: true,
      providerDisclosureAccepted: provider,
      reviewedAt: reviewedAt,
    );
    expect(consent(now).isFreshAt(now), isTrue);
    expect(
      consent(now.subtract(const Duration(minutes: 2))).isFreshAt(now),
      isFalse,
    );
    expect(
      consent(now.add(const Duration(seconds: 1))).isFreshAt(now),
      isFalse,
    );
    expect(consent(now, provider: false).isFreshAt(now), isFalse);
    expect(
      GuardianRecipientConsent(
        ownerId: 'invalid',
        deliveryLimitsAcknowledged: true,
        providerDisclosureAccepted: true,
        reviewedAt: now,
      ).isFreshAt(now),
      isFalse,
    );
    expect(consent(now).toString(), isNot(contains(owner)));
  });
}
