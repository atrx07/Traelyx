import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';

const ownerA = '11111111-1111-4111-8111-111111111111';
const ownerB = '22222222-2222-4222-8222-222222222222';
const activation = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const capability =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

GuardianDriverConsent reviewed(
  String axis, {
  DateTime? at,
  bool mounted = true,
}) => GuardianDriverConsent(
  ownerId: ownerA,
  forwardAxis: axis,
  rigidMountConfirmed: mounted,
  safetyLimitsAcknowledged: true,
  recipientSharingAcknowledged: true,
  reviewedAt: at ?? DateTime.now().toUtc(),
);

final class TestAccount implements AccountGateway {
  final changes = StreamController<AccountIdentity?>.broadcast();
  AccountIdentity? identity = const AccountIdentity(
    userId: ownerA,
    email: null,
  );

  void change(String owner) {
    identity = AccountIdentity(userId: owner, email: null);
    changes.add(identity);
  }

  @override
  bool get isAvailable => true;
  @override
  AccountIdentity? get currentIdentity => identity;
  @override
  Stream<AccountIdentity?> get identityChanges => changes.stream;
  @override
  Future<void> refreshSession() async {}
  @override
  Future<void> sendSignInLink(String email) async {}
  @override
  Future<void> signOut() async {}
}

final class OwnerPort implements GuardianOwnerPort {
  final owners = <String?>[];
  @override
  Future<void> bindOwner(String? ownerId) async => owners.add(ownerId);

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId) async =>
      null;
}

final class NativePort implements GuardianNativeActivationPort {
  NativePort(this.events);
  final List<String> events;
  int aborts = 0, disables = 0, commits = 0;
  Future<void> Function()? beforeCommit;

  @override
  Future<GuardianActivationDraft> begin(String owner, String axis) async {
    events.add('begin');
    return GuardianActivationDraft(
      ownerId: owner,
      activationId: activation,
      credential: capability,
      forwardAxis: axis,
    );
  }

  @override
  Future<DateTime> commit(
    String owner,
    String activationId,
    DateTime expiry,
  ) async {
    events.add('commit');
    commits++;
    await beforeCommit?.call();
    return expiry;
  }

  @override
  Future<void> abort(String owner, String activationId) async {
    events.add('abort');
    aborts++;
  }

  @override
  Future<void> disable(String owner) async {
    events.add('disable');
    disables++;
  }
}

final class Server implements GuardianDriverSessionGateway {
  Server(this.events);
  final List<String> events;
  Future<GuardianSessionConfirmation> Function()? onActivate;
  int revokes = 0;

  @override
  Future<GuardianSessionConfirmation> activate(
    GuardianActivationDraft draft,
    DateTime preparedAt,
  ) async {
    events.add('server');
    expect(draft.ownerId, ownerA);
    expect(draft.credential, capability);
    return await onActivate?.call() ??
        GuardianSessionConfirmation(
          activation,
          preparedAt.add(const Duration(hours: 7)),
        );
  }

