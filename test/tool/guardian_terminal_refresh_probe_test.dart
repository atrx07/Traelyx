import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';

import '../../tool/guardian_terminal_refresh_probe.dart';
import '../features/guardian/guardian_sdk_refresh_test.dart' show receipt;

class Source implements TerminalSessionSource {
  @override
  String? owner = 'private-owner';
  @override
  Object? sessionMarker = Object();
  @override
  int? expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  int revokes = 0, refreshes = 0;
  bool failRevoke = false, clearOnRevoke = false, clearOnRefresh = true;
  TerminalRefreshResult result = TerminalRefreshResult.rejected;
  Completer<void>? revokeGate;
  void clear() {
    owner = null;
    sessionMarker = null;
  }

  @override
  Future<void> revokeCurrentServerSession(Object expectedSession) async {
    revokes++;
    if (revokeGate != null) await revokeGate!.future;
    if (failRevoke) throw StateError('private provider diagnostic');
    if (clearOnRevoke) clear();
  }

  @override
  Future<TerminalRefreshResult> refreshOnce(Object expectedSession) async {
    refreshes++;
    if (clearOnRefresh) clear();
    return result;
  }
}

class Fixture {
  final source = Source();
  bool clean = true, cleanup = true, cleanupFails = false;
  GuardianRecipientLocalStatus? currentReceipt = receipt;
  int initializes = 0, reads = 0, cleanupCalls = 0;
  Completer<void>? readGate;
  void Function()? onRead;
  void Function()? onCleanup;
  late final runtime = TerminalRefreshRuntime(
    source,
    (_) async {
      reads++;
      if (readGate != null) await readGate!.future;
      onRead?.call();
      return TerminalRecipientAuthority(currentReceipt, idleAndClean: clean);
    },
    () async {
      cleanupCalls++;
      onCleanup?.call();
      if (cleanupFails) throw StateError('private cleanup diagnostic');
      return cleanup;
    },
  );
  Future<GuardianTerminalRefreshProbe?> prepare({
    bool debug = true,
    bool enabled = true,
    bool pilotsOff = true,
    String project = 'https://ksydjfcyzdtpbigskahm.supabase.co',
    Duration timeout = const Duration(seconds: 30),
    void Function(TerminalAdmissionReason)? onBlocked,
  }) => GuardianTerminalRefreshProbe.prepare(
    debugBuild: debug,
    enabled: enabled,
    pilotsOff: pilotsOff,
    projectUrl: project,
    timeout: timeout,
    onBlocked: onBlocked,
    initialize: () async {
      initializes++;
      return runtime;
    },
  );
}

