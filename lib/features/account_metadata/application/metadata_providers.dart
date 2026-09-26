import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account_metadata/application/metadata_service.dart';
import 'package:traelyx/features/account_metadata/data/metadata_repository.dart';
import 'package:traelyx/features/account_metadata/data/supabase_metadata_gateway.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

final metadataGatewayProvider = Provider<MetadataGateway>((ref) {
  final account = ref.watch(accountGatewayProvider);
  return account is SupabaseAccountGateway
      ? SupabaseMetadataGateway(account.client)
      : const UnavailableMetadataGateway();
});
final metadataRepositoryProvider = Provider<MetadataRepository>(
  (ref) => MetadataRepository(ref.watch(appDatabaseProvider)),
);
final metadataServiceProvider = Provider<MetadataService>(
  (ref) => MetadataService(
    ref.watch(metadataRepositoryProvider),
    ref.watch(metadataGatewayProvider),
    ref.watch(accountGatewayProvider),
  ),
);
final metadataEntriesProvider = FutureProvider.autoDispose
    .family<List<MetadataEntry>, String>(
      (ref, owner) => ref.watch(metadataServiceProvider).entries(owner),
    );
