// Alternate debug entrypoint. Requires separate live approval after source CI.
// Never imported by the ordinary app. No service-role key or Auth policy edit.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

enum TerminalRefreshResult { rejected, refreshed, uncertain }

enum TerminalAdmissionReason {
  configuration('Probe configuration is closed'),
  initialization('Account initialization unavailable'),
  session('Existing signed-in session unavailable'),
  authority('Local authority preflight unavailable'),
  changed('Session changed during preflight'),
  idle('Idle driver and empty cleanup journals required'),
  receipt('Existing receiver registration required'),
  headroom('Waiting for normal session refresh headroom'),
  binding('Local owner binding unavailable'),
  driverStatus('Local driver status unavailable'),
  recipientStatus('Local receiver status unavailable'),
  recipientJournal('Local receiver cleanup status unavailable'),
  driverJournal('Local driver cleanup status unavailable');

  const TerminalAdmissionReason(this.label);
  final String label;
}

class TerminalAdmissionException implements Exception {
  const TerminalAdmissionException(this.reason);
  final TerminalAdmissionReason reason;
}

Future<T> _admissionRead<T>(
  TerminalAdmissionReason reason,
  Future<T> Function() operation,
) async {
  try {
    return await operation();
  } catch (_) {
    throw TerminalAdmissionException(
      reason,
    ); // No raw provider/platform detail.
  }
}

abstract interface class TerminalSessionSource {
  String? get owner;
  Object? get sessionMarker;
  int? get expiresAt;
  Future<void> revokeCurrentServerSession(Object expectedSession);
  Future<TerminalRefreshResult> refreshOnce(Object expectedSession);
}

/// Session references/credentials stay in memory, never in labels or diagnostics.
final class SdkTerminalSessionSource implements TerminalSessionSource {
  SdkTerminalSessionSource(this._client, this._account) {
    _changes = _client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event != AuthChangeEvent.initialSession) {
          // Explicit lifecycle events invalidate even if credentials are reused.
          _lastSession = null;
          _marker = null;
        }
      },
      onError: (Object _) {
        // A diagnostic is not a grant change. Getter checks still sample Auth.
      },
    );
  }
  final SupabaseClient _client;
  final AccountGateway _account;
  late final StreamSubscription<AuthState> _changes;
  Session? _lastSession;
  Object? _marker;
  @override
  String? get owner => _account.currentIdentity?.userId;
  @override
  Object? get sessionMarker {
    final current = _client.auth.currentSession;
    if (current == null || current.refreshToken?.isNotEmpty != true) {
      _lastSession = null;
      _marker = null;
      return null;
    }
    final previous = _lastSession;
    // recoverSession can replace the wrapper without changing the grant.
    // Compare only in memory; never stringify or persist these credentials.
    if (previous == null ||
        previous.user.id != current.user.id ||
        previous.accessToken != current.accessToken ||
        previous.refreshToken != current.refreshToken) {
      _marker = Object();
    }
    _lastSession = current;
    return _marker;
  }

  @override
  int? get expiresAt => _client.auth.currentSession?.expiresAt;

  @override
  Future<void> revokeCurrentServerSession(Object expectedSession) async {
    if (!identical(sessionMarker, expectedSession)) {
      throw const FormatException();
    }
    final current = _client.auth.currentSession;
    if (current == null) throw const FormatException();
    // Same /logout endpoint used by the SDK's ordinary signOut. Calling only
    // this transport method leaves local Auth intact for the rejection check.
    await _client.auth.admin.signOut(
      current.accessToken,
      scope: SignOutScope.local,
    );
  }

  @override
  Future<TerminalRefreshResult> refreshOnce(Object expectedSession) async {
    if (!identical(sessionMarker, expectedSession)) {
      return TerminalRefreshResult.uncertain;
    }
    try {
      await _account.refreshSession();
      return TerminalRefreshResult.refreshed;
    } on AuthException catch (error) {
      const terminalCodes = {
        'refresh_token_not_found',
        'refresh_token_already_used',
        'session_not_found',
        'session_expired',
      };
      return (error.statusCode == '400' || error.statusCode == '401') &&
              terminalCodes.contains(error.code) &&
              owner == null &&
              sessionMarker == null
          ? TerminalRefreshResult.rejected
          : TerminalRefreshResult.uncertain;
    } catch (_) {
      return TerminalRefreshResult.uncertain;
    }
  }

  Future<void> dispose() => _changes.cancel();
}

class TerminalRecipientAuthority {
  const TerminalRecipientAuthority(this.receipt, {required this.idleAndClean});
  final GuardianRecipientLocalStatus? receipt;
  final bool idleAndClean;
}

class TerminalRefreshRuntime {
  const TerminalRefreshRuntime(
    this.source,
    this.readAuthority,
    this.finishOwnerCleanup,
  );
  final TerminalSessionSource source;
  final Future<TerminalRecipientAuthority> Function(String owner) readAuthority;
  final Future<bool> Function() finishOwnerCleanup;
}

