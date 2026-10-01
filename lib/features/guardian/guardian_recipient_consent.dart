/// A single foreground review. It grants no lasting registration authority.
final class GuardianRecipientConsent {
  const GuardianRecipientConsent({
    required this.ownerId,
    required this.deliveryLimitsAcknowledged,
    required this.providerDisclosureAccepted,
    required this.reviewedAt,
  });

  final String ownerId;
  final bool deliveryLimitsAcknowledged;
  final bool providerDisclosureAccepted;
  final DateTime reviewedAt;

  static final _ownerPattern = RegExp(
    r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
  );

  bool isFreshAt(DateTime now) {
    final age = now.toUtc().difference(reviewedAt.toUtc());
    return _ownerPattern.hasMatch(ownerId) &&
        deliveryLimitsAcknowledged &&
        providerDisclosureAccepted &&
        !age.isNegative &&
        age < const Duration(minutes: 2);
  }

  @override
  String toString() => 'GuardianRecipientConsent(redacted)';
}
