import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/guardian/guardian_alerts.dart';
import 'package:traelyx/features/guardian/guardian_inbox.dart';
import '../summary_sync/summary_sync_test.dart' show TestAccount, userA, userB;

const deliveryId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
Map<String, Object?> alertJson(DateTime now) => {
  'delivery_id': deliveryId,
  'kind': 'possible_crash',
  'rule_version': 1,
  'occurred_at': now
      .subtract(const Duration(minutes: 1))
      .toUtc()
      .toIso8601String(),
  'uncertainty': 'experimental_not_confirmed',
  'status': 'provider_accepted',
  'driver_display_name': 'Driver',
  'guardian_display_name': 'Guardian',
  'own_event': false,
};

class AlertFake implements GuardianAlertGateway {
  AlertFake(this.rows);
  List<GuardianAlert> rows;
  int reads = 0, opens = 0;
  bool permitted = true;
  Future<void> Function()? onRead, onOpen;
  @override
  Future<List<GuardianAlert>> load(String owner) async {
    reads++;
    await onRead?.call();
    return rows;
  }

  @override
  Future<bool> open(String owner, String delivery) async {
    opens++;
    await onOpen?.call();
    return permitted;
  }
}

void main() {
  test(
    'strict alert parser rejects unsupported, private and duplicate data',
    () {
      final raw = alertJson(DateTime.now());
      expect(
        GuardianAlert.parse([raw]).single.deliveryState,
        GuardianDeliveryState.providerAccepted,
      );
      for (final changed in [
        {...raw, 'latitude': 1},
        {...raw, 'rule_version': 2},
        {...raw, 'kind': 'confirmed_crash'},
        {...raw, 'status': 'revoked'},
        {...raw, 'uncertainty': 'confirmed'},
        {...raw, 'own_event': 'false'},
        {...raw, 'occurred_at': '2026-01-01T00:00:00'},
      ]) {
        expect(() => GuardianAlert.parse([changed]), throwsFormatException);
      }
      expect(() => GuardianAlert.parse([raw, raw]), throwsFormatException);
      expect(
        () => GuardianAlert.parse(List.filled(101, raw)),
        throwsFormatException,
      );
    },
  );
  test(
    'inbox inert on construction; explicit open rechecks access and records view',
    () async {
      final account = TestAccount();
      final fake = AlertFake(GuardianAlert.parse([alertJson(DateTime.now())]));
      final inbox = GuardianInbox(userA, fake, account);
      addTearDown(inbox.dispose);
      expect(fake.reads, 0);
      await inbox.reload();
      expect(fake.opens, 0);
      await inbox.open(inbox.state.alerts.single);
      expect(fake.reads, 2);
      expect(fake.opens, 1);
      expect(inbox.state.opened?.deliveryState, GuardianDeliveryState.viewed);
      expect(
        inbox.state.alerts.single.deliveryState,
        GuardianDeliveryState.viewed,
      );
    },
  );
  test('revocation between reload and open removes cached details', () async {
    final fake = AlertFake(GuardianAlert.parse([alertJson(DateTime.now())]));
    final inbox = GuardianInbox(userA, fake, TestAccount());
    addTearDown(inbox.dispose);
    await inbox.reload();
    final reviewed = inbox.state.alerts.single;
    fake.permitted = false;
    await inbox.open(reviewed);
    expect(inbox.state.opened, isNull);
    expect(inbox.state.alerts, isEmpty);
    expect(inbox.state.notice, contains('revoked'));
  });
  test(
    'background clear and account switch discard delayed responses',
    () async {
      final account = TestAccount();
      final fake = AlertFake(GuardianAlert.parse([alertJson(DateTime.now())]));
      final inbox = GuardianInbox(userA, fake, account);
      addTearDown(inbox.dispose);
      final pending = Completer<void>();
      fake.onRead = () => pending.future;
      final read = inbox.reload();
      inbox.clear();
      pending.complete();
      await read;
      expect(inbox.state.loaded, false);
      fake.onRead = () async {
        account.user = userB;
      };
      await inbox.reload();
      expect(inbox.state.alerts, isEmpty);
      expect(inbox.state.opened, isNull);
    },
  );
  test(
    'own events cannot acknowledge recipient view; expired rows excluded',
    () async {
      final now = DateTime.now();
      final fake = AlertFake(
        GuardianAlert.parse([
          {...alertJson(now), 'own_event': true},
        ]),
      );
      final inbox = GuardianInbox(userA, fake, TestAccount(), now: () => now);
      addTearDown(inbox.dispose);
      await inbox.reload();
      await inbox.open(inbox.state.alerts.single);
      expect(fake.opens, 0);
      fake.rows = GuardianAlert.parse([
        alertJson(now.subtract(const Duration(minutes: 10))),
      ]);
      await inbox.reload();
      expect(inbox.state.alerts, isEmpty);
    },
  );
  testWidgets(
    'large text inbox distinguishes receipt and opening; background clears',
    (tester) async {
      final fake = AlertFake(GuardianAlert.parse([alertJson(DateTime.now())]));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountGatewayProvider.overrideWithValue(TestAccount()),
            guardianAlertGatewayProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: GuardianInboxPanel(owner: userA),
                ),
              ),
            ),
          ),
        ),
      );
      expect(fake.reads, 0);
      await tester.tap(find.text('Reload alerts'));
      await tester.pumpAndSettle();
      expect(
        find.text(GuardianDeliveryState.providerAccepted.label),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Open alert'));
      await tester.tap(find.text('Open alert'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This is not confirmation'), findsOneWidget);
      expect(find.text(GuardianDeliveryState.viewed.label), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GuardianInboxPanel)),
      );
      expect(container.read(guardianInboxProvider(userA)).opened, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('This is not confirmation'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
