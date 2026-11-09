// Alternate debug entrypoint only. Observe normal SDK refresh; never induce it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

class PassiveSessionMetadata {
  const PassiveSessionMetadata(this.owner, this.expiresAt);
  final String? owner;
  final int? expiresAt;
}

enum PassiveSessionEvent { refreshed, sessionChanged, other }

abstract interface class PassiveRefreshSource {
  PassiveSessionMetadata get metadata;
  Stream<PassiveSessionEvent> get refreshEvents;
}

class PassiveRecipientAuthority {
  const PassiveRecipientAuthority({
    required this.receipt,
    required this.pendingCleanup,
    required this.driverDisabled,
  });
  final GuardianRecipientLocalStatus? receipt;
  final bool pendingCleanup;
  final bool driverDisabled;
}

class PassiveRefreshRuntime {
  const PassiveRefreshRuntime(this.source, this.readAuthority);
  final PassiveRefreshSource source;
  final Future<PassiveRecipientAuthority> Function(String owner) readAuthority;
}

enum PassiveRefreshStage {
  ready('Ready to observe normal access-token rollover'),
  observing('Waiting for normal SDK refresh'),
  refreshed('Refresh observed; waiting for the original expiry boundary'),
  complete('Natural access-token rollover observed'),
  blocked('Preconditions changed; observation closed'),
  uncertain('Observation uncertain; restore the ordinary app'),
  timedOut('Observation deadline reached; no pass recorded'),
  cancelled('Observation cancelled; no pass recorded');

  const PassiveRefreshStage(this.label);
  final String label;
}

/// Contains no refresh, sign-out, registration, session injection or SDK settings
/// API. Owner/expiry/receipt metadata stays in memory and never reaches the UI.
class GuardianPassiveRefreshProbe extends ChangeNotifier {
  GuardianPassiveRefreshProbe._(
    this._runtime,
    this._owner,
    this._receipt,
    this._now,
    this._window,
    this._readTimeout,
  );

  final PassiveRefreshRuntime _runtime;
  final String _owner;
  final GuardianRecipientLocalStatus _receipt;
  final DateTime Function() _now;
  final Duration _window;
  final Duration _readTimeout;
  PassiveRefreshStage _stage = PassiveRefreshStage.ready;
  PassiveRefreshStage get stage => _stage;
  StreamSubscription<PassiveSessionEvent>? _events;
  Timer? _deadline;
  int? _startedAt;
  int? _originalExpiry;
  bool _sawRefresh = false;
  bool _checking = false;
  bool _disposed = false;

  static Future<GuardianPassiveRefreshProbe?> prepare({
    required bool debugBuild,
    required bool enabled,
    required bool pilotsOff,
    required String projectUrl,
    required Future<PassiveRefreshRuntime?> Function() initialize,
    DateTime Function()? now,
    Duration window = const Duration(minutes: 80),
    Duration readTimeout = const Duration(seconds: 30),
  }) async {
    if (!debugBuild ||
        !enabled ||
        !pilotsOff ||
        projectUrl != 'https://ksydjfcyzdtpbigskahm.supabase.co' ||
        window <= Duration.zero ||
        window > const Duration(minutes: 80)) {
      return null;
    }
    try {
      final runtime = await initialize().timeout(readTimeout);
      if (runtime == null) return null;
      final metadata = runtime.source.metadata;
      final owner = metadata.owner;
      if (owner == null || metadata.expiresAt == null) return null;
      final authority = await runtime.readAuthority(owner).timeout(readTimeout);
      if (runtime.source.metadata.owner != owner ||
          authority.receipt == null ||
          authority.pendingCleanup ||
          !authority.driverDisabled) {
        return null;
      }
      return GuardianPassiveRefreshProbe._(
        runtime,
        owner,
        authority.receipt!,
        now ?? DateTime.now,
        window,
        readTimeout,
      );
    } catch (_) {
      return null; // Never expose a provider body or private metadata.
    }
  }

