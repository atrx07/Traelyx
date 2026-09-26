import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/domain/account_link_failure.dart';

AccountLinkFailure classifyAccountLinkFailure(Object error) {
  if (error is TimeoutException) return AccountLinkFailure.network;
  if (error is! AuthException) return AccountLinkFailure.unknown;

  final status = int.tryParse(error.statusCode ?? '');
  if (status == 429 ||
      error.code == 'over_email_send_rate_limit' ||
      error.code == 'over_request_rate_limit') {
    return AccountLinkFailure.rateLimited;
  }
  if (status != null && status >= 500) return AccountLinkFailure.service;
  if (error is AuthRetryableFetchException && status == null) {
    return AccountLinkFailure.network;
  }
  if (status != null && status >= 400) return AccountLinkFailure.rejected;
  return AccountLinkFailure.unknown;
}