enum TerminalProbeStage {
  ready('Ready for the separately approved server rejection check'),
  running('Checking one server revocation and refresh'),
  complete('Server refresh rejected; local owner cleanup completed'),
  blocked('Preconditions changed; no server revocation attempted'),
  uncertain('Outcome uncertain; do not retry. Restore the ordinary app');

  const TerminalProbeStage(this.label);
  final String label;
}

class GuardianTerminalRefreshProbe extends ChangeNotifier {
  GuardianTerminalRefreshProbe._(
    this._runtime,
    this._owner,
    this._session,
    this._receipt,
    this._now,
    this._timeout,
  );
  final TerminalRefreshRuntime _runtime;
  final String _owner;
  final Object _session;
  final GuardianRecipientLocalStatus _receipt;
  final DateTime Function() _now;
  final Duration _timeout;
  TerminalProbeStage _stage = TerminalProbeStage.ready;
  TerminalProbeStage get stage => _stage;
  bool _attempted = false;
  bool _disposed = false;

  static Future<GuardianTerminalRefreshProbe?> prepare({
    required bool debugBuild,
    required bool enabled,
    required bool pilotsOff,
    required String projectUrl,
    required Future<TerminalRefreshRuntime?> Function() initialize,
    DateTime Function()? now,
    Duration timeout = const Duration(seconds: 30),
    void Function(TerminalAdmissionReason)? onBlocked,
  }) async {
    if (!debugBuild ||
        !enabled ||
        !pilotsOff ||
        projectUrl != 'https://ksydjfcyzdtpbigskahm.supabase.co' ||
        timeout <= Duration.zero ||
        timeout > const Duration(seconds: 30)) {
      onBlocked?.call(TerminalAdmissionReason.configuration);
      return null;
    }
    var failure = TerminalAdmissionReason.initialization;
    GuardianTerminalRefreshProbe? blocked(TerminalAdmissionReason reason) {
      onBlocked?.call(reason);
      return null;
    }

    try {
      final runtime = await initialize().timeout(timeout);
      if (runtime == null) {
        return blocked(TerminalAdmissionReason.initialization);
      }
      final source = runtime.source;
      final owner = source.owner;
      final session = source.sessionMarker;
      if (owner == null || session == null) {
        return blocked(TerminalAdmissionReason.session);
      }
      final clock = now ?? DateTime.now;
      failure = TerminalAdmissionReason.authority;
      final authority = await runtime.readAuthority(owner).timeout(timeout);
      if (source.owner != owner || !identical(source.sessionMarker, session)) {
        return blocked(TerminalAdmissionReason.changed);
      }
      if (!authority.idleAndClean) {
        return blocked(TerminalAdmissionReason.idle);
      }
      if (authority.receipt == null) {
        return blocked(TerminalAdmissionReason.receipt);
      }
      if ((source.expiresAt ?? 0) - clock().millisecondsSinceEpoch ~/ 1000 <
          120) {
        return blocked(TerminalAdmissionReason.headroom);
      }
      return GuardianTerminalRefreshProbe._(
        runtime,
        owner,
        session,
        authority.receipt!,
        clock,
        timeout,
      );
    } catch (error) {
      return blocked(
        error is TerminalAdmissionException ? error.reason : failure,
      );
    }
  }

  void _set(TerminalProbeStage value) {
    if (_disposed) return;
    _stage = value;
    notifyListeners();
  }

  void _checkSession() {
    final source = _runtime.source;
    if (_disposed ||
        _stage != TerminalProbeStage.running ||
        source.owner != _owner ||
        !identical(source.sessionMarker, _session) ||
        (source.expiresAt ?? 0) - _now().millisecondsSinceEpoch ~/ 1000 < 120) {
      throw const FormatException();
    }
  }

  Future<void> _checkAuthority() async {
    _checkSession();
    final current = await _runtime.readAuthority(_owner).timeout(_timeout);
    _checkSession();
    if (!current.idleAndClean ||
        current.receipt?.deviceId != _receipt.deviceId ||
        current.receipt?.generation != _receipt.generation) {
      throw const FormatException();
    }
  }

  Future<void> runOnce() async {
    if (_disposed || _stage != TerminalProbeStage.ready) return;
    _set(TerminalProbeStage.running); // Synchronous one-shot before any await.
    try {
      await _checkAuthority();
      _checkSession();
      _attempted = true; // Timeout/failure after this point is never retried.
      await _runtime.source
          .revokeCurrentServerSession(_session)
          .timeout(_timeout);
      await _checkAuthority(); // Revocation must not itself sign out locally.
      _checkSession(); // Recheck cancellation in this await's continuation.
      final result = await _runtime.source
          .refreshOnce(_session)
          .timeout(_timeout);
      if (_disposed ||
          _stage != TerminalProbeStage.running ||
          result != TerminalRefreshResult.rejected ||
          _runtime.source.owner != null ||
          _runtime.source.sessionMarker != null ||
          !await _runtime.finishOwnerCleanup().timeout(_timeout) ||
          _runtime.source.owner != null ||
          _runtime.source.sessionMarker != null ||
          _stage != TerminalProbeStage.running) {
        throw const FormatException();
      }
      _set(TerminalProbeStage.complete);
    } catch (_) {
      _set(
        _attempted ? TerminalProbeStage.uncertain : TerminalProbeStage.blocked,
      );
    }
  }

