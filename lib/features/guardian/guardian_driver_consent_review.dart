import 'package:flutter/material.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';

/// Open only from a deliberate activation action after delivery gates pass.
/// Reviewing alone neither persists consent nor enables monitoring.
Future<GuardianDriverConsent?> showGuardianDriverConsentReview(
  BuildContext context,
  String ownerId,
) {
  String? forwardAxis;
  var rigidMount = false;
  var safetyLimits = false;
  var recipientSharing = false;
  return showDialog<GuardianDriverConsent>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Review driver alerts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Guardian alerts are experimental. They may miss a serious event or send a false alarm. '
                'They are not emergency assistance and delivery is not guaranteed.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Mount the phone rigidly. Choose which part of the mounted phone points toward the front of the vehicle. '
                'If the mount moves, stop and review the direction again.',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const ValueKey('guardian-forward-axis'),
                initialValue: forwardAxis,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Phone forward direction',
                ),
                items: const [
                  DropdownMenuItem(value: '+y', child: Text('Top edge')),
                  DropdownMenuItem(value: '-y', child: Text('Bottom edge')),
                  DropdownMenuItem(value: '+x', child: Text('Right edge')),
                  DropdownMenuItem(value: '-x', child: Text('Left edge')),
                  DropdownMenuItem(
                    value: '+z',
                    child: Text('Screen faces forward'),
                  ),
                  DropdownMenuItem(
                    value: '-z',
                    child: Text('Back faces forward'),
                  ),
                ],
                onChanged: (value) => setDialogState(() => forwardAxis = value),
              ),
              CheckboxListTile(
                key: const ValueKey('guardian-rigid-mount'),
                value: rigidMount,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I confirm this phone is rigidly mounted'),
                onChanged: (value) =>
                    setDialogState(() => rigidMount = value ?? false),
              ),
              CheckboxListTile(
                key: const ValueKey('guardian-safety-limits'),
                value: safetyLimits,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I understand the missed-event and false-alarm limits',
                ),
                onChanged: (value) =>
                    setDialogState(() => safetyLimits = value ?? false),
              ),
              const Text(
                'Only permitted event type, time and uncertainty are sent. '
                'Connected Guardians may see your shared name after opening an alert. '
                'Routes, live location, speed and trip history are not shared.',
              ),
              CheckboxListTile(
                key: const ValueKey('guardian-recipient-sharing'),
                value: recipientSharing,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I agree to these limited notices to opted-in Guardians',
                ),
                onChanged: (value) =>
                    setDialogState(() => recipientSharing = value ?? false),
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
            key: const ValueKey('guardian-confirm-review'),
            onPressed:
                forwardAxis != null &&
                    rigidMount &&
                    safetyLimits &&
                    recipientSharing
                ? () => Navigator.pop(
                    context,
                    GuardianDriverConsent(
                      ownerId: ownerId,
                      forwardAxis: forwardAxis!,
                      rigidMountConfirmed: rigidMount,
                      safetyLimitsAcknowledged: safetyLimits,
                      recipientSharingAcknowledged: recipientSharing,
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
