import 'dart:async';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';

final _recipientUuid = RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');

final class GuardianRecipientLocalStatus {
  const GuardianRecipientLocalStatus(this.deviceId, this.generation);

  final String deviceId;
  final String generation;
}

abstract interface class GuardianOwnerPort {
  Future<void> bindOwner(String? ownerId);
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId);
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(String ownerId);
  Future<void> recordRegistrationAttempt(
    String ownerId,
    GuardianRecipientLocalStatus status,
  );
  Future<void> confirmPendingRevoke(
    String ownerId,
    GuardianRecipientLocalStatus status,
  );
  Future<void> disableConfirmedRecipient(
    String ownerId,
    GuardianRecipientLocalStatus status,
  );
}

final class MethodChannelGuardianOwnerPort implements GuardianOwnerPort {
  const MethodChannelGuardianOwnerPort();

  static const _driverChannel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_activation',
  );
  static const _recipientChannel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_recipient',
  );

  @override
  Future<void> bindOwner(String? ownerId) async {
    // Sign-out waits for both local authorities to be cleared before Auth exits.
    await _recipientChannel.invokeMethod<void>('bindOwner', {
      'ownerId': ownerId,
    });
    await _driverChannel.invokeMethod<void>('bindOwner', {'ownerId': ownerId});
  }

  @override
  Future<GuardianRecipientLocalStatus?> recipientStatus(String ownerId) async {
    if (!_recipientUuid.hasMatch(ownerId)) throw const FormatException();
    final raw = await _recipientChannel.invokeMethod<Object?>('snapshot', {
      'ownerId': ownerId,
    });
    if (raw == null) return null;
    if (raw is! Map ||
        raw.length != 3 ||
        !raw.containsKey('deviceId') ||
        !raw.containsKey('generation') ||
        !raw.containsKey('expiresAtEpochMillis')) {
      throw const FormatException('Invalid Guardian recipient status');
    }
    final device = raw['deviceId'];
    final generation = raw['generation'];
    final expiresAt = raw['expiresAtEpochMillis'];
    if (device is! String ||
        generation is! String ||
        !_recipientUuid.hasMatch(device) ||
        !_recipientUuid.hasMatch(generation) ||
        expiresAt is! int ||
        expiresAt <= 0) {
      throw const FormatException('Invalid Guardian recipient status');
    }
    return GuardianRecipientLocalStatus(device, generation);
  }

  @override
  Future<List<GuardianRecipientLocalStatus>> pendingRevokes(
    String ownerId,
  ) async {
    if (!_recipientUuid.hasMatch(ownerId)) throw const FormatException();
    final raw = await _recipientChannel.invokeMethod<Object?>(
      'pendingRevokes',
      {'ownerId': ownerId},
    );
    if (raw is! List || raw.length > 8) throw const FormatException();
    final result = <GuardianRecipientLocalStatus>[];
    final seen = <(String, String)>{};
    for (final item in raw) {
      if (item is! Map ||
          item.length != 2 ||
          !item.containsKey('deviceId') ||
          !item.containsKey('generation')) {
        throw const FormatException();
      }
      final device = item['deviceId'];
      final generation = item['generation'];
      if (device is! String ||
          generation is! String ||
          !_recipientUuid.hasMatch(device) ||
          !_recipientUuid.hasMatch(generation) ||
          !seen.add((device, generation))) {
        throw const FormatException();
      }
      result.add(GuardianRecipientLocalStatus(device, generation));
    }
    return result;
  }

  @override
  Future<void> recordRegistrationAttempt(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) {
    if (!_recipientUuid.hasMatch(ownerId) ||
        !_recipientUuid.hasMatch(status.deviceId) ||
        !_recipientUuid.hasMatch(status.generation)) {
      throw const FormatException();
    }
    return _recipientChannel.invokeMethod<void>('recordAttempt', {
      'ownerId': ownerId,
      'deviceId': status.deviceId,
      'generation': status.generation,
    });
  }

  @override
  Future<void> confirmPendingRevoke(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) {
    if (!_recipientUuid.hasMatch(ownerId) ||
        !_recipientUuid.hasMatch(status.deviceId) ||
        !_recipientUuid.hasMatch(status.generation)) {
      throw const FormatException();
    }
    return _recipientChannel.invokeMethod<void>('confirmRevoke', {
      'ownerId': ownerId,
      'deviceId': status.deviceId,
      'generation': status.generation,
    });
  }

  @override
  Future<void> disableConfirmedRecipient(
    String ownerId,
    GuardianRecipientLocalStatus status,
  ) {
    if (!_recipientUuid.hasMatch(ownerId) ||
        !_recipientUuid.hasMatch(status.deviceId) ||
        !_recipientUuid.hasMatch(status.generation)) {
      throw const FormatException();
    }
    return _recipientChannel.invokeMethod<void>('disableConfirmed', {
      'ownerId': ownerId,
      'deviceId': status.deviceId,
      'generation': status.generation,
    });
  }
}

final class GuardianLocalCleanupException implements Exception {
  const GuardianLocalCleanupException();
}

