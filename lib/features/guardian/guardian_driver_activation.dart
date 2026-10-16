import 'dart:async';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';

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
  Future<String?> stop(String owner);
  Future<List<String>> pendingRevokes(String owner);
  Future<void> confirmRevoke(String owner, String activation);
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

  @override
  Future<String?> stop(String owner) async {
    final raw = await _channel.invokeMethod<Object?>('stop', {
      'ownerId': owner,
    });
    if (raw is! Map || raw.length != 1 || !raw.containsKey('activationId')) {
      throw const FormatException('Invalid Guardian stop response');
    }
    final activation = raw['activationId'];
    if (activation != null &&
        (activation is! String || !_uuid.hasMatch(activation))) {
      throw const FormatException('Invalid Guardian stopped activation');
    }
    return activation as String?;
  }

  @override
  Future<List<String>> pendingRevokes(String owner) async {
    final raw = await _channel.invokeMethod<Object?>('pendingRevokes', {
      'ownerId': owner,
    });
    if (raw is! List || raw.length > 8) throw const FormatException();
    final result = <String>[];
    for (final item in raw) {
      if (item is! Map || item.length != 1 || item['activationId'] is! String) {
        throw const FormatException('Invalid Guardian revoke ticket');
      }
      final activation = item['activationId'] as String;
      if (!_uuid.hasMatch(activation) || result.contains(activation)) {
        throw const FormatException('Invalid Guardian revoke identity');
      }
      result.add(activation);
    }
    return result;
  }

  @override
  Future<void> confirmRevoke(String owner, String activation) =>
      _channel.invokeMethod<void>('confirmRevoke', {
        'ownerId': owner,
        'activationId': activation,
      });
}

/// Decimal text preserves the full PostgreSQL bigint range on every Dart target.
final class GuardianDriverRevision {
  const GuardianDriverRevision._(this.value);
  final String value;

  static GuardianDriverRevision parse(Object? raw) {
    if (raw is! Map || raw.length != 1 || raw['revision'] is! String) {
      throw const FormatException('Invalid Guardian revision');
    }
    final value = raw['revision'] as String;
    if (!RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(value) ||
        BigInt.parse(value) > BigInt.parse('9223372036854775807')) {
      throw const FormatException('Invalid Guardian revision');
    }
    return GuardianDriverRevision._(value);
  }
}

