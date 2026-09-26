import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/guardian/guardian_controller.dart';
import 'package:traelyx/features/guardian/guardian_models.dart';
import 'package:traelyx/features/guardian/guardian_screen.dart';
import '../summary_sync/summary_sync_test.dart' show TestAccount, userA, userB;

const guardianTestId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
final guardianTestToken = List.filled(64, 'a').join();
const guardianTestPermissions = GuardianPermissions();
GuardianInvite issuedInvite() => GuardianInvite(
  guardianTestId,
  DateTime.now().add(const Duration(minutes: 10)),
  guardianTestPermissions,
  token: guardianTestToken,
);
GuardianPreview previewInvite() => GuardianPreview(
  issuedInvite(),
  'driver_name',
  'Driver',
  'my_name',
  'My name',
);
GuardianConnection connection({
  String role = 'driver',
  String state = 'confirm',
  int revision = 1,
}) => GuardianConnection(
  guardianTestId,
  revision,
  role,
  'trusted_name',
  'Trusted name',
  state,
  guardianTestPermissions,
  DateTime.utc(2026),
  const [],
);

class GuardianFake implements GuardianGateway {
  int reads = 0,
      creates = 0,
      accepts = 0,
      changes = 0,
      cancels = 0,
      previews = 0;
  bool fail = false;
  Future<void> Function()? onCreate;
  Future<void> Function()? onRead;
  GuardianSnapshot snapshot = const GuardianSnapshot(
    username: 'my_name',
    displayName: 'My name',
  );
  GuardianInvite? nextInvite;
  @override
  Future<GuardianSnapshot> load(String owner) async {
    reads++;
    await onRead?.call();
    return snapshot;
  }

  @override
  Future<GuardianInvite> create(
    String owner,
    String username,
    String name,
    GuardianPermissions p,
  ) async {
    creates++;
    await onCreate?.call();
    if (fail) throw Exception('secret response $guardianTestToken');
    return nextInvite ?? issuedInvite();
  }

  @override
  Future<void> cancel(String owner, String inviteId) async {
    cancels++;
  }

  @override
  Future<GuardianPreview?> preview(String owner, String token) async {
    previews++;
    return previewInvite();
  }

  @override
  Future<void> accept(
    String owner,
    GuardianPreview preview,
    String token,
  ) async {
    accepts++;
    if (fail) throw Exception('uncertain');
  }

  @override
  Future<void> change(
    String owner,
    GuardianConnection row,
    GuardianAction action, {
    GuardianPermissions? permissions,
  }) async {
    changes++;
    if (fail) throw Exception('uncertain');
  }
}

