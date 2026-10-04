import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_recipient_registration.dart';

/// Only a deliberately configured debug pilot can expose recipient consent.
final guardianRecipientPilotProvider = Provider<bool>(
  (ref) =>
      kDebugMode &&
      const bool.fromEnvironment('TRAELYX_GUARDIAN_RECIPIENT_PILOT'),
);

final guardianRecipientRegistrationProvider =
    Provider<GuardianRecipientRegistrationService?>((ref) {
      final account = ref.watch(accountGatewayProvider);
      final client = accountClientOf(account);
      if (account is! GuardianBoundAccountGateway || client == null) {
        return null;
      }
      return GuardianRecipientRegistrationService(
        account: account,
        ownerPort: const MethodChannelGuardianOwnerPort(),
        tokenPort: const MethodChannelGuardianRecipientTokenPort(),
        server: GuardianDeviceServerGateway(
          SupabaseGuardianDeviceRpcTransport(client),
        ),
        receiptPort: const MethodChannelGuardianRecipientReceiptPort(),
      );
    });
