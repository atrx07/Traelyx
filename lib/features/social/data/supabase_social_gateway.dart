import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/social/domain/social.dart';

class SupabaseSocialGateway implements SocialGateway {
  const SupabaseSocialGateway(this.client);
  final SupabaseClient client;
  Future<Object?> _rpc(
    String owner,
    String name,
    Map<String, Object?> params,
  ) async {
    void check() {
      if (client.auth.currentUser?.id != owner) {
        throw const SocialException(
          'The signed-in account changed. Review again.',
        );
      }
    }

    check();
    try {
      final Object? result = await client.rpc(name, params: params);
      check();
      return result;
    } on PostgrestException catch (e) {
      throw SocialException(switch (e.code) {
        '40001' => 'This connection changed. Reload before acting again.',
        'P0002' => 'Request limit reached. Try again after 24 hours.',
        'P0001' =>
          'This request is unavailable. Check your saved profile or try later.',
        '42501' || 'PGRST301' => 'Sign in again, then reload Social.',
        _ => 'Could not confirm the action. Reload before trying again.',
      });
    }
  }

  @override
  Future<List<SocialEntry>> load(String owner) async {
    final result = await _rpc(owner, 'list_social_v1', {
      'expected_user_id': owner,
    });
    final rows = (result! as List)
        .map((e) => SocialEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    if (rows.length > 1000 ||
        rows.map((e) => e.id).toSet().length != rows.length) {
      throw const FormatException('Invalid relationship list');
    }
    return List.unmodifiable(rows);
  }

  @override
  Future<SocialPerson?> lookup(String owner, String username) async {
    if (!RegExp(r'^[a-z][a-z0-9_]{2,29}$').hasMatch(username)) {
      throw const SocialException(
        'Enter an exact username: 3–30 lowercase letters, digits, or underscores; start with a letter.',
      );
    }
    final result = await _rpc(owner, 'lookup_public_profile_v1', {
      'profile_username': username,
    });
    final rows = result! as List;
    if (rows.length > 1) throw const FormatException('Invalid lookup');
    if (rows.isEmpty) return null;
    final person = SocialPerson.fromJson(
      (rows.single as Map).cast<String, dynamic>(),
    );
    if (person.username != username) {
      throw const FormatException('Lookup mismatch');
    }
    return person;
  }

  @override
  Future<void> request(
    String owner,
    SocialPerson person,
    String mutationId,
  ) async {
    await _rpc(owner, 'request_friend_v1', {
      'expected_user_id': owner,
      'target_username': person.username,
      'target_display_name': person.displayName,
      'mutation_id': mutationId,
    });
  }

  @override
  Future<void> change(
    String owner,
    SocialEntry entry,
    SocialAction action,
  ) async {
    if (!entry.actions.contains(action)) {
      throw const SocialException('Reload before acting again.');
    }
    await _rpc(owner, 'change_friend_v1', {
      'expected_user_id': owner,
      'relationship_id': entry.id,
      'expected_revision': entry.revision,
      'action_name': action.name,
    });
  }
}

class UnavailableSocialGateway implements SocialGateway {
  const UnavailableSocialGateway();
  Never _fail() => throw const SocialException(
    'Online account services are not configured. Local driving is available.',
  );
  @override
  Future<List<SocialEntry>> load(String owner) async => _fail();
  @override
  Future<SocialPerson?> lookup(String owner, String username) async => _fail();
  @override
  Future<void> request(
    String owner,
    SocialPerson person,
    String mutationId,
  ) async => _fail();
  @override
  Future<void> change(
    String owner,
    SocialEntry entry,
    SocialAction action,
  ) async => _fail();
}