void main() {
  test(
    'strict permissions preserve defaults and reject unsupported access',
    () {
      final p = guardianTestPermissions.toJson();
      expect(p['crash_alert'], true);
      expect(p.values.where((v) => v), hasLength(1));
      expect(GuardianPermissions.fromJson(p).crash, true);
      for (final key in ['live_location', 'current_speed', 'trip_history']) {
        expect(
          () => GuardianPermissions.fromJson({...p, key: true}),
          throwsFormatException,
        );
      }
      expect(
        () => GuardianPermissions.fromJson({...p, 'extra': false}),
        throwsFormatException,
      );
      expect(
        () => GuardianInvite.fromJson({
          'id': guardianTestId,
          'expires_at': DateTime.now().toIso8601String(),
          'permissions': p,
          'token': guardianTestToken,
        }),
        throwsFormatException,
      );
      expect(
        () => GuardianSnapshot.fromJson({
          'profile': null,
          'invite': null,
          'connections': <Object?>[],
          'email': 'private',
        }),
        throwsFormatException,
      );
      expect(
        connection(role: 'guardian', state: 'active').actions,
        isNot(contains(GuardianAction.permissions)),
      );
      expect(connection(state: 'blocked').actions, [GuardianAction.unblock]);
    },
  );
  test(
    'inert construction and explicit account-checked create cancel',
    () async {
      final fake = GuardianFake();
      final c = GuardianController(userA, fake, TestAccount());
      addTearDown(c.dispose);
      expect(fake.reads, 0);
      await c.create(guardianTestPermissions);
      expect(fake.creates, 0);
      await c.reload();
      await c.create(guardianTestPermissions);
      expect(fake.creates, 1);
      expect(c.state.issued?.token, guardianTestToken);
      await c.cancel(c.state.issued!);
      expect(fake.cancels, 1);
      expect(c.state.issued, isNull);
    },
  );
  test('lost response hides secrets; no automatic retry', () async {
    final fake = GuardianFake()..fail = true;
    final c = GuardianController(userA, fake, TestAccount());
    addTearDown(c.dispose);
    await c.reload();
    await c.create(guardianTestPermissions);
    expect(fake.creates, 1);
    expect(c.state.loaded, false);
    expect(c.state.issued, isNull);
    expect(c.state.notice, isNot(contains(guardianTestToken)));
    await c.create(guardianTestPermissions);
    expect(fake.creates, 1);
  });
  test('backgrounding during create cannot restore an invite secret', () async {
    final gate = Completer<void>();
    final fake = GuardianFake()..onCreate = () => gate.future;
    final c = GuardianController(userA, fake, TestAccount());
    addTearDown(c.dispose);
    await c.reload();
    final pending = c.create(guardianTestPermissions);
    await Future<void>.delayed(Duration.zero);
    c.clearSecrets();
    gate.complete();
    await pending;
    expect(c.state.issued, isNull);
    expect(c.state.loaded, false);
  });
  test(
    'account switch after read or create rejects response and follow-up',
    () async {
      final account = TestAccount();
      final fake = GuardianFake();
      final c = GuardianController(userA, fake, account);
      addTearDown(c.dispose);
      fake.onRead = () async {
        account.user = userB;
      };
      await c.reload();
      expect(c.state.snapshot, isNull);
      account.user = userA;
      fake.onRead = null;
      await c.reload();
      fake.onCreate = () async {
        account.user = userB;
      };
      await c.create(guardianTestPermissions);
      expect(c.state.issued, isNull);
      await c.reload();
      expect(fake.reads, 2);
    },
  );
  test(
    'accept requires current reviewed invite; clearing invalidates consent',
    () async {
      final fake = GuardianFake();
      final c = GuardianController(userA, fake, TestAccount());
      addTearDown(c.dispose);
      await c.preview(guardianTestToken);
      final preview = c.state.preview!;
      c.clearSecrets();
      await c.accept(preview);
      expect(fake.accepts, 0);
      await c.preview(guardianTestToken);
      await c.accept(c.state.preview!);
      expect(fake.accepts, 1);
      expect(c.state.preview, isNull);
    },
  );
  test(
    'stale or cleared connection cannot be changed; uncertain change requires reload',
    () async {
      final fake = GuardianFake()
        ..snapshot = GuardianSnapshot(
          username: 'my_name',
          displayName: 'My name',
          connections: [connection()],
        );
      final c = GuardianController(userA, fake, TestAccount());
      addTearDown(c.dispose);
      await c.reload();
      await c.change(connection(revision: 2), GuardianAction.confirm);
      expect(fake.changes, 0);
      await c.reload();
      fake.fail = true;
      await c.change(connection(), GuardianAction.confirm);
      expect(fake.changes, 1);
      await c.change(connection(), GuardianAction.confirm);
      expect(fake.changes, 1);
    },
  );
  test('concurrent clicks issue only one mutation', () async {
    final gate = Completer<void>();
    final fake = GuardianFake()..onCreate = () => gate.future;
    final c = GuardianController(userA, fake, TestAccount());
    addTearDown(c.dispose);
    await c.reload();
    final pending = c.create(guardianTestPermissions);
    await c.create(guardianTestPermissions);
    expect(fake.creates, 1);
    gate.complete();
    await pending;
  });
  testWidgets(
    'create consent can be cancelled and background clears visible code',
    (tester) async {
      final fake = GuardianFake();
      tester.view.physicalSize = const Size(500, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountGatewayProvider.overrideWithValue(TestAccount()),
            guardianGatewayProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: TraelyxTheme.dark,
            home: const Scaffold(body: GuardianScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.reads, 0);
      await tester.tap(find.text('Reload Guardian'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review new invite'));
      await tester.tap(find.text('Review new invite'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No trip data is shared'), findsOneWidget);
      await tester.tap(find.text('Keep unchanged'));
      await tester.pumpAndSettle();
      expect(fake.creates, 0);
      await tester.tap(find.text('Review new invite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create invite'));
      await tester.pumpAndSettle();
      expect(fake.creates, 1);
      await tester.ensureVisible(find.text('Copy invite code'));
      expect(find.text(guardianTestToken), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(find.text(guardianTestToken), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'explicit preview acceptance and driver confirmation are separately reviewed',
    (tester) async {
      final fake = GuardianFake();
      tester.view.physicalSize = const Size(500, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountGatewayProvider.overrideWithValue(TestAccount()),
            guardianGatewayProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: TraelyxTheme.dark,
            home: const Scaffold(body: GuardianScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), guardianTestToken);
      await tester.ensureVisible(find.text('Review invite code'));
      await tester.tap(find.text('Review invite code'));
      await tester.pumpAndSettle();
      expect(fake.accepts, 0);
      await tester.ensureVisible(find.text('Review acceptance'));
      await tester.tap(find.text('Review acceptance'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('even if your profile is private'),
        findsOneWidget,
      );
      await tester.tap(find.text('Accept invite'));
      await tester.pumpAndSettle();
      expect(fake.accepts, 1);
      fake.snapshot = GuardianSnapshot(
        username: 'my_name',
        displayName: 'My name',
        connections: [connection()],
      );
      await tester.ensureVisible(find.text('Reload Guardian'));
      await tester.tap(find.text('Reload Guardian'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Confirm trusted person'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm trusted person'));
      await tester.pumpAndSettle();
      expect(fake.changes, 0);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm trusted person'),
      );
      await tester.pumpAndSettle();
      expect(fake.changes, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('code expiry clears secret without a network request', (
    tester,
  ) async {
    final fake = GuardianFake()
      ..nextInvite = GuardianInvite(
        guardianTestId,
        DateTime.now().add(const Duration(seconds: 1)),
        guardianTestPermissions,
        token: guardianTestToken,
      );
    final c = GuardianController(userA, fake, TestAccount());
    await c.reload();
    await c.create(guardianTestPermissions);
    expect(c.state.issued, isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(c.state.issued, isNull);
    expect(fake.reads, 1);
    c.dispose();
  });
  testWidgets('signed-out large text is accountless and performs no reads', (
    tester,
  ) async {
    final fake = GuardianFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(TestAccount()..user = null),
          guardianGatewayProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: GuardianScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.reads, 0);
    expect(find.text('Open Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
