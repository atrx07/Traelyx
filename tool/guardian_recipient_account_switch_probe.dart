// Alternate entrypoint for a separately reviewed account-replacement check.
// Never imported by the ordinary app. No registration or Guardian server RPC.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

enum AccountSwitchProbeStage {
  ready('Ready for the separately approved account replacement'),
  checking('Checking the existing local registration'),
  waiting('Link requested; open it inside this emulator'),
  complete('Account changed; local recipient cleanup confirmed'),
  blocked('Preconditions changed; no link request was attempted'),
  uncertain('Outcome uncertain; restore the ordinary app for review');

  const AccountSwitchProbeStage(this.label);
  final String label;
}

/// Observes a real SDK email-link callback without signing out the old account.
/// Native owner binding captures the old receiver's ID-only revoke ticket.
/// No server revoker is supplied: reconciliation belongs to the ordinary app
/// after the maintainer returns to the original account under reviewed recovery.
final class RecipientAccountSwitchProbe extends ChangeNotifier {
  RecipientAccountSwitchProbe._(
    this._account,
    this._port,
    this._driver,
    this._owner,
    this._receipt,
    this._binding,
    this._timeout,
  ) {
    _subscription = _account.identityChanges.listen(_changed);
  }

  final AccountGateway _account;
  final GuardianOwnerPort _port;
  final GuardianDriverStatusPort _driver;
  final String _owner;
  final GuardianRecipientLocalStatus _receipt;
  final GuardianBoundAccountGateway _binding;
  final Duration _timeout;
  late final StreamSubscription<AccountIdentity?> _subscription;
  AccountSwitchProbeStage _stage = AccountSwitchProbeStage.ready;
  AccountSwitchProbeStage get stage => _stage;
  bool _spent = false;
  bool _armed = false;
  bool _requestConfirmed = false;
  bool _verifying = false;
  bool _closed = false;
  String? _replacement;

