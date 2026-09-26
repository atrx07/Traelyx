import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/data/classify_account_link_failure.dart';
import 'package:traelyx/features/account/domain/account_link_failure.dart';

void main() {
  test('provider limits are distinct from connection failures', () {
    for (final error in [
      const AuthApiException('private response', statusCode: '429'),
      const AuthApiException(
        'private response',
        code: 'over_email_send_rate_limit',
      ),
      const AuthApiException(
        'private response',
        code: 'over_request_rate_limit',
      ),
    ]) {
      expect(classifyAccountLinkFailure(error), AccountLinkFailure.rateLimited);
    }
  });

  test('HTTP server failures are not reported as an offline phone', () {
    expect(
      classifyAccountLinkFailure(
        AuthRetryableFetchException(statusCode: '503'),
      ),
      AccountLinkFailure.service,
    );
    expect(
      classifyAccountLinkFailure(
        const AuthApiException('failure', statusCode: '500'),
      ),
      AccountLinkFailure.service,
    );
  });

  test('transport failures and timeouts suggest checking the connection', () {
    expect(
      classifyAccountLinkFailure(AuthRetryableFetchException()),
      AccountLinkFailure.network,
    );
    expect(
      classifyAccountLinkFailure(TimeoutException('timeout')),
      AccountLinkFailure.network,
    );
  });

  test(
    'rejected requests and unknown local faults do not blame the network',
    () {
      expect(
        classifyAccountLinkFailure(
          const AuthApiException('private response', statusCode: '400'),
        ),
        AccountLinkFailure.rejected,
      );
      expect(
        classifyAccountLinkFailure(StateError('private local detail')),
        AccountLinkFailure.unknown,
      );
    },
  );
}
