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
import 'package:traelyx/features/guardian/guardian_gateway.dart';
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
}