abstract interface class GuardianDriverSessionGateway {
  Future<GuardianDriverRevision> revision(String owner);
  Future<GuardianSessionConfirmation> activate(
    GuardianActivationDraft draft,
    DateTime preparedAt,
    GuardianDriverRevision revision,
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
  Future<GuardianDriverRevision> revision(String owner) async {
    _checkOwner(owner);
    final raw = await client
        .rpc<Object?>(
          'get_guardian_driver_revision_v2',
          params: {'expected_user_id': owner},
        )
        .timeout(const Duration(seconds: 20));
    _checkOwner(owner);
    return GuardianDriverRevision.parse(raw);
  }

  @override
  Future<GuardianSessionConfirmation> activate(
    GuardianActivationDraft draft,
    DateTime preparedAt,
    GuardianDriverRevision revision,
  ) async {
    _checkOwner(draft.ownerId);
    final Object? raw = await client
        .rpc<Object?>(
          'set_guardian_driver_session_v2',
          params: {
            'expected_user_id': draft.ownerId,
            'activation': draft.activationId,
            'credential': draft.credential,
            'expected_revision': revision.value,
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
          'set_guardian_driver_session_v2',
          params: {
            'expected_user_id': owner,
            'activation': activation,
            'credential': null,
            'expected_revision': null,
          },
        )
        .timeout(const Duration(seconds: 20));
    _checkOwner(owner);
    if (raw is! Map || raw.length != 1 || raw['enabled'] != false) {
      throw const FormatException('Invalid Guardian revocation response');
    }
  }
}

/// Reusable by explicit sign-out while the original Auth owner is still present.
final class GuardianDriverStopService {
  const GuardianDriverStopService(this.account, this.native, this.server);
  final AccountGateway account;
  final GuardianNativeActivationPort native;
  final GuardianDriverSessionGateway server;

  /// Stops local authority before attempting an exact, owner-checked server revoke.
  /// A failed network revoke cannot restore the erased local capability.
  Future<void> stop(String owner) => _stop(owner, invalidateReview: true);

  Future<void> _stop(String owner, {required bool invalidateReview}) async {
    if (!_uuid.hasMatch(owner) || account.currentIdentity?.userId != owner) {
      throw const GuardianActivationException('Guardian account unavailable.');
    }
    if (invalidateReview && account is GuardianBoundAccountGateway) {
      (account as GuardianBoundAccountGateway).invalidateDriverReview();
    }
    // Native verifies its bound owner. Local stop must not wait for an unrelated
    // recipient-reconciliation request or Auth refresh before erasing authority.
    try {
      await native.stop(owner);
    } catch (_) {
      throw const GuardianActivationException(
        'Guardian local stop could not be confirmed. Check driver state and try again.',
      );
    }
    try {
      await _reconcileStops(owner);
    } catch (_) {
      throw const GuardianActivationException(
        'Guardian stopped locally. Server confirmation is unavailable.',
      );
    }
  }

  Future<void> _reconcileStops(String owner) async {
    void checkOwner() {
      if (account.currentIdentity?.userId != owner) {
        throw const GuardianActivationException('Signed-in account changed.');
      }
    }

    checkOwner();
    final pending = await native.pendingRevokes(owner);
    checkOwner();
    for (final activation in pending) {
      checkOwner();
      await server.revoke(owner, activation);
      checkOwner();
      await native.confirmRevoke(owner, activation);
      checkOwner();
    }
  }
}

/// Not exposed in the UI until recorder, recipient opt-in and delivery gates pass.
final class GuardianDriverActivationService {
  const GuardianDriverActivationService(
    this.account,
    this.native,
    this.server, {
    this.now = DateTime.now,
  });
  final GuardianBoundAccountGateway account;
  final GuardianNativeActivationPort native;
  final GuardianDriverSessionGateway server;
  final DateTime Function() now;

  Future<void> stop(String owner) =>
      GuardianDriverStopService(account, native, server).stop(owner);

  Future<DateTime> prepareAfterExplicitConsent(
    GuardianDriverConsent consent,
  ) async {
    final owner = consent.ownerId;
    final forwardAxis = consent.forwardAxis;
    if (!_uuid.hasMatch(owner) ||
        !consent.isFreshAt(now().toUtc()) ||
        account.currentIdentity?.userId != owner) {
      throw const GuardianActivationException('Guardian account unavailable.');
    }
    GuardianActivationDraft? draft;
    try {
      return await account.runDriverActivation(owner, (generation) async {
        void checkReview() {
          if (!consent.isFreshAt(now().toUtc()) ||
              !account.canContinueDriverActivation(owner, generation)) {
            throw const GuardianActivationException('Guardian review changed.');
          }
        }

        checkReview();
        await GuardianDriverStopService(
          account,
          native,
          server,
        )._stop(owner, invalidateReview: false);
        checkReview();
        final revision = await server.revision(owner);
        checkReview();
        final preparedAt = now().toUtc();
        final proposal = await native.begin(owner, forwardAxis);
        draft = proposal;
        if (proposal.ownerId != owner ||
            proposal.forwardAxis != forwardAxis ||
            !_uuid.hasMatch(proposal.activationId) ||
            !_credential.hasMatch(proposal.credential)) {
          throw const FormatException('Guardian proposal changed');
        }
        checkReview();
        final confirmed = await server.activate(proposal, preparedAt, revision);
        checkReview();
        if (confirmed.activationId != proposal.activationId) {
          throw const FormatException('Guardian owner or confirmation changed');
        }
        final expiry = await native.commit(
          owner,
          proposal.activationId,
          confirmed.expiresAt,
        );
        checkReview();
        return expiry;
      });
    } catch (_) {
      var localCleanupFailed = false;
      if (draft != null) {
        try {
          await native.abort(owner, draft!.activationId);
        } catch (_) {
          localCleanupFailed = true;
        }
        if (account.currentIdentity?.userId == owner) {
          try {
            await server.revoke(owner, draft!.activationId);
            if (!localCleanupFailed &&
                account.currentIdentity?.userId == owner) {
              await native.confirmRevoke(owner, draft!.activationId);
            }
          } catch (_) {
            // The exact native ticket remains available for a later Stop retry.
          }
        }
      }
      throw GuardianActivationException(
        localCleanupFailed
            ? 'Guardian local cleanup could not be confirmed. Check driver state and try Stop.'
            : 'This Guardian activation could not be confirmed.',
      );
    }
  }
}
