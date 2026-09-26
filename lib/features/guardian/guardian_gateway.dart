import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/guardian/guardian_models.dart';

class SupabaseGuardianGateway implements GuardianGateway {
  const SupabaseGuardianGateway(this.client);
  final SupabaseClient client;
  Future<Object?> _rpc(
    String owner,
    String name,
    Map<String, Object?> params,
  ) async {
    void check() {
      if (client.auth.currentUser?.id != owner) {
        throw const GuardianException(
          'The signed-in account changed. Reload Guardian.',
        );
      }
    }

    check();
    try {
      final Object? result = await client.rpc(
        name,
        params: {'expected_user_id': owner, ...params},
      );
      check();
      return result;
    } on PostgrestException catch (e) {
      throw GuardianException(switch (e.code) {
        '40001' => 'Details changed. Reload and review again.',
        'P0002' =>
          'Guardian daily limit reached. Revocation remains available.',
        '42501' || 'PGRST301' => 'Sign in again, then reload Guardian.',
        _ => 'Could not confirm the action. Reload before trying again.',
      });
    }
  }

  @override
  Future<GuardianSnapshot> load(String owner) async =>
      GuardianSnapshot.fromJson(await _rpc(owner, 'list_guardian_v1', {}));
  @override
  Future<GuardianInvite> create(
    String owner,
    String username,
    String displayName,
    GuardianPermissions permissions,
  ) async => GuardianInvite.fromJson(
    await _rpc(owner, 'create_guardian_invite_v1', {
      'expected_username': username,
      'expected_display_name': displayName,
      'requested_permissions': permissions.toJson(),
    }),
    issued: true,
  );
  @override
  Future<void> cancel(String owner, String inviteId) async {
    await _rpc(owner, 'cancel_guardian_invite_v1', {'invite_id': inviteId});
  }

  @override
  Future<GuardianPreview?> preview(String owner, String token) async {
    if (!validGuardianToken(token)) {
      throw const GuardianException(
        'Enter the complete 64-character invite code.',
      );
    }
    final result = await _rpc(owner, 'preview_guardian_invite_v1', {
      'invite_token': token,
    });
    return result == null ? null : GuardianPreview.fromJson(result);
  }

  @override
  Future<void> accept(
    String owner,
    GuardianPreview preview,
    String token,
  ) async {
    if (!validGuardianToken(token)) {
      throw const GuardianException('Review the invite again.');
    }
    await _rpc(owner, 'accept_guardian_invite_v1', {
      'invite_id': preview.invite.id,
      'invite_token': token,
      'expected_username': preview.ownUsername,
      'expected_display_name': preview.ownDisplayName,
    });
  }

  @override
  Future<void> change(
    String owner,
    GuardianConnection connection,
    GuardianAction action, {
    GuardianPermissions? permissions,
  }) async {
    if (!connection.actions.contains(action) ||
        (action == GuardianAction.permissions && permissions == null)) {
      throw const GuardianException('Reload before acting again.');
    }
    await _rpc(owner, 'change_guardian_connection_v1', {
      'connection_id': connection.id,
      'expected_revision': connection.revision,
      'action_name': action.name,
      'requested_permissions': permissions?.toJson(),
    });
  }
}
