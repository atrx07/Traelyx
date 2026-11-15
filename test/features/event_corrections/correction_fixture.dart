import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';

Future<void> seedCorrectionTrip(AppDatabase db) async {
  await db
      .into(db.vehicles)
      .insert(
        VehiclesCompanion.insert(
          id: 'private-vehicle',
          ownerNamespace: 'local:anonymous',
          displayName: 'Private bike',
          vehicleType: 'motorcycle',
          createdAtMicros: 1,
          updatedAtMicros: 1,
        ),
      );
  await db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: 'private-trip',
          vehicleId: 'private-vehicle',
          startWallTimeMicros: 1000000,
          startElapsedNanos: 1,
          endWallTimeMicros: const Value(91000000),
          durationMillis: const Value(90000),
          completionState: 'completed',
          recoveryState: 'clean',
          telemetrySchemaVersion: 1,
          integrityStatus: 'verified',
          cloudSyncState: 'local_only',
          createdAtMicros: 1,
          updatedAtMicros: 1,
        ),
      );
  await db
      .into(db.tripEvents)
      .insert(
        TripEventsCompanion.insert(
          id: 'private-event',
          tripId: 'private-trip',
          eventType: 'EVT_BRAKE_STRONG',
          startElapsedNanos: 8000000000,
          peakElapsedNanos: 9000000000,
          endElapsedNanos: 10000000000,
          severity: .5,
          severityCalibrationVersion: 'activation-ratio-cap2-v1',
          confidence: .5,
          qualityFlagsJson: '["generated_limited"]',
          primaryMeasurementsJson: '{"private_measurement":12.345}',
          ruleEvidenceJson: '{"confidenceCategory":"LIMITED"}',
          contextTagsJson: '[]',
          algorithmVersion: '1',
          createdAtMicros: 20,
        ),
      );
  await db
      .into(db.tripScores)
      .insert(
        TripScoresCompanion.insert(
          id: 'private-score',
          tripId: 'private-trip',
          scoreSchemaVersion: 1,
          scoringVersion: '1',
          dimensionValuesJson: '{}',
          overallScore: const Value(50),
          eligibilityState: 'limited',
          auditContributionsJson: '{"original_audit":"unchanged"}',
          createdAtMicros: 20,
        ),
      );
}
