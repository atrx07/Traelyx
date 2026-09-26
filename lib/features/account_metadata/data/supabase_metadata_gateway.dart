import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

class SupabaseMetadataGateway implements MetadataGateway {
  const SupabaseMetadataGateway(this.client);
  final SupabaseClient client;
  void _check(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw const MetadataException(MetadataFailure.accountChanged);
    }
  }

  @override
  Future<List<AccountMetadata>> fetch(String userId) async {
    _check(userId);
    try {
      final profile = await client
          .from('profiles')
          .select('user_id,username,display_name,visibility,revision')
          .eq('user_id', userId)
          .maybeSingle();
      _check(userId);
      final result = <AccountMetadata>[
        if (profile != null) _decode(MetadataKind.profile, profile),
      ];
      for (var offset = 0; offset < 10000; offset += 200) {
        _check(userId);
        final vehicles = await client
            .from('vehicles')
            .select('user_id,id,display_name,vehicle_class,revision')
            .eq('user_id', userId)
            .order('id')
            .range(offset, offset + 199);
        _check(userId);
        result.addAll(vehicles.map((v) => _decode(MetadataKind.vehicle, v)));
        if (vehicles.length < 200) return result;
      }
      throw const MetadataException(MetadataFailure.invalidData);
    } on PostgrestException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<AccountMetadata> save(MetadataMutation mutation) async {
    final data = mutation.data;
    _check(data.userId);
    final params = <String, Object?>{
      'expected_user_id': data.userId,
      'expected_revision': data.revision,
      'mutation_id': mutation.mutationId,
      if (data.kind == MetadataKind.profile) ...{
        'profile_username': data.fields['username'],
        'profile_display_name': data.displayName,
        'profile_visibility': data.fields['visibility'],
      } else ...{
        'vehicle_id': data.id,
        'vehicle_display_name': data.displayName,
        'vehicle_class_name': data.fields['vehicle_class'],
      },
    };
    try {
      final Object? response = await client.rpc(
        data.kind == MetadataKind.profile
            ? 'save_profile_v1'
            : 'save_vehicle_v1',
        params: params,
      );
      _check(data.userId);
      final result = _decode(
        data.kind,
        (response! as Map).cast<String, dynamic>(),
      );
      if (!result.sameFields(data) || result.revision <= data.revision) {
        throw const MetadataException(MetadataFailure.conflict);
      }
      return result;
    } on PostgrestException catch (error) {
      throw _failure(error);
    }
  }

  static AccountMetadata _decode(
    MetadataKind kind,
    Map<String, dynamic> row,
  ) => AccountMetadata(
    userId: row['user_id'] as String,
    kind: kind,
    id: (kind == MetadataKind.profile ? row['user_id'] : row['id']) as String,
    revision: row['revision'] as int,
    fields: {
      'display_name': row['display_name'],
      if (kind == MetadataKind.profile) ...{
        'username': row['username'],
        'visibility': row['visibility'],
      } else
        'vehicle_class': row['vehicle_class'],
    },
  );
  static MetadataException _failure(PostgrestException error) =>
      MetadataException(switch (error.code) {
        '40001' || '23505' => MetadataFailure.conflict,
        '42501' || 'PGRST301' => MetadataFailure.accessDenied,
        '23503' || '23514' || '22023' => MetadataFailure.invalidData,
        _ => MetadataFailure.connection,
      });
}

class UnavailableMetadataGateway implements MetadataGateway {
  const UnavailableMetadataGateway();
  @override
  Future<List<AccountMetadata>> fetch(String userId) async =>
      throw const MetadataException(MetadataFailure.unavailable);
  @override
  Future<AccountMetadata> save(MetadataMutation mutation) async =>
      throw const MetadataException(MetadataFailure.unavailable);
}
