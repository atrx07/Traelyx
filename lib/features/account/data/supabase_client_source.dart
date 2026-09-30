import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the optional cloud transport across account gateway decorators.
abstract interface class SupabaseClientSource {
  SupabaseClient? get accountClient;
}

SupabaseClient? accountClientOf(Object gateway) =>
    gateway is SupabaseClientSource ? gateway.accountClient : null;
