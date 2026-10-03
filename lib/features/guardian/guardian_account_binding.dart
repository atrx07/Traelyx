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
        result.complete(true);
      } catch (_) {
        _hasBoundOwner = false;
        result.complete(false);
      }
    });
    return result.future;
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
