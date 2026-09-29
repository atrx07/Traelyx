import 'dart:async';

import 'package:flutter/services.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';

abstract interface class GuardianOwnerPort {
  Future<void> bindOwner(String? ownerId);
}

final class MethodChannelGuardianOwnerPort implements GuardianOwnerPort {
  const MethodChannelGuardianOwnerPort();

  static const _channel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_activation',
  );

  @override
  Future<void> bindOwner(String? ownerId) async {
    await _channel.invokeMethod<void>('bindOwner', {'ownerId': ownerId});
  }
}

final class GuardianLocalCleanupException implements Exception {
  const GuardianLocalCleanupException();
}

/// Keeps native Guardian authority aligned with Auth without delaying local trips.
final class GuardianBoundAccountGateway implements AccountGateway {
  GuardianBoundAccountGateway(this._account, this._guardian) {
    _subscription = _account.identityChanges.listen((_) => _updateOwner());
    _updateOwner();
  }

  final AccountGateway _account;
  final GuardianOwnerPort _guardian;
  late final StreamSubscription<AccountIdentity?> _subscription;
  Future<void> _tail = Future<void>.value();
  String? _desiredOwner;
  bool _signingOut = false;
  bool _localCleanupRequired = false;

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
      try {
        await _guardian.bindOwner(_desiredOwner);
        result.complete(true);
      } catch (_) {
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
    _signingOut = true;
    _localCleanupRequired = true;
    _desiredOwner = null;
    try {
      if (!await _queueBind()) throw const GuardianLocalCleanupException();
      await _account.signOut();
      _localCleanupRequired = false;
    } finally {
      _signingOut = false;
      _updateOwner();
    }
  }
}
