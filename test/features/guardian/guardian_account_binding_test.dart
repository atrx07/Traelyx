import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/account_metadata/application/metadata_providers.dart';
import 'package:traelyx/features/account_metadata/data/supabase_metadata_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_alerts.dart';
import 'package:traelyx/features/guardian/guardian_controller.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_gateway.dart';
import 'package:traelyx/features/guardian/guardian_recipient_consent.dart';
import 'package:traelyx/features/guardian/guardian_recipient_registration.dart';
import 'package:traelyx/features/rankings/ranking_service.dart';
import 'package:traelyx/features/social/application/social_controller.dart';
import 'package:traelyx/features/social/data/supabase_social_gateway.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_providers.dart';
import 'package:traelyx/features/summary_sync/data/supabase_summary_gateway.dart';

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
  GuardianRecipientLocalStatus? status;
  int statusCalls = 0;
  final pending = <GuardianRecipientLocalStatus>[];
  String? pendingOwnerId;
  final confirmed = <(String, String, String)>[];
  final disabled = <(String, String, String)>[];
  bool failConfirm = false;

  @override
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(
    String ownerId,
  ) async => pendingOwnerId == null || pendingOwnerId == ownerId
      ? List.of(pending)
      : [];

  @override
  Future<void> recordRegistrationAttempt(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {
    pendingOwnerId = ownerId;
    pending.add(status);
  }

  @override
  Future<void> confirmPendingRevoke(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {
    if (failConfirm) throw StateError('local journal unavailable');
    confirmed.add((ownerId, status.deviceId, status.generation));
    pending.remove(status);
  }

  @override
  Future<void> disableConfirmedRecipient(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) async {
    disabled.add((ownerId, status.deviceId, status.generation));
    pending.remove(status);
    this.status = null;
  }

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId) async {
    statusCalls++;
    return status;
  }

  @override
  Future<void> bindOwner(String? ownerId) async {
    calls.add(ownerId);
    if (ownerId == null && failCleanup) throw StateError('vault unavailable');
    final blocked = nextCall;
    nextCall = null;
    await blocked?.future;
  }
}

final class FakeDeviceRevoker implements GuardianDeviceRevoker {
  final calls = <(String, String, String)>[];
  Completer<void>? nextCall;
  bool fail = false;

  @override
  Future<void> revoke(String owner, String device, String generation) async {
    calls.add((owner, device, generation));
    if (fail) throw StateError('offline');
    await nextCall?.future;
  }
}

final class FakeRecipientTokenPort implements GuardianRecipientTokenPort {
  int calls = 0;
  Completer<String>? waiting;
  Completer<void>? started;
  @override
  Future<String> acquire(String ownerId, String generation) async {
    calls++;
    started?.complete();
    final pending = waiting;
    return pending == null
        ? 'synthetic-routing-token-123456789'
        : await pending.future;
  }
}

final class FakeRecipientReceiptPort implements GuardianRecipientReceiptPort {
  FakeRecipientReceiptPort(this.ownerPort);
  final FakeOwnerPort ownerPort;
  bool fail = false;
  int calls = 0;
  @override
  Future<void> commit(
    GuardianDeviceRegistration registration,
    DateTime registeredAt,
    DateTime expiresAt,
  ) async {
    calls++;
    if (fail) throw StateError('local receipt unavailable');
    ownerPort.status = GuardianRecipientLocalStatus(
      registration.deviceId,
      registration.generation,
    );
  }
}

final class FakeRecipientIdentitySource
    implements GuardianRecipientIdentitySource {
  int _next = 0;
  @override
  String newUuid() => _next++ == 0
      ? '33333333-3333-4333-8333-333333333333'
      : '44444444-4444-4444-8444-444444444444';
  @override
  String newCredential() => 'a' * 64;
}

final class FakeRecipientTransport implements GuardianDeviceRpcTransport {
  FakeRecipientTransport(this.account);
  final FakeAccount account;
  final calls = <Map<String, Object?>>[];
  bool failRegistration = false;
  bool failRevocation = false;
  @override
  String? get currentOwnerId => account.currentIdentity?.userId;
  @override
  Future<Object?> call(String name, Map<String, Object?> parameters) async {
    calls.add(parameters);
    if ((parameters['routing_token'] != null && failRegistration) ||
        (parameters['routing_token'] == null && failRevocation)) {
      throw StateError('server unavailable');
    }
    return null;
  }
}

