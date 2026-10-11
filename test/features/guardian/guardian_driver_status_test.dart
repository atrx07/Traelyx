import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';
import 'package:traelyx/features/guardian/guardian_driver_status_panel.dart';

const owner = '11111111-1111-4111-8111-111111111111';

final class Account implements AccountGateway {
  String? id = owner;
  final changes = StreamController<AccountIdentity?>.broadcast();
  @override
  AccountIdentity? get currentIdentity =>
      id == null ? null : AccountIdentity(userId: id!, email: null);
  @override
  Stream<AccountIdentity?> get identityChanges => changes.stream;
  @override
  bool get isAvailable => true;
  @override
  Future<void> refreshSession() async => throw StateError('No network allowed');
  @override
  Future<void> sendSignInLink(String email) async =>
      throw StateError('No network allowed');
  @override
  Future<void> signOut() async =>
      throw StateError('No account mutation allowed');
}

final class Port implements GuardianDriverStatusPort {
  int calls = 0;
  Completer<GuardianDriverStatus>? pending;
  bool fail = false;
  @override
  Future<GuardianDriverStatus> read(String owner) async {
    calls++;
    if (fail) throw StateError('Synthetic vault failure');
    return pending?.future ??
        const GuardianDriverStatus(GuardianDriverState.disabled, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('wire states enforce exact shape and bounded consistent consent', () {
    final now = DateTime.utc(2026, 10, 11);
    for (final state in GuardianDriverState.values) {
      final raw = {
        'state': state.wire,
        'expiresEpochMillis': state == GuardianDriverState.disabled
            ? null
            : now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      };
      expect(GuardianDriverStatus.parse(raw, now).state, state);
    }
    expect(
      GuardianDriverStatus.parse({
        'state': 'evidence_unavailable',
        'expiresEpochMillis': null,
      }, now).expiresAt,
      isNull,
    );
    for (final raw in [
      {'state': 'monitoring_experimental', 'expiresEpochMillis': null},
      {
        'state': 'disabled',
        'expiresEpochMillis': now.millisecondsSinceEpoch + 1,
      },
      {
        'state': 'monitoring_experimental',
        'expiresEpochMillis': now.millisecondsSinceEpoch,
      },
      {
        'state': 'calibrating',
        'expiresEpochMillis': now
            .add(const Duration(hours: 9))
            .millisecondsSinceEpoch,
      },
      {'state': 'unknown', 'expiresEpochMillis': null},
      {
        'state': 'disabled',
        'expiresEpochMillis': null,
        'credential': 'rejected',
      },
      {'state': 'calibrating', 'expiresEpochMillis': 'not an integer'},
    ]) {
      expect(() => GuardianDriverStatus.parse(raw, now), throwsFormatException);
    }
  });

  test(
    'channel uses only owner and local status method; bad owner never crosses',
    () async {
      const channel = MethodChannel(
        'io.github.atrx07.traelyx/guardian_activation',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {'state': 'disabled', 'expiresEpochMillis': null};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const port = MethodChannelGuardianDriverStatusPort();
      expect((await port.read(owner)).state, GuardianDriverState.disabled);
      expect(calls.single.method, 'driverStatus');
      expect(calls.single.arguments, {'ownerId': owner});
      await expectLater(port.read('invalid'), throwsFormatException);
      expect(calls.length, 1);
    },
  );

  test(
    'identity change and foreground clearing reject late observations',
    () async {
      final account = Account();
      final port = Port();
      final controller = GuardianDriverStatusController(owner, account, port);
      addTearDown(controller.dispose);
      addTearDown(account.changes.close);
      for (final changeAccount in [false, true]) {
        port.pending = Completer<GuardianDriverStatus>();
        final check = controller.check();
        if (changeAccount) {
          account.id = null;
          account.changes.add(null);
          await Future<void>.delayed(Duration.zero);
        } else {
          controller.clear();
        }
        port.pending!.complete(
          const GuardianDriverStatus(
            GuardianDriverState.monitoringExperimental,
            null,
          ),
        );
        await check;
        expect(controller.state.status, isNull);
        expect(controller.state.busy, isFalse);
      }
      await controller.check();
      expect(port.calls, 2); // Absent owner causes no channel call.
    },
  );

  test(
    'failure clears previous status instead of claiming its old result',
    () async {
      final account = Account();
      final port = Port();
      final controller = GuardianDriverStatusController(owner, account, port);
      addTearDown(controller.dispose);
      addTearDown(account.changes.close);
      await controller.check();
      expect(controller.state.status, isNotNull);
      port.fail = true;
      await controller.check();
      expect(controller.state.status, isNull);
      expect(controller.state.notice, isNotNull);
    },
  );

  testWidgets(
    'timed-out local status never publishes a late monitoring reply',
    (tester) async {
      final account = Account();
      final port = Port()..pending = Completer<GuardianDriverStatus>();
      final controller = GuardianDriverStatusController(owner, account, port);
      addTearDown(controller.dispose);
      addTearDown(account.changes.close);
      unawaited(controller.check());
      await tester.pump(const Duration(seconds: 6));
      expect(controller.state.status, isNull);
      expect(controller.state.busy, isFalse);
      expect(controller.state.notice, isNotNull);
      port.pending!.complete(
        const GuardianDriverStatus(
          GuardianDriverState.monitoringExperimental,
          null,
        ),
      );
      await tester.pump();
      expect(controller.state.status, isNull);
    },
  );

  testWidgets('panel checks only on tap and clears after backgrounding', (
    tester,
  ) async {
    final account = Account();
    final port = Port();
    addTearDown(account.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(account),
          guardianDriverStatusPortProvider.overrideWithValue(port),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardianDriverStatusPanel(owner: owner),
            ),
          ),
        ),
      ),
    );
    expect(port.calls, 0);
    expect(find.textContaining('new driver review'), findsOneWidget);
    await tester.tap(find.text('Check driver state'));
    await tester.pumpAndSettle();
    expect(find.text('Driver monitoring is off'), findsOneWidget);
    expect(find.textContaining('Checked '), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GuardianDriverStatusPanel)),
    );
    expect(container.read(guardianDriverStatusProvider(owner)).status, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Driver monitoring is off'), findsNothing);
    expect(find.text('Driver state has not been checked.'), findsOneWidget);
    expect(port.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