  bool get _active =>
      _stage == PassiveRefreshStage.observing ||
      _stage == PassiveRefreshStage.refreshed;
  int get _seconds => _now().toUtc().millisecondsSinceEpoch ~/ 1000;

  void _set(PassiveRefreshStage next) {
    if (_disposed) return;
    _stage = next;
    if (!_active) {
      _deadline?.cancel();
      unawaited(_events?.cancel());
    }
    notifyListeners();
  }

  void begin() {
    if (_disposed || _stage != PassiveRefreshStage.ready) return;
    final metadata = _runtime.source.metadata;
    final expiry = metadata.expiresAt;
    final now = _seconds;
    if (metadata.owner != _owner ||
        expiry == null ||
        expiry <= now ||
        expiry - now >= _window.inSeconds) {
      _set(PassiveRefreshStage.blocked);
      return;
    }
    _startedAt = now;
    _originalExpiry = expiry;
    _set(PassiveRefreshStage.observing);
    if (!_active) return;
    _deadline = Timer(_window, () => _set(PassiveRefreshStage.timedOut));
    _events = _runtime.source.refreshEvents.listen(
      (event) {
        if (_active && event == PassiveSessionEvent.sessionChanged) {
          _set(PassiveRefreshStage.blocked);
          return;
        }
        if (!_active || !_checkOwnerAndTime()) return;
        final expiry = _runtime.source.metadata.expiresAt;
        if (event == PassiveSessionEvent.refreshed &&
            expiry != null &&
            expiry > _originalExpiry!) {
          _sawRefresh = true;
          _set(PassiveRefreshStage.refreshed);
        }
      },
      onError: (Object _) {
        // Retry diagnostics are not ownership loss. The explicit check re-samples
        // actual SDK identity, including terminal loss, without rendering errors.
        if (_active) _checkOwnerAndTime();
      },
      onDone: () {
        if (_active) _set(PassiveRefreshStage.uncertain);
      },
    );
  }

  bool _checkOwnerAndTime() {
    final now = _seconds;
    if (now < _startedAt! || now - _startedAt! >= _window.inSeconds) {
      _set(PassiveRefreshStage.timedOut);
      return false;
    }
    if (_runtime.source.metadata.owner != _owner) {
      _set(PassiveRefreshStage.blocked);
      return false;
    }
    return true;
  }

  Future<void> check() async {
    if (_disposed || !_active || _checking || !_checkOwnerAndTime()) return;
    _checking = true;
    try {
      final authority = await _runtime
          .readAuthority(_owner)
          .timeout(_readTimeout);
      if (_disposed || !_active || !_checkOwnerAndTime()) return;
      if (authority.pendingCleanup ||
          !authority.driverDisabled ||
          authority.receipt?.deviceId != _receipt.deviceId ||
          authority.receipt?.generation != _receipt.generation) {
        _set(PassiveRefreshStage.blocked);
        return;
      }
      final expiry = _runtime.source.metadata.expiresAt;
      if (_sawRefresh &&
          _seconds >= _originalExpiry! &&
          expiry != null &&
          expiry > _originalExpiry! &&
          expiry > _seconds) {
        _set(PassiveRefreshStage.complete);
      }
    } catch (_) {
      if (_active) _set(PassiveRefreshStage.uncertain);
    } finally {
      _checking = false;
    }
  }

