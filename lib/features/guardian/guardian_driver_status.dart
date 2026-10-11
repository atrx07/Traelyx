import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';

enum GuardianDriverState {
  disabled('disabled', 'Driver monitoring is off'),
  reactivationRequired(
    'reactivation_required',
    'A new driver review is required',
  ),
  waitingForTrip(
    'waiting_for_trip',
    'Consent ready; waiting for a recorded trip',
  ),
  calibrating('calibrating', 'Calibrating; evaluation is not ready'),
  monitoringExperimental(
    'monitoring_experimental',
    'Experimental evaluation observed',
  ),
  evidenceUnavailable(
    'evidence_unavailable',
    'Guardian evidence is unavailable',
  );

  const GuardianDriverState(this.wire, this.label);
  final String wire, label;
}

final class GuardianDriverStatus {
  const GuardianDriverStatus(this.state, this.expiresAt);
  final GuardianDriverState state;
  final DateTime? expiresAt;

  static GuardianDriverStatus parse(Object? raw, DateTime now) {
    if (raw is! Map ||
        raw.length != 2 ||
        !raw.containsKey('state') ||
        !raw.containsKey('expiresEpochMillis')) {
      throw const FormatException('Invalid Guardian driver status');
    }
    final states = GuardianDriverState.values.where(
      (s) => s.wire == raw['state'],
    );
    if (states.length != 1) {
      throw const FormatException('Unknown driver status');
    }
    final state = states.single;
    final epoch = raw['expiresEpochMillis'];
    DateTime? expiry;
    if (epoch != null) {
      if (epoch is! int ||
          epoch <= now.millisecondsSinceEpoch ||
          epoch > now.add(const Duration(hours: 8)).millisecondsSinceEpoch) {
        throw const FormatException('Invalid driver status expiry');
      }
      expiry = DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
    }
    if ((state == GuardianDriverState.disabled && expiry != null) ||
        (state != GuardianDriverState.disabled &&
            state != GuardianDriverState.evidenceUnavailable &&
            expiry == null)) {
      throw const FormatException('Inconsistent driver status');
    }
    return GuardianDriverStatus(state, expiry);
  }
}

abstract interface class GuardianDriverStatusPort {
  Future<GuardianDriverStatus> read(String owner);
}

final class MethodChannelGuardianDriverStatusPort
    implements GuardianDriverStatusPort {
  const MethodChannelGuardianDriverStatusPort();
  static const _channel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_activation',
  );

  @override
  Future<GuardianDriverStatus> read(String owner) async {
    if (!RegExp(
      r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
    ).hasMatch(owner)) {
      throw const FormatException('Invalid Guardian account');
    }
    final raw = await _channel.invokeMethod<Object?>('driverStatus', {
      'ownerId': owner,
    });
    return GuardianDriverStatus.parse(raw, DateTime.now().toUtc());
  }
}

final class GuardianDriverCheck {
  const GuardianDriverCheck({
    this.status,
    this.checkedAt,
    this.busy = false,
    this.notice,
  });
  final GuardianDriverStatus? status;
  final DateTime? checkedAt;
  final bool busy;
  final String? notice;
}

/// Explicit, local-only observations. No Auth refresh, registration, activation or polling.
class GuardianDriverStatusController
    extends StateNotifier<GuardianDriverCheck> {
  GuardianDriverStatusController(this.owner, this.account, this.port)
    : super(const GuardianDriverCheck()) {
    _identity = account.identityChanges.listen((identity) {
      if (identity?.userId != owner) clear();
    }, onError: (Object _) => clear());
  }
  final String owner;
  final AccountGateway account;
  final GuardianDriverStatusPort port;
  late final StreamSubscription<Object?> _identity;
  int _epoch = 0;

  void clear() {
    _epoch++;
    if (mounted) state = const GuardianDriverCheck();
  }

  Future<void> check() async {
    if (!mounted || state.busy) return;
    final epoch = _epoch;
    state = const GuardianDriverCheck(busy: true);
    try {
      if (account.currentIdentity?.userId != owner) {
        throw const FormatException();
      }
      final status = await port.read(owner).timeout(const Duration(seconds: 5));
      if (!mounted || epoch != _epoch) return;
      if (account.currentIdentity?.userId != owner) {
        throw const FormatException();
      }
      state = GuardianDriverCheck(
        status: status,
        checkedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      if (mounted && epoch == _epoch) {
        state = const GuardianDriverCheck(
          notice:
              'Driver state could not be checked. Open Account if needed, then try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    unawaited(_identity.cancel());
    super.dispose();
  }
}

final guardianDriverStatusPortProvider = Provider<GuardianDriverStatusPort>(
  (ref) => const MethodChannelGuardianDriverStatusPort(),
);
final guardianDriverStatusProvider = StateNotifierProvider.autoDispose
    .family<GuardianDriverStatusController, GuardianDriverCheck, String>(
      (ref, owner) => GuardianDriverStatusController(
        owner,
        ref.watch(accountGatewayProvider),
        ref.watch(guardianDriverStatusPortProvider),
      ),
    );
