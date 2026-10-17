import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/guardian/guardian_driver_controls.dart';
import 'package:traelyx/features/guardian/guardian_driver_controls_panel.dart';
import 'package:traelyx/features/guardian/guardian_pending_alerts.dart';
import 'guardian_driver_activation_test.dart'
    show TestAccount, ownerA, ownerB, activation;
import 'guardian_driver_controls_test.dart' show Controls;

Map<String, Object?> wire({
  String state = 'cancellable',
  bool canCancel = true,
}) => {
  'activationId': activation,
  'eventId': ownerB,
  'kind': 'possible_crash',
  'state': state,
  'canCancel': canCancel,
  'cancellationReadyInMillis': 30000,
};

class Port implements GuardianPendingAlertsPort {
  int reads = 0, cancels = 0;
  bool result = true, fail = false;
  Completer<List<GuardianLocalAlert>>? reply;
  Completer<bool>? cancellation;
  List<GuardianLocalAlert> alerts = GuardianLocalAlert.parse([wire()]);
  @override
  Future<List<GuardianLocalAlert>> read(String owner) async {
    reads++;
    if (fail) throw StateError('private diagnostic');
    return reply?.future ?? alerts;
  }

  @override
  Future<bool> cancel(String owner, GuardianLocalAlert alert) async {
    cancels++;
    if (fail) throw StateError('private diagnostic');
    return cancellation?.future ?? result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.github.atrx07.traelyx/guardian_activation');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'parser permits only bounded metadata and rejects drift and impossible cancellation',
    () {
      for (final invalid in [
        null,
        <String, Object?>{},
        List.filled(17, wire()),
        [wire(), wire()],
        [wire()..['credential'] = 'forbidden'],
        [wire()..['eventId'] = 'wrong'],
        [wire()..['kind'] = 'confirmed_crash'],
        [wire(state: 'backend_accepted')],
        [wire()..['cancellationReadyInMillis'] = 30001],
        [wire()..['canCancel'] = 1],
        [wire()..['state'] = 'delivered'],
      ]) {
        expect(() => GuardianLocalAlert.parse(invalid), throwsFormatException);
      }
      final alert = GuardianLocalAlert.parse([wire()]).single;
      expect(alert.toString(), isNot(contains(activation)));
      expect(alert.status, contains('Waiting locally'));
      expect(
        GuardianLocalAlert.parse([
          wire(state: 'backend_accepted', canCancel: false),
        ]).single.status,
        contains('delivery is not confirmed'),
      );
    },
  );
  test(
    'channel sends exact local identity and refuses non-Boolean cancellation replies',
    () async {
      final calls = <MethodCall>[];
      Object? reply = [wire()];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return reply;
          });
      const port = MethodChannelGuardianPendingAlertsPort();
      final alert = (await port.read(ownerA)).single;
      expect(calls.single.method, 'pendingAlerts');
      expect(calls.single.arguments, {'ownerId': ownerA});
      reply = true;
      expect(await port.cancel(ownerA, alert), isTrue);
      expect(calls.last.arguments, {
        'ownerId': ownerA,
        'activationId': activation,
        'eventId': ownerB,
      });
      reply = {'cancelled': true};
      await expectLater(port.cancel(ownerA, alert), throwsFormatException);
      await expectLater(port.read('invalid'), throwsFormatException);
    },
  );
  test(
    'controller is idle until explicit check and reports only persisted local cancellation',
    () async {
      final account = TestAccount(), port = Port();
      final c = GuardianPendingAlertsController(ownerA, account, port);
      addTearDown(c.dispose);
      addTearDown(account.changes.close);
      expect(port.reads + port.cancels, 0);
      await c.check();
      expect(c.state.alerts.length, 1);
      await c.cancel(c.state.alerts.single);
      expect(port.cancels, 1);
      expect(port.reads, 1);
      expect(c.state.alerts, isEmpty);
      expect(
        c.state.notice,
        contains('cancelled locally before sending began'),
      );
    },
  );
  test(
    'false or failed cancel cannot claim success or display raw diagnostics',
    () async {
      for (final fail in [false, true]) {
        final account = TestAccount(), port = Port()..result = false;
        final c = GuardianPendingAlertsController(ownerA, account, port);
        await c.check();
        port.fail = fail;
        await c.cancel(c.state.alerts.single);
        expect(c.state.notice, contains('attempt may already have begun'));
        expect(c.state.notice, isNot(contains('private diagnostic')));
        c.dispose();
        await account.changes.close();
      }
    },
  );
  test(
    'background owner change and disposal discard late reads or cancellation replies',
    () async {
      for (final cancel in [false, true]) {
        final account = TestAccount(), port = Port();
        final c = GuardianPendingAlertsController(ownerA, account, port);
        if (cancel) await c.check();
        final item = cancel ? c.state.alerts.single : null;
        if (cancel) {
          port.cancellation = Completer<bool>();
        } else {
          port.reply = Completer<List<GuardianLocalAlert>>();
        }
        final work = cancel ? c.cancel(item!) : c.check();
        c.clear();
        account.change(ownerB);
        if (cancel) {
          port.cancellation!.complete(true);
        } else {
          port.reply!.complete(port.alerts);
        }
        await work;
        expect(c.state.alerts, isEmpty);
        expect(c.state.notice, isNull);
        await c.check();
        expect(port.reads, 1);
        c.dispose();
        await account.changes.close();
      }
    },
  );
  test(
    'noncancelable or unobserved item cannot invoke native cancellation',
    () async {
      final account = TestAccount(), port = Port();
      final c = GuardianPendingAlertsController(ownerA, account, port);
      addTearDown(c.dispose);
      addTearDown(account.changes.close);
      await c.cancel(port.alerts.single);
      expect(port.cancels, 0);
      port.alerts = GuardianLocalAlert.parse([
        wire(state: 'queued', canCancel: false),
      ]);
      await c.check();
      await c.cancel(c.state.alerts.single);
      expect(port.cancels, 0);
    },
  );
  testWidgets(
    'pilot local controls are explicit, readable at large text, and clear in background',
    (tester) async {
      final account = TestAccount(), port = Port();
      addTearDown(account.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountGatewayProvider.overrideWithValue(account),
            guardianDriverPilotProvider.overrideWithValue(true),
            guardianDriverControlsProvider.overrideWithValue(Controls()),
            guardianPendingAlertsPortProvider.overrideWithValue(port),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: GuardianDriverControlsPanel(owner: ownerA),
                ),
              ),
            ),
          ),
        ),
      );
      expect(port.reads + port.cancels, 0);
      await tester.ensureVisible(find.text('Check pending alerts'));
      await tester.tap(find.text('Check pending alerts'));
      await tester.pumpAndSettle();
      expect(
        find.text('Possible-crash evidence (experimental)'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cancel alert'));
      await tester.tap(find.text('Cancel alert'));
      await tester.pumpAndSettle();
      expect(port.cancels, 1);
      expect(find.textContaining('Alert cancelled locally'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('Alert cancelled locally'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