void main() {
  test(
    'production owner port binds recipient before driver and clears both',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const recipient = MethodChannel(
        'io.github.atrx07.traelyx/guardian_recipient',
      );
      const driver = MethodChannel(
        'io.github.atrx07.traelyx/guardian_activation',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(recipient, (call) async {
        expect(call.method, 'bindOwner');
        calls.add('recipient:${(call.arguments as Map)['ownerId']}');
        return null;
      });
      messenger.setMockMethodCallHandler(driver, (call) async {
        expect(call.method, 'bindOwner');
        calls.add('driver:${(call.arguments as Map)['ownerId']}');
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(recipient, null);
        messenger.setMockMethodCallHandler(driver, null);
      });

      const port = MethodChannelGuardianOwnerPort();
      await port.bindOwner(ownerA.userId);
      await port.bindOwner(null);
      expect(calls, [
        'recipient:${ownerA.userId}',
        'driver:${ownerA.userId}',
        'recipient:null',
        'driver:null',
      ]);
    },
  );

  test(
    'recipient cleanup failure prevents the driver bind from claiming success',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const recipient = MethodChannel(
        'io.github.atrx07.traelyx/guardian_recipient',
      );
      const driver = MethodChannel(
        'io.github.atrx07.traelyx/guardian_activation',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var driverCalls = 0;
      messenger.setMockMethodCallHandler(
        recipient,
        (_) async => throw PlatformException(code: 'cleanup_failed'),
      );
      messenger.setMockMethodCallHandler(driver, (_) async {
        driverCalls++;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(recipient, null);
        messenger.setMockMethodCallHandler(driver, null);
      });

      await expectLater(
        const MethodChannelGuardianOwnerPort().bindOwner(null),
        throwsA(isA<PlatformException>()),
      );
      expect(driverCalls, 0);
    },
  );

  test(
    'production recipient snapshot exposes only bounded device identity',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const recipient = MethodChannel(
        'io.github.atrx07.traelyx/guardian_recipient',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Object? reply = {
        'deviceId': '33333333-3333-4333-8333-333333333333',
        'generation': '44444444-4444-4444-8444-444444444444',
        'expiresAtEpochMillis': 1800000000000,
      };
      messenger.setMockMethodCallHandler(recipient, (call) async {
        expect(call.method, 'snapshot');
        expect(call.arguments, {'ownerId': ownerA.userId});
        return reply;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(recipient, null));

      const port = MethodChannelGuardianOwnerPort();
      final status = await port.recipientStatus(ownerA.userId);
      expect(status?.deviceId, '33333333-3333-4333-8333-333333333333');
      expect(status?.generation, '44444444-4444-4444-8444-444444444444');
      reply = {...(reply as Map), 'credential': 'must-not-cross-channel'};
      await expectLater(
        port.recipientStatus(ownerA.userId),
        throwsA(isA<FormatException>()),
      );
      reply = null;
      expect(await port.recipientStatus(ownerA.userId), isNull);
    },
  );

  test(
    'production pending revoke parser rejects extra fields and duplicates',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const recipient = MethodChannel(
        'io.github.atrx07.traelyx/guardian_recipient',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const row = {
        'deviceId': '33333333-3333-4333-8333-333333333333',
        'generation': '44444444-4444-4444-8444-444444444444',
      };
      Object? reply = [row];
      messenger.setMockMethodCallHandler(recipient, (call) async {
        expect(call.method, 'pendingRevokes');
        expect(call.arguments, {'ownerId': ownerA.userId});
        return reply;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(recipient, null));
      const port = MethodChannelGuardianOwnerPort();
      expect(
        (await port.pendingRevokes(ownerA.userId)).single.deviceId,
        row['deviceId'],
      );
      reply = [
        {...row, 'credential': 'must-not-cross-channel'},
      ];
      await expectLater(
        port.pendingRevokes(ownerA.userId),
        throwsA(isA<FormatException>()),
      );
      reply = [row, row];
      await expectLater(
        port.pendingRevokes(ownerA.userId),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('production revoke confirmation sends only exact device IDs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const recipient = MethodChannel(
      'io.github.atrx07.traelyx/guardian_recipient',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(recipient, (call) async {
      expect(call.arguments, {
        'ownerId': ownerA.userId,
        'deviceId': '33333333-3333-4333-8333-333333333333',
        'generation': '44444444-4444-4444-8444-444444444444',
      });
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(recipient, null));
    const port = MethodChannelGuardianOwnerPort();
    const status = GuardianRecipientLocalStatus(
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
    );
    await port.confirmPendingRevoke(ownerA.userId, status);
    await port.disableConfirmedRecipient(ownerA.userId, status);
    await port.recordRegistrationAttempt(ownerA.userId, status);
    expect(calls, ['confirmRevoke', 'disableConfirmed', 'recordAttempt']);
    expect(
      () => port.recordRegistrationAttempt(
        ownerA.userId,
        const GuardianRecipientLocalStatus('bad', 'bad'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'interrupted registration with a local receipt revokes then erases it',
    () async {
      final account = FakeAccount(ownerA);
      const ticket = GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
      final port = FakeOwnerPort()..status = ticket;
      await port.recordRegistrationAttempt(ownerA.userId, ticket);
      final revoker = FakeDeviceRevoker();
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      expect(revoker.calls, [
        (ownerA.userId, ticket.deviceId, ticket.generation),
      ]);
      expect(port.disabled, [
        (ownerA.userId, ticket.deviceId, ticket.generation),
      ]);
      expect(port.pending, isEmpty);
      expect(port.status, isNull);
      expect(
        port.calls.where((owner) => owner == ownerA.userId).length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test(
    'offline interrupted registration retains its receipt and ticket',
    () async {
      final account = FakeAccount(ownerA);
      const ticket = GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
      final port = FakeOwnerPort()..status = ticket;
      await port.recordRegistrationAttempt(ownerA.userId, ticket);
      final revoker = FakeDeviceRevoker()..fail = true;
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isFalse);
      expect(port.pending, [ticket]);
      expect(port.status, same(ticket));
      expect(port.disabled, isEmpty);
    },
  );

  test(
    'offline pending revoke retries under the same signed-in owner',
    () async {
      final account = FakeAccount(ownerA);
      final ticket = const GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
      final port = FakeOwnerPort()..pending.add(ticket);
      port.pendingOwnerId = ownerA.userId;
      final revoker = FakeDeviceRevoker()..fail = true;
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isFalse);
      expect(port.pending, [ticket]);
      expect(port.confirmed, isEmpty);
      final failedCalls = revoker.calls.length;
      revoker.fail = false;
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      expect(revoker.calls.length, failedCalls + 1);
      expect(port.confirmed, [
        (ownerA.userId, ticket.deviceId, ticket.generation),
      ]);
      expect(port.pending, isEmpty);
    },
  );

  test(
    'owner change during pending revoke keeps ticket for later retry',
    () async {
      final account = FakeAccount(ownerA);
      final ticket = const GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
      final port = FakeOwnerPort()..pending.add(ticket);
      port.pendingOwnerId = ownerA.userId;
      final revoker = FakeDeviceRevoker();
      final waiting = Completer<void>();
      revoker.nextCall = waiting;
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      await Future<void>.delayed(Duration.zero);
      expect(revoker.calls, [
        (ownerA.userId, ticket.deviceId, ticket.generation),
      ]);
      account.emit(ownerB);
      waiting.complete();
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      expect(port.confirmed, isEmpty);
      expect(port.pending, [ticket]);
      expect(port.calls.last, ownerB.userId);
    },
  );

  test('failed local ticket confirmation retries the server revoke', () async {
    final account = FakeAccount(ownerA);
    final ticket = const GuardianRecipientLocalStatus(
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
    );
    final port = FakeOwnerPort()..pending.add(ticket);
    port.pendingOwnerId = ownerA.userId;
    port.failConfirm = true;
    final revoker = FakeDeviceRevoker();
    final bound = GuardianBoundAccountGateway(
      account,
      port,
      deviceRevoker: revoker,
    );
    addTearDown(() async {
      await bound.dispose();
      await account.close();
    });
    expect(await bound.ensureCurrentOwnerBound(), isFalse);
    expect(port.pending, [ticket]);
    expect(port.confirmed, isEmpty);
    final sent = revoker.calls.length;
    port.failConfirm = false;
    expect(await bound.ensureCurrentOwnerBound(), isTrue);
    expect(revoker.calls.length, sent + 1);
    expect(port.pending, isEmpty);
  });

  test(
    'registration transaction does not revoke its own pending ticket',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort();
      final revoker = FakeDeviceRevoker();
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      const ticket = GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
      final hold = Completer<void>();
      final transaction = bound.runRecipientRegistration(
        ownerA.userId,
        () async {
          await port.recordRegistrationAttempt(ownerA.userId, ticket);
          await hold.future;
        },
      );
      await Future<void>.delayed(Duration.zero);
      final binds = port.calls.length;
      account.emit(ownerA);
      await Future<void>.delayed(Duration.zero);
      expect(port.calls.length, binds);
      expect(port.pending, [ticket]);
      expect(revoker.calls, isEmpty);
      await expectLater(
        bound.runRecipientRegistration(ownerA.userId, () async {}),
        throwsA(isA<GuardianLocalCleanupException>()),
      );
      await expectLater(
        bound.signOut(),
        throwsA(isA<GuardianLocalCleanupException>()),
      );
      expect(account.signOutCount, 0);
      hold.complete();
      await transaction;
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      expect(port.pending, isEmpty);
      expect(revoker.calls, [
        (ownerA.userId, ticket.deviceId, ticket.generation),
      ]);
    },
  );

  test(
    'account change cannot report registration transaction success',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort();
      final bound = GuardianBoundAccountGateway(account, port);
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      final hold = Completer<void>();
      final transaction = bound.runRecipientRegistration(
        ownerA.userId,
        () async {
          await hold.future;
          return 1;
        },
      );
      await Future<void>.delayed(Duration.zero);
      account.emit(ownerB);
      hold.complete();
      await expectLater(
        transaction,
        throwsA(isA<GuardianLocalCleanupException>()),
      );
      expect(await bound.ensureCurrentOwnerBound(), isTrue);
      expect(port.calls.last, ownerB.userId);
    },
  );

  test(
    'dormant registration reserves before server and commits locally',
    () async {
      final account = FakeAccount(ownerA);
      final ownerPort = FakeOwnerPort();
      final tokenPort = FakeRecipientTokenPort();
      final transport = FakeRecipientTransport(account);
      final receiptPort = FakeRecipientReceiptPort(ownerPort);
      final bound = GuardianBoundAccountGateway(
        account,
        ownerPort,
        deviceRevoker: GuardianDeviceServerGateway(transport),
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      final service = GuardianRecipientRegistrationService(
        account: bound,
        ownerPort: ownerPort,
        tokenPort: tokenPort,
        server: GuardianDeviceServerGateway(transport),
        receiptPort: receiptPort,
        identitySource: FakeRecipientIdentitySource(),
      );
      await service.registerAfterExplicitConsent(
        GuardianRecipientConsent(
          ownerId: ownerA.userId,
          deliveryLimitsAcknowledged: true,
          providerDisclosureAccepted: true,
          reviewedAt: DateTime.now().toUtc(),
        ),
      );
      expect(tokenPort.calls, 1);
      expect(transport.calls.length, 1);
      expect(
        transport.calls.single['routing_token'],
        'synthetic-routing-token-123456789',
      );
      expect(receiptPort.calls, 1);
      expect(
        ownerPort.status?.deviceId,
        '33333333-3333-4333-8333-333333333333',
      );
      expect(ownerPort.pending, isEmpty);
    },
  );

  test(
    'local receipt failure revokes server row and clears reservation',
    () async {
      final account = FakeAccount(ownerA);
      final ownerPort = FakeOwnerPort();
      final transport = FakeRecipientTransport(account);
      final receiptPort = FakeRecipientReceiptPort(ownerPort)..fail = true;
      final bound = GuardianBoundAccountGateway(
        account,
        ownerPort,
        deviceRevoker: GuardianDeviceServerGateway(transport),
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      final service = GuardianRecipientRegistrationService(
        account: bound,
        ownerPort: ownerPort,
        tokenPort: FakeRecipientTokenPort(),
        server: GuardianDeviceServerGateway(transport),
        receiptPort: receiptPort,
        identitySource: FakeRecipientIdentitySource(),
      );
      await expectLater(
        service.registerAfterExplicitConsent(
          GuardianRecipientConsent(
            ownerId: ownerA.userId,
            deliveryLimitsAcknowledged: true,
            providerDisclosureAccepted: true,
            reviewedAt: DateTime.now().toUtc(),
          ),
        ),
        throwsA(isA<GuardianRecipientRegistrationException>()),
      );
      expect(transport.calls.length, 2);
      expect(transport.calls.last['routing_token'], isNull);
      expect(ownerPort.pending, isEmpty);
      expect(ownerPort.status, isNull);
    },
  );

  test(
    'owner switch during token acquisition leaves exact retry ticket',
    () async {
      final account = FakeAccount(ownerA);
      final ownerPort = FakeOwnerPort();
      final tokenPort = FakeRecipientTokenPort()
        ..waiting = Completer<String>()
        ..started = Completer<void>();
      final transport = FakeRecipientTransport(account);
      final bound = GuardianBoundAccountGateway(
        account,
        ownerPort,
        deviceRevoker: GuardianDeviceServerGateway(transport),
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      final service = GuardianRecipientRegistrationService(
        account: bound,
        ownerPort: ownerPort,
        tokenPort: tokenPort,
        server: GuardianDeviceServerGateway(transport),
        receiptPort: FakeRecipientReceiptPort(ownerPort),
        identitySource: FakeRecipientIdentitySource(),
      );
      final registration = service.registerAfterExplicitConsent(
        GuardianRecipientConsent(
          ownerId: ownerA.userId,
          deliveryLimitsAcknowledged: true,
          providerDisclosureAccepted: true,
          reviewedAt: DateTime.now().toUtc(),
        ),
      );
      await tokenPort.started!.future;
      account.emit(ownerB);
      tokenPort.waiting!.complete('synthetic-routing-token-123456789');
      await expectLater(
        registration,
        throwsA(isA<GuardianRecipientRegistrationException>()),
      );
      expect(transport.calls, isEmpty);
      expect(ownerPort.pending.length, 1);
      expect(ownerPort.pendingOwnerId, ownerA.userId);
    },
  );

  test(
    'failed server revocation keeps registration ticket for retry',
    () async {
      final account = FakeAccount(ownerA);
      final ownerPort = FakeOwnerPort();
      final transport = FakeRecipientTransport(account)..failRevocation = true;
      final receiptPort = FakeRecipientReceiptPort(ownerPort)..fail = true;
      final bound = GuardianBoundAccountGateway(
        account,
        ownerPort,
        deviceRevoker: GuardianDeviceServerGateway(transport),
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      final service = GuardianRecipientRegistrationService(
        account: bound,
        ownerPort: ownerPort,
        tokenPort: FakeRecipientTokenPort(),
        server: GuardianDeviceServerGateway(transport),
        receiptPort: receiptPort,
        identitySource: FakeRecipientIdentitySource(),
      );
      await expectLater(
        service.registerAfterExplicitConsent(
          GuardianRecipientConsent(
            ownerId: ownerA.userId,
            deliveryLimitsAcknowledged: true,
            providerDisclosureAccepted: true,
            reviewedAt: DateTime.now().toUtc(),
          ),
        ),
        throwsA(isA<GuardianRecipientRegistrationException>()),
      );
      expect(ownerPort.pending.length, 1);
      expect(ownerPort.pendingOwnerId, ownerA.userId);
      expect(ownerPort.status, isNull);
    },
  );

  test(
    'native receipt commit sends exact fields and validates response',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(
        'io.github.atrx07.traelyx/guardian_recipient',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Object? response = {
        'deviceId': '33333333-3333-4333-8333-333333333333',
        'generation': '44444444-4444-4444-8444-444444444444',
        'expiresAtEpochMillis': 1_800_000_000_000,
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'commit');
        expect((call.arguments as Map).keys.toSet(), {
          'ownerId',
          'deviceId',
          'generation',
          'credential',
          'registeredAtEpochMillis',
          'expiresAtEpochMillis',
        });
        return response;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const registration = GuardianDeviceRegistration(
        ownerId: '11111111-1111-4111-8111-111111111111',
        deviceId: '33333333-3333-4333-8333-333333333333',
        generation: '44444444-4444-4444-8444-444444444444',
        routingToken: 'synthetic-routing-token-123456789',
        credential:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      const port = MethodChannelGuardianRecipientReceiptPort();
      final registeredAt = DateTime.fromMillisecondsSinceEpoch(
        1_799_900_000_000,
        isUtc: true,
      );
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        1_800_000_000_000,
        isUtc: true,
      );
      await port.commit(registration, registeredAt, expiresAt);
      response = {...(response as Map), 'credential': 'must-not-return'};
      await expectLater(
        port.commit(registration, registeredAt, expiresAt),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('stale recipient review cannot reserve or request a token', () async {
    final account = FakeAccount(ownerA);
    final ownerPort = FakeOwnerPort();
    final tokenPort = FakeRecipientTokenPort();
    final transport = FakeRecipientTransport(account);
    final bound = GuardianBoundAccountGateway(
      account,
      ownerPort,
      deviceRevoker: GuardianDeviceServerGateway(transport),
    );
    addTearDown(() async {
      await bound.dispose();
      await account.close();
    });
    final service = GuardianRecipientRegistrationService(
      account: bound,
      ownerPort: ownerPort,
      tokenPort: tokenPort,
      server: GuardianDeviceServerGateway(transport),
      receiptPort: FakeRecipientReceiptPort(ownerPort),
      identitySource: FakeRecipientIdentitySource(),
    );
    await expectLater(
      service.registerAfterExplicitConsent(
        GuardianRecipientConsent(
          ownerId: ownerA.userId,
          deliveryLimitsAcknowledged: true,
          providerDisclosureAccepted: true,
          reviewedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 3),
          ),
        ),
      ),
      throwsA(isA<GuardianRecipientRegistrationException>()),
    );
    expect(tokenPort.calls, 0);
    expect(transport.calls, isEmpty);
    expect(ownerPort.pending, isEmpty);
  });

  test(
    'review expiring while owner binding waits cannot request token',
    () async {
      final account = FakeAccount(ownerA);
      final ownerPort = FakeOwnerPort();
      final waiting = Completer<void>();
      ownerPort.nextCall = waiting;
      final tokenPort = FakeRecipientTokenPort();
      final transport = FakeRecipientTransport(account);
      final bound = GuardianBoundAccountGateway(
        account,
        ownerPort,
        deviceRevoker: GuardianDeviceServerGateway(transport),
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      var current = DateTime.utc(2026, 10, 4, 12);
      final service = GuardianRecipientRegistrationService(
        account: bound,
        ownerPort: ownerPort,
        tokenPort: tokenPort,
        server: GuardianDeviceServerGateway(transport),
        receiptPort: FakeRecipientReceiptPort(ownerPort),
        identitySource: FakeRecipientIdentitySource(),
        now: () => current,
      );
      final registration = service.registerAfterExplicitConsent(
        GuardianRecipientConsent(
          ownerId: ownerA.userId,
          deliveryLimitsAcknowledged: true,
          providerDisclosureAccepted: true,
          reviewedAt: current,
        ),
      );
      current = current.add(const Duration(minutes: 3));
      waiting.complete();
      await expectLater(
        registration,
        throwsA(isA<GuardianRecipientRegistrationException>()),
      );
      expect(tokenPort.calls, 0);
      expect(ownerPort.pending, isEmpty);
      expect(transport.calls, isEmpty);
    },
  );

  test('decorated Auth keeps every optional cloud gateway available', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test-key',
    );
    final bound = GuardianBoundAccountGateway(
      SupabaseAccountGateway(client),
      FakeOwnerPort(),
    );
    final container = ProviderContainer(
      overrides: [accountGatewayProvider.overrideWithValue(bound)],
    );
    addTearDown(() async {
      container.dispose();
      await bound.dispose();
      await client.dispose();
    });

    expect(accountClientOf(bound), same(client));
    expect(
      container.read(metadataGatewayProvider),
      isA<SupabaseMetadataGateway>(),
    );
    expect(
      container.read(summaryCloudGatewayProvider),
      isA<SupabaseSummaryGateway>(),
    );
    expect(
      container.read(guardianGatewayProvider),
      isA<SupabaseGuardianGateway>(),
    );
    expect(
      container.read(guardianAlertGatewayProvider),
      isA<SupabaseGuardianAlertGateway>(),
    );
    expect(container.read(socialGatewayProvider), isA<SupabaseSocialGateway>());
    expect(
      container.read(rankingGatewayProvider),
      isA<SupabaseRankingGateway>(),
    );
  });

  test('accountless decorator exposes no cloud client', () async {
    final bound = GuardianBoundAccountGateway(
      const UnavailableAccountGateway(),
      FakeOwnerPort(),
    );
    addTearDown(bound.dispose);
    expect(accountClientOf(bound), isNull);
  });

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

  test(
    'explicit sign-out revokes a stored device before local cleanup',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort()
        ..status = const GuardianRecipientLocalStatus(
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        );
      final revoker = FakeDeviceRevoker();
      final pending = Completer<void>();
      revoker.nextCall = pending;
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isTrue);

      final signingOut = bound.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(revoker.calls, [
        (
          ownerA.userId,
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        ),
      ]);
      expect(port.calls.last, ownerA.userId);
      expect(account.signOutCount, 0);
      pending.complete();
      await signingOut;
      expect(port.calls.last, null);
      expect(port.disabled, [
        (
          ownerA.userId,
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        ),
      ]);
      expect(account.signOutCount, 1);
    },
  );

  test(
    'offline server revoke leaves Auth and local binding for retry',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort()
        ..status = const GuardianRecipientLocalStatus(
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        );
      final revoker = FakeDeviceRevoker()..fail = true;
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isTrue);

      await expectLater(
        bound.signOut(),
        throwsA(isA<GuardianLocalCleanupException>()),
      );
      expect(account.signOutCount, 0);
      expect(account.currentIdentity, ownerA);
      expect(port.calls.last, ownerA.userId);
      revoker.fail = false;
      await bound.signOut();
      expect(revoker.calls.length, 2);
      expect(account.signOutCount, 1);
    },
  );

  test('missing server revoker blocks sign-out with a stored device', () async {
    final account = FakeAccount(ownerA);
    final port = FakeOwnerPort()
      ..status = const GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
    final bound = GuardianBoundAccountGateway(account, port);
    addTearDown(() async {
      await bound.dispose();
      await account.close();
    });
    expect(await bound.ensureCurrentOwnerBound(), isTrue);
    await expectLater(
      bound.signOut(),
      throwsA(isA<GuardianLocalCleanupException>()),
    );
    expect(account.signOutCount, 0);
    expect(port.calls.last, ownerA.userId);
  });

  test(
    'retry after local deletion failure does not require a second server revoke',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort()
        ..status = const GuardianRecipientLocalStatus(
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        );
      final revoker = FakeDeviceRevoker();
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
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
      expect(revoker.calls.length, 1);
      expect(account.signOutCount, 0);
      port.failCleanup = false;
      await bound.signOut();
      expect(revoker.calls.length, 1);
      expect(account.signOutCount, 1);
    },
  );

  test('concurrent sign-out cannot start a second device revocation', () async {
    final account = FakeAccount(ownerA);
    final port = FakeOwnerPort()
      ..status = const GuardianRecipientLocalStatus(
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
      );
    final revoker = FakeDeviceRevoker();
    final pending = Completer<void>();
    revoker.nextCall = pending;
    final bound = GuardianBoundAccountGateway(
      account,
      port,
      deviceRevoker: revoker,
    );
    addTearDown(() async {
      await bound.dispose();
      await account.close();
    });
    expect(await bound.ensureCurrentOwnerBound(), isTrue);

    final first = bound.signOut();
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      bound.signOut(),
      throwsA(isA<GuardianLocalCleanupException>()),
    );
    expect(revoker.calls.length, 1);
    pending.complete();
    await first;
    expect(account.signOutCount, 1);
  });

  test(
    'account replacement during revoke cannot sign out the new owner',
    () async {
      final account = FakeAccount(ownerA);
      final port = FakeOwnerPort()
        ..status = const GuardianRecipientLocalStatus(
          '33333333-3333-4333-8333-333333333333',
          '44444444-4444-4444-8444-444444444444',
        );
      final revoker = FakeDeviceRevoker();
      final pending = Completer<void>();
      revoker.nextCall = pending;
      final bound = GuardianBoundAccountGateway(
        account,
        port,
        deviceRevoker: revoker,
      );
      addTearDown(() async {
        await bound.dispose();
        await account.close();
      });
      expect(await bound.ensureCurrentOwnerBound(), isTrue);

      final signingOut = bound.signOut();
      await Future<void>.delayed(Duration.zero);
      account.emit(ownerB);
      pending.complete();
      await expectLater(
        signingOut,
        throwsA(isA<GuardianLocalCleanupException>()),
      );
      expect(account.signOutCount, 0);
      expect(account.currentIdentity, ownerB);
    },
  );
}
