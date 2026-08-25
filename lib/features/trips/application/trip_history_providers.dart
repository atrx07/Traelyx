import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

final tripHistoryRepositoryProvider = Provider<TripHistoryRepository>((ref) {
  return DriftTripHistoryRepository(ref.watch(appDatabaseProvider));
});

final tripHistoryProvider = StreamProvider.autoDispose<List<TripHistoryItem>>((
  ref,
) {
  return ref.watch(tripHistoryRepositoryProvider).watchHistory();
});

final tripResultProvider = FutureProvider.autoDispose
    .family<TripResult?, String>((ref, tripId) {
      return ref.watch(tripHistoryRepositoryProvider).loadResult(tripId);
    });
