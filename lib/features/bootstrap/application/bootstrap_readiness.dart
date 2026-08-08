import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';

class BootstrapReadiness {
  const BootstrapReadiness({
    required this.databaseReady,
    required this.bridgeVersion,
    required this.recorderState,
    required this.recordingAvailable,
  });

  final bool databaseReady;
  final int bridgeVersion;
  final String recorderState;
  final bool recordingAvailable;
}

final bootstrapReadinessProvider = FutureProvider<BootstrapReadiness>((
  ref,
) async {
  final database = ref.watch(appDatabaseProvider);
  await database.customSelect('SELECT 1').getSingle();

  final capabilities = await ref.watch(recorderCapabilitiesProvider.future);
  return BootstrapReadiness(
    databaseReady: true,
    bridgeVersion: capabilities.bridgeVersion,
    recorderState: capabilities.implementationState,
    recordingAvailable: capabilities.recordingAvailable,
  );
});
