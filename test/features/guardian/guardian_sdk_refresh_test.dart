import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/application/refresh_account_session.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';

import '../account/data/supabase_account_refresh_test.dart'
    show owner, sessionJson;

const other = '22222222-2222-4222-8222-222222222222';
const receipt = GuardianRecipientLocalStatus(
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
);

// Models the owner/journal contract only; no native storage/provider reliability claim.
class NativeOwner implements GuardianOwnerPort {
  GuardianRecipientLocalStatus? local = receipt;
  final pending = <GuardianRecipientLocalStatus>[];
  final boundOwners = <String?>[];
  @override
  Future<void> bindOwner(String? next) async {
    boundOwners.add(next);
    if (next != owner && local != null) {
      pending.add(local!);
      local = null;
    }
  }

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String user) async =>
      user == owner ? local : null;
  @override
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(
    String user,
  ) async => user == owner ? List.of(pending) : [];
  @override
  Future<void> confirmPendingRevoke(
    String user,
    GuardianRecipientLocalStatus status,
  ) async {
    expect(user, owner);
    pending.removeWhere(
      (entry) =>
          entry.deviceId == status.deviceId &&
          entry.generation == status.generation,
    );
  }

  @override
  Future<void> disableConfirmedRecipient(
    String user,
    GuardianRecipientLocalStatus status,
  ) async => fail('No registration or explicit withdrawal in this check');
  @override
  Future<void> recordRegistrationAttempt(
    String user,
    GuardianRecipientLocalStatus status,
  ) async => fail('No automatic registration');
}

class ServerRevoker implements GuardianDeviceRevoker {
  final calls = <(String, String, String)>[];
  @override
  Future<void> revoke(String user, String device, String generation) async {
    calls.add((user, device, generation));
  }
}

class AuthFixture {
  late SupabaseClient client;
  int status = 200;
  final started = Completer<void>();
  Completer<void>? replyGate;
  int nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  Future<void> initialize({bool expired = false}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/auth/v1/token');
      expect(request.uri.queryParameters['grant_type'], 'refresh_token');
      await request.drain<void>();
      if (!started.isCompleted) started.complete();
      if (replyGate != null) await replyGate!.future;
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = status;
      request.response.write(
        jsonEncode(
          status == 200
              ? sessionJson(owner, nowSeconds + 3600)
              : {
                  'code': 'refresh_token_not_found',
                  'message': 'synthetic provider detail',
                },
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-client',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    // Only generated JWT timestamps are expired; no host/device clock changes.
    await client.auth.setInitialSession(
      jsonEncode(sessionJson(owner, nowSeconds + (expired ? -120 : 3600))),
    );
  }

  Future<GuardianBoundAccountGateway> bind(
    NativeOwner native,
    ServerRevoker server,
  ) async {
    final bound = GuardianBoundAccountGateway(
      SupabaseAccountGateway(client),
      native,
      deviceRevoker: server,
    );
    addTearDown(bound.dispose);
    expect(await bound.ensureCurrentOwnerBound(), isTrue);
    return bound;
  }
}

void main() {
  test(
    'expired access JWT refresh preserves same-owner Guardian authority',
    () async {
      final auth = AuthFixture();
      await auth.initialize(expired: true);
      expect(auth.client.auth.currentSession!.isExpired, isTrue);
      final native = NativeOwner(), server = ServerRevoker();
      final account = await auth.bind(native, server);
      expect(
        await refreshAccountSession(account),
        AccountRefreshOutcome.refreshed,
      );
      expect(await account.ensureCurrentOwnerBound(), isTrue);
      expect(auth.client.auth.currentSession!.isExpired, isFalse);
      expect(account.currentIdentity?.userId, owner);
      expect(native.local, receipt);
      expect(native.pending, isEmpty);
      expect(native.boundOwners, isNot(contains(null)));
      expect(server.calls, isEmpty);
    },
  );

  test(
    'retryable SDK failure retains Auth and never clears Guardian owner',
    () async {
      final auth = AuthFixture();
      await auth.initialize(expired: true);
      auth.status = 503;
      final native = NativeOwner(), server = ServerRevoker();
      final account = await auth.bind(native, server);
      expect(
        await refreshAccountSession(account),
        AccountRefreshOutcome.failed,
      );
      expect(await account.ensureCurrentOwnerBound(), isTrue);
      expect(account.currentIdentity?.userId, owner);
      expect(native.local, receipt);
      expect(native.pending, isEmpty);
      expect(native.boundOwners, isNot(contains(null)));
      expect(server.calls, isEmpty);
      auth.status = 200;
      expect(
        await refreshAccountSession(account),
        AccountRefreshOutcome.refreshed,
      );
      expect(native.local, receipt);
    },
  );

  test(
    'terminal SDK loss journals cleanup and reconciles only on same-owner recovery',
    () async {
      final auth = AuthFixture();
      await auth.initialize(expired: true);
      auth.status = 400;
      final native = NativeOwner(), server = ServerRevoker();
      final account = await auth.bind(native, server);
      expect(await refreshAccountSession(account), AccountRefreshOutcome.ended);
      expect(await account.ensureCurrentOwnerBound(), isTrue);
      expect(account.currentIdentity, isNull);
      expect(native.local, isNull);
      expect(native.pending, [receipt]);
      expect(server.calls, isEmpty);
      await auth.client.auth.recoverSession(
        jsonEncode(sessionJson(owner, auth.nowSeconds + 3600)),
      );
      expect(await account.ensureCurrentOwnerBound(), isTrue);
      expect(server.calls, [(owner, receipt.deviceId, receipt.generation)]);
      expect(native.pending, isEmpty);
      expect(native.local, isNull); // Recovery is not receiver consent.
    },
  );

  for (final status in [200, 400, 503]) {
    test(
      'late $status refresh cannot replace or sign out a newer owner',
      () async {
        final auth = AuthFixture();
        await auth.initialize();
        auth.status = status;
        final native = NativeOwner(), server = ServerRevoker();
        final account = await auth.bind(native, server);
        final gate = Completer<void>();
        auth.replyGate = gate;
        final operation = refreshAccountSession(account);
        await auth.started.future.timeout(const Duration(seconds: 5));
        await auth.client.auth.recoverSession(
          jsonEncode(sessionJson(other, auth.nowSeconds + 3600)),
        );
        expect(await account.ensureCurrentOwnerBound(), isTrue);
        gate.complete();
        expect(await operation, AccountRefreshOutcome.accountChanged);
        expect(account.currentIdentity?.userId, other);
        expect(native.boundOwners.last, other);
        expect(native.pending, [receipt]);
        expect(native.local, isNull);
        expect(server.calls, isEmpty);
      },
    );
  }
}
