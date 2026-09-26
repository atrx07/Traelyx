import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/social/application/social_controller.dart';
import 'package:traelyx/features/social/domain/social.dart';
import 'package:traelyx/features/social/presentation/social_screen.dart';
import '../summary_sync/summary_sync_test.dart' show TestAccount, userA, userB;

final person = SocialPerson('other_driver', 'Other driver');
SocialEntry entry(SocialStatus status) =>
    SocialEntry('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 2, person, status);

class SocialFake implements SocialGateway {
  int reads = 0;
  int writes = 0;
  bool fail = false;
  final requests = <String>[];
  List<SocialEntry> rows = [];
  Future<void> Function()? onRead;
  @override
  Future<List<SocialEntry>> load(String owner) async {
    reads++;
    await onRead?.call();
    if (fail) throw Exception('sensitive provider body');
    return rows;
  }

  @override
  Future<SocialPerson?> lookup(String owner, String name) async => person;
  @override
  Future<void> request(
    String owner,
    SocialPerson person,
    String mutationId,
  ) async {
    requests.add(mutationId);
    writes++;
    rows = [entry(SocialStatus.outgoing)];
    if (fail) throw Exception('uncertain write');
  }

  @override
  Future<void> change(
    String owner,
    SocialEntry row,
    SocialAction action,
  ) async {
    writes++;
    rows = [];
  }
}

void main() {
  test('strict projection rejects extra private fields and invalid state', () {
    expect(
      () => SocialPerson.fromJson({
        'username': 'other_driver',
        'display_name': 'Other',
        'email': 'secret',
      }),
      throwsFormatException,
    );
    expect(
      () => SocialEntry.fromJson({
        'id': 'bad',
        'revision': 1,
        'username': 'other_driver',
        'display_name': 'Other',
        'state': 'friend',
      }),
      throwsFormatException,
    );
    expect(entry(SocialStatus.incoming).actions, contains(SocialAction.accept));
    expect(
      entry(SocialStatus.outgoing).actions,
      isNot(contains(SocialAction.accept)),
    );
    expect(entry(SocialStatus.blocked).actions, [SocialAction.unblock]);
  });
  test(
    'opening is inert; explicit load and edits use current account',
    () async {
      final gateway = SocialFake();
      final account = TestAccount();
      final controller = SocialController(userA, gateway, account);
      addTearDown(controller.dispose);
      expect(gateway.reads, 0);
      await controller.reload();
      expect(controller.state.loaded, isTrue);
      await controller.request(person);
      expect(gateway.writes, 1);
      expect(gateway.requests.single, hasLength(36));
      expect(controller.state.rows.single.status, SocialStatus.outgoing);
      await controller.change(
        controller.state.rows.single,
        SocialAction.accept,
      );
      expect(gateway.writes, 1);
      expect(controller.state.loaded, isFalse);
      account.user = userB;
      await controller.request(person);
      expect(gateway.writes, 1);
      expect(controller.state.rows, isEmpty);
    },
  );
  test(
    'account change during response clears results and stops follow-up',
    () async {
      final gateway = SocialFake()..rows = [entry(SocialStatus.friend)];
      final account = TestAccount();
      final controller = SocialController(userA, gateway, account);
      addTearDown(controller.dispose);
      gateway.onRead = () async {
        account.user = userB;
      };
      await controller.reload();
      expect(controller.state.rows, isEmpty);
      expect(controller.state.loaded, isFalse);
    },
  );
  test(
    'unknown write result is not retried automatically and requires reload',
    () async {
      final gateway = SocialFake()..fail = true;
      final controller = SocialController(userA, gateway, TestAccount());
      addTearDown(controller.dispose);
      await controller.request(person);
      expect(gateway.writes, 1);
      expect(controller.state.loaded, isFalse);
      expect(controller.state.notice, contains('may have completed'));
      expect(controller.state.notice, isNot(contains('uncertain write')));
      gateway.fail = false;
      await controller.reload();
      expect(controller.state.rows.single.status, SocialStatus.outgoing);
      expect(gateway.writes, 1);
    },
  );
  test(
    'serializes actions and safely ignores response after disposal',
    () async {
      final wait = Completer<void>();
      final gateway = SocialFake()..onRead = () => wait.future;
      final controller = SocialController(userA, gateway, TestAccount());
      final first = controller.reload();
      await controller.reload();
      expect(gateway.reads, 1);
      controller.dispose();
      wait.complete();
      await first;
    },
  );
  testWidgets(
    'request requires explicit disclosure confirmation, cancellation is inert',
    (tester) async {
      final gateway = SocialFake();
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountGatewayProvider.overrideWithValue(TestAccount()),
            socialGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp(
            theme: TraelyxTheme.dark,
            home: const Scaffold(body: SocialScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.reads, 0);
      await tester.enterText(find.byType(TextField), 'other_driver');
      await tester.tap(find.text('Find public profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send friend request'));
      await tester.tap(find.text('Send friend request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('even'), findsWidgets);
      expect(find.textContaining('No trip data'), findsOneWidget);
      await tester.tap(find.text('Keep unchanged'));
      await tester.pumpAndSettle();
      expect(gateway.writes, 0);
      await tester.tap(find.text('Send friend request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(gateway.writes, 1);
      expect(find.text('Request sent.'), findsOneWidget);
    },
  );
  testWidgets('incoming request can be blocked after confirmation', (
    tester,
  ) async {
    final gateway = SocialFake()..rows = [entry(SocialStatus.incoming)];
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(TestAccount()),
          socialGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          theme: TraelyxTheme.dark,
          home: const Scaffold(body: SocialScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reload connections'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Block'));
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unblocking does not restore'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(gateway.writes, 1);
    expect(find.text('Incoming request'), findsNothing);
  });
  testWidgets('signed-out large text remains scrollable without online reads', (
    tester,
  ) async {
    final gateway = SocialFake();
    final account = TestAccount()..user = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(account),
          socialGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: SocialScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(gateway.reads, 0);
    expect(find.textContaining('Sign in to manage'), findsOneWidget);
  });
}