  void cancel() {
    if (_stage == TerminalProbeStage.ready ||
        _stage == TerminalProbeStage.running) {
      _set(
        _attempted ? TerminalProbeStage.uncertain : TerminalProbeStage.blocked,
      );
    }
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    // Keep the production owner observer alive for late SDK/cleanup completion.
    super.dispose();
  }
}

Future<TerminalRefreshRuntime?> _initializeRuntime() async {
  final raw = await initializeAccount();
  final client = accountClientOf(raw);
  if (client == null) return null;
  const native = MethodChannelGuardianOwnerPort();
  const driver = MethodChannelGuardianActivationPort();
  final bound = GuardianBoundAccountGateway(
    raw,
    native,
    driverStopper: GuardianDriverStopService(
      raw,
      driver,
      SupabaseGuardianDriverSessionGateway(client),
    ).stop,
    deviceRevoker: GuardianDeviceServerGateway(
      SupabaseGuardianDeviceRpcTransport(client),
    ),
  );
  return TerminalRefreshRuntime(SdkTerminalSessionSource(client, raw), (
    owner,
  ) async {
    if (raw.currentIdentity?.userId != owner ||
        !await _admissionRead(
          TerminalAdmissionReason.binding,
          bound.ensureCurrentOwnerBound,
        )) {
      throw const TerminalAdmissionException(TerminalAdmissionReason.binding);
    }
    // Status recovery can journal expired driver authority; read journals
    // afterward so a newly retained cleanup ticket cannot escape admission.
    final status = await _admissionRead(
      TerminalAdmissionReason.driverStatus,
      () => const MethodChannelGuardianDriverStatusPort().read(owner),
    );
    final receipt = await _admissionRead(
      TerminalAdmissionReason.recipientStatus,
      () => native.recipientStatus(owner),
    );
    final pending = await _admissionRead(
      TerminalAdmissionReason.recipientJournal,
      () => native.pendingRevokes(owner),
    );
    final driverPending = await _admissionRead(
      TerminalAdmissionReason.driverJournal,
      () => driver.pendingRevokes(owner),
    );
    if (raw.currentIdentity?.userId != owner) throw const FormatException();
    return TerminalRecipientAuthority(
      receipt,
      idleAndClean:
          pending.isEmpty &&
          driverPending.isEmpty &&
          status.state == GuardianDriverState.disabled &&
          status.expiresAt == null,
    );
  }, bound.ensureCurrentOwnerBound);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TerminalAdmissionReason? closedReason;
  final probe = await GuardianTerminalRefreshProbe.prepare(
    debugBuild: kDebugMode,
    enabled: const bool.fromEnvironment(
      'TRAELYX_GUARDIAN_TERMINAL_REFRESH_PROBE',
    ),
    pilotsOff:
        !const bool.fromEnvironment('TRAELYX_GUARDIAN_RECIPIENT_PILOT') &&
        !const bool.fromEnvironment('TRAELYX_GUARDIAN_DRIVER_PILOT') &&
        !const bool.fromEnvironment('TRAELYX_GUARDIAN_SENDING_PILOT'),
    projectUrl: const String.fromEnvironment('TRAELYX_SUPABASE_URL'),
    initialize: _initializeRuntime,
    onBlocked: (reason) => closedReason = reason,
  );
  runApp(
    MaterialApp(
      home: TerminalRefreshProbeScreen(
        probe: probe,
        closedReason: closedReason,
      ),
    ),
  );
}

class TerminalRefreshProbeScreen extends StatefulWidget {
  const TerminalRefreshProbeScreen({
    super.key,
    required this.probe,
    this.closedReason,
  });
  final GuardianTerminalRefreshProbe? probe;
  final TerminalAdmissionReason? closedReason;
  @override
  State<TerminalRefreshProbeScreen> createState() =>
      _TerminalRefreshScreenState();
}

class _TerminalRefreshScreenState extends State<TerminalRefreshProbeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.probe?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.probe?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guardian server rejection probe')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: widget.probe == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Probe closed; no action available'),
                if (widget.closedReason != null)
                  Text(widget.closedReason!.label),
              ],
            )
          : ListenableBuilder(
              listenable: widget.probe!,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operator test only. Requires separate live approval. '
                    'Revokes only this session, then attempts one refresh. '
                    'No alert or trip upload. Recovery needs a new sign-in link.',
                  ),
                  const SizedBox(height: 16),
                  Text(widget.probe!.stage.label),
                  FilledButton(
                    onPressed: widget.probe!.stage == TerminalProbeStage.ready
                        ? widget.probe!.runOnce
                        : null,
                    child: const Text(
                      'Revoke this server session and refresh once',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.probe!.cancel,
                    child: const Text('Cancel check'),
                  ),
                ],
              ),
            ),
    ),
  );
}
