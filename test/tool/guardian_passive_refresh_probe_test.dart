import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';

import '../../tool/guardian_passive_refresh_probe.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const receipt = GuardianRecipientLocalStatus(
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
);

class Source implements PassiveRefreshSource {
  Source(this.metadata);
  @override
  PassiveSessionMetadata metadata;
  final events = StreamController<PassiveSessionEvent>.broadcast(sync: true);
  @override
  Stream<PassiveSessionEvent> get refreshEvents => events.stream;
}

class Fixture {
  DateTime now = DateTime.utc(2026, 11, 9);
  int get seconds => now.millisecondsSinceEpoch ~/ 1000;
  late final source = Source(PassiveSessionMetadata(owner, seconds + 60));
  GuardianRecipientLocalStatus? currentReceipt = receipt;
  bool pending = false;
  bool driverDisabled = true;
  bool failRead = false;
  int initializations = 0;
  Completer<void>? gate;
  void Function()? onRead;
  late final runtime = PassiveRefreshRuntime(source, (_) async {
    if (gate != null) await gate!.future;
    onRead?.call();
    if (failRead) throw StateError('private provider detail');
    return PassiveRecipientAuthority(
      receipt: currentReceipt,
      pendingCleanup: pending,
      driverDisabled: driverDisabled,
    );
  });

  Future<GuardianPassiveRefreshProbe?> prepare({
    bool debug = true,
    bool enabled = true,
    bool pilotsOff = true,
    String project = 'https://ksydjfcyzdtpbigskahm.supabase.co',
    Duration window = const Duration(minutes: 2),
    Duration readTimeout = const Duration(seconds: 1),
  }) async {
    final probe = await GuardianPassiveRefreshProbe.prepare(
      debugBuild: debug,
      enabled: enabled,
      pilotsOff: pilotsOff,
      projectUrl: project,
      initialize: () async {
        initializations++;
        return runtime;
      },
      now: () => now,
      window: window,
      readTimeout: readTimeout,
    );
    if (probe != null) addTearDown(probe.dispose);
    return probe;
  }

  void refresh({bool event = true}) {
    source.metadata = PassiveSessionMetadata(owner, seconds + 3600);
    source.events.add(
      event ? PassiveSessionEvent.refreshed : PassiveSessionEvent.other,
    );
  }

  void dispose() => unawaited(source.events.close());
}

