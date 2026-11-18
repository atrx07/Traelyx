import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/settings/drift_non_secret_settings_repository.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/cloud_commentary/application/cloud_commentary_service.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/cloud_commentary/presentation/cloud_commentary_screen.dart';
import 'package:traelyx/features/cloud_commentary/presentation/cloud_replay_control.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

import '../../support/failure_ux_capture.dart';
import 'cloud_fixture.dart';

void main() {
  late AppDatabase db;
  late MemoryCloudVault vault;
  late _Provider provider;
  late CloudCommentaryService service;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vault = MemoryCloudVault();
    provider = _Provider();
    service = CloudCommentaryService(
      secureStore: vault,
      settings: DriftNonSecretSettingsRepository(db),
      provider: provider,
      modelPolicy: fixturePolicy,
      isRecorderIdle: () async => true,
    );
  });
  tearDown(() async {
    service.cancel();
    await db.close();
  });
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    bool readableCapture = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cloudCommentaryServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: readableCapture ? failureUxTheme() : TraelyxTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: failureUxBoundary(child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      final scrollable = find.byType(AlertDialog).evaluate().isEmpty
          ? find.byType(Scrollable).first
          : find.byType(Scrollable).last;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> setupCloud() async {
    await service.saveKey('fixture-placeholder');
    await service.configure(
      enabled: true,
      mode: CloudModelMode.custom,
      model: 'llama-fixture',
    );
  }

  Future<void> sendReviewed(WidgetTester tester) async {
    await reveal(tester, find.byKey(const ValueKey('cloud-replay-parked')));
    await tester.tap(find.byKey(const ValueKey('cloud-replay-parked')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('cloud-review-request')));
    await tester.tap(find.byKey(const ValueKey('cloud-review-request')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('cloud-confirm-send')),
          )
          .onPressed,
      null,
    );
    expect(provider.generations, 0);
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('cloud-dossier-review')),
          )
          .data,
      isNot(contains('private untrusted')),
    );
    await reveal(tester, find.byKey(const ValueKey('cloud-send-consent')));
    await tester.tap(find.byKey(const ValueKey('cloud-send-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cloud-confirm-send')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'commentary settings deep link opens in the You branch without HTTP',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = createTraelyxRouter(
        initialLocation: TraelyxRoutes.youCommentary,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudCommentaryServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        TraelyxRoutes.youCommentary,
      );
      expect(find.text('Commentary engine'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      expect(provider.calls, 0);
    },
  );
  testWidgets(
    'settings load is local, credential is obscured and save leaves permission off',
    (tester) async {
      await pump(tester, const CloudCommentaryScreen());
      expect(provider.calls, 0);
      await reveal(tester, find.byKey(const ValueKey('cloud-permission')));
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('cloud-permission')),
            )
            .value,
        false,
      );
      await reveal(tester, find.byKey(const ValueKey('cloud-key-input')));
      final input = find.byKey(const ValueKey('cloud-key-input'));
      expect(tester.widget<TextField>(input).obscureText, true);
      expect(
        tester.widget<TextField>(input).enableIMEPersonalizedLearning,
        false,
      );
      await tester.enterText(input, 'fixture-placeholder');
      await reveal(tester, find.byKey(const ValueKey('cloud-save-key')));
      await tester.tap(find.byKey(const ValueKey('cloud-save-key')));
      await tester.pumpAndSettle();
      expect(vault.value, 'fixture-placeholder');
      expect(provider.calls, 0);
      expect((await service.load()).configuration.enabled, false);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      await reveal(tester, find.byKey(const ValueKey('cloud-remove-key')));
      await tester.tap(find.byKey(const ValueKey('cloud-remove-key')));
      await tester.pumpAndSettle();
      expect(vault.value, null);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'large text settings and reduced motion remain scrollable; leaving app clears parked state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, const CloudCommentaryScreen(), scale: 1.7);
      await reveal(tester, find.byKey(const ValueKey('cloud-settings-parked')));
      await tester.tap(find.byKey(const ValueKey('cloud-settings-parked')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('cloud-settings-parked')),
            )
            .value,
        true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('cloud-settings-parked')),
            )
            .value,
        false,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(provider.calls, 0);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'replay sends only after exact review and keeps cloud output session-only',
    (tester) async {
      await setupCloud();
      var plan = fixturePlan();
      var applied = 0;
      var paused = 0;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: SingleChildScrollView(
              child: CloudReplayControl(
                plan: plan,
                pause: () => paused++,
                onApply: (value) {
                  applied++;
                  update(() => plan = value);
                },
                onBuiltin: () => update(() => plan = fixturePlan()),
              ),
            ),
          ),
        ),
      );
      expect(provider.calls, 0);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cloud-review-request')),
            )
            .onPressed,
        null,
      );
      await sendReviewed(tester);
      expect(provider.generations, 1);
      expect(applied, 1);
      expect(paused, greaterThan(0));
      expect(
        find.textContaining('Groq selected reviewed wording'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('cloud-replay-parked')),
            )
            .value,
        false,
      );
      expect(
        (await db.select(db.appSettings).get()).every(
          (row) => !row.value.contains('wordingChoices'),
        ),
        true,
      );
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'declining a reviewed request returns to built-in without generation',
    (tester) async {
      await setupCloud();
      var builtin = 0;
      await pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: CloudReplayControl(
              plan: fixturePlan(),
              pause: () {},
              onApply: (_) => fail('unapproved generation applied'),
              onBuiltin: () => builtin++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('cloud-replay-parked')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cloud-review-request')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep built-in'));
      await tester.pumpAndSettle();
      expect(provider.generations, 0);
      expect(builtin, 1);
    },
  );
  testWidgets(
    'background cancellation discards a late response and restores built-in narration',
    (tester) async {
      await setupCloud();
      provider.pending = Completer<ProceduralCommentaryPlan>();
      final plan = fixturePlan();
      var applied = 0;
      var builtin = 0;
      await pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: CloudReplayControl(
              plan: plan,
              pause: () {},
              onApply: (_) => applied++,
              onBuiltin: () => builtin++,
            ),
          ),
        ),
      );
      await sendReviewed(tester);
      expect(provider.generations, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      provider.pending!.complete(plan);
      await tester.pumpAndSettle();
      expect(applied, 0);
      expect(builtin, 1);
      // Paused apps do not paint; inspect the rebuilt controls after resuming.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('cloud-replay-parked')),
            )
            .value,
        false,
      );
      expect(applied, 0);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'a rejected settings key can be replaced locally without another request',
    (tester) async {
      await tester.runAsync(loadFailureUxFonts);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await setupCloud();
      provider.failure = CloudFailure.credential;
      await pump(
        tester,
        const CloudCommentaryScreen(),
        scale: 2,
        readableCapture: true,
      );
      await reveal(tester, find.byKey(const ValueKey('cloud-settings-parked')));
      await tester.tap(find.byKey(const ValueKey('cloud-settings-parked')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('cloud-refresh-models')));
      await tester.tap(find.byKey(const ValueKey('cloud-refresh-models')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cloud-settings-notice')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cloud-settings-notice')))
            .data,
        contains('key is missing or was rejected'),
      );
      expect(provider.calls, 1);
      await captureFailureUx(tester, 'cloud-settings-key-2x');
      await reveal(tester, find.byKey(const ValueKey('cloud-key-input')));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('cloud-key-input')))
            .obscureText,
        true,
      );
      await tester.enterText(
        find.byKey(const ValueKey('cloud-key-input')),
        'synthetic-replacement',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('cloud-save-key')));
      await tester.tap(find.byKey(const ValueKey('cloud-save-key')));
      await tester.pumpAndSettle();
      expect(vault.value, 'synthetic-replacement');
      expect(provider.calls, 1);
      expect((await service.load()).configuration.enabled, false);
      expect(find.textContaining('synthetic-replacement'), findsNothing);
      expect(
        find.byKey(const ValueKey('cloud-settings-notice')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .getBottomRight(
              find.byKey(const ValueKey('cloud-settings-feedback')),
            )
            .dy,
        lessThanOrEqualTo(544),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in [
    CloudFailure.credential,
    CloudFailure.network,
    CloudFailure.timeout,
    CloudFailure.rateLimit,
    CloudFailure.modelUnavailable,
    CloudFailure.malformed,
    CloudFailure.server,
    CloudFailure.refused,
  ]) {
    testWidgets(
      '${failure.name} shows bounded guidance and explicit recovery without auto retry',
      (tester) async {
        await tester.runAsync(loadFailureUxFonts);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await setupCloud();
        provider.failure = failure;
        final plan = fixturePlan();
        var applied = 0;
        var builtin = 0;
        await pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: CloudReplayControl(
                plan: plan,
                pause: () {},
                onApply: (_) => applied++,
                onBuiltin: () => builtin++,
              ),
            ),
          ),
          scale: 2,
          readableCapture: true,
        );
        await sendReviewed(tester);
        final notice = find.byKey(const ValueKey('cloud-replay-notice'));
        await reveal(tester, notice);
        expect(
          tester.widget<Text>(notice).data,
          contains(cloudFailureMessage(CloudException(failure))),
        );
        expect(
          tester.widget<Text>(notice).data,
          contains('Built-in narration is available'),
        );
        expect(find.textContaining('fixture-placeholder'), findsNothing);
        expect(applied, 0);
        expect(builtin, 1);
        expect(provider.generations, 1);
        await tester.pump(const Duration(seconds: 60));
        expect(provider.generations, 1);
        if (failure == CloudFailure.credential ||
            failure == CloudFailure.network ||
            failure == CloudFailure.malformed) {
          await captureFailureUx(tester, 'cloud-${failure.name}-2x');
        }
        // A new explicit review/send can recover; no settings, event or score rewrite.
        provider.failure = null;
        await reveal(
          tester,
          find.byKey(const ValueKey('cloud-review-request')),
        );
        await tester.tap(find.byKey(const ValueKey('cloud-review-request')));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('cloud-send-consent')));
        await tester.tap(find.byKey(const ValueKey('cloud-send-consent')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cloud-confirm-send')));
        await tester.pumpAndSettle();
        expect(provider.generations, 2);
        expect(applied, 1);
        expect((await service.load()).configuration.enabled, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Provider implements CommentaryProvider {
  @override
  String get id => 'groq';
  int calls = 0;
  int generations = 0;
  CloudFailure? failure;
  Completer<ProceduralCommentaryPlan>? pending;
  @override
  Future<List<CloudModel>> listModels(
    String credential,
    CloudCancellation cancellation,
  ) async {
    calls++;
    if (failure != null) throw CloudException(failure!);
    return const [CloudModel('llama-fixture', 8192)];
  }

  @override
  Future<ProceduralCommentaryPlan> generate({
    required String credential,
    required String model,
    required CommentaryDossier dossier,
    required CloudCancellation cancellation,
  }) async {
    calls++;
    generations++;
    if (failure != null) throw CloudException(failure!);
    return pending?.future ??
        Future.value(
          dossier.apply({
            'choices': [1, 0],
          }),
        );
  }
}
