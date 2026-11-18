import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_providers.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_service.dart';
import 'package:traelyx/features/summary_sync/data/summary_sync_repository.dart';
import 'package:traelyx/features/summary_sync/presentation/summary_sync_screen.dart';

import '../../support/failure_ux_capture.dart';
import 'summary_sync_test.dart'
    show TestAccount, TestCloud, seedTrip, tripA, userA;

void main() {
  testWidgets(
    'review/cancel sends nothing; explicit confirmation uploads one compact snapshot',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTrip(db, tripA);
      final cloud = TestCloud();
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            accountGatewayProvider.overrideWithValue(TestAccount()),
            summaryCloudGatewayProvider.overrideWithValue(cloud),
          ],
          child: MaterialApp(
            theme: TraelyxTheme.dark,
            home: const Scaffold(body: SummarySyncScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cloud.calls, isEmpty);
      final review = find.byKey(const ValueKey('review-summary-upload'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep local'));
      await tester.pumpAndSettle();
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
      expect(cloud.calls, isEmpty);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-summary-upload')));
      await tester.pumpAndSettle();
      expect(cloud.calls, hasLength(1));
      expect((await db.select(db.syncQueue).getSingle()).state, 'synced');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signed-out summary deep link cannot review or upload', (
    tester,
  ) async {
    final account = TestAccount()..user = null;
    final cloud = TestCloud();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(account),
          summaryCloudGatewayProvider.overrideWithValue(cloud),
        ],
        child: const MaterialApp(home: Scaffold(body: SummarySyncScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Sign in to review optional summary sync.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-summary-upload')), findsNothing);
    expect(cloud.calls, isEmpty);
  });

  testWidgets(
    'offline upload preserves history and queue until a due explicit retry',
    (tester) async {
      await tester.runAsync(loadFailureUxFonts);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTrip(db, tripA);
      final before = (await db.select(db.trips).getSingle()).toJson()
        ..remove('cloudSyncState');
      final account = TestAccount();
      final cloud = TestCloud()..fail = true;
      var now = DateTime.utc(2030);
      final service = SummarySyncService(
        SummarySyncRepository(db),
        cloud,
        account,
        clock: () => now,
      );
      await service.consent(await service.preview(userA));
      final payload = (await db.select(db.syncQueue).getSingle()).payloadJson;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            accountGatewayProvider.overrideWithValue(account),
            summarySyncServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: failureUxTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: failureUxBoundary(const Scaffold(body: SummarySyncScreen())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('retry-summary-upload'));
      Future<void> reveal(Finder target) async {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }

      await reveal(retry);
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(cloud.calls, hasLength(1));
      await reveal(
        find.textContaining('Local trips and queued summaries are retained'),
      );
      expect(
        find.textContaining('Local trips and queued summaries are retained'),
        findsOneWidget,
      );
      var queued = await db.select(db.syncQueue).getSingle();
      expect(queued.state, 'retry');
      expect(queued.payloadJson, payload);
      expect(queued.attemptCount, 1);
      await tester.ensureVisible(
        find.textContaining('Local trips and queued summaries are retained'),
      );
      await captureFailureUx(tester, 'offline-sync-2x');
      await tester.pump(const Duration(seconds: 60));
      expect(cloud.calls, hasLength(1));
      await reveal(retry);
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(cloud.calls, hasLength(1));
      await reveal(find.textContaining('No summaries uploaded this attempt'));
      expect(
        find.textContaining('No summaries uploaded this attempt'),
        findsOneWidget,
      );
      now = now.add(const Duration(seconds: 31));
      cloud.fail = false;
      await reveal(retry);
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(cloud.calls, hasLength(2));
      queued = await db.select(db.syncQueue).getSingle();
      expect(queued.state, 'synced');
      final after = (await db.select(db.trips).getSingle()).toJson()
        ..remove('cloudSyncState');
      expect(jsonEncode(after), jsonEncode(before));
      expect(tester.takeException(), isNull);
    },
  );
}