void main() {
  late Fixture fixture;
  setUp(() => fixture = Fixture());
  tearDown(() => fixture.dispose());

  test('closed build/project/pilot guards never initialize Auth', () async {
    expect(await fixture.prepare(debug: false), isNull);
    expect(await fixture.prepare(enabled: false), isNull);
    expect(await fixture.prepare(pilotsOff: false), isNull);
    expect(await fixture.prepare(project: 'https://example.invalid'), isNull);
    expect(await fixture.prepare(window: Duration.zero), isNull);
    expect(await fixture.prepare(window: const Duration(minutes: 81)), isNull);
    expect(fixture.initializations, 0);
  });

  test('missing Auth or expiry never admits observation', () async {
    fixture.source.metadata = const PassiveSessionMetadata(null, null);
    expect(await fixture.prepare(), isNull);
    fixture.source.metadata = const PassiveSessionMetadata(owner, null);
    expect(await fixture.prepare(), isNull);
  });

  test(
    'missing receipt, pending cleanup or driver authority blocks admission',
    () async {
      fixture.currentReceipt = null;
      expect(await fixture.prepare(), isNull);
      fixture.currentReceipt = receipt;
      fixture.pending = true;
      expect(await fixture.prepare(), isNull);
      fixture.pending = false;
      fixture.driverDisabled = false;
      expect(await fixture.prepare(), isNull);
    },
  );

  test('owner change during admission is rejected', () async {
    fixture.onRead = () => fixture.source.metadata = PassiveSessionMetadata(
      other,
      fixture.seconds + 60,
    );
    expect(await fixture.prepare(), isNull);
  });

  test(
    'expiry already reached or outside bounded window blocks begin',
    () async {
      fixture.source.metadata = PassiveSessionMetadata(owner, fixture.seconds);
      final expired = (await fixture.prepare())!;
      expired.begin();
      expect(expired.stage, PassiveRefreshStage.blocked);
      fixture.source.metadata = PassiveSessionMetadata(
        owner,
        fixture.seconds + 120,
      );
      final outside = (await fixture.prepare())!;
      outside.begin();
      expect(outside.stage, PassiveRefreshStage.blocked);
    },
  );

  test(
    'normal same-owner refresh passes only after original boundary',
    () async {
      final probe = (await fixture.prepare())!..begin();
      fixture.refresh();
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.refreshed);
      fixture.now = fixture.now.add(const Duration(seconds: 61));
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.complete);
      probe.begin(); // One shot; never recaptures a new baseline.
      expect(probe.stage, PassiveRefreshStage.complete);
    },
  );

  test('later metadata without a tokenRefreshed event cannot pass', () async {
    final probe = (await fixture.prepare())!..begin();
    fixture.refresh(event: false);
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    await probe.check();
    expect(probe.stage, PassiveRefreshStage.observing);
  });

  test('refresh event without advanced expiry cannot pass', () async {
    final probe = (await fixture.prepare())!..begin();
    fixture.source.events.add(PassiveSessionEvent.refreshed);
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    await probe.check();
    expect(probe.stage, PassiveRefreshStage.observing);
  });

  test(
    'diagnostic stream errors retain actual owner without false success',
    () async {
      final probe = (await fixture.prepare())!..begin();
      fixture.source.events.addError(StateError('private diagnostic'));
      expect(probe.stage, PassiveRefreshStage.observing);
      fixture.refresh();
      fixture.now = fixture.now.add(const Duration(seconds: 61));
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.complete);
    },
  );

  for (final replacement in <String?>[other, null]) {
    test(
      'owner replacement/loss closes even after a refresh event: $replacement',
      () async {
        final probe = (await fixture.prepare())!..begin();
        fixture.refresh();
        fixture.source.metadata = PassiveSessionMetadata(
          replacement,
          fixture.seconds + 3600,
        );
        fixture.source.events.add(PassiveSessionEvent.other);
        fixture.now = fixture.now.add(const Duration(seconds: 61));
        await probe.check();
        expect(probe.stage, PassiveRefreshStage.blocked);
      },
    );
  }

  test(
    'changed receipt generation, cleanup or driver state denies completion',
    () async {
      for (final changed in ['receipt', 'journal', 'driver']) {
        fixture.currentReceipt = receipt;
        fixture.pending = false;
        fixture.driverDisabled = true;
        fixture.source.metadata = PassiveSessionMetadata(
          owner,
          fixture.seconds + 60,
        );
        final probe = (await fixture.prepare())!..begin();
        fixture.refresh();
        fixture.now = fixture.now.add(const Duration(seconds: 61));
        if (changed == 'receipt') {
          fixture.currentReceipt = const GuardianRecipientLocalStatus(
            'different',
            'generation',
          );
        } else if (changed == 'journal') {
          fixture.pending = true;
        } else {
          fixture.driverDisabled = false;
        }
        await probe.check();
        expect(probe.stage, PassiveRefreshStage.blocked);
      }
    },
  );

  test(
    'owner change during native read cannot complete for a new owner',
    () async {
      final probe = (await fixture.prepare())!..begin();
      fixture.refresh();
      fixture.now = fixture.now.add(const Duration(seconds: 61));
      fixture.onRead = () => fixture.source.metadata = PassiveSessionMetadata(
        other,
        fixture.seconds + 3600,
      );
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.blocked);
    },
  );

  test('closed Auth event stream cannot leave a pass eligible', () async {
    final probe = (await fixture.prepare())!..begin();
    fixture.refresh();
    await fixture.source.events.close();
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    await probe.check();
    expect(probe.stage, PassiveRefreshStage.uncertain);
  });

  test('same-owner session replacement cannot masquerade as refresh', () async {
    final probe = (await fixture.prepare())!..begin();
    fixture.refresh();
    fixture.source.events.add(PassiveSessionEvent.sessionChanged);
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    await probe.check();
    expect(probe.stage, PassiveRefreshStage.blocked);
  });

  test('native timeout cannot become a late pass', () async {
    final probe = (await fixture.prepare(
      readTimeout: const Duration(milliseconds: 10),
    ))!..begin();
    fixture.refresh();
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    fixture.gate = Completer<void>();
    await probe.check();
    expect(probe.stage, PassiveRefreshStage.uncertain);
    fixture.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(probe.stage, PassiveRefreshStage.uncertain);
  });

  test('cancelled in-flight native read cannot later record a pass', () async {
    final probe = (await fixture.prepare())!..begin();
    fixture.refresh();
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    fixture.gate = Completer<void>();
    final check = probe.check();
    probe.cancel();
    fixture.gate!.complete();
    await check;
    expect(probe.stage, PassiveRefreshStage.cancelled);
  });

  test('elapsed deadline or wall-clock rollback never passes', () async {
    for (final offset in [120, -1]) {
      fixture.source.metadata = PassiveSessionMetadata(
        owner,
        fixture.seconds + 60,
      );
      final probe = (await fixture.prepare())!..begin();
      fixture.refresh();
      fixture.now = fixture.now.add(Duration(seconds: offset));
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.timedOut);
    }
  });

  test(
    'native error closes uncertainty without exposing provider details',
    () async {
      final probe = (await fixture.prepare())!..begin();
      fixture.failRead = true;
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.uncertain);
      expect(probe.stage.label, isNot(contains('private')));
      expect(await fixture.prepare(), isNull);
    },
  );

  testWidgets(
    'backgrounding cancels without recording resumed refresh as a pass',
    (tester) async {
      final probe = (await fixture.prepare())!;
      await tester.pumpWidget(
        MaterialApp(home: PassiveRefreshProbeScreen(probe: probe)),
      );
      await tester.tap(find.text('Begin passive observation'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(probe.stage, PassiveRefreshStage.cancelled);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      fixture.refresh();
      fixture.now = fixture.now.add(const Duration(seconds: 61));
      await probe.check();
      expect(probe.stage, PassiveRefreshStage.cancelled);
    },
  );

  testWidgets('fixed UI hides private metadata and timer bounds observation', (
    tester,
  ) async {
    final probe = (await fixture.prepare())!;
    await tester.pumpWidget(
      MaterialApp(home: PassiveRefreshProbeScreen(probe: probe)),
    );
    expect(find.textContaining(owner), findsNothing);
    expect(find.textContaining(receipt.deviceId), findsNothing);
    await tester.tap(find.text('Begin passive observation'));
    await tester.pump();
    expect(find.text(PassiveRefreshStage.observing.label), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
    expect(find.text(PassiveRefreshStage.timedOut.label), findsOneWidget);
  });
}
