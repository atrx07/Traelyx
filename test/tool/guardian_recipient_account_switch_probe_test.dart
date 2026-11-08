import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

import '../../tool/guardian_recipient_account_switch_probe.dart';

const original = AccountIdentity(
  userId: '11111111-1111-4111-8111-111111111111',
  email: null,
);
const replacement = AccountIdentity(
  userId: '22222222-2222-4222-8222-222222222222',
  email: null,
);
const third = AccountIdentity(
  userId: '55555555-5555-4555-8555-555555555555',
  email: null,
);
const receipt = GuardianRecipientLocalStatus(
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
);

class FakeAccount implements AccountGateway {
  final changes = StreamController<AccountIdentity?>.broadcast(sync: true);
  AccountIdentity? identity = original;
  int requests = 0;
  String? address;
  Completer<void>? requestGate;
  bool failRequest = false;
  void emit(AccountIdentity? next) {
    identity = next;
    changes.add(next);
  }

  @override
  bool get isAvailable => true;
  @override
  AccountIdentity? get currentIdentity => identity;
  @override
  Stream<AccountIdentity?> get identityChanges => changes.stream;
  @override
  Future<void> sendSignInLink(String email) async {
    requests++;
    address = email;
    if (requestGate != null) await requestGate!.future;
    if (failRequest) throw StateError('private provider response');
  }

  @override
  Future<void> signOut() async => fail('Probe must not sign out');
  @override
  Future<void> refreshSession() async => fail('Probe must not force refresh');
}

