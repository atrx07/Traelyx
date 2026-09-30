import 'dart:async';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';

const guardianForwardAxes = {'+x', '-x', '+y', '-y', '+z', '-z'};
final _uuid = RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');
final _credential = RegExp(r'^[a-f0-9]{64}$');

final class GuardianActivationException implements Exception {
  const GuardianActivationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transient capability. Keep this value in memory only and never log it.
final class GuardianActivationDraft {
  const GuardianActivationDraft({
    required this.ownerId,
    required this.activationId,
    required this.credential,
    required this.forwardAxis,
  });
  final String ownerId, activationId, credential, forwardAxis;

  @override
  String toString() => 'GuardianActivationDraft(redacted)';
}

final class GuardianSessionConfirmation {
  const GuardianSessionConfirmation(this.activationId, this.expiresAt);
  final String activationId;
  final DateTime expiresAt;

  static GuardianSessionConfirmation parse(
    Object? raw,
    String expectedActivation,
    DateTime preparedAt,
  ) {
    if (raw is! Map ||
        raw.length != 3 ||
        raw['enabled'] != true ||
        raw['activation_id'] != expectedActivation ||
        raw['expires_at'] is! String) {
      throw const FormatException('Invalid Guardian session confirmation');
    }
    final timestamp = raw['expires_at'] as String;
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(timestamp)) {
      throw const FormatException('Guardian expiry has no timezone');
    }
    final expiry = DateTime.tryParse(timestamp);
    if (expiry == null ||
        !expiry.isUtc ||
        !expiry.isAfter(DateTime.now()) ||
        expiry.isAfter(preparedAt.add(const Duration(hours: 8, minutes: 2)))) {
      throw const FormatException('Invalid Guardian session expiry');
    }
    return GuardianSessionConfirmation(expectedActivation, expiry);
  }
}

abstract interface class GuardianNativeActivationPort {
  Future<GuardianActivationDraft> begin(String owner, String axis);
  Future<DateTime> commit(
    String owner,
    String activation,
    DateTime serverExpiry,
  );
  Future<void> abort(String owner, String activation);
  Future<void> disable(String owner);
}

final class MethodChannelGuardianActivationPort
    implements GuardianNativeActivationPort {
  const MethodChannelGuardianActivationPort();
  static const _channel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_activation',
  );

  @override
  Future<GuardianActivationDraft> begin(String owner, String axis) async {
    final raw = await _channel.invokeMethod<Object?>('begin', {
      'ownerId': owner,
      'forwardAxis': axis,
      'rigidMountConfirmed': true,
    });
    if (raw is! Map ||
        raw.length != 4 ||
        raw['ownerId'] != owner ||
        raw['forwardAxis'] != axis ||
        raw['activationId'] is! String ||
        raw['credential'] is! String ||
        !_uuid.hasMatch(raw['activationId'] as String) ||
        !_credential.hasMatch(raw['credential'] as String)) {
      throw const FormatException('Invalid local Guardian proposal');
    }
    return GuardianActivationDraft(
      ownerId: owner,
      activationId: raw['activationId'] as String,
      credential: raw['credential'] as String,
      forwardAxis: axis,
    );
  }

  @override
  Future<DateTime> commit(
    String owner,
    String activation,
    DateTime serverExpiry,
  ) async {
    final raw = await _channel.invokeMethod<Object?>('commit', {
      'ownerId': owner,
      'activationId': activation,
      'serverExpiresEpochMillis': serverExpiry.millisecondsSinceEpoch,
    });
    if (raw is! Map ||
        raw.length != 2 ||
        raw['localLeasePresent'] != true ||
        raw['expiresEpochMillis'] is! int) {
      throw const FormatException('Invalid local Guardian lease');
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      raw['expiresEpochMillis'] as int,
      isUtc: true,
    );
    if (!expiry.isAfter(DateTime.now()) || expiry.isAfter(serverExpiry)) {
      throw const FormatException('Invalid local Guardian lease expiry');
    }
    return expiry;
  }

  @override
  Future<void> abort(String owner, String activation) =>
      _channel.invokeMethod<void>('abort', {
        'ownerId': owner,
        'activationId': activation,
      });

  @override
  Future<void> disable(String owner) =>
      _channel.invokeMethod<void>('disable', {'ownerId': owner});
}

