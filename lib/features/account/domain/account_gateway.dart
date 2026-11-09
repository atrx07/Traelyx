import 'package:traelyx/features/account/domain/account_identity.dart';

abstract interface class AccountGateway {
  bool get isAvailable;

  AccountIdentity? get currentIdentity;

  /// Identity snapshots, including null for genuine Auth loss. Provider refresh
  /// diagnostics must not replace identity with an error or imply sign-out;
  /// explicit operation failures remain available through their Futures.
  Stream<AccountIdentity?> get identityChanges;

  Future<void> sendSignInLink(String email);

  Future<void> refreshSession();

  Future<void> signOut();
}

final class AccountUnavailableException implements Exception {
  const AccountUnavailableException();
}

final class UnavailableAccountGateway implements AccountGateway {
  const UnavailableAccountGateway();

  @override
  bool get isAvailable => false;

  @override
  AccountIdentity? get currentIdentity => null;

  @override
  Stream<AccountIdentity?> get identityChanges => const Stream.empty();

  @override
  Future<void> refreshSession() =>
      Future<void>.error(const AccountUnavailableException());

  @override
  Future<void> sendSignInLink(String email) =>
      Future<void>.error(const AccountUnavailableException());

  @override
  Future<void> signOut() =>
      Future<void>.error(const AccountUnavailableException());
}
