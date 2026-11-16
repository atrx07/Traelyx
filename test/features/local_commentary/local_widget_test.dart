import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_providers.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_service.dart';
import 'package:traelyx/features/local_commentary/data/local_model_store.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';
import 'package:traelyx/features/local_commentary/presentation/local_commentary_card.dart';

class StatusService extends LocalCommentaryService {
  StatusService()
    : super(
        catalog: () async =>
            LocalModelCatalog.parse('{"schemaVersion":1,"models":[]}'),
        device: () async => throw StateError('unused'),
        runtime: const UnavailableLocalRuntime(),
        source: const UnavailableLocalSource(),
        isRecorderIdle: () async => true,
      );
  int reads = 0, removals = 0;
  bool fail = false;
  LocalModelInventory inventory = const LocalModelInventory(217, 0, 1);
  @override
  Future<LocalModelStatus> status() async {
    reads++;
    if (fail) throw const LocalCommentaryException(LocalFailure.storage);
    return LocalModelStatus(
      inventory,
      0,
      false,
      LocalDevice(
        root: '/private-path',
        androidApi: 37,
        abis: ['x86_64'],
        freeBytes: 9999,
      ),
    );
  }

  @override
  Future<void> removeModels({
    required bool parked,
    required bool confirmed,
  }) async {
    if (!parked || !confirmed) throw StateError('Missing confirmation');
    removals++;
    inventory = const LocalModelInventory(0, 0, 0);
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    StatusService service, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localCommentaryServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: LocalCommentaryCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opening settings does no storage/model work; explicit refresh reports real bytes',
    (tester) async {
      final service = StatusService();
      await pump(tester, service);
      expect(service.reads, 0);
      expect(find.textContaining('Unavailable in this build'), findsOneWidget);
      await tester.tap(find.text('Refresh local model status'));
      await tester.pumpAndSettle();
      expect(service.reads, 1);
      expect(find.textContaining('217 bytes'), findsOneWidget);
      expect(find.textContaining('/private-path'), findsNothing);
      expect(find.textContaining('0 models'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'removal requires parked and final confirmation; background resets parked',
    (tester) async {
      final service = StatusService();
      await pump(tester, service);
      await tester.tap(find.text('Refresh local model status'));
      await tester.pumpAndSettle();
      final remove = find.widgetWithText(
        OutlinedButton,
        'Review removal of model files',
      );
      expect(tester.widget<OutlinedButton>(remove).onPressed, null);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(remove).onPressed, null);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep files'));
      await tester.pumpAndSettle();
      expect(service.removals, 0);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove model files'));
      await tester.pumpAndSettle();
      expect(service.removals, 1);
      expect(find.textContaining('0 bytes'), findsOneWidget);
    },
  );
  testWidgets(
    'large text remains scrollable and storage failure never claims zero bytes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = StatusService()..fail = true;
      await pump(tester, service, scale: 1.7);
      await tester.ensureVisible(find.text('Refresh local model status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh local model status'));
      await tester.pumpAndSettle();
      expect(find.textContaining('storage is unavailable'), findsOneWidget);
      expect(find.textContaining('0 bytes'), findsNothing);
      expect(tester.takeException(), null);
    },
  );
}
