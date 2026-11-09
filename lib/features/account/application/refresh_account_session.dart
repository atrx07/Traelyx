import 'package:traelyx/features/account/domain/account_gateway.dart';

enum AccountRefreshOutcome {
  refreshed,
  failed,
  ended,
  accountChanged,
  unavailable,
}

/// Classifies the authoritative post-operation identity, including a late SDK
/// response after another account signed in. Never signs out or retries itself.
Future<AccountRefreshOutcome> refreshAccountSession(
  AccountGateway account,
) async {
  if (!account.isAvailable) return AccountRefreshOutcome.unavailable;
  final owner = account.currentIdentity?.userId;
  if (owner == null) return AccountRefreshOutcome.ended;
  var refreshed = false;
  try {
    await account.refreshSession();
    refreshed = true;
  } catch (_) {
    // Provider bodies and credentials never become presentation data.
  }
  final current = account.currentIdentity?.userId;
  if (current == null) return AccountRefreshOutcome.ended;
  if (current != owner) return AccountRefreshOutcome.accountChanged;
  return refreshed
      ? AccountRefreshOutcome.refreshed
      : AccountRefreshOutcome.failed;
}
