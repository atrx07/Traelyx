import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/data/secure_auth_storage.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';

const _supabaseUrl = String.fromEnvironment('TRAELYX_SUPABASE_URL');
const _publishableKey = String.fromEnvironment(
  'TRAELYX_SUPABASE_PUBLISHABLE_KEY',
);

Future<AccountGateway> initializeAccount() async {
  final uri = Uri.tryParse(_supabaseUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      _publishableKey.isEmpty) {
    return const UnavailableAccountGateway();
  }

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      sharedPreferencesName: 'TraelyxAuth',
      resetOnError: false,
    ),
  );
  try {
    // Fail closed if the platform cannot read or write encrypted session data.
    const probeKey = 'traelyx.auth.storage_probe';
    await storage.write(key: probeKey, value: 'ready');
    if (await storage.read(key: probeKey) != 'ready') {
      return const UnavailableAccountGateway();
    }
    await storage.delete(key: probeKey);

    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureAuthStorage(storage),
        pkceAsyncStorage: SecurePkceStorage(storage),
        detectSessionInUriPredicate: _isAuthCallback,
      ),
    );
    return SupabaseAccountGateway(Supabase.instance.client);
  } catch (_) {
    return const UnavailableAccountGateway();
  }
}

bool _isAuthCallback(Uri uri) =>
    uri.scheme == 'io.github.atrx07.traelyx' && uri.host == 'auth-callback';
