import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';

const ownerA = AccountIdentity(
  userId: '11111111-1111-4111-8111-111111111111',
  email: null,
);
const ownerB = AccountIdentity(
  userId: '22222222-2222-4222-8222-222222222222',
  email: null,
);

final class FakeAccount implements AccountGateway {
  FakeAccount(this._identity);
  final _changes = StreamController<AccountIdentity?>.broadcast();
  AccountIdentity? _identity;
  int signOutCount = 0;

  void emit(AccountIdentity? identity) {
    _identity = identity;
    _changes.add(identity);
  }

  Future<void> close() => _changes.close();

  @override
  bool get isAvailable => true;
  @override
  AccountIdentity? get currentIdentity => _identity;
  @override
  Stream<AccountIdentity?> get identityChanges => _changes.stream;
  @override
  Future<void> sendSignInLink(String email) async {}
  @override
  Future<void> refreshSession() async {}
  @override
  Future<void> signOut() async {
    signOutCount++;
    emit(null);
  }
}

final class FakeOwnerPort implements GuardianOwnerPort {
  final calls = <String?>[];
  Completer<void>? nextCall;
  bool failCleanup = false;

  @override
  Future<void> bindOwner(String? ownerId) async {
    calls.add(ownerId);
    if (ownerId == null && failCleanup) throw StateError('vault unavailable');
    final blocked = nextCall;
    nextCall = null;
    await blocked?.future;
  }
}

void main() {
  test(
    'startup and rapid account changes bind only the latest queued owner',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort();
      final first = Completer<void>();
      port.nextCall = first;
      final bound = GuardianBoundAccountGateway(account, port);
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });

      await Future<void>.delayed(Duration.zero);
      expect(port.calls, [ownerA.userId]);
      account.emit(ownerB);
      account.emit(null);
      first.complete();
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      expect(port.calls.first, ownerA.userId);
      expect(port.calls.skip(1), everyElement(isNull));
      expect(port.calls.last, null);
    },
  );

  test('sign-out waits for local cleanup before clearing Auth', () async {
    final account = FakeAccount(ownerA);
    final port = FakeOwnerPort();
    final bound = GuardianBoundAccountGateway(account, port);
    addTearDown(() async {
      await bound.dispose();
      await account.close();
    });
    expect(await bound.ensureCurrentOwnerBound(), isTrue);

    final cleanup = Completer<void>();
    port.nextCall = cleanup;
    final signingOut = bound.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(account.signOutCount, 0);
    expect(port.calls.last, null);
    cleanup.complete();
    await signingOut;
    expect(account.signOutCount, 1);
    expect(bound.currentIdentity, null);
    expect(await bound.ensureCurrentOwnerBound(), isTrue);
  });

  test('failed local cleanup blocks sign-out and later owner rebind', () async {
    final account = FakeAccount(ownerA);
    final port = FakeOwnerPort();
    final bound = GuardianBoundAccountGateway(account, port);
    addTearDown(() async {
      await bound.dispose();
      await account.close();
    });
    expect(await bound.ensureCurrentOwnerBound(), isTrue);

    port.failCleanup = true;
    await expectLater(
      bound.signOut(),
      throwsA(isA<GuardianLocalCleanupException>()),
    );
    expect(account.signOutCount, 0);
    account.emit(ownerA);
    await Future<void>.delayed(Duration.zero);
    expect(port.calls.last, null);
    expect(await bound.ensureCurrentOwnerBound(), isFalse);
  });
}
