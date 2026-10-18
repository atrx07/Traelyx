/// One foreground review only. It is never persisted as background authority;
/// the server-confirmed encrypted lease supplies that bounded authority later.
const guardianForwardAxes = {'+x', '-x', '+y', '-y', '+z', '-z'};

final class GuardianDriverConsent {
  const GuardianDriverConsent({
    required this.ownerId,
    required this.forwardAxis,
    required this.rigidMountConfirmed,
    required this.safetyLimitsAcknowledged,
    required this.recipientSharingAcknowledged,
    required this.reviewedAt,
    this.sendingAcknowledged = false,
    this.sendingReviewVersion = 0,
  });

  final String ownerId;
  final String forwardAxis;
  final bool rigidMountConfirmed;
  final bool safetyLimitsAcknowledged;
  final bool recipientSharingAcknowledged;
  final DateTime reviewedAt;
  final bool sendingAcknowledged;
  final int sendingReviewVersion;
  bool get permitsSending => sendingAcknowledged && sendingReviewVersion == 1;

  bool isFreshAt(DateTime now) {
    final age = now.toUtc().difference(reviewedAt.toUtc());
    return rigidMountConfirmed &&
        safetyLimitsAcknowledged &&
        recipientSharingAcknowledged &&
        ((!sendingAcknowledged && sendingReviewVersion == 0) ||
            permitsSending) &&
        guardianForwardAxes.contains(forwardAxis) &&
        !age.isNegative &&
        age < const Duration(minutes: 2);
  }

  @override
  String toString() => 'GuardianDriverConsent(redacted)';
}
