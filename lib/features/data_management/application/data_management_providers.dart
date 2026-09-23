import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/platform/data_management_bridge.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/core/settings/non_secret_setting.dart';
import 'package:traelyx/core/settings/non_secret_settings_repository.dart';
import 'package:traelyx/core/settings/settings_providers.dart';
import 'package:traelyx/features/data_management/data/data_management_repository.dart';
import 'package:traelyx/features/data_management/domain/data_management_models.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

final rawRetentionPolicySetting = NonSecretSetting<RawRetentionPolicy>(
  key: 'storage.raw_retention_policy',
  defaultValue: RawRetentionPolicy.manual,
  encode: (value) => value.encoded,
  decode: RawRetentionPolicyContract.decode,
);

final dataManagementPlatformProvider = Provider<DataManagementPlatform>((ref) {
  return const DataManagementBridge();
});

final dataManagementRepositoryProvider = Provider<DataManagementRepository>((
  ref,
) {
  return DriftDataManagementRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dataManagementPlatformProvider),
  );
});

final storedTripsProvider = StreamProvider.autoDispose<List<StoredTripData>>((
  ref,
) {
  return ref.watch(dataManagementRepositoryProvider).watchStoredTrips();
});

final rawRetentionPolicyProvider = StreamProvider<RawRetentionPolicy>((ref) {
  return ref
      .watch(nonSecretSettingsRepositoryProvider)
      .watch(rawRetentionPolicySetting);
});

final dataManagementServiceProvider = Provider<DataManagementActions>((ref) {
  return DataManagementService(
    repository: ref.watch(dataManagementRepositoryProvider),
    tripHistoryRepository: ref.watch(tripHistoryRepositoryProvider),
    preciseExporter: ref.watch(recorderTripDebugExporterProvider),
    platform: ref.watch(dataManagementPlatformProvider),
    settings: ref.watch(nonSecretSettingsRepositoryProvider),
  );
});

abstract interface class DataManagementActions {
  Future<void> setRetentionPolicy(RawRetentionPolicy policy);

  Future<RawCleanupPlan> planCleanup(RawRetentionPolicy policy);

  Future<RawCleanupResult> executeCleanup(RawRetentionPolicy policy);

  Future<int> deleteRawForTrip(String tripId);

  Future<bool> deleteTrip(String tripId);

  Future<TripDebugExportResult> exportPrecise(String tripId);

  Future<RedactedTripExportResult> exportRedacted(String tripId);
}

class DataManagementService implements DataManagementActions {
  const DataManagementService({
    required this.repository,
    required this.tripHistoryRepository,
    required this.preciseExporter,
    required this.platform,
    required this.settings,
  });

  final DataManagementRepository repository;
  final TripHistoryRepository tripHistoryRepository;
  final RecorderTripDebugExporter preciseExporter;
  final DataManagementPlatform platform;
  final NonSecretSettingsRepository settings;

  @override
  Future<void> setRetentionPolicy(RawRetentionPolicy policy) {
    return settings.write(rawRetentionPolicySetting, policy);
  }

  @override
  Future<RawCleanupPlan> planCleanup(RawRetentionPolicy policy) {
    return repository.planCleanup(policy, DateTime.now().toUtc());
  }

  @override
  Future<RawCleanupResult> executeCleanup(RawRetentionPolicy policy) {
    return repository.executeCleanup(policy, DateTime.now().toUtc());
  }

  @override
  Future<int> deleteRawForTrip(String tripId) {
    return repository.deleteRawForTrip(tripId);
  }

  @override
  Future<bool> deleteTrip(String tripId) {
    return repository.deleteTrip(tripId);
  }

  @override
  Future<TripDebugExportResult> exportPrecise(String tripId) {
    return preciseExporter.exportTrip(tripId);
  }

  @override
  Future<RedactedTripExportResult> exportRedacted(String tripId) async {
    final result = await tripHistoryRepository.loadResult(tripId);
    if (result == null) {
      throw const DataManagementFailure('trip_not_found');
    }
    return platform.exportRedactedTripSummary(_redactedPayload(result));
  }
}

RedactedTripExportPayload _redactedPayload(TripResult result) {
  final score = result.score;
  final completeScore =
      score != null &&
          score.overallScore != null &&
          score.scoringVersion.trim().isNotEmpty
      ? score
      : null;
  return RedactedTripExportPayload(
    durationMillis: result.trip.duration?.inMilliseconds,
    distanceMeters: result.trip.distanceMeters,
    completionState: _stateToken(result.trip.completionState),
    recoveryState: _stateToken(result.trip.recoveryState),
    integrityState: _stateToken(result.trip.integrityState),
    telemetrySchemaVersion: result.telemetrySchemaVersion,
    eventCount: result.events.length,
    overallScore: completeScore?.overallScore,
    scoreEligibility: completeScore != null
        ? _stateToken(completeScore.eligibilityState)
        : null,
    scoringVersion: completeScore?.scoringVersion,
  );
}

String _stateToken(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'verified',
  TripEvidenceState.limited => 'limited',
  TripEvidenceState.reviewRequired => 'review_required',
  TripEvidenceState.unavailable => 'unavailable',
  TripEvidenceState.notAssessed => 'not_assessed',
};