abstract interface class GuardianDriverSessionGateway {
  Future<GuardianSessionConfirmation> activate(
    GuardianActivationDraft draft,
    DateTime preparedAt,
  );
  Future<void> revoke(String owner, String activation);
}

final class SupabaseGuardianDriverSessionGateway
    implements GuardianDriverSessionGateway {
  const SupabaseGuardianDriverSessionGateway(this.client);
  final SupabaseClient client;

  void _checkOwner(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw const GuardianActivationException('Signed-in account changed.');
    }
  }

  @override
  Future<GuardianSessionConfirmation> activate(
    GuardianActivationDraft draft,
    DateTime preparedAt,
  ) async {
    _checkOwner(draft.ownerId);
    final Object? raw = await client
        .rpc<Object?>(
          'set_guardian_driver_session_v1',
          params: {
            'expected_user_id': draft.ownerId,
            'activation': draft.activationId,
            'credential': draft.credential,
          },
        )
        .timeout(const Duration(seconds: 20));
    _checkOwner(draft.ownerId);
    return GuardianSessionConfirmation.parse(
      raw,
      draft.activationId,
      preparedAt,
    );
  }

  @override
  Future<void> revoke(String owner, String activation) async {
    _checkOwner(owner);
    final Object? raw = await client
        .rpc<Object?>(
          'set_guardian_driver_session_v1',
          params: {
            'expected_user_id': owner,
            'activation': activation,
            'credential': null,
          },
        )
        .timeout(const Duration(seconds: 20));
    _checkOwner(owner);
    if (raw is! Map || raw.length != 1 || raw['enabled'] != false) {
      throw const FormatException('Invalid Guardian revocation response');
    }
  }
}

/// Not exposed in the UI until recorder, recipient opt-in and delivery gates pass.
final class GuardianDriverActivationService {
  const GuardianDriverActivationService(this.account, this.native, this.server);
  final GuardianBoundAccountGateway account;
  final GuardianNativeActivationPort native;
  final GuardianDriverSessionGateway server;

  Future<DateTime> prepareAfterExplicitConsent(
    String owner,
    String forwardAxis,
  ) async {
    if (!_uuid.hasMatch(owner) ||
        !guardianForwardAxes.contains(forwardAxis) ||
        account.currentIdentity?.userId != owner ||
        !await account.ensureCurrentOwnerBound()) {
      throw const GuardianActivationException('Guardian account unavailable.');
    }
    GuardianActivationDraft? draft;
    try {
      final preparedAt = DateTime.now().toUtc();
      draft = await native.begin(owner, forwardAxis);
      if (draft.ownerId != owner ||
          draft.forwardAxis != forwardAxis ||
          !_uuid.hasMatch(draft.activationId) ||
          !_credential.hasMatch(draft.credential) ||
          account.currentIdentity?.userId != owner) {
        throw const FormatException('Guardian proposal changed');
      }
      final confirmed = await server.activate(draft, preparedAt);
      if (confirmed.activationId != draft.activationId ||
          account.currentIdentity?.userId != owner ||
          !await account.ensureCurrentOwnerBound()) {
        throw const FormatException('Guardian owner or confirmation changed');
      }
      final expiry = await native.commit(
        owner,
        draft.activationId,
        confirmed.expiresAt,
      );
      if (account.currentIdentity?.userId != owner ||
          !await account.ensureCurrentOwnerBound()) {
        throw const FormatException('Guardian owner changed during commit');
      }
      return expiry;
    } catch (_) {
      var localCleanupFailed = false;
      if (draft != null) {
        try {
          if (account.currentIdentity?.userId == owner) {
            await native.disable(owner);
          } else {
            await native.abort(owner, draft.activationId);
          }
        } catch (_) {
          localCleanupFailed = true;
        }
        if (account.currentIdentity?.userId == owner) {
          try {
            await server.revoke(owner, draft.activationId);
          } catch (_) {
            // The native capability is unavailable; server TTL is the fallback.
          }
        }
      }
      throw GuardianActivationException(
        localCleanupFailed
            ? 'Guardian local cleanup could not be confirmed. Alerts remain unavailable.'
            : 'Guardian activation could not be confirmed. Alerts remain unavailable.',
      );
    }
  }
}