/// Keeps native Guardian authority aligned with Auth without delaying local trips.
final class GuardianBoundAccountGateway
    implements AccountGateway, SupabaseClientSource {
  GuardianBoundAccountGateway(
    this._account,
    this._guardian, {
    this.deviceRevoker,
  }) {
    _subscription = _account.identityChanges.listen((_) => _updateOwner());
    _updateOwner();
  }

  final AccountGateway _account;
  final GuardianOwnerPort _guardian;
  final GuardianDeviceRevoker? deviceRevoker;

  @override
  SupabaseClient? get accountClient => accountClientOf(_account);
  late final StreamSubscription<AccountIdentity?> _subscription;
  Future<void> _tail = Future<void>.value();
  String? _desiredOwner;
  bool _signingOut = false;
  bool _preparingSignOut = false;
  bool _localCleanupRequired = false;
  String? _cleanupOwnerId;
  bool _hasBoundOwner = false;
  String? _boundOwner;

  void _updateOwner() {
    _desiredOwner = _signingOut || _localCleanupRequired
        ? null
        : _account.currentIdentity?.userId;
    unawaited(_queueBind());
  }

  // Every operation samples the latest target when it runs. The native bridge
  // also serializes calls, so an older account cannot finish after a newer one.
  Future<bool> _queueBind() {
    final result = Completer<bool>();
    _tail = _tail.then((_) async {
      final target = _desiredOwner;
      try {
        await _guardian.bindOwner(target);
        _boundOwner = target;
        _hasBoundOwner = true;
        try {
          if (target != null) await _reconcilePending(target);
          result.complete(true);
        } catch (_) {
          result.complete(false);
        }
      } catch (_) {
        _hasBoundOwner = false;
        result.complete(false);
      }
    });
    return result.future;
  }

  Future<void> _reconcilePending(String owner) async {
    void checkOwner() {
      if (_account.currentIdentity?.userId != owner ||
          _desiredOwner != owner ||
          _signingOut ||
          _localCleanupRequired) {
        throw const GuardianLocalCleanupException();
      }
    }

    checkOwner();
    final pending = await _guardian.pendingRevokes(owner);
    checkOwner();
    if (pending.isEmpty) return;
    final revoker = deviceRevoker;
    if (revoker == null) throw const GuardianLocalCleanupException();
    for (final status in pending) {
      checkOwner();
      await revoker.revoke(owner, status.deviceId, status.generation);
      checkOwner();
      final local = await _guardian.recipientStatus(owner);
      checkOwner();
      if (local?.deviceId == status.deviceId &&
          local?.generation == status.generation) {
        await _guardian.disableConfirmedRecipient(owner, status);
        checkOwner();
        await _guardian.bindOwner(owner);
      } else {
        await _guardian.confirmPendingRevoke(owner, status);
      }
      checkOwner();
    }
  }

  /// A later consent flow must call this and check the Auth identity again.
  Future<bool> ensureCurrentOwnerBound() {
    if (_signingOut || _localCleanupRequired) return Future<bool>.value(false);
    _desiredOwner = _account.currentIdentity?.userId;
    return _queueBind();
  }

  Future<void> dispose() => _subscription.cancel();

  @override
  bool get isAvailable => _account.isAvailable;

  @override
  AccountIdentity? get currentIdentity => _account.currentIdentity;

  @override
  Stream<AccountIdentity?> get identityChanges => _account.identityChanges;

  @override
  Future<void> sendSignInLink(String email) => _account.sendSignInLink(email);

  @override
  Future<void> refreshSession() => _account.refreshSession();

  @override
  Future<void> signOut() async {
    if (_preparingSignOut || _signingOut) {
      throw const GuardianLocalCleanupException();
    }
    _preparingSignOut = true;
    try {
      await _signOutGuarded();
    } finally {
      _preparingSignOut = false;
    }
  }

  Future<void> _signOutGuarded() async {
    final owner = _account.currentIdentity?.userId;
    if (_localCleanupRequired && owner != _cleanupOwnerId) {
      throw const GuardianLocalCleanupException();
    }
    if (!_localCleanupRequired && owner != null) {
      await _tail;
      if (_account.currentIdentity?.userId != owner ||
          _desiredOwner != owner ||
          !_hasBoundOwner ||
          _boundOwner != owner) {
        throw const GuardianLocalCleanupException();
      }
      final GuardianRecipientLocalStatus? status;
      try {
        status = await _guardian.recipientStatus(owner);
      } catch (_) {
        throw const GuardianLocalCleanupException();
      }
      if (_account.currentIdentity?.userId != owner) {
        throw const GuardianLocalCleanupException();
      }
      if (status != null) {
        final revoker = deviceRevoker;
        if (revoker == null) throw const GuardianLocalCleanupException();
        try {
          await revoker.revoke(owner, status.deviceId, status.generation);
        } catch (_) {
          throw const GuardianLocalCleanupException();
        }
        if (_account.currentIdentity?.userId != owner) {
          throw const GuardianLocalCleanupException();
        }
        try {
          await _guardian.disableConfirmedRecipient(owner, status);
        } catch (_) {
          throw const GuardianLocalCleanupException();
        }
        if (_account.currentIdentity?.userId != owner) {
          throw const GuardianLocalCleanupException();
        }
      }
    }
    _signingOut = true;
    _localCleanupRequired = true;
    _cleanupOwnerId = owner;
    _desiredOwner = null;
    try {
      if (!await _queueBind()) throw const GuardianLocalCleanupException();
      if (_account.currentIdentity?.userId != owner) {
        throw const GuardianLocalCleanupException();
      }
      await _account.signOut();
      _localCleanupRequired = false;
      _cleanupOwnerId = null;
    } finally {
      _signingOut = false;
      _updateOwner();
    }
  }
}
