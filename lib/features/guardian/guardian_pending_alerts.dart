import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';

final _id = RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');
const _states = {
  'cancellable',
  'queued',
  'backend_accepted',
  'cancelled',
  'expired',
  'consent_revoked',
  'retries_exhausted',
};

final class GuardianLocalAlert {
  const GuardianLocalAlert(
    this.activationId,
    this.eventId,
    this.kind,
    this.state,
    this.canCancel,
    this.readyInMillis,
  );
  final String activationId, eventId, kind, state;
  final bool canCancel;
  final int? readyInMillis;
  String get label => kind == 'possible_crash'
      ? 'Possible-crash evidence (experimental)'
      : 'Severe-driving evidence (experimental)';
  String get status => switch (state) {
    'cancelled' => 'Cancelled locally',
    'backend_accepted' => 'Backend accepted; delivery is not confirmed',
    'expired' => 'Expired locally',
    'consent_revoked' => 'Authorization unavailable',
    'retries_exhausted' => 'Attempts exhausted; delivery is not confirmed',
    _ =>
      canCancel
          ? 'Waiting locally; cancellation is available'
          : 'Send attempt started; cannot retract',
  };
  @override
  String toString() => 'GuardianLocalAlert(redacted)';

  static List<GuardianLocalAlert> parse(Object? raw) {
    if (raw is! List || raw.length > 16) {
      throw const FormatException('Invalid local alerts');
    }
    final ids = <String>{};
    return List.unmodifiable(
      raw.map((item) {
        if (item is! Map ||
            item.length != 6 ||
            !item.keys.toSet().containsAll({
              'activationId',
              'eventId',
              'kind',
              'state',
              'canCancel',
              'cancellationReadyInMillis',
            })) {
          throw const FormatException('Invalid local alert');
        }
        final activation = item['activationId'], event = item['eventId'];
        final kind = item['kind'],
            state = item['state'],
            cancel = item['canCancel'];
        final remaining = item['cancellationReadyInMillis'];
        if (activation is! String ||
            !_id.hasMatch(activation) ||
            event is! String ||
            !_id.hasMatch(event) ||
            !ids.add(event) ||
            (kind != 'possible_crash' && kind != 'severe_drive') ||
            state is! String ||
            !_states.contains(state) ||
            cancel is! bool ||
            (cancel && state != 'cancellable' && state != 'queued') ||
            (remaining != null &&
                (remaining is! int || remaining < 0 || remaining > 30000))) {
          throw const FormatException('Invalid local alert fields');
        }
        return GuardianLocalAlert(
          activation,
          event,
          kind as String,
          state,
          cancel,
          remaining as int?,
        );
      }),
    );
  }
}

abstract interface class GuardianPendingAlertsPort {
  Future<List<GuardianLocalAlert>> read(String owner);
  Future<bool> cancel(String owner, GuardianLocalAlert alert);
}

final class MethodChannelGuardianPendingAlertsPort
    implements GuardianPendingAlertsPort {
  const MethodChannelGuardianPendingAlertsPort();
  static const _channel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_activation',
  );
  @override
  Future<List<GuardianLocalAlert>> read(String owner) async {
    if (!_id.hasMatch(owner)) {
      throw const FormatException('Invalid Guardian account');
    }
    return GuardianLocalAlert.parse(
      await _channel.invokeMethod<Object?>('pendingAlerts', {'ownerId': owner}),
    );
  }

  @override
  Future<bool> cancel(String owner, GuardianLocalAlert alert) async {
    if (!_id.hasMatch(owner) ||
        !_id.hasMatch(alert.activationId) ||
        !_id.hasMatch(alert.eventId)) {
      throw const FormatException('Invalid Guardian cancellation');
    }
    final result = await _channel.invokeMethod<Object?>('cancelAlert', {
      'ownerId': owner,
      'activationId': alert.activationId,
      'eventId': alert.eventId,
    });
    if (result is! bool) {
      throw const FormatException('Invalid cancellation reply');
    }
    return result;
  }
}

final class GuardianPendingCheck {
  const GuardianPendingCheck({
    this.alerts = const [],
    this.busy = false,
    this.checked = false,
    this.notice,
  });
  final List<GuardianLocalAlert> alerts;
  final bool busy, checked;
  final String? notice;
}

/// Explicit local operations only; clearing UI never cancels an already requested native operation.
class GuardianPendingAlertsController
    extends StateNotifier<GuardianPendingCheck> {
  GuardianPendingAlertsController(this.owner, this.account, this.port)
    : super(const GuardianPendingCheck()) {
    _identity = account.identityChanges.listen((identity) {
      if (identity?.userId != owner) clear();
    }, onError: (Object _) => clear());
  }
  final String owner;
  final AccountGateway account;
  final GuardianPendingAlertsPort port;
  late final StreamSubscription<Object?> _identity;
  int _epoch = 0;
  bool get _sameOwner => account.currentIdentity?.userId == owner;
  void clear() {
    _epoch++;
    if (mounted) state = const GuardianPendingCheck();
  }

  Future<void> check() async {
    if (!mounted || state.busy || !_sameOwner) return;
    final epoch = _epoch;
    state = const GuardianPendingCheck(busy: true);
    try {
      final alerts = await port.read(owner).timeout(const Duration(seconds: 5));
      if (!mounted || epoch != _epoch || !_sameOwner) return;
      state = GuardianPendingCheck(alerts: alerts, checked: true);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        state = const GuardianPendingCheck(
          notice: 'Local alerts could not be checked. Try again.',
        );
      }
    }
  }

  Future<void> cancel(GuardianLocalAlert alert) async {
    if (!mounted ||
        state.busy ||
        !_sameOwner ||
        !alert.canCancel ||
        !state.alerts.contains(alert)) {
      return;
    }
    final epoch = _epoch;
    state = const GuardianPendingCheck(busy: true);
    try {
      final cancelled = await port
          .cancel(owner, alert)
          .timeout(const Duration(seconds: 5));
      if (!mounted || epoch != _epoch || !_sameOwner) return;
      state = GuardianPendingCheck(
        notice: cancelled
            ? 'Alert cancelled locally before sending began.'
            : 'Cancellation unavailable. An attempt may already have begun. Check again.',
      );
    } catch (_) {
      if (mounted && epoch == _epoch) {
        state = const GuardianPendingCheck(
          notice:
              'Cancellation could not be confirmed. Check again; an attempt may already have begun.',
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

final guardianPendingAlertsPortProvider = Provider<GuardianPendingAlertsPort>(
  (ref) => const MethodChannelGuardianPendingAlertsPort(),
);
final guardianPendingAlertsProvider = StateNotifierProvider.autoDispose
    .family<GuardianPendingAlertsController, GuardianPendingCheck, String>(
      (ref, owner) => GuardianPendingAlertsController(
        owner,
        ref.watch(accountGatewayProvider),
        ref.watch(guardianPendingAlertsPortProvider),
      ),
    );
