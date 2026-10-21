import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

import '../../tool/guardian_recipient_auth_loss_probe.dart';

const _owner = AccountIdentity(
  userId: '11111111-1111-4111-8111-111111111111',
  email: 'private@example.invalid',
);
const _other = AccountIdentity(
  userId: '22222222-2222-4222-8222-222222222222',
  email: null,
);
const _receipt = GuardianRecipientLocalStatus(
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
);

final class _Account implements AccountGateway {
  AccountIdentity? identity = _owner;
  final changes = StreamController<AccountIdentity?>.broadcast(sync: true);
  int signOuts = 0;
  Completer<void>? signOutGate;
  bool failSignOut = false;
  void emit(AccountIdentity? value) {
    identity = value;
    changes.add(value);
  }

  @override
  bool get isAvailable => true;
  @override
  AccountIdentity? get currentIdentity => identity;
  @override
  Stream<AccountIdentity?> get identityChanges => changes.stream;
  @override
  Future<void> refreshSession() async => throw UnimplementedError();
  @override
  Future<void> sendSignInLink(String email) async => throw UnimplementedError();
  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutGate != null) await signOutGate!.future;
    if (failSignOut) throw StateError('private diagnostic must not be shown');
    emit(null);
  }
}

// In-memory model of native journal capture, not a native reliability proof.
final class _Native implements GuardianOwnerPort, GuardianDriverStatusPort {
  GuardianRecipientLocalStatus? receipt = _receipt;
  final pending = <GuardianRecipientLocalStatus>[];
  GuardianDriverStatus driver = const GuardianDriverStatus(
    GuardianDriverState.disabled,
    null,
  );
  String? bound;
  int calls = 0;
  bool failCleanup = false;
  void Function()? onRead;

