import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/maps/offline_canvas_map_provider.dart';
import 'package:traelyx/features/trips/data/trip_route_repository.dart';

final tripRouteRepositoryProvider = Provider<TripRouteRepository>((ref) {
  return const NativeTripRouteRepository();
});

final tripRouteProvider = FutureProvider.autoDispose
    .family<TripRouteResult, String>((ref, tripId) {
      return ref.watch(tripRouteRepositoryProvider).load(tripId);
    });

final traelyxMapProviderProvider = Provider<TraelyxMapProvider>((ref) {
  return const OfflineCanvasMapProvider();
});

final tripMapControllerProvider =
    FutureProvider.autoDispose<TraelyxMapController>((ref) {
      return ref.watch(traelyxMapProviderProvider).createController();
    });

final tripMapCacheStatusProvider = StreamProvider.autoDispose<MapCacheStatus>((
  ref,
) async* {
  final controller = await ref.watch(tripMapControllerProvider.future);
  yield* controller.watchCacheStatus();
});
