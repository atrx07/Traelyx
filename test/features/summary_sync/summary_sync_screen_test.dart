import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_providers.dart';
import 'package:traelyx/features/summary_sync/presentation/summary_sync_screen.dart';

import 'summary_sync_test.dart' show TestAccount, TestCloud, seedTrip, tripA;

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
}
