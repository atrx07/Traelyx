import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/application/refresh_account_session.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/account/presentation/account_screen.dart';

const original = AccountIdentity(
  userId: '11111111-1111-4111-8111-111111111111',
  email: 'original@example.invalid',
);
const other = AccountIdentity(
  userId: '22222222-2222-4222-8222-222222222222',
  email: 'other@example.invalid',
);

class RefreshAccount implements AccountGateway {
  AccountIdentity? identity = original;
  final changes = StreamController<AccountIdentity?>.broadcast(sync: true);
  Future<void> Function()? operation;
  int calls = 0;
  @override
  bool get isAvailable => true;
  @override
  AccountIdentity? get currentIdentity => identity;
  @override
  Stream<AccountIdentity?> get identityChanges => changes.stream;
  void emit(AccountIdentity? value) {
    identity = value;
    changes.add(value);
  }

  @override
  Future<void> refreshSession() async {
    calls++;
    await operation?.call();
  }

  @override
  Future<void> signOut() async => fail('Refresh must not call Sign out');
  @override
  Future<void> sendSignInLink(String email) async =>
      fail('No automatic sign-in');
}

void main() {
  Future<RefreshAccount> show(WidgetTester tester) async {
    final account = RefreshAccount();
    addTearDown(account.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountGatewayProvider.overrideWithValue(account)],
        child: const MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account-refresh')),
      200,
    );
    return account;
  }

  test('unavailable/signed-out refresh has no SDK side effect', () async {
    expect(
      await refreshAccountSession(const UnavailableAccountGateway()),
      AccountRefreshOutcome.unavailable,
    );
    final account = RefreshAccount()..identity = null;
    addTearDown(account.changes.close);
    expect(await refreshAccountSession(account), AccountRefreshOutcome.ended);
    expect(account.calls, 0);
  });

  testWidgets(
    'terminal refresh shows ended sign-in instead of connection advice',
    (tester) async {
      final account = await show(tester);
      account.operation = () async {
        account.emit(null);
        throw StateError('private provider detail');
      };
      await tester.tap(find.byKey(const ValueKey('account-refresh')));
      await tester.pumpAndSettle();
      const ended =
          'Your sign-in has ended. Sign in again. Local trips remain on this device.';
      await tester.scrollUntilVisible(
        find.text(ended),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(ended), findsOneWidget);
      expect(find.text('Sign in or create an account'), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsNothing);
      expect(find.textContaining('private provider detail'), findsNothing);
    },
  );

  testWidgets(
    'retained session failure keeps Signed in and gives neutral retry',
    (tester) async {
      final account = await show(tester);
      account.operation = () async =>
          throw StateError('private provider detail');
      await tester.tap(find.byKey(const ValueKey('account-refresh')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Could not refresh sign-in. Try again.'),
        200,
      );
      expect(account.currentIdentity, original);
      expect(find.text('Signed in'), findsOneWidget);
      expect(
        find.text('Could not refresh sign-in. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Check your connection'), findsNothing);
      expect(find.textContaining('private provider detail'), findsNothing);
    },
  );

  testWidgets(
    'stale refresh cannot claim success or failure for the replacement account',
    (tester) async {
      final account = await show(tester);
      final gate = Completer<void>();
      account.operation = () => gate.future;
      await tester.tap(find.byKey(const ValueKey('account-refresh')));
      await tester.pump();
      account.emit(other);
      gate.complete();
      await tester.pumpAndSettle();
      expect(account.currentIdentity, other);
      expect(find.text('Sign-in refreshed on this device.'), findsNothing);
      expect(find.textContaining('Could not refresh sign-in'), findsNothing);
      expect(find.textContaining('Your sign-in has ended'), findsNothing);
    },
  );
}