  @override
  Future<void> revoke(String owner, String activationId) async {
    events.add('revoke');
    revokes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.github.atrx07.traelyx/guardian_activation');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'native bridge exchanges only reviewed fields and redacted status',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            switch (call.method) {
              case 'begin':
                expect(call.arguments, {
                  'ownerId': ownerA,
                  'forwardAxis': '+y',
                  'rigidMountConfirmed': true,
                });
                return {
                  'ownerId': ownerA,
                  'activationId': activation,
                  'credential': capability,
                  'forwardAxis': '+y',
                };
              case 'commit':
                final args = call.arguments as Map;
                expect(args.keys.toSet(), {
                  'ownerId',
                  'activationId',
                  'serverExpiresEpochMillis',
                });
                expect(args['ownerId'], ownerA);
                expect(args['activationId'], activation);
                return {
                  'localLeasePresent': true,
                  'expiresEpochMillis': args['serverExpiresEpochMillis'],
                };
              default:
                fail('Unexpected native activation command');
            }
          });
      const port = MethodChannelGuardianActivationPort();
      final draft = await port.begin(ownerA, '+y');
      final serverExpiry = DateTime.now().toUtc().add(const Duration(hours: 7));
      expect(draft.toString(), isNot(contains(capability)));
      expect(
        (await port.commit(
          ownerA,
          draft.activationId,
          serverExpiry,
        )).millisecondsSinceEpoch,
        serverExpiry.millisecondsSinceEpoch,
      );
      expect(calls, ['begin', 'commit']);
    },
  );

  test('server confirmation precedes native commit', () async {
    final events = <String>[];
    final account = TestAccount();
    final bound = GuardianBoundAccountGateway(account, OwnerPort());
    final native = NativePort(events);
    final server = Server(events);
    addTearDown(() async {
      await bound.dispose();
      await account.changes.close();
    });

    final expiry = await GuardianDriverActivationService(
      bound,
      native,
      server,
    ).prepareAfterExplicitConsent(reviewed('+y'));
    expect(expiry.isAfter(DateTime.now()), isTrue);
    expect(events, ['begin', 'server', 'commit']);
    expect(native.disables, 0);
    expect(server.revokes, 0);
  });

  test('stale or incomplete review cannot reach the native proposal', () async {
    final events = <String>[];
    final account = TestAccount();
    final bound = GuardianBoundAccountGateway(account, OwnerPort());
    final native = NativePort(events);
    final server = Server(events);
    addTearDown(() async {
      await bound.dispose();
      await account.changes.close();
    });

    for (final consent in [
      reviewed(
        '+y',
        at: DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
      ),
      reviewed('+y', mounted: false),
      GuardianDriverConsent(
        ownerId: ownerA,
        forwardAxis: '+y',
        rigidMountConfirmed: true,
        safetyLimitsAcknowledged: false,
        recipientSharingAcknowledged: true,
        reviewedAt: DateTime.now().toUtc(),
      ),
      GuardianDriverConsent(
        ownerId: ownerA,
        forwardAxis: '+y',
        rigidMountConfirmed: true,
        safetyLimitsAcknowledged: true,
        recipientSharingAcknowledged: false,
        reviewedAt: DateTime.now().toUtc(),
      ),
    ]) {
      await expectLater(
        GuardianDriverActivationService(
          bound,
          native,
          server,
        ).prepareAfterExplicitConsent(consent),
        throwsA(isA<GuardianActivationException>()),
      );
    }
    expect(events, isEmpty);
    expect(reviewed('+y').toString(), isNot(contains(ownerA)));
  });

  test(
    'server failure clears local proposal and attempts scoped revoke',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      final server = Server(events)
        ..onActivate = () => throw StateError('synthetic rejection');
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });

      await expectLater(
        GuardianDriverActivationService(
          bound,
          native,
          server,
        ).prepareAfterExplicitConsent(reviewed('+x')),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(events, ['begin', 'server', 'disable', 'revoke']);
      expect(native.commits, 0);
    },
  );

  test(
    'account change while server responds never commits old lease',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      final reply = Completer<GuardianSessionConfirmation>();
      final server = Server(events)..onActivate = () => reply.future;
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });

      final pending = GuardianDriverActivationService(
        bound,
        native,
        server,
      ).prepareAfterExplicitConsent(reviewed('+z'));
      await Future<void>.delayed(Duration.zero);
      account.change(ownerB);
      reply.complete(
        GuardianSessionConfirmation(
          activation,
          DateTime.now().toUtc().add(const Duration(hours: 7)),
        ),
      );
      await expectLater(pending, throwsA(isA<GuardianActivationException>()));
      expect(native.commits, 0);
      expect(native.aborts, 1);
    },
  );

  test(
    'owner change after commit rejects success and removes old authority',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final ownerPort = OwnerPort();
      final bound = GuardianBoundAccountGateway(account, ownerPort);
      final native = NativePort(events)
        ..beforeCommit = () async => account.change(ownerB);
      final server = Server(events);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });

      await expectLater(
        GuardianDriverActivationService(
          bound,
          native,
          server,
        ).prepareAfterExplicitConsent(reviewed('-x')),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(native.commits, 1);
      expect(ownerPort.owners.last, ownerB);
    },
  );

  test('server confirmation rejects mismatched and unbounded responses', () {
    final prepared = DateTime.now().toUtc();
    final valid = <String, Object?>{
      'enabled': true,
      'activation_id': activation,
      'expires_at': prepared.add(const Duration(hours: 7)).toIso8601String(),
    };
    expect(
      GuardianSessionConfirmation.parse(
        valid,
        activation,
        prepared,
      ).activationId,
      activation,
    );
    for (final invalid in [
      {...valid, 'enabled': false},
      {...valid, 'activation_id': ownerB},
      {...valid, 'route': 'private'},
      {...valid, 'expires_at': '2026-09-30T00:00:00'},
      {
        ...valid,
        'expires_at': prepared.add(const Duration(hours: 9)).toIso8601String(),
      },
    ]) {
      expect(
        () => GuardianSessionConfirmation.parse(invalid, activation, prepared),
        throwsFormatException,
      );
    }
    expect(
      GuardianActivationDraft(
        ownerId: ownerA,
        activationId: activation,
        credential: capability,
        forwardAxis: '+x',
      ).toString(),
      isNot(contains(capability)),
    );
  });
}