  @override
  Future<void> bindOwner(String? ownerId) async {
    calls++;
    if (ownerId != _owner.userId && receipt != null) {
      pending.add(receipt!);
      receipt = null;
    }
    if (ownerId == null && failCleanup) throw StateError('local failure');
    bound = ownerId;
  }

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId) async {
    calls++;
    if (ownerId != bound) throw StateError('owner must be bound before reads');
    return receipt;
  }

  @override
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(
    String ownerId,
  ) async {
    calls++;
    if (ownerId != bound) throw StateError('owner must be bound before reads');
    return ownerId == _owner.userId ? List.of(pending) : [];
  }

  @override
  Future<GuardianDriverStatus> read(String owner) async {
    calls++;
    if (owner != bound) throw StateError('owner must be bound before reads');
    onRead?.call();
    return driver;
  }

  @override
  Future<void> recordRegistrationAttempt(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async => throw UnimplementedError();
  @override
  Future<void> confirmPendingRevoke(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {
    expect(ownerId, _owner.userId);
    pending.remove(status);
  }

  @override
  Future<void> disableConfirmedRecipient(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async => throw UnimplementedError();
}

final class _Server implements GuardianDeviceRevoker {
  bool rowPresent = true;
  int revocations = 0;
  @override
  Future<void> revoke(String owner, String device, String generation) async {
    expect(
      (owner, device, generation),
      (_owner.userId, _receipt.deviceId, _receipt.generation),
    );
    rowPresent = false;
    revocations++;
  }
}

void main() {
  late _Account account;
  late _Native native;
  final probes = <RecipientAuthLossProbe>[];
  setUp(() {
    account = _Account();
    native = _Native();
  });
  tearDown(() async {
    for (final probe in probes) {
      await probe.dispose();
    }
    probes.clear();
    await account.changes.close();
  });

  Future<RecipientAuthLossProbe> prepare({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final result = await RecipientAuthLossProbe.prepare(
      debugBuild: true,
      enabled: true,
      projectUrl: 'https://ksydjfcyzdtpbigskahm.supabase.co',
      initialize: () async => account,
      port: native,
      driver: native,
      timeout: timeout,
    );
    expect(result, isNotNull);
    probes.add(result!);
    return result;
  }

  test(
    'release, default-off and other-project paths never initialize Auth',
    () async {
      for (final config in [
        (false, true, 'https://ksydjfcyzdtpbigskahm.supabase.co'),
        (true, false, 'https://ksydjfcyzdtpbigskahm.supabase.co'),
        (true, true, 'https://another-project.supabase.co'),
      ]) {
        final result = await RecipientAuthLossProbe.prepare(
          debugBuild: config.$1,
          enabled: config.$2,
          projectUrl: config.$3,
          initialize: () async => throw StateError('must not initialize'),
          port: native,
          driver: native,
        );
        expect(result, isNull);
      }
      expect(native.calls, 0);
      expect(account.signOuts, 0);
    },
  );

  test(
    'missing Auth, receipt, existing journal or active driver deny preparation',
    () async {
      for (final condition in ['auth', 'receipt', 'journal', 'driver']) {
        account.identity = condition == 'auth' ? null : _owner;
        native.receipt = condition == 'receipt' ? null : _receipt;
        native.pending.clear();
        if (condition == 'journal') native.pending.add(_receipt);
        native.driver = GuardianDriverStatus(
          condition == 'driver'
              ? GuardianDriverState.waitingForTrip
              : GuardianDriverState.disabled,
          condition == 'driver'
              ? DateTime.now().add(const Duration(hours: 1))
              : null,
        );
        expect(
          await RecipientAuthLossProbe.prepare(
            debugBuild: true,
            enabled: true,
            projectUrl: 'https://ksydjfcyzdtpbigskahm.supabase.co',
            initialize: () async => account,
            port: native,
            driver: native,
          ),
          isNull,
        );
        if (condition == 'journal') expect(native.pending, [_receipt]);
      }
      expect(account.signOuts, 0);
      expect(native.bound, _owner.userId);
    },
  );

  test(
    'loss captures journal without server revoke; normal rebind reconciles',
    () async {
      final server = _Server();
      final probe = await prepare();
      await probe.runOnce();
      expect(probe.stage, AuthLossProbeStage.complete);
      expect(account.currentIdentity, isNull);
      expect(native.bound, isNull);
      expect(native.receipt, isNull);
      expect(native.pending, [_receipt]);
      expect(server.rowPresent, isTrue);
      expect(server.revocations, 0);
      await probe.dispose();
      probes.remove(probe);

      account.emit(_owner);
      final ordinary = GuardianBoundAccountGateway(
        account,
        native,
        deviceRevoker: server,
      );
      try {
        expect(await ordinary.ensureCurrentOwnerBound(), isTrue);
        expect(server.revocations, 1);
        expect(server.rowPresent, isFalse);
        expect(native.pending, isEmpty);
        expect(native.receipt, isNull); // Sign-in cannot register the receiver.
      } finally {
        await ordinary.dispose();
      }
    },
  );

  test('concurrent taps and later retries cannot sign out twice', () async {
    final probe = await prepare();
    account.signOutGate = Completer<void>();
    final first = probe.runOnce();
    await probe.runOnce();
    account.signOutGate!.complete();
    await first;
    await probe.runOnce();
    expect(probe.stage, AuthLossProbeStage.complete);
    expect(account.signOuts, 1);
  });

  test(
    'account replacement while checking driver denies raw sign-out',
    () async {
      final probe = await prepare();
      native.onRead = () => account.emit(_other);
      await probe.runOnce();
      expect(probe.stage, AuthLossProbeStage.blocked);
      expect(account.signOuts, 0);
      expect(account.currentIdentity, _other);
    },
  );

  test(
    'changed receipt or active driver after preparation blocks action',
    () async {
      final probe = await prepare();
      native.receipt = null;
      await probe.runOnce();
      expect(probe.stage, AuthLossProbeStage.blocked);
      expect(account.signOuts, 0);
      await probe.dispose();
      probes.remove(probe);
      native.receipt = _receipt;
      final second = await prepare();
      native.driver = GuardianDriverStatus(
        GuardianDriverState.waitingForTrip,
        DateTime.now().add(const Duration(hours: 1)),
      );
      await second.runOnce();
      expect(second.stage, AuthLossProbeStage.blocked);
      expect(account.signOuts, 0);
    },
  );

  test('SDK failure remains uncertain and is never retried', () async {
    final probe = await prepare();
    account.failSignOut = true;
    await probe.runOnce();
    expect(probe.stage, AuthLossProbeStage.uncertain);
    await probe.runOnce();
    expect(account.signOuts, 1);
    expect(account.currentIdentity, _owner);
  });

  test(
    'timeout retains observer for late SDK loss and native journal capture',
    () async {
      final probe = await prepare(timeout: const Duration(milliseconds: 20));
      account.signOutGate = Completer<void>();
      await probe.runOnce();
      expect(probe.stage, AuthLossProbeStage.uncertain);
      account.signOutGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(native.receipt, isNull);
      expect(native.pending, [_receipt]);
      await probe.runOnce();
      expect(account.signOuts, 1);
      expect(probe.stage, AuthLossProbeStage.uncertain);
    },
  );

  test('native cleanup failure cannot be reported as complete', () async {
    final probe = await prepare();
    native.failCleanup = true;
    await probe.runOnce();
    expect(probe.stage, AuthLossProbeStage.uncertain);
    expect(native.pending, [_receipt]);
    expect(account.signOuts, 1);
  });

  testWidgets('UI exposes fixed stages and one disabled action after failure', (
    tester,
  ) async {
    final probe = await prepare();
    account.failSignOut = true;
    await tester.pumpWidget(
      MaterialApp(home: AuthLossProbeScreen(probe: probe)),
    );
    await tester.tap(find.text('Simulate local sign-in loss once'));
    await tester.pumpAndSettle();
    expect(find.text(AuthLossProbeStage.uncertain.label), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((e) => e.data)
        .join();
    for (final private in [
      _owner.email!,
      _owner.userId,
      _receipt.deviceId,
      'private diagnostic',
    ]) {
      expect(text, isNot(contains(private)));
    }
  });
}