  static Future<RecipientAccountSwitchProbe?> prepare({
    required bool debugBuild,
    required bool enabled,
    required String projectUrl,
    required Future<AccountGateway> Function() initialize,
    required GuardianOwnerPort port,
    required GuardianDriverStatusPort driver,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    if (!debugBuild ||
        !enabled ||
        projectUrl != 'https://ksydjfcyzdtpbigskahm.supabase.co') {
      return null;
    }
    final account = await initialize().timeout(timeout);
    final owner = account.currentIdentity?.userId;
    if (!account.isAvailable || owner == null) return null;
    final binding = GuardianBoundAccountGateway(account, port);
    // Keep the production observer alive after uncertainty until ordinary restore.
    void check() {
      if (account.currentIdentity?.userId != owner) {
        throw const FormatException();
      }
    }

    if (!await binding.ensureCurrentOwnerBound().timeout(timeout)) return null;
    check();
    final pending = await port.pendingRevokes(owner).timeout(timeout);
    check();
    if (pending.isNotEmpty) return null;
    final state = await driver.read(owner).timeout(timeout);
    check();
    if (state.state != GuardianDriverState.disabled ||
        state.expiresAt != null) {
      return null;
    }
    final receipt = await port.recipientStatus(owner).timeout(timeout);
    check();
    if (receipt == null) return null;
    return RecipientAccountSwitchProbe._(
      account,
      port,
      driver,
      owner,
      receipt,
      binding,
      timeout,
    );
  }

  void _set(AccountSwitchProbeStage next) {
    _stage = next;
    if (!_closed) notifyListeners();
  }

  void _checkOwner(String owner) {
    if (_account.currentIdentity?.userId != owner) {
      throw const FormatException();
    }
  }

  Future<void> _preflight() async {
    _checkOwner(_owner);
    if (!await _binding.ensureCurrentOwnerBound().timeout(_timeout)) {
      throw const FormatException();
    }
    _checkOwner(_owner);
    final pending = await _port.pendingRevokes(_owner).timeout(_timeout);
    _checkOwner(_owner);
    if (pending.isNotEmpty) throw const FormatException();
    final driver = await _driver.read(_owner).timeout(_timeout);
    _checkOwner(_owner);
    if (driver.state != GuardianDriverState.disabled ||
        driver.expiresAt != null) {
      throw const FormatException();
    }
    final receipt = await _port.recipientStatus(_owner).timeout(_timeout);
    _checkOwner(_owner);
    if (receipt?.deviceId != _receipt.deviceId ||
        receipt?.generation != _receipt.generation) {
      throw const FormatException();
    }
  }

  Future<void> requestOnce(String email) async {
    if (_spent || _closed) return;
    _spent = true;
    _set(AccountSwitchProbeStage.checking);
    var attempted = false;
    try {
      final address = email.trim();
      if (address.isEmpty || address.length > 254 || !address.contains('@')) {
        throw const FormatException();
      }
      await _preflight();
      _checkOwner(_owner);
      _armed = true;
      attempted = true;
      await _account.sendSignInLink(address).timeout(_timeout);
      _requestConfirmed = true;
      if (_stage == AccountSwitchProbeStage.uncertain) return;
      _set(AccountSwitchProbeStage.waiting);
      _changed(_account.currentIdentity);
    } catch (_) {
      _armed = false;
      _set(
        attempted
            ? AccountSwitchProbeStage.uncertain
            : AccountSwitchProbeStage.blocked,
      );
    }
  }

  void _changed(AccountIdentity? identity) {
    if (!_armed || _closed || _stage == AccountSwitchProbeStage.uncertain) {
      return;
    }
    final next = identity?.userId;
    if (next == null || (_replacement != null && next != _replacement)) {
      _set(AccountSwitchProbeStage.uncertain);
      return;
    }
    if (next == _owner) return; // Same-owner token refresh is not replacement.
    _replacement ??= next;
    if (!_requestConfirmed || _verifying) return;
    _verifying = true;
    unawaited(_verifyReplacement(next));
  }

  Future<void> _verifyReplacement(String next) async {
    try {
      _checkOwner(next);
      if (!await _binding.ensureCurrentOwnerBound().timeout(_timeout)) {
        throw const FormatException();
      }
      _checkOwner(next);
      final receipt = await _port.recipientStatus(next).timeout(_timeout);
      _checkOwner(next);
      final driver = await _driver.read(next).timeout(_timeout);
      _checkOwner(next);
      if (receipt != null ||
          driver.state != GuardianDriverState.disabled ||
          driver.expiresAt != null ||
          _stage == AccountSwitchProbeStage.uncertain) {
        throw const FormatException();
      }
      _set(AccountSwitchProbeStage.complete);
    } catch (_) {
      _set(AccountSwitchProbeStage.uncertain);
    }
  }

  /// Tests/process shutdown only; preserve the native observer after uncertainty.
  Future<void> close() async {
    _closed = true;
    await _subscription.cancel();
    await _binding.dispose();
    super.dispose();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RecipientAccountSwitchProbe? probe;
  try {
    probe = await RecipientAccountSwitchProbe.prepare(
      debugBuild: kDebugMode,
      enabled: const bool.fromEnvironment(
        'TRAELYX_GUARDIAN_ACCOUNT_SWITCH_PROBE',
      ),
      projectUrl: const String.fromEnvironment('TRAELYX_SUPABASE_URL'),
      initialize: initializeAccount,
      port: const MethodChannelGuardianOwnerPort(),
      driver: const MethodChannelGuardianDriverStatusPort(),
    );
  } catch (_) {
    // Fixed closed state; never expose raw SDK/platform errors or account data.
  }
  runApp(MaterialApp(home: AccountSwitchProbeScreen(probe: probe)));
}

class AccountSwitchProbeScreen extends StatefulWidget {
  const AccountSwitchProbeScreen({super.key, required this.probe});
  final RecipientAccountSwitchProbe? probe;

  @override
  State<AccountSwitchProbeScreen> createState() =>
      _AccountSwitchProbeScreenState();
}

class _AccountSwitchProbeScreenState extends State<AccountSwitchProbeScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guardian account replacement probe')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: ListenableBuilder(
        listenable: widget.probe ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          final ready = widget.probe?.stage == AccountSwitchProbeStage.ready;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operator test only. Requires separate live approval.',
              ),
              const Text(
                'Use a different account you control. Open its link here.',
              ),
              const SizedBox(height: 16),
              Text(
                widget.probe?.stage.label ??
                    'Probe closed; no action available',
              ),
              TextField(
                controller: _email,
                enabled: ready,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Different account email',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ready
                    ? () {
                        final email = _email.text;
                        _email.clear();
                        unawaited(widget.probe!.requestOnce(email));
                      }
                    : null,
                child: const Text('Request one sign-in link'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
