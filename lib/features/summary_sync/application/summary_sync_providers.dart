import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_service.dart';
import 'package:traelyx/features/summary_sync/data/summary_sync_repository.dart';
import 'package:traelyx/features/summary_sync/data/supabase_summary_gateway.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

final summaryCloudGatewayProvider = Provider<SummaryCloudGateway>((ref) {
  final account = ref.watch(accountGatewayProvider);
  return account is SupabaseAccountGateway
      ? SupabaseSummaryGateway(account.client)
      : const UnavailableSummaryGateway();
});

final summarySyncServiceProvider = Provider<SummarySyncService>(
  (ref) => SummarySyncService(
    SummarySyncRepository(ref.watch(appDatabaseProvider)),
    ref.watch(summaryCloudGatewayProvider),
    ref.watch(accountGatewayProvider),
  ),
);

final summarySyncPreviewProvider = FutureProvider.autoDispose
    .family<SummarySyncPreview, String>(
      (ref, userId) => ref.watch(summarySyncServiceProvider).preview(userId),
    );
