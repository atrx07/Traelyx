final class AccountIdentity {
  const AccountIdentity({required this.userId, required this.email});

  final String userId;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AccountIdentity &&
      other.userId == userId &&
      other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);
}
