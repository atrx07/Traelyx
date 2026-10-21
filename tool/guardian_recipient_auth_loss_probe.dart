// Alternate entrypoint for a separately reviewed Pixel lifecycle check only.
// Never imported by the ordinary app. This deliberately bypasses the app's
// server-first Sign out path; it is not a simulation of natural token expiry.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

const _reviewedProject = 'https://ksydjfcyzdtpbigskahm.supabase.co';

enum AuthLossProbeStage {
  ready('Ready for the separately approved local sign-in loss check'),
  running('Checking and clearing local sign-in once'),
  complete('Sign-in cleared; local owner cleanup confirmed'),
  blocked('Preconditions changed; no probe sign-out was attempted'),
  uncertain(
    'Outcome uncertain; do not retry. Restore the ordinary app for review',
  );

  const AuthLossProbeStage(this.label);
  final String label;
}

/// One-shot fault injection. No Guardian RPC, registration or driver activation.
/// The real bound gateway observes SDK Auth loss and runs native owner cleanup.
/// Its device revoker is deliberately absent: the server row must survive until
/// the ordinary app's reviewed same-owner reconciliation after a later sign-in.
final class RecipientAuthLossProbe {
  RecipientAuthLossProbe._(
    this._account,
    this._port,
    this._driver,
    this._owner,
    this._receipt,
    this._binding,
    this._timeout,
  );

  final AccountGateway _account;
  final GuardianOwnerPort _port;
  final GuardianDriverStatusPort _driver;
  final String _owner;
  final GuardianRecipientLocalStatus _receipt;
  final GuardianBoundAccountGateway _binding;
  final Duration _timeout;
  AuthLossProbeStage _stage = AuthLossProbeStage.ready;
  AuthLossProbeStage get stage => _stage;
  bool _spent = false;

  /// Guard before even initializing Auth. Injected inputs make the closed path
  /// testable; main supplies compile-time constants, including kDebugMode.
  static Future<RecipientAuthLossProbe?> prepare({
    required bool debugBuild,
    required bool enabled,
    required String projectUrl,
    required Future<AccountGateway> Function() initialize,
    required GuardianOwnerPort port,
    required GuardianDriverStatusPort driver,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    if (!debugBuild || !enabled || projectUrl != _reviewedProject) return null;
    final account = await initialize().timeout(timeout);
    final owner = account.currentIdentity?.userId;
    if (!account.isAvailable || owner == null) return null;
    void checkOwner() {
      if (account.currentIdentity?.userId != owner) {
        throw const FormatException();
      }
    }

    // Native reads require a bound owner in this new process. This gateway has
    // no server revoker: an existing journal makes binding fail closed, retaining
    // its tickets for the ordinary app. Binding can clean stale local authority.
    final binding = GuardianBoundAccountGateway(account, port);
    // Keep the observer alive even after failure/timeout: a late Auth event
    // must still clear local authority. The operator restores the ordinary app.
    final bound = await binding.ensureCurrentOwnerBound().timeout(timeout);
    checkOwner();
    if (!bound) return null;
    final pending = await port.pendingRevokes(owner).timeout(timeout);
    checkOwner();
    if (pending.isNotEmpty) return null;
    final status = await driver.read(owner).timeout(timeout);
    checkOwner();
    if (status.state != GuardianDriverState.disabled ||
        status.expiresAt != null) {
      return null;
    }
    final receipt = await port.recipientStatus(owner).timeout(timeout);
    checkOwner();
    if (receipt == null) return null;
    return RecipientAuthLossProbe._(
      account,
      port,
      driver,
      owner,
      receipt,
      binding,
      timeout,
    );
  }

  void _checkOwner() {
    if (_account.currentIdentity?.userId != _owner) {
      throw const FormatException();
    }
  }

  Future<void> _checkPreconditions() async {
    _checkOwner();
    if (!await _binding.ensureCurrentOwnerBound().timeout(_timeout)) {
      throw const FormatException();
    }
    _checkOwner();
    final pending = await _port.pendingRevokes(_owner).timeout(_timeout);
    _checkOwner();
    if (pending.isNotEmpty) throw const FormatException();
    final driver = await _driver.read(_owner).timeout(_timeout);
    _checkOwner();
    if (driver.state != GuardianDriverState.disabled ||
        driver.expiresAt != null) {
      throw const FormatException();
    }
    final receipt = await _port.recipientStatus(_owner).timeout(_timeout);
    _checkOwner();
    if (receipt?.deviceId != _receipt.deviceId ||
        receipt?.generation != _receipt.generation) {
      throw const FormatException();
    }
  }

  Future<void> runOnce() async {
    if (_spent) return;
    _spent = true; // Before any await; double taps and failures never retry.
    _stage = AuthLossProbeStage.running;
    var attempted = false;
    try {
      await _checkPreconditions();
      _checkOwner();
      attempted = true;
      // Raw SDK local sign-out, NOT GuardianBoundAccountGateway.signOut().
      await _account.signOut().timeout(_timeout);
      if (_account.currentIdentity != null ||
          !await _binding.ensureCurrentOwnerBound().timeout(_timeout) ||
          _account.currentIdentity != null) {
        throw const FormatException();
      }
      _stage = AuthLossProbeStage.complete;
    } catch (_) {
      // Never display an exception, identity, receipt or credential.
      _stage = attempted
          ? AuthLossProbeStage.uncertain
          : AuthLossProbeStage.blocked;
    }
  }

  /// Tests/process shutdown only. Do not cancel the observer after uncertainty.
  Future<void> dispose() => _binding.dispose();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RecipientAuthLossProbe? probe;
  try {
    probe = await RecipientAuthLossProbe.prepare(
      debugBuild: kDebugMode,
      enabled: const bool.fromEnvironment('TRAELYX_GUARDIAN_AUTH_LOSS_PROBE'),
      projectUrl: const String.fromEnvironment('TRAELYX_SUPABASE_URL'),
      initialize: initializeAccount,
      port: const MethodChannelGuardianOwnerPort(),
      driver: const MethodChannelGuardianDriverStatusPort(),
    );
  } catch (_) {
    // Closed result, no raw platform/Auth exception output.
  }
  runApp(MaterialApp(home: AuthLossProbeScreen(probe: probe)));
}

class AuthLossProbeScreen extends StatefulWidget {
  const AuthLossProbeScreen({super.key, required this.probe});
  final RecipientAuthLossProbe? probe;

  @override
  State<AuthLossProbeScreen> createState() => _AuthLossProbeScreenState();
}

class _AuthLossProbeScreenState extends State<AuthLossProbeScreen> {
  Future<void> _run() async {
    final operation = widget.probe!.runOnce();
    setState(() {});
    await operation;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guardian local Auth-loss probe')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operator test only. Requires separate live approval.'),
          const SizedBox(height: 16),
          Text(
            widget.probe?.stage.label ?? 'Probe closed; no action available',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.probe?.stage == AuthLossProbeStage.ready
                ? _run
                : null,
            child: const Text('Simulate local sign-in loss once'),
          ),
        ],
      ),
    ),
  );
}