void main() {
  test(
    'admission failures expose only fixed categories without changing guards',
    () async {
      for (final (mutation, expected)
          in <(void Function(Fixture), TerminalAdmissionReason)>[
            ((f) => f.source.clear(), TerminalAdmissionReason.session),
            ((f) => f.clean = false, TerminalAdmissionReason.idle),
            ((f) => f.currentReceipt = null, TerminalAdmissionReason.receipt),
            ((f) => f.source.expiresAt = 0, TerminalAdmissionReason.headroom),
            (
              (f) => f.onRead = () {
                f.source.sessionMarker = Object();
              },
              TerminalAdmissionReason.changed,
            ),
            (
              (f) => f.onRead = () {
                throw StateError('private diagnostic');
              },
              TerminalAdmissionReason.authority,
            ),
          ]) {
        final f = Fixture();
        mutation(f);
        final reasons = <TerminalAdmissionReason>[];
        expect(await f.prepare(onBlocked: reasons.add), isNull);
        expect(reasons, [expected]);
        expect(f.source.revokes, 0);
      }
      final f = Fixture(), reasons = <TerminalAdmissionReason>[];
      expect(await f.prepare(enabled: false, onBlocked: reasons.add), isNull);
      expect(reasons, [TerminalAdmissionReason.configuration]);
      expect(f.initializes, 0);
    },
  );
  test(
    'native read category survives catch without exporting exception details',
    () async {
      final f = Fixture(), reasons = <TerminalAdmissionReason>[];
      f.onRead = () => throw const TerminalAdmissionException(
        TerminalAdmissionReason.driverJournal,
      );
      expect(await f.prepare(onBlocked: reasons.add), isNull);
      expect(reasons, [TerminalAdmissionReason.driverJournal]);
      expect(f.source.revokes, 0);
    },
  );
  testWidgets('closed reason is fixed text and never exposes an action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TerminalRefreshProbeScreen(
          probe: null,
          closedReason: TerminalAdmissionReason.driverStatus,
        ),
      ),
    );
    expect(find.text('Local driver status unavailable'), findsOneWidget);
    expect(find.text('Probe closed; no action available'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('private diagnostic'), findsNothing);
  });
  test(
    'closed debug/define/project/pilot/timeout guards never initialize',
    () async {
      final f = Fixture();
      expect(await f.prepare(debug: false), isNull);
      expect(await f.prepare(enabled: false), isNull);
      expect(await f.prepare(pilotsOff: false), isNull);
      expect(await f.prepare(project: 'https://other.invalid'), isNull);
      expect(await f.prepare(timeout: Duration.zero), isNull);
      expect(await f.prepare(timeout: const Duration(seconds: 31)), isNull);
      expect(f.initializes, 0);
    },
  );
  test(
    'missing session, headroom, receipt or clean idle state closes admission',
    () async {
      for (final mutation in <void Function(Fixture)>[
        (f) => f.source.clear(),
        (f) => f.source.expiresAt =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 119,
        (f) => f.currentReceipt = null,
        (f) => f.clean = false,
      ]) {
        final f = Fixture();
        mutation(f);
        expect(await f.prepare(), isNull);
        expect(f.source.revokes, 0);
      }
    },
  );
  test(
    'one-shot double tap requires terminal rejection then owner cleanup',
    () async {
      final f = Fixture();
      final p = (await f.prepare())!;
      await Future.wait([p.runOnce(), p.runOnce()]);
      expect(p.stage, TerminalProbeStage.complete);
      expect((f.source.revokes, f.source.refreshes, f.cleanupCalls), (1, 1, 1));
      await p.runOnce();
      expect(f.source.revokes, 1);
      p.dispose();
    },
  );
  test(
    'same-owner replaced session and changed authority block before send',
    () async {
      for (final mutation in <void Function(Fixture)>[
        (f) => f.source.sessionMarker = Object(),
        (f) => f.source.owner = 'replacement-owner',
        (f) => f.currentReceipt = null,
        (f) => f.clean = false,
      ]) {
        final f = Fixture();
        final probe = (await f.prepare())!;
        mutation(f);
        await probe.runOnce();
        expect(probe.stage, TerminalProbeStage.blocked);
        expect(f.source.revokes, 0);
        probe.dispose();
      }
    },
  );
  test('revoke failure never refreshes or retries', () async {
    final f = Fixture();
    final p = (await f.prepare())!;
    f.source.failRevoke = true;
    await p.runOnce();
    await p.runOnce();
    expect(p.stage, TerminalProbeStage.uncertain);
    expect((f.source.revokes, f.source.refreshes), (1, 0));
    p.dispose();
  });
  test(
    'session replacement during awaited preflight blocks revocation',
    () async {
      final f = Fixture();
      final p = (await f.prepare())!;
      f.readGate = Completer<void>();
      final pending = p.runOnce();
      f.source.sessionMarker = Object();
      f.readGate!.complete();
      await pending;
      expect(p.stage, TerminalProbeStage.blocked);
      expect(f.source.revokes, 0);
      p.dispose();
    },
  );
  test('authority changed after server revocation prevents refresh', () async {
    final f = Fixture();
    final p = (await f.prepare())!;
    f.onRead = () {
      if (f.reads == 3) f.clean = false;
    };
    await p.runOnce();
    expect(p.stage, TerminalProbeStage.uncertain);
    expect((f.source.revokes, f.source.refreshes), (1, 0));
    p.dispose();
  });
  test(
    'revocation that signs out locally cannot prove server-rejected refresh',
    () async {
      final f = Fixture();
      final p = (await f.prepare())!;
      f.source.clearOnRevoke = true;
      await p.runOnce();
      expect(p.stage, TerminalProbeStage.uncertain);
      expect(f.source.refreshes, 0);
      p.dispose();
    },
  );
  test('timeout with late revoke completion cannot start a refresh', () async {
    final f = Fixture();
    final p = (await f.prepare(timeout: const Duration(milliseconds: 10)))!;
    f.source.revokeGate = Completer<void>();
    await p.runOnce();
    f.source.revokeGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(p.stage, TerminalProbeStage.uncertain);
    expect(f.source.refreshes, 0);
    p.dispose();
  });
  test(
    'cancel during revoke prevents refresh and blocks later retry',
    () async {
      final f = Fixture();
      final p = (await f.prepare())!;
      f.source.revokeGate = Completer<void>();
      final pending = p.runOnce();
      while (f.source.revokes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      p.cancel();
      f.source.revokeGate!.complete();
      await pending;
      expect(p.stage, TerminalProbeStage.uncertain);
      expect(f.source.refreshes, 0);
      p.dispose();
    },
  );
  test('successful/unknown refresh or retained owner cannot pass', () async {
    for (final (result, clear) in [
      (TerminalRefreshResult.refreshed, true),
      (TerminalRefreshResult.uncertain, true),
      (TerminalRefreshResult.rejected, false),
    ]) {
      final f = Fixture();
      final p = (await f.prepare())!;
      f.source.result = result;
      f.source.clearOnRefresh = clear;
      await p.runOnce();
      expect(p.stage, TerminalProbeStage.uncertain);
      expect(f.cleanupCalls, 0);
      p.dispose();
    }
  });
  test(
    'cleanup failure or replacement during cleanup denies success',
    () async {
      for (final mutation in <void Function(Fixture)>[
        (f) => f.cleanup = false,
        (f) => f.cleanupFails = true,
        (f) => f.onCleanup = () {
          f.source.owner = 'new-owner';
          f.source.sessionMarker = Object();
        },
      ]) {
        final f = Fixture();
        final p = (await f.prepare())!;
        mutation(f);
        await p.runOnce();
        expect(p.stage, TerminalProbeStage.uncertain);
        p.dispose();
      }
    },
  );
  testWidgets(
    'fixed labels hide provider/owner details and lifecycle cancels',
    (tester) async {
      final f = Fixture();
      final p = (await f.prepare())!;
      await tester.pumpWidget(
        MaterialApp(home: TerminalRefreshProbeScreen(probe: p)),
      );
      expect(find.textContaining('private-owner'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(p.stage, TerminalProbeStage.blocked);
      await p.runOnce();
      expect(f.source.revokes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
