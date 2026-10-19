import 'package:flutter/material.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';

/// Open only from a deliberate action in the controlled debug driver pilot.
/// Reviewing alone neither persists consent nor enables monitoring.
Future<GuardianDriverConsent?> showGuardianDriverConsentReview(
  BuildContext context,
  String ownerId, {
  bool sendingAvailable = false,
}) {
  String? forwardAxis;
  var rigidMount = false;
  var safetyLimits = false;
  var recipientSharing = false;
  var sending = false;
  String? missingChoice() {
    if (forwardAxis == null) return 'Choose the phone forward direction first.';
    if (!rigidMount) {
      return 'Confirm a rigid vehicle mount, or cancel if not ready.';
    }
    if (!safetyLimits) return 'Review and acknowledge the safety limits.';
    if (!recipientSharing) {
      return 'Review and agree to the limited Guardian notices.';
    }
    if (sendingAvailable && !sending) {
      return 'Review and agree to experimental sending for this session.';
    }
    return null;
  }

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
              Text(
                'Confirming stores a temporary driver session in your Traelyx account and a private lease on this phone, '
                'lasting up to eight hours. '
                '${sendingAvailable ? 'This pilot can send experimental alerts during a recorded trip after this new review. Delivery is not guaranteed.' : 'This review uploads no trip data. Alert sending is unavailable in this build.'}',
              ),
              const SizedBox(height: 12),
              Text(
                'During a recorded trip, this phone may show a generic local alert with a Cancel alert action. '
                'You can also check pending alerts here while parked. Cancellation is available before a send attempt starts. '
                '${sendingAvailable ? 'An alert waits at least 30 seconds after its cancellation notice becomes available on this phone. Already handed-off notices cannot be retracted.' : 'This build does not send those alerts.'}',
              ),
              const SizedBox(height: 12),
              const Text(
                'If Android ends the app process or the phone restarts, monitoring stops. '
                'Open Traelyx and review driver alerts again before relying on the setting. '
                'Saved consent alone does not mean monitoring is running.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Review while parked with the phone rigidly mounted in the vehicle. A phone resting on a table does not meet this requirement. '
                'Choose which part of the mounted phone points toward the front of the vehicle. '
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
              if (sendingAvailable) ...[
                const Text(
                  'Supabase processes your account session and permitted event data. '
                  'Google Firebase routes generic notices using registered receiver tokens and opaque delivery IDs. '
                  'No route, location, speed or raw telemetry is uploaded by these alerts.',
                ),
                CheckboxListTile(
                  key: const ValueKey('guardian-sending-consent'),
                  value: sending,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I agree to experimental alert sending for this driver session',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => sending = value ?? false),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (missingChoice() case final String message)
            SizedBox(
              width: double.infinity,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const ValueKey('guardian-review-required-choice'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('guardian-confirm-review'),
            onPressed: missingChoice() == null
                ? () => Navigator.pop(
                    context,
                    GuardianDriverConsent(
                      ownerId: ownerId,
                      forwardAxis: forwardAxis!,
                      rigidMountConfirmed: rigidMount,
                      safetyLimitsAcknowledged: safetyLimits,
                      recipientSharingAcknowledged: recipientSharing,
                      reviewedAt: DateTime.now().toUtc(),
                      sendingAcknowledged: sendingAvailable && sending,
                      sendingReviewVersion: sendingAvailable && sending ? 1 : 0,
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