// Models the native boundary's owner isolation and journal capture, not Android
// Keystore/provider reliability. Live checks inspect the real native boundary.
class FakeNative implements GuardianOwnerPort, GuardianDriverStatusPort {
  String? bound;
  GuardianRecipientLocalStatus? local = receipt;
  final journal = <GuardianRecipientLocalStatus>[];
  bool driverActive = false, failOtherBind = false;
  VoidCallback? onDriverRead;
  Completer<void>? replacementReadGate;
  @override
  Future<void> bindOwner(String? ownerId) async {
    if (ownerId != original.userId && local != null) {
      journal.add(local!);
      local = null;
    }
    if (ownerId != original.userId && failOtherBind) {
      throw StateError('provider failure');
    }
    bound = ownerId;
  }

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId) async {
    if (ownerId != bound) throw StateError('unbound read');
    if (ownerId == replacement.userId && replacementReadGate != null) {
      await replacementReadGate!.future;
    }
    return ownerId == original.userId ? local : null;
  }

  @override
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(
    String ownerId,
  ) async => ownerId == original.userId ? List.of(journal) : [];
  @override
  Future<GuardianDriverStatus> read(String ownerId) async {
    if (ownerId != bound) throw StateError('unbound driver');
    onDriverRead?.call();
    return GuardianDriverStatus(
      driverActive
          ? GuardianDriverState.waitingForTrip
          : GuardianDriverState.disabled,
      null,
    );
  }

  @override
  Future<void> recordRegistrationAttempt(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async => fail('No registration');
  @override
  Future<void> confirmPendingRevoke(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async => fail('No server confirmation in probe');
  @override
  Future<void> disableConfirmedRecipient(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async => fail('No explicit recipient withdrawal');
}

void main() {
  late FakeAccount account;
  late FakeNative native;
  final probes = <RecipientAccountSwitchProbe>[];
  setUp(() {
    account = FakeAccount();
    native = FakeNative();
  });
  tearDown(() async {
    for (final probe in probes) {
      await probe.close();
    }
    probes.clear();
    await account.changes.close();
  });
  Future<RecipientAccountSwitchProbe?> prepare({
    bool debug = true,
    bool enabled = true,
    String url = 'https://ksydjfcyzdtpbigskahm.supabase.co',
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final probe = await RecipientAccountSwitchProbe.prepare(
      debugBuild: debug,
      enabled: enabled,
      projectUrl: url,
      initialize: () async => account,
      port: native,
      driver: native,
      timeout: timeout,
    );
    if (probe != null) probes.add(probe);
    return probe;
  }

  Future<void> settle() async {
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('closed configurations never initialize Auth', () async {
    var initialized = 0;
    for (final config in [
      (false, true, 'https://ksydjfcyzdtpbigskahm.supabase.co'),
      (true, false, 'https://ksydjfcyzdtpbigskahm.supabase.co'),
      (true, true, 'https://other.invalid'),
    ]) {
      expect(
        await RecipientAccountSwitchProbe.prepare(
          debugBuild: config.$1,
          enabled: config.$2,
          projectUrl: config.$3,
          initialize: () async {
            initialized++;
            return account;
          },
          port: native,
          driver: native,
        ),
        isNull,
      );
    }
    expect(initialized, 0);
  });

  test(
    'missing sign-in, receipt, active driver or pending cleanup closes preparation',
    () async {
      account.identity = null;
      expect(await prepare(), isNull);
      account.identity = original;
      native.local = null;
      expect(await prepare(), isNull);
      native.local = receipt;
      native.driverActive = true;
      expect(await prepare(), isNull);
      native.driverActive = false;
      native.journal.add(receipt);
      expect(await prepare(), isNull);
      expect(account.requests, 0);
    },
  );

  test(
    'requests once without clearing existing owner before callback',
    () async {
      final probe = (await prepare())!;
      final gate = Completer<void>();
      account.requestGate = gate;
      final first = probe.requestOnce(' next@example.invalid ');
      await settle();
      await probe.requestOnce('again@example.invalid');
      expect(account.requests, 1);
      expect(account.address, 'next@example.invalid');
      expect(account.currentIdentity, original);
      expect(native.local, receipt);
      gate.complete();
      await first;
      expect(probe.stage, AccountSwitchProbeStage.waiting);
    },
  );

  test(
    'real owner event removes local authority and preserves original cleanup ticket',
    () async {
      final probe = (await prepare())!;
      await probe.requestOnce('next@example.invalid');
      account.emit(replacement);
      await settle();
      expect(probe.stage, AccountSwitchProbeStage.complete);
      expect(native.bound, replacement.userId);
      expect(native.local, isNull);
      expect(native.journal, [receipt]);
      expect(await native.pendingRevokes(replacement.userId), isEmpty);
      expect(account.currentIdentity, replacement);
      expect(account.requests, 1);
    },
  );

  test('same-owner refresh cannot count as account replacement', () async {
    final probe = (await prepare())!;
    await probe.requestOnce('next@example.invalid');
    account.emit(original);
    await settle();
    expect(probe.stage, AccountSwitchProbeStage.waiting);
    expect(native.local, receipt);
    expect(native.journal, isEmpty);
  });

  test(
    'owner or receipt change during preflight blocks email request',
    () async {
      final probe = (await prepare())!;
      native.onDriverRead = () => account.emit(replacement);
      await probe.requestOnce('next@example.invalid');
      expect(account.requests, 0);
      expect(probe.stage, AccountSwitchProbeStage.blocked);
      await probe.requestOnce('again@example.invalid');
      expect(account.requests, 0);
    },
  );

  test('changed receipt generation blocks email request', () async {
    final probe = (await prepare())!;
    native.local = const GuardianRecipientLocalStatus(
      '33333333-3333-4333-8333-333333333333',
      '66666666-6666-4666-8666-666666666666',
    );
    await probe.requestOnce('next@example.invalid');
    expect(account.requests, 0);
    expect(probe.stage, AccountSwitchProbeStage.blocked);
  });

  test('empty input spends the action without sending an email', () async {
    final probe = (await prepare())!;
    await probe.requestOnce(' ');
    await probe.requestOnce('next@example.invalid');
    expect(probe.stage, AccountSwitchProbeStage.blocked);
    expect(account.requests, 0);
    expect(native.local, receipt);
  });

  test('driver becoming active after preparation blocks the request', () async {
    final probe = (await prepare())!;
    native.driverActive = true;
    await probe.requestOnce('next@example.invalid');
    expect(account.requests, 0);
    expect(probe.stage, AccountSwitchProbeStage.blocked);
  });

  test(
    'Auth loss is uncertain while the production cleanup observer survives',
    () async {
      final probe = (await prepare())!;
      await probe.requestOnce('next@example.invalid');
      account.emit(null);
      await settle();
      expect(probe.stage, AccountSwitchProbeStage.uncertain);
      expect(native.local, isNull);
      expect(native.journal, [receipt]);
      expect(account.requests, 1);
    },
  );

  test(
    'callback arriving before request completion is still checked',
    () async {
      final probe = (await prepare())!;
      final gate = Completer<void>();
      account.requestGate = gate;
      final request = probe.requestOnce('next@example.invalid');
      await settle();
      account.emit(replacement);
      await settle();
      gate.complete();
      await request;
      await settle();
      expect(probe.stage, AccountSwitchProbeStage.complete);
      expect(native.journal, [receipt]);
    },
  );

  test('provider failure is uncertain and does not retry', () async {
    final probe = (await prepare())!;
    account.failRequest = true;
    await probe.requestOnce('next@example.invalid');
    expect(probe.stage, AccountSwitchProbeStage.uncertain);
    await probe.requestOnce('again@example.invalid');
    expect(account.requests, 1);
  });

  test('native cleanup failure cannot report complete', () async {
    final probe = (await prepare())!;
    await probe.requestOnce('next@example.invalid');
    native.failOtherBind = true;
    account.emit(replacement);
    await settle();
    expect(probe.stage, AccountSwitchProbeStage.uncertain);
    expect(native.journal, [receipt]);
  });

  test(
    'Auth loss or another replacement during verification stays uncertain',
    () async {
      final probe = (await prepare())!;
      await probe.requestOnce('next@example.invalid');
      final gate = Completer<void>();
      native.replacementReadGate = gate;
      account.emit(replacement);
      await settle();
      account.emit(third);
      gate.complete();
      await settle();
      expect(probe.stage, AccountSwitchProbeStage.uncertain);
      expect(account.requests, 1);
    },
  );

  test(
    'late request after timeout cannot report successful replacement',
    () async {
      final probe = (await prepare(timeout: const Duration(milliseconds: 20)))!;
      final gate = Completer<void>();
      account.requestGate = gate;
      await probe.requestOnce('next@example.invalid');
      expect(probe.stage, AccountSwitchProbeStage.uncertain);
      account.emit(replacement);
      gate.complete();
      await settle();
      expect(probe.stage, AccountSwitchProbeStage.uncertain);
      expect(native.local, isNull); // Production owner observer remains alive.
      expect(native.journal, [receipt]);
    },
  );

  testWidgets(
    'request UI clears entered email and exposes only fixed outcome text',
    (tester) async {
      final probe = (await prepare())!;
      await tester.pumpWidget(
        MaterialApp(home: AccountSwitchProbeScreen(probe: probe)),
      );
      await tester.enterText(find.byType(TextField), 'next@example.invalid');
      await tester.tap(find.text('Request one sign-in link'));
      await tester.pumpAndSettle();
      expect(find.text('next@example.invalid'), findsNothing);
      expect(find.text(AccountSwitchProbeStage.waiting.label), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text(original.userId), findsNothing);
      expect(find.text(receipt.deviceId), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
