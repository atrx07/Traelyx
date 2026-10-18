import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';
import 'package:traelyx/features/guardian/guardian_driver_controls.dart';
import 'package:traelyx/features/guardian/guardian_driver_controls_panel.dart';

import 'guardian_driver_activation_test.dart'
    show TestAccount, ownerA, ownerB, reviewed;

class Controls implements GuardianDriverControls {
  int starts = 0, stops = 0;
  GuardianDriverReviewCancellation? token;
  Completer<DateTime>? activation;
  Completer<void>? stopping;
  bool failStop = false;
  @override
  Future<DateTime> activate(
    GuardianDriverConsent review,
    GuardianDriverReviewCancellation cancellation,
  ) async {
    starts++;
    expect(review.ownerId, ownerA);
    token = cancellation;
    return activation?.future ??
        DateTime.now().toUtc().add(const Duration(hours: 1));
  }

  @override
  Future<void> stop(String owner) async {
    expect(owner, ownerA);
    stops++;
    if (failStop) throw StateError('private raw error');
    await stopping?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('default build cannot resolve driver mutation controls', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(guardianDriverPilotProvider), isFalse);
    expect(container.read(guardianDriverSendingPilotProvider), isFalse);
    expect(container.read(guardianDriverControlsProvider), isNull);
  });

  test(
    'controller rejects sending consent while its pilot is unavailable',
    () async {
      final account = TestAccount();
      final controls = Controls();
      final c = GuardianDriverControlsController(
        ownerA,
        account,
        controls,
        () async => true,
      );
      addTearDown(c.dispose);
      addTearDown(account.changes.close);
      await c.activate(reviewed('+y', sending: true));
      expect(controls.starts, 0);
      expect(c.state.notice, contains('unavailable'));
    },
  );

  test(
    'idle and freshness preflights fail without activation or raw errors',
    () async {
      final account = TestAccount();
      final controls = Controls();
      var idle = false;
      var fail = false;
      final c = GuardianDriverControlsController(
        ownerA,
        account,
        controls,
        () async {
          if (fail) throw StateError('private raw error');
          return idle;
        },
      );
      addTearDown(c.dispose);
      addTearDown(account.changes.close);
      expect(await c.canReview(), isFalse);
      await c.activate(reviewed('+y'));
      expect(controls.starts, 0);
      idle = true;
      fail = true;
      expect(await c.canReview(), isFalse);
      expect(c.state.notice, isNot(contains('private')));
      fail = false;
      await c.activate(
        reviewed('+y', at: DateTime.now().subtract(const Duration(minutes: 3))),
      );
      account.change(ownerB);
      expect(await c.canReview(), isFalse);
      await c.activate(reviewed('+y'));
      expect(controls.starts, 0);
    },
  );

  test(
    'Stop stays usable during activation and a late success cannot replace it',
    () async {
      final account = TestAccount();
      final controls = Controls()..activation = Completer<DateTime>();
      final c = GuardianDriverControlsController(
        ownerA,
        account,
        controls,
        () async => true,
      );
      addTearDown(c.dispose);
      addTearDown(account.changes.close);
      final work = c.activate(reviewed('+y'));
      await Future<void>.delayed(Duration.zero);
      expect(c.state.activating, isTrue);
      await c.activate(reviewed('+y'));
      expect(controls.starts, 1);
      await c.stop();
      expect(controls.stops, 1);
      expect(controls.token!.isCancelled, isTrue);
      final stoppedNotice = c.state.notice;
      controls.activation!.complete(
        DateTime.now().add(const Duration(hours: 1)),
      );
      await work;
      expect(c.state.expiresAt, isNull);
      expect(c.state.notice, stoppedNotice);
      expect(c.state.activating, isFalse);
    },
  );

  test(
    'background and owner changes cancel their pending review without late success',
    () async {
      for (final changeOwner in [false, true]) {
        final account = TestAccount();
        final controls = Controls()..activation = Completer<DateTime>();
        final c = GuardianDriverControlsController(
          ownerA,
          account,
          controls,
          () async => true,
        );
        final work = c.activate(reviewed('+y'));
        await Future<void>.delayed(Duration.zero);
        if (changeOwner) {
          account.change(ownerB);
          await Future<void>.delayed(Duration.zero);
        } else {
          c.interrupt();
        }
        expect(controls.token!.isCancelled, isTrue);
        controls.activation!.complete(
          DateTime.now().add(const Duration(hours: 1)),
        );
        await work;
        expect(c.state.expiresAt, isNull);
        expect(c.state.notice, isNot(contains('saved')));
        c.dispose();
        await account.changes.close();
      }
    },
  );

  test('navigation disposes only its own cancellation token', () async {
    final account = TestAccount();
    final controls = Controls()..activation = Completer<DateTime>();
    final c = GuardianDriverControlsController(
      ownerA,
      account,
      controls,
      () async => true,
    );
    final work = c.activate(reviewed('+y'));
    await Future<void>.delayed(Duration.zero);
    final old = controls.token!;
    c.dispose();
    expect(old.isCancelled, isTrue);
    controls.activation!.complete(DateTime.now().add(const Duration(hours: 1)));
    await work;
    controls.activation = null;
    final next = GuardianDriverControlsController(
      ownerA,
      account,
      controls,
      () async => true,
    );
    await next.activate(reviewed('+y'));
    await old.cancel();
    expect(controls.token!.isCancelled, isFalse);
    expect(next.state.expiresAt, isNotNull);
    next.dispose();
    await account.changes.close();
  });

  test(
    'Stop skips idle checks, rejects duplicate work and reports uncertain failure',
    () async {
      final account = TestAccount();
      final controls = Controls()..stopping = Completer<void>();
      final c = GuardianDriverControlsController(
        ownerA,
        account,
        controls,
        () => throw StateError('No recorder mutation'),
      );
      addTearDown(c.dispose);
      addTearDown(account.changes.close);
      final stop = c.stop();
      await c.stop();
      expect(await c.canReview(), isFalse);
      await c.activate(reviewed('+y'));
      expect(controls.starts, 0);
      expect(controls.stops, 1);
      controls.stopping!.complete();
      await stop;
      controls.failStop = true;
      await c.stop();
      expect(c.state.notice, contains('could not be fully confirmed'));
      expect(c.state.notice, isNot(contains('private')));
    },
  );

  Future<void> panel(
    WidgetTester tester,
    TestAccount account,
    Controls controls, {
    bool pilot = true,
    Future<bool> Function()? idle,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(account),
          guardianDriverPilotProvider.overrideWithValue(pilot),
          guardianDriverControlsProvider.overrideWithValue(controls),
          guardianDriverIdleCheckProvider.overrideWithValue(
            idle ?? () async => true,
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: GuardianDriverControlsPanel(owner: ownerA),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> confirmChoices(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('guardian-forward-axis')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian-forward-axis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top edge').last);
    await tester.pumpAndSettle();
    for (final key in [
      'guardian-rigid-mount',
      'guardian-safety-limits',
      'guardian-recipient-sharing',
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('default-off panel performs no preflight or mutations', (
    tester,
  ) async {
    final account = TestAccount();
    final controls = Controls();
    addTearDown(account.changes.close);
    await panel(
      tester,
      account,
      controls,
      pilot: false,
      idle: () => throw StateError('No startup call'),
    );
    expect(find.text('Review driver alerts'), findsNothing);
    expect(find.text('Stop driver alerts'), findsNothing);
    expect(controls.starts + controls.stops, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cancelling review never calls activation; confirmation reports only consent',
    (tester) async {
      final account = TestAccount();
      final controls = Controls();
      addTearDown(account.changes.close);
      var checks = 0;
      await panel(
        tester,
        account,
        controls,
        idle: () async {
          checks++;
          return true;
        },
      );
      expect(checks, 0);
      await tester.tap(find.text('Review driver alerts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controls.starts, 0);
      expect(checks, 1);
      await tester.tap(find.text('Review driver alerts'));
      await tester.pumpAndSettle();
      await confirmChoices(tester);
      await tester.tap(find.byKey(const ValueKey('guardian-confirm-review')));
      await tester.pumpAndSettle();
      expect(controls.starts, 1);
      expect(checks, 3);
      expect(find.textContaining('Driver consent saved.'), findsOneWidget);
      expect(find.textContaining('sending is unavailable'), findsWidgets);
      expect(find.text('Experimental evaluation observed'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backgrounded modal review cannot activate after resume', (
    tester,
  ) async {
    final account = TestAccount();
    final controls = Controls();
    addTearDown(account.changes.close);
    await panel(tester, account, controls);
    await tester.tap(find.text('Review driver alerts'));
    await tester.pumpAndSettle();
    await confirmChoices(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guardian-confirm-review')));
    await tester.pumpAndSettle();
    expect(controls.starts, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Review driver alerts'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'large text keeps Stop reachable and route removal cancels pending activation',
    (tester) async {
      final account = TestAccount();
      final controls = Controls()..activation = Completer<DateTime>();
      addTearDown(account.changes.close);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await panel(tester, account, controls, scale: 1.7);
      await tester.ensureVisible(find.text('Review driver alerts'));
      await tester.tap(find.text('Review driver alerts'));
      await tester.pumpAndSettle();
      await confirmChoices(tester);
      await tester.tap(find.byKey(const ValueKey('guardian-confirm-review')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(find.text('Stop driver alerts'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Stop driver alerts'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controls.token!.isCancelled, isTrue);
      controls.activation!.complete(
        DateTime.now().add(const Duration(hours: 1)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('background during idle preflight cannot open a stale review', (
    tester,
  ) async {
    final account = TestAccount();
    final controls = Controls();
    addTearDown(account.changes.close);
    final idle = Completer<bool>();
    await panel(tester, account, controls, idle: () => idle.future);
    await tester.tap(find.text('Review driver alerts'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    idle.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(controls.starts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