  void cancel() {
    if (!_disposed && (_active || _stage == PassiveRefreshStage.ready)) {
      _set(PassiveRefreshStage.cancelled);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _deadline?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }
}

class _SdkSource implements PassiveRefreshSource {
  const _SdkSource(this.client);
  final SupabaseClient client;
  @override
  PassiveSessionMetadata get metadata => PassiveSessionMetadata(
    client.auth.currentUser?.id,
    client.auth.currentSession?.expiresAt,
  );
  @override
  Stream<PassiveSessionEvent> get refreshEvents =>
      client.auth.onAuthStateChange.map((state) {
        if (state.session == null ||
            state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.signedOut ||
            state.event == AuthChangeEvent.passwordRecovery) {
          return PassiveSessionEvent.sessionChanged;
        }
        return state.event == AuthChangeEvent.tokenRefreshed
            ? PassiveSessionEvent.refreshed
            : PassiveSessionEvent.other;
      });
}

Future<PassiveRefreshRuntime?> _initializeRuntime() async {
  final raw = await initializeAccount(); // Normal storage and auto-refresh.
  final client = accountClientOf(raw);
  if (client == null) return null;
  const native = MethodChannelGuardianOwnerPort();
  // Same ownership/stop/reconciliation composition as the ordinary entrypoint.
  final account = GuardianBoundAccountGateway(
    raw,
    native,
    driverStopper: GuardianDriverStopService(
      raw,
      const MethodChannelGuardianActivationPort(),
      SupabaseGuardianDriverSessionGateway(client),
    ).stop,
    deviceRevoker: GuardianDeviceServerGateway(
      SupabaseGuardianDeviceRpcTransport(client),
    ),
  );
  return PassiveRefreshRuntime(_SdkSource(client), (owner) async {
    if (account.currentIdentity?.userId != owner ||
        !await account.ensureCurrentOwnerBound()) {
      throw const FormatException();
    }
    final receipt = await native.recipientStatus(owner);
    final pending = await native.pendingRevokes(owner);
    final driverPending = await const MethodChannelGuardianActivationPort()
        .pendingRevokes(owner);
    final driver = await const MethodChannelGuardianDriverStatusPort().read(
      owner,
    );
    if (account.currentIdentity?.userId != owner) throw const FormatException();
    return PassiveRecipientAuthority(
      receipt: receipt,
      pendingCleanup: pending.isNotEmpty || driverPending.isNotEmpty,
      driverDisabled:
          driver.state == GuardianDriverState.disabled &&
          driver.expiresAt == null,
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final probe = await GuardianPassiveRefreshProbe.prepare(
    debugBuild: kDebugMode,
    enabled: const bool.fromEnvironment(
      'TRAELYX_GUARDIAN_PASSIVE_REFRESH_PROBE',
    ),
    pilotsOff:
        !const bool.fromEnvironment('TRAELYX_GUARDIAN_RECIPIENT_PILOT') &&
        !const bool.fromEnvironment('TRAELYX_GUARDIAN_DRIVER_PILOT') &&
        !const bool.fromEnvironment('TRAELYX_GUARDIAN_SENDING_PILOT'),
    projectUrl: const String.fromEnvironment('TRAELYX_SUPABASE_URL'),
    initialize: _initializeRuntime,
  );
  runApp(MaterialApp(home: PassiveRefreshProbeScreen(probe: probe)));
}

class PassiveRefreshProbeScreen extends StatefulWidget {
  const PassiveRefreshProbeScreen({super.key, required this.probe});
  final GuardianPassiveRefreshProbe? probe;

  @override
  State<PassiveRefreshProbeScreen> createState() =>
      _PassiveRefreshScreenState();
}

class _PassiveRefreshScreenState extends State<PassiveRefreshProbeScreen>
    with WidgetsBindingObserver {
  GuardianPassiveRefreshProbe? get probe => widget.probe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) probe?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    probe?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guardian passive refresh observer')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: probe == null
            ? const Text('Observer closed; no action available')
            : ListenableBuilder(
                listenable: probe!,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operator check only. No forced refresh or sign-out. '
                      'Maximum observation: 80 minutes. Keep this app foreground.',
                    ),
                    const SizedBox(height: 16),
                    Text(probe!.stage.label),
                    FilledButton(
                      onPressed: probe!.stage == PassiveRefreshStage.ready
                          ? probe!.begin
                          : null,
                      child: const Text('Begin passive observation'),
                    ),
                    OutlinedButton(
                      onPressed: probe!._active ? probe!.check : null,
                      child: const Text('Check observation'),
                    ),
                    TextButton(
                      onPressed: probe!.cancel,
                      child: const Text('Cancel observation'),
                    ),
                    const Text(
                      'Successful access-token rollover does not prove '
                      'terminal Auth-session expiry or active-driver cleanup.',
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
