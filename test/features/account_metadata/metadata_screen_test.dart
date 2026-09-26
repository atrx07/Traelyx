import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account_metadata/application/metadata_providers.dart';
import 'package:traelyx/features/account_metadata/presentation/metadata_screen.dart';

import '../summary_sync/summary_sync_test.dart' show TestAccount;
import 'metadata_test.dart' show MetadataCloud;

void main() {
  for (final publish in [false, true]) {
    testWidgets(
      'profile defaults private, cancel is inert, explicit save public=$publish',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final cloud = MetadataCloud();
        tester.view.physicalSize = const Size(430, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              accountGatewayProvider.overrideWithValue(TestAccount()),
              metadataGatewayProvider.overrideWithValue(cloud),
            ],
            child: MaterialApp(
              theme: TraelyxTheme.dark,
              home: const Scaffold(body: MetadataScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cloud.calls, isEmpty);
        final edit = find.byKey(const ValueKey('edit-cloud-profile'));
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('metadata-public-choice')),
              )
              .value,
          isFalse,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await db.select(db.accountMetadataCache).get(), isEmpty);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('metadata-display-name')),
          'Synthetic driver',
        );
        await tester.enterText(
          find.byKey(const ValueKey('metadata-username')),
          'synthetic_driver',
        );
        if (publish) {
          final choice = find.byKey(const ValueKey('metadata-public-choice'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
        }
        expect(
          find.text(publish ? 'Save public profile' : 'Save privately'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('confirm-metadata-save')));
        await tester.pumpAndSettle();
        expect(cloud.calls, hasLength(1));
        expect(cloud.calls.single.data.isPublic, publish);
        expect(await db.select(db.tripAccountLinks).get(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('signed-out metadata route is gated at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGatewayProvider.overrideWithValue(TestAccount()..user = null),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: MetadataScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-cloud-profile')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Sign in to manage optional profile and vehicle sync.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Sign in to manage optional profile and vehicle sync.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
