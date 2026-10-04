import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_recipient_registration.dart';

/// Enabled only after hosted registration and withdrawal gates pass.
final guardianRecipientPilotProvider = Provider<bool>((ref) => false);

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
