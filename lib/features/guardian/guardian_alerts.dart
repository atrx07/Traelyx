import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_models.dart';

enum GuardianDeliveryState {
  pending('Waiting for a provider attempt'),
  providerAccepted('Push provider accepted; device receipt unconfirmed'),
  deviceReceived('Recipient device received; opening unconfirmed'),
  viewed('Recipient opened the alert');

  const GuardianDeliveryState(this.label);
  final String label;
}

class GuardianAlert {
  const GuardianAlert({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.deliveryState,
    required this.driverName,
    required this.guardianName,
    required this.ownEvent,
  });
  final String id, kind, driverName, guardianName;
  final DateTime occurredAt;
  final GuardianDeliveryState deliveryState;
  final bool ownEvent;
  DateTime get expiresAt => occurredAt.add(const Duration(minutes: 10));
  GuardianAlert asViewed() => GuardianAlert(
    id: id,
    kind: kind,
    occurredAt: occurredAt,
    deliveryState: GuardianDeliveryState.viewed,
    driverName: driverName,
    guardianName: guardianName,
    ownEvent: ownEvent,
  );
  String get title => kind == 'possible_crash'
      ? 'Possible crash pattern — unconfirmed'
      : 'Strong braking pattern — unconfirmed';

  static List<GuardianAlert> parse(Object? value) {
    if (value is! List || value.length > 100) {
      throw const FormatException('Invalid Guardian alert list');
    }
    final ids = <String>{};
    return List.unmodifiable(
      value.map((raw) {
        if (raw is! Map ||
            raw.length != 9 ||
            raw['rule_version'] != 1 ||
            raw['uncertainty'] != 'experimental_not_confirmed' ||
            raw['own_event'] is! bool) {
          throw const FormatException('Invalid Guardian alert');
        }
        String text(String key, int limit) {
          final item = raw[key];
          if (item is! String || item.isEmpty || item.length > limit) {
            throw const FormatException('Invalid Guardian alert field');
          }
          return item;
        }

        final id = text('delivery_id', 36);
        if (!RegExp(
              r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
            ).hasMatch(id) ||
            !ids.add(id)) {
          throw const FormatException('Invalid Guardian delivery identity');
        }
        final kind = text('kind', 20);
        if (kind != 'possible_crash' && kind != 'severe_drive') {
          throw const FormatException('Unknown Guardian kind');
        }
        final time = DateTime.tryParse(text('occurred_at', 40));
        if (time == null || !time.isUtc) {
          throw const FormatException('Invalid Guardian time');
        }
        final state = switch (raw['status']) {
          'pending' => GuardianDeliveryState.pending,
          'provider_accepted' => GuardianDeliveryState.providerAccepted,
          'device_received' => GuardianDeliveryState.deviceReceived,
          'viewed' => GuardianDeliveryState.viewed,
          _ => throw const FormatException('Unavailable Guardian delivery'),
        };
        return GuardianAlert(
          id: id,
          kind: kind,
          occurredAt: time,
          deliveryState: state,
          driverName: text('driver_display_name', 80),
          guardianName: text('guardian_display_name', 80),
          ownEvent: raw['own_event'] as bool,
        );
      }),
    );
  }
}

abstract interface class GuardianAlertGateway {
  Future<List<GuardianAlert>> load(String owner);
  Future<bool> open(String owner, String delivery);
}

class SupabaseGuardianAlertGateway implements GuardianAlertGateway {
  const SupabaseGuardianAlertGateway(this.client);
  final SupabaseClient client;
  Future<Object?> _rpc(
    String owner,
    String name,
    Map<String, Object?> params,
  ) async {
    void check() {
      if (client.auth.currentUser?.id != owner) {
        throw const GuardianException(
          'Account changed. Reload Guardian alerts.',
        );
      }
    }

    check();
    try {
      final Object? result = await client.rpc(
        name,
        params: {'expected_user_id': owner, ...params},
      );
      check();
      return result;
    } on PostgrestException {
      throw const GuardianException(
        'Alert access could not be confirmed. Reload when connected.',
      );
    }
  }

