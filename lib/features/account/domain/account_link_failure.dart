enum AccountLinkFailure { network, rateLimited, service, rejected, unknown }

final class AccountLinkException implements Exception {
  const AccountLinkException(this.reason);

  final AccountLinkFailure reason;
}
