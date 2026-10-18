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
  bool sending = false,
  int? sendingVersion,
}) => GuardianDriverConsent(
  ownerId: ownerA,
  forwardAxis: axis,
  rigidMountConfirmed: mounted,
  safetyLimitsAcknowledged: true,
  recipientSharingAcknowledged: true,
  reviewedAt: at ?? DateTime.now().toUtc(),
  sendingAcknowledged: sending,
  sendingReviewVersion: sendingVersion ?? (sending ? 1 : 0),
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
  final recipientRevokes = <GuardianRecipientLocalStatus>[];
  @override
  Future<void> bindOwner(String? ownerId) async => owners.add(ownerId);

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId) async =>
      null;

  @override
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(
    String ownerId,
  ) async => List.of(recipientRevokes);

  @override
  Future<void> recordRegistrationAttempt(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {}

  @override
  Future<void> confirmPendingRevoke(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {}

  @override
  Future<void> disableConfirmedRecipient(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {}
}

final class NativePort
    implements
        GuardianNativeActivationPort,
        GuardianNativeSendingActivationPort {
  NativePort(this.events);
  final List<String> events;
  int aborts = 0, disables = 0, commits = 0;
  String? stoppedActivation;
  final pending = <String>[];
  int confirmations = 0;
  Future<void> Function()? beforeCommitReply;
  Future<void> Function()? afterBegin;
  bool failAbort = false;
  int sendingBegins = 0;

  @override
  Future<GuardianActivationDraft> beginSending(String owner, String axis) {
    sendingBegins++;
    return begin(owner, axis);
  }

  @override
  Future<GuardianActivationDraft> begin(String owner, String axis) async {
    events.add('begin');
    pending.add(activation);
    await afterBegin?.call();
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
    // Native writes on one serialized worker before returning its bridge reply.
    // The independent cleanup ticket survives for the entire committed lease.
    stoppedActivation = activationId;
    await beforeCommitReply?.call();
    return expiry;
  }

  @override
  Future<void> abort(String owner, String activationId) async {
    events.add('abort');
    aborts++;
    if (failAbort) throw StateError('local cleanup failed');
    if (stoppedActivation == activationId) {
      stoppedActivation = null;
      if (!pending.contains(activationId)) pending.add(activationId);
    }
  }

  @override
  Future<void> disable(String owner) async {
    events.add('disable');
    disables++;
  }

  @override
  Future<String?> stop(String owner) async {
    events.add('stop');
    final previous = stoppedActivation;
    stoppedActivation = null;
    if (previous != null && !pending.contains(previous)) pending.add(previous);
    return previous;
  }

  @override
  Future<List<String>> pendingRevokes(String owner) async => List.of(pending);

  @override
  Future<void> confirmRevoke(String owner, String activation) async {
    if (stoppedActivation == activation) {
      throw StateError('Stop local activation before confirming revoke');
    }
    confirmations++;
    pending.remove(activation);
  }
}

final class Server implements GuardianDriverSessionGateway {
  Server(this.events);
  final List<String> events;
  Future<GuardianSessionConfirmation> Function()? onActivate;
  Future<void> Function()? onRevoke;
  Future<void> Function()? onRevision;

  @override
  Future<GuardianDriverRevision> revision(String owner) async {
    expect(owner, ownerA);
    events.add('revision');
    await onRevision?.call();
    return GuardianDriverRevision.parse({'revision': '0'});
  }

  int revokes = 0;

  @override
  Future<GuardianSessionConfirmation> activate(
    GuardianActivationDraft draft,
    DateTime preparedAt,
    GuardianDriverRevision revision,
  ) async {
    events.add('server');
    expect(revision.value, '0');
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
    expect(owner, ownerA);
    expect(activationId, activation);
    events.add('revoke');
    revokes++;
    await onRevoke?.call();
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
    'sending review needs a current version and enabled pilot before any side effect',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      final server = Server(events);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      for (final entry in [
        (reviewed('+y', sending: true), false),
        (reviewed('+y', sending: true, sendingVersion: 2), true),
        (reviewed('+y', sendingVersion: 1), true),
        (
          reviewed(
            '+y',
            sending: true,
            at: DateTime.now().add(const Duration(minutes: 1)),
          ),
          true,
        ),
      ]) {
        await expectLater(
          GuardianDriverActivationService(
            bound,
            native,
            server,
            sendingPilotAvailable: entry.$2,
          ).prepareAfterExplicitConsent(entry.$1),
          throwsA(isA<GuardianActivationException>()),
        );
        expect(events, isEmpty);
      }
    },
  );

  test(
    'fresh sending review uses fenced activation and interruption still revokes exact commit',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      final server = Server(events);
      final service = GuardianDriverActivationService(
        bound,
        native,
        server,
        sendingPilotAvailable: true,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await service.prepareAfterExplicitConsent(reviewed('+y', sending: true));
      expect(native.sendingBegins, 1);
      expect(events, ['stop', 'revision', 'begin', 'server', 'commit']);
      final token = GuardianDriverReviewCancellation();
      native.beforeCommitReply = () async {
        await token.cancel();
      };
      await expectLater(
        service.prepareAfterExplicitConsent(
          reviewed('+y', sending: true),
          cancellation: token,
        ),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(native.stoppedActivation, isNull);
      expect(native.aborts, greaterThan(0));
      expect(server.revokes, greaterThan(0));
    },
  );

  test('sending pilot never upgrades an old evaluation-only review', () async {
    final events = <String>[];
    final account = TestAccount();
    final bound = GuardianBoundAccountGateway(account, OwnerPort());
    final native = NativePort(events);
    addTearDown(() async {
      await bound.dispose();
      await account.changes.close();
    });
    await GuardianDriverActivationService(
      bound,
      native,
      Server(events),
      sendingPilotAvailable: true,
    ).prepareAfterExplicitConsent(reviewed('+y'));
    expect(native.sendingBegins, 0);
  });

  test(
    'sending bridge sends only its distinct versioned acknowledgement contract',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'beginSending');
            expect(call.arguments, {
              'ownerId': ownerA,
              'forwardAxis': '+y',
              'rigidMountConfirmed': true,
              'sendingAcknowledged': true,
              'sendingReviewVersion': 1,
            });
            return {
              'ownerId': ownerA,
              'activationId': activation,
              'credential': capability,
              'forwardAxis': '+y',
            };
          });
      final draft = await const MethodChannelGuardianActivationPort()
          .beginSending(ownerA, '+y');
      expect(draft.activationId, activation);
      expect(draft.toString(), isNot(contains(capability)));
    },
  );

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
    expect(events, ['stop', 'revision', 'begin', 'server', 'commit']);
    expect(native.disables, 0);
    expect(server.revokes, 0);
    expect(native.pending, [activation]);
  });

  test(
    'lost vault authority still permits exact Stop retry from retained ticket',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      final server = Server(events);
      final service = GuardianDriverActivationService(bound, native, server);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await service.prepareAfterExplicitConsent(reviewed('+y'));
      native.stoppedActivation =
          null; // Destructive native vault failure, separate journal intact.
      server.onRevoke = () async => throw StateError('offline');
      await expectLater(
        service.stop(ownerA),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(native.pending, [activation]);
      expect(native.confirmations, 0);
      server.onRevoke = null;
      await service.stop(ownerA);
      expect(native.pending, isEmpty);
      expect(native.confirmations, 1);
      expect(server.revokes, 2);
      expect(native.commits, 1);
      expect(events.sublist(5), ['stop', 'revoke', 'stop', 'revoke']);
    },
  );

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
      expect(events, [
        'stop',
        'revision',
        'begin',
        'server',
        'abort',
        'revoke',
      ]);
      expect(native.pending, isEmpty);
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
        ..beforeCommitReply = () async => account.change(ownerB);
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

  test('stop erases locally before an exact server revoke', () async {
    final events = <String>[];
    final account = TestAccount();
    final bound = GuardianBoundAccountGateway(account, OwnerPort());
    final native = NativePort(events)..stoppedActivation = activation;
    final server = Server(events);
    addTearDown(() async {
      await bound.dispose();
      await account.changes.close();
    });
    final service = GuardianDriverActivationService(bound, native, server);
    await service.stop(ownerA);
    expect(events, ['stop', 'revoke']);
    await service.stop(ownerA);
    expect(events, ['stop', 'revoke', 'stop']);
    await expectLater(
      service.stop(ownerB),
      throwsA(isA<GuardianActivationException>()),
    );
    expect(events, ['stop', 'revoke', 'stop']);
  });

  test(
    'failed server revoke preserves an exact retry without restoring authority',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events)..stoppedActivation = activation;
      final server = Server(events)
        ..onRevoke = () => throw StateError('synthetic network failure');
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      final service = GuardianDriverActivationService(bound, native, server);
      await expectLater(
        service.stop(ownerA),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(events, ['stop', 'revoke']);
      expect(native.pending, [activation]);
      expect(native.confirmations, 0);
      server.onRevoke = null;
      await service.stop(ownerA);
      expect(events, ['stop', 'revoke', 'stop', 'revoke']);
      expect(native.pending, isEmpty);
      expect(native.confirmations, 1);
    },
  );

  test(
    'native stop bridge accepts only a redacted activation response',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'stop');
            expect(call.arguments, {'ownerId': ownerA});
            return {'activationId': activation};
          });
      expect(
        await const MethodChannelGuardianActivationPort().stop(ownerA),
        activation,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {
              'activationId': activation,
              'credential': capability,
            },
          );
      await expectLater(
        const MethodChannelGuardianActivationPort().stop(ownerA),
        throwsFormatException,
      );
    },
  );

  test(
    'new activation reconciles an outstanding stop before proposal',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events)..pending.add(activation);
      final server = Server(events);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await GuardianDriverActivationService(
        bound,
        native,
        server,
      ).prepareAfterExplicitConsent(reviewed('+y'));
      expect(events, [
        'stop',
        'revoke',
        'revision',
        'begin',
        'server',
        'commit',
      ]);
      expect(native.pending, [activation]);
    },
  );

  test(
    'account change during stop retry preserves the unconfirmed ticket',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events)..stoppedActivation = activation;
      final server = Server(events)
        ..onRevoke = () async => account.change(ownerB);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await expectLater(
        GuardianDriverActivationService(bound, native, server).stop(ownerA),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(native.pending, [activation]);
      expect(native.confirmations, 0);
    },
  );

  test(
    'pending stop bridge rejects duplicate and credential-bearing replies',
    () async {
      for (final reply in [
        [
          {'activationId': activation},
          {'activationId': activation},
        ],
        [
          {'activationId': activation, 'credential': capability},
        ],
        [
          {'activationId': 'invalid'},
        ],
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => reply);
        await expectLater(
          const MethodChannelGuardianActivationPort().pendingRevokes(ownerA),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'local stop does not depend on recipient cleanup reaching the network',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final ownerPort = OwnerPort()
        ..recipientRevokes.add(
          const GuardianRecipientLocalStatus(ownerB, ownerB),
        );
      final bound = GuardianBoundAccountGateway(account, ownerPort);
      final native = NativePort(events)..stoppedActivation = activation;
      final server = Server(events);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isFalse);
      await GuardianDriverActivationService(bound, native, server).stop(ownerA);
      expect(events, ['stop', 'revoke']);
      expect(native.pending, isEmpty);
    },
  );
  test('revision parser rejects lossy or noncanonical counters', () {
    for (final value in ['0', '9007199254740993', '9223372036854775807']) {
      expect(GuardianDriverRevision.parse({'revision': value}).value, value);
    }
    for (final raw in [
      null,
      {'revision': 0},
      {'revision': '-1'},
      {'revision': '01'},
      {'revision': ' 1'},
      {'revision': '1\n'},
      {'revision': '9223372036854775808'},
      {'revision': '1', 'extra': true},
    ]) {
      expect(() => GuardianDriverRevision.parse(raw), throwsFormatException);
    }
  });

  test('two service instances cannot overlap one account review', () async {
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
    final first = GuardianDriverActivationService(
      bound,
      native,
      server,
    ).prepareAfterExplicitConsent(reviewed('+y'));
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      GuardianDriverActivationService(
        bound,
        native,
        server,
      ).prepareAfterExplicitConsent(reviewed('+y')),
      throwsA(isA<GuardianActivationException>()),
    );
    expect(native.aborts, 0);
    expect(events.where((e) => e == 'begin').length, 1);
    reply.complete(
      GuardianSessionConfirmation(
        activation,
        DateTime.now().toUtc().add(const Duration(hours: 7)),
      ),
    );
    await first;
    expect(native.commits, 1);
  });

  test('Stop during revision read cancels review before proposal', () async {
    final events = <String>[];
    final account = TestAccount();
    final bound = GuardianBoundAccountGateway(account, OwnerPort());
    final native = NativePort(events);
    final reply = Completer<void>();
    final server = Server(events)..onRevision = () => reply.future;
    addTearDown(() async {
      await bound.dispose();
      await account.changes.close();
    });
    final service = GuardianDriverActivationService(bound, native, server);
    final first = service.prepareAfterExplicitConsent(reviewed('+y'));
    await Future<void>.delayed(Duration.zero);
    await service.stop(ownerA);
    reply.complete();
    await expectLater(first, throwsA(isA<GuardianActivationException>()));
    expect(events, ['stop', 'revision', 'stop']);
  });

  test(
    'Stop during server activation prevents delayed native commit',
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
      final service = GuardianDriverActivationService(bound, native, server);
      final first = service.prepareAfterExplicitConsent(reviewed('+y'));
      await Future<void>.delayed(Duration.zero);
      await service.stop(ownerA);
      expect(native.pending, isEmpty);
      reply.complete(
        GuardianSessionConfirmation(
          activation,
          DateTime.now().toUtc().add(const Duration(hours: 7)),
        ),
      );
      await expectLater(first, throwsA(isA<GuardianActivationException>()));
      expect(native.commits, 0);
      expect(native.aborts, 1);
      expect(native.disables, 0);
    },
  );

  test(
    'sign-out invalidates review without waiting for delayed activation',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final native = NativePort(events);
      final reply = Completer<GuardianSessionConfirmation>();
      final server = Server(events)..onActivate = () => reply.future;
      late GuardianBoundAccountGateway bound;
      bound = GuardianBoundAccountGateway(
        account,
        OwnerPort(),
        driverStopper: (owner) =>
            GuardianDriverStopService(account, native, server).stop(owner),
      );
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      final first = GuardianDriverActivationService(
        bound,
        native,
        server,
      ).prepareAfterExplicitConsent(reviewed('+y'));
      await Future<void>.delayed(Duration.zero);
      await bound.signOut();
      reply.complete(
        GuardianSessionConfirmation(
          activation,
          DateTime.now().toUtc().add(const Duration(hours: 7)),
        ),
      );
      await expectLater(first, throwsA(isA<GuardianActivationException>()));
      expect(native.commits, 0);
      expect(native.disables, 0);
    },
  );

  test(
    'failed activation and failed revoke retain a retryable reservation',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      final server = Server(events)
        ..onActivate = () {
          throw StateError('response lost');
        }
        ..onRevoke = () {
          throw StateError('offline');
        };
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      final service = GuardianDriverActivationService(bound, native, server);
      await expectLater(
        service.prepareAfterExplicitConsent(reviewed('+y')),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(native.pending, [activation]);
      expect(native.confirmations, 0);
      server.onRevoke = null;
      await service.stop(ownerA);
      expect(native.pending, isEmpty);
      expect(native.commits, 0);
    },
  );
  test(
    'review expiry during revision read cannot create native authority',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      var clock = DateTime.now().toUtc();
      final consent = reviewed('+y', at: clock);
      final server = Server(events)
        ..onRevision = () async {
          clock = clock.add(const Duration(minutes: 2));
        };
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await expectLater(
        GuardianDriverActivationService(
          bound,
          native,
          server,
          now: () => clock,
        ).prepareAfterExplicitConsent(consent),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(events, ['stop', 'revision']);
    },
  );

  test(
    'review expiry during activation response cleans only its exact proposal',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events);
      var clock = DateTime.now().toUtc();
      final consent = reviewed('+y', at: clock);
      final server = Server(events)
        ..onActivate = () async {
          clock = clock.add(const Duration(minutes: 2));
          return GuardianSessionConfirmation(
            activation,
            clock.add(const Duration(hours: 7)),
          );
        };
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await expectLater(
        GuardianDriverActivationService(
          bound,
          native,
          server,
          now: () => clock,
        ).prepareAfterExplicitConsent(consent),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(events, [
        'stop',
        'revision',
        'begin',
        'server',
        'abort',
        'revoke',
      ]);
      expect(native.commits, 0);
      expect(native.pending, isEmpty);
    },
  );
  test(
    'lost native proposal reply retains identity for next explicit Stop',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events)
        ..afterBegin = () async {
          throw StateError('bridge reply lost');
        };
      final server = Server(events);
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      final service = GuardianDriverActivationService(bound, native, server);
      await expectLater(
        service.prepareAfterExplicitConsent(reviewed('+y')),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(events, ['stop', 'revision', 'begin']);
      expect(native.pending, [activation]);
      await service.stop(ownerA);
      expect(native.pending, isEmpty);
      expect(server.revokes, 1);
    },
  );

  test(
    'server cleanup success cannot discard ticket when local abort is uncertain',
    () async {
      final events = <String>[];
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final native = NativePort(events)..failAbort = true;
      final server = Server(events)
        ..onActivate = () async {
          throw StateError('response lost');
        };
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await expectLater(
        GuardianDriverActivationService(
          bound,
          native,
          server,
        ).prepareAfterExplicitConsent(reviewed('+y')),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(server.revokes, 1);
      expect(native.confirmations, 0);
      expect(native.pending, [activation]);
    },
  );
  test(
    'per-review cancellation before start cannot create any authority',
    () async {
      final account = TestAccount();
      final bound = GuardianBoundAccountGateway(account, OwnerPort());
      final events = <String>[];
      final token = GuardianDriverReviewCancellation();
      await token.cancel();
      addTearDown(() async {
        await bound.dispose();
        await account.changes.close();
      });
      await expectLater(
        GuardianDriverActivationService(
          bound,
          NativePort(events),
          Server(events),
        ).prepareAfterExplicitConsent(reviewed('+y'), cancellation: token),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(events, isEmpty);
    },
  );

  test(
    'per-review cancellation after server response or commit retains exact cleanup',
    () async {
      for (final cancelDuringCommit in [false, true]) {
        final account = TestAccount();
        final bound = GuardianBoundAccountGateway(account, OwnerPort());
        final events = <String>[];
        final native = NativePort(events);
        final server = Server(events);
        final token = GuardianDriverReviewCancellation();
        if (cancelDuringCommit) {
          native.beforeCommitReply = () async {
            await token.cancel();
          };
        } else {
          server.onActivate = () async {
            await token.cancel();
            return GuardianSessionConfirmation(
              activation,
              DateTime.now().toUtc().add(const Duration(hours: 7)),
            );
          };
        }
        await expectLater(
          GuardianDriverActivationService(
            bound,
            native,
            server,
          ).prepareAfterExplicitConsent(reviewed('+y'), cancellation: token),
          throwsA(isA<GuardianActivationException>()),
        );
        expect(native.aborts, 1);
        expect(native.disables, 0);
        expect(native.pending, isEmpty);
        expect(native.stoppedActivation, isNull);
        expect(server.revokes, 1);
        await bound.dispose();
        await account.changes.close();
      }
    },
  );
  test(
    'completed review stays cancellable until foreground accepts the result',
    () async {
      for (final accepted in [false, true]) {
        final account = TestAccount();
        final bound = GuardianBoundAccountGateway(account, OwnerPort());
        final events = <String>[];
        final native = NativePort(events);
        final server = Server(events);
        final token = GuardianDriverReviewCancellation();
        final service = GuardianDriverActivationService(bound, native, server);
        await service.prepareAfterExplicitConsent(
          reviewed('+y'),
          cancellation: token,
        );
        if (accepted) token.acceptCompletion();
        await token.cancel();
        await token.cancel();
        expect(server.revokes, accepted ? 0 : 1);
        expect(native.stoppedActivation, accepted ? activation : isNull);
        final before = List.of(events);
        await expectLater(
          service.prepareAfterExplicitConsent(
            reviewed('+y'),
            cancellation: token,
          ),
          throwsA(isA<GuardianActivationException>()),
        );
        expect(events, before);
        await bound.dispose();
        await account.changes.close();
      }
    },
  );
}