  @override
  Future<List<GuardianAlert>> load(String owner) async =>
      GuardianAlert.parse(await _rpc(owner, 'list_guardian_alerts_v1', {}));
  @override
  Future<bool> open(String owner, String delivery) async =>
      await _rpc(owner, 'view_guardian_alert_v1', {'delivery': delivery}) ==
      true;
}

class GuardianInboxState {
  const GuardianInboxState({
    this.alerts = const [],
    this.opened,
    this.busy = false,
    this.loaded = false,
    this.notice,
  });
  final List<GuardianAlert> alerts;
  final GuardianAlert? opened;
  final bool busy, loaded;
  final String? notice;
}

class GuardianInbox extends StateNotifier<GuardianInboxState> {
  GuardianInbox(
    this.owner,
    this.gateway,
    this.account, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(const GuardianInboxState()) {
    _identity = account.identityChanges.listen((identity) {
      if (identity?.userId != owner) clear();
    }, onError: (Object _) => clear());
  }
  final String owner;
  final GuardianAlertGateway? gateway;
  final AccountGateway account;
  final DateTime Function() now;
  late final StreamSubscription<Object?> _identity;
  Timer? _expiry;
  int _epoch = 0;
  void clear() {
    _epoch++;
    _expiry?.cancel();
    if (mounted) state = const GuardianInboxState();
  }

  void _check() {
    if (!mounted ||
        gateway == null ||
        account.currentIdentity?.userId != owner) {
      throw const GuardianException('Sign in and reload Guardian alerts.');
    }
  }

  Future<void> reload() => _run();
  Future<void> open(GuardianAlert reviewed) => _run(reviewed: reviewed);
  Future<void> _run({GuardianAlert? reviewed}) async {
    if (state.busy) return;
    final epoch = _epoch;
    final known =
        reviewed == null || state.alerts.any((row) => identical(row, reviewed));
    _expiry?.cancel();
    state = const GuardianInboxState(busy: true);
    try {
      _check();
      if (!known || reviewed?.ownEvent == true) {
        throw const GuardianException(
          'Reload before opening an incoming alert.',
        );
      }
      final alerts =
          (await gateway!.load(owner).timeout(const Duration(seconds: 20)))
              .where(
                (row) =>
                    row.expiresAt.isAfter(now()) &&
                    !row.occurredAt.isAfter(now()),
              )
              .toList(growable: false);
      _check();
      if (epoch != _epoch) return;
      GuardianAlert? opened;
      if (reviewed != null) {
        for (final row in alerts) {
          if (row.id == reviewed.id && !row.ownEvent) opened = row;
        }
        if (opened == null ||
            !await gateway!
                .open(owner, opened.id)
                .timeout(const Duration(seconds: 20))) {
          throw const GuardianException(
            'This alert expired or its permission was revoked.',
          );
        }
        _check();
        if (epoch != _epoch) return;
        if (!opened.expiresAt.isAfter(now())) {
          throw const GuardianException('This alert expired.');
        }
      }
      opened = opened?.asViewed();
      state = GuardianInboxState(
        alerts: List.unmodifiable(
          alerts.map((row) => row.id == opened?.id ? opened! : row),
        ),
        opened: opened,
        loaded: true,
      );
      if (alerts.isNotEmpty) {
        final firstExpiry = alerts
            .map((row) => row.expiresAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final delay = firstExpiry.difference(now());
        _expiry = Timer(delay.isNegative ? Duration.zero : delay, clear);
      }
    } catch (e) {
      if (mounted && epoch == _epoch) {
        state = GuardianInboxState(
          notice: e is GuardianException
              ? e.message
              : 'Alert access unavailable. Reload when connected.',
        );
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    _expiry?.cancel();
    unawaited(_identity.cancel());
    super.dispose();
  }
}

final guardianAlertGatewayProvider = Provider<GuardianAlertGateway?>((ref) {
  final client = accountClientOf(ref.watch(accountGatewayProvider));
  return client != null ? SupabaseGuardianAlertGateway(client) : null;
});
final guardianInboxProvider = StateNotifierProvider.autoDispose
    .family<GuardianInbox, GuardianInboxState, String>(
      (ref, owner) => GuardianInbox(
        owner,
        ref.watch(guardianAlertGatewayProvider),
        ref.watch(accountGatewayProvider),
      ),
    );
