import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

class SupabaseSummaryGateway implements SummaryCloudGateway {
  const SupabaseSummaryGateway(this.client);
  final SupabaseClient client;

  void _check(String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw const SummarySyncException(SummaryFailure.accountChanged);
    }
  }

  @override
  Future<void> upload(CompactTripSummary summary) async {
    _check(summary.userId);
    try {
      await client
          .from('trip_summaries')
          .upsert(
            summary.toJson(),
            onConflict: 'user_id,source_trip_id',
            ignoreDuplicates: true,
          );
      _check(summary.userId);
      final row = await client
          .from('trip_summaries')
          .select(summary.toJson().keys.join(','))
          .eq('user_id', summary.userId)
          .eq('source_trip_id', summary.tripId)
          .single();
      if (!summary.sameContent(CompactTripSummary.fromJson(row))) {
        throw const SummarySyncException(SummaryFailure.conflict);
      }
    } on PostgrestException catch (error) {
      throw SummarySyncException(
        ['42501', 'PGRST301', 'PGRST205'].contains(error.code)
            ? SummaryFailure.accessDenied
            : SummaryFailure.connection,
      );
    }
  }
}

class UnavailableSummaryGateway implements SummaryCloudGateway {
  const UnavailableSummaryGateway();
  @override
  Future<void> upload(CompactTripSummary summary) async =>
      throw const SummarySyncException(SummaryFailure.accessDenied);
}
