import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent_review.dart';

const owner = '11111111-1111-4111-8111-111111111111';

void main() {
  testWidgets(
    'all acknowledgements without direction explain disabled confirm',
    (tester) async {
      GuardianDriverConsent? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showGuardianDriverConsentReview(
                      context,
                      owner,
                      sendingAvailable: true,
                    ),
                child: const Text('Review setup'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review setup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('phone resting on a table'), findsOneWidget);
      for (final key in [
        'guardian-rigid-mount',
        'guardian-safety-limits',
        'guardian-recipient-sharing',
        'guardian-sending-consent',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      final confirm = find.byKey(const ValueKey('guardian-confirm-review'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      final guidance = find.text('Choose the phone forward direction first.');
      expect(guidance, findsOneWidget);
      expect(guidance.hitTestable(), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(result, isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('guardian-forward-axis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guardian-forward-axis')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top edge').last);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      expect(
        find.byKey(const ValueKey('guardian-review-required-choice')),
        findsNothing,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );

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
    expect(
      find.text('Choose the phone forward direction first.'),
      findsOneWidget,
    );
    expect(find.textContaining('not emergency assistance'), findsOneWidget);
    expect(find.textContaining('monitoring stops'), findsOneWidget);
    expect(find.textContaining('Saved consent alone'), findsOneWidget);
    expect(find.textContaining('temporary driver session'), findsOneWidget);
    expect(find.textContaining('sending is unavailable'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.text('Review setup'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('guardian-forward-axis')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian-forward-axis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top edge').last);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);

    expect(
      find.text('Confirm a rigid vehicle mount, or cancel if not ready.'),
      findsOneWidget,
    );

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
    expect(result?.permitsSending, isFalse);
  });

  testWidgets(
    'sending review requires a separate unchecked choice and remains usable with large text',
    (tester) async {
      GuardianDriverConsent? result;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.4)),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showGuardianDriverConsentReview(
                      context,
                      owner,
                      sendingAvailable: true,
                    );
                  },
                  child: const Text('Review sending'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review sending'));
      await tester.pumpAndSettle();
      FilledButton confirm() => tester.widget<FilledButton>(
        find.byKey(const ValueKey('guardian-confirm-review')),
      );
      expect(confirm().onPressed, isNull);
      expect(find.textContaining('Supabase processes'), findsOneWidget);
      expect(find.textContaining('30 seconds'), findsOneWidget);
      expect(find.textContaining('sending is unavailable'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('guardian-forward-axis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guardian-forward-axis')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top edge').last);
      await tester.pumpAndSettle();
      for (final key in [
        'guardian-rigid-mount',
        'guardian-safety-limits',
        'guardian-recipient-sharing',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      expect(confirm().onPressed, isNull);
      final sending = find.byKey(const ValueKey('guardian-sending-consent'));
      expect(
        find
            .text('Review and agree to experimental sending for this session.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(sending).value, isFalse);
      await tester.ensureVisible(sending);
      await tester.pumpAndSettle();
      await tester.tap(sending);
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('guardian-confirm-review')));
      await tester.pumpAndSettle();
      expect(result?.permitsSending, isTrue);
      expect(result?.sendingReviewVersion, 1);
      expect(result?.isFreshAt(DateTime.now().toUtc()), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
