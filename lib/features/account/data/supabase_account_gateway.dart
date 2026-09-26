import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';

final class SupabaseAccountGateway implements AccountGateway {
  const SupabaseAccountGateway(this.client);

  static const callbackUrl = 'io.github.atrx07.traelyx://auth-callback/';

  final SupabaseClient client;

  @override
  bool get isAvailable => true;

  @override
  AccountIdentity? get currentIdentity => _identity(client.auth.currentUser);

  @override
  Stream<AccountIdentity?> get identityChanges => client.auth.onAuthStateChange
      .map((state) => _identity(state.session?.user))
      .distinct();

  @override
  Future<void> sendSignInLink(String email) => client.auth.signInWithOtp(
    email: email,
    emailRedirectTo: callbackUrl,
    shouldCreateUser: true,
  );

  @override
  Future<void> refreshSession() async {
    await client.auth.refreshSession();
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);

  static AccountIdentity? _identity(User? user) =>
      user == null ? null : AccountIdentity(userId: user.id, email: user.email);
}
