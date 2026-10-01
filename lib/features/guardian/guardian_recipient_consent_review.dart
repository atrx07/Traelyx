import 'package:flutter/material.dart';
import 'package:traelyx/features/guardian/guardian_recipient_consent.dart';

/// A deliberate review only. No Firebase initialization, permission prompt,
/// device registration or server mutation occurs here.
Future<GuardianRecipientConsent?> showGuardianRecipientConsentReview(
  BuildContext context,
  String ownerId,
) {
  var deliveryLimits = false;
  var providerDisclosure = false;
  return showDialog<GuardianRecipientConsent>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Review Guardian notifications'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If you opt in, this device may receive generic Guardian push notices '
                'for drivers who separately allow alerts to you. Pairing alone does not turn them on.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Experimental rules may miss an event or raise a false alarm. Push may be late or never arrive. '
                'This is not emergency assistance. No emergency call is placed.',
              ),
              CheckboxListTile(
                key: const ValueKey('guardian-recipient-limits'),
                value: deliveryLimits,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I understand the detection and delivery limits',
                ),
                onChanged: (value) =>
                    setDialogState(() => deliveryLimits = value ?? false),
              ),
              const Text(
                'Registration sends Firebase installation and device metadata to Google and stores '
                'a routing token privately for this account. Push content contains no driver name, '
                'location, speed or event details. Open Traelyx to check current permission and details.',
              ),
              CheckboxListTile(
                key: const ValueKey('guardian-recipient-provider'),
                value: providerDisclosure,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I agree to this push registration'),
                onChanged: (value) =>
                    setDialogState(() => providerDisclosure = value ?? false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('guardian-recipient-confirm-review'),
            onPressed: deliveryLimits && providerDisclosure
                ? () => Navigator.pop(
                    context,
                    GuardianRecipientConsent(
                      ownerId: ownerId,
                      deliveryLimitsAcknowledged: deliveryLimits,
                      providerDisclosureAccepted: providerDisclosure,
                      reviewedAt: DateTime.now().toUtc(),
                    ),
                  )
                : null,
            child: const Text('Confirm review'),
          ),
        ],
      ),
    ),
  );
}
