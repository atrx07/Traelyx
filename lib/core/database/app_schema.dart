import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@TableIndex(name: 'vehicles_owner_namespace', columns: {#ownerNamespace})
class Vehicles extends Table {
  TextColumn get id => text()();

  TextColumn get ownerNamespace => text()();

  TextColumn get displayName => text()();

  TextColumn get vehicleType => text()();

  TextColumn get manufacturer => text().nullable()();

  TextColumn get model => text().nullable()();

  IntColumn get modelYear => integer().nullable()();

  TextColumn get calibrationMetadataJson => text().nullable()();

  TextColumn get baselineMetadataJson => text().nullable()();

  IntColumn get createdAtMicros => integer()();

  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'trips_vehicle_start',
  columns: {#vehicleId, #startWallTimeMicros},
)
@TableIndex(name: 'trips_start_time', columns: {#startWallTimeMicros})
class Trips extends Table {
  TextColumn get id => text()();

  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.restrict)();

  IntColumn get startWallTimeMicros => integer()();

  IntColumn get endWallTimeMicros => integer().nullable()();

  IntColumn get startElapsedNanos => integer()();

  IntColumn get endElapsedNanos => integer().nullable()();

  IntColumn get durationMillis => integer().nullable()();

  RealColumn get distanceMeters => real().nullable()();

  TextColumn get completionState => text()();

  TextColumn get recoveryState => text()();

  IntColumn get telemetrySchemaVersion => integer()();

  TextColumn get scoringVersion => text().nullable()();

  TextColumn get eventEngineVersion => text().nullable()();

  TextColumn get mlModelRefsJson => text().nullable()();

  TextColumn get integrityStatus => text()();

  RealColumn get telemetryConfidence => real().nullable()();

  TextColumn get telemetryQualitySummaryJson => text().nullable()();

  TextColumn get cloudSyncState => text()();

  IntColumn get createdAtMicros => integer()();

  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (end_wall_time_micros IS NULL OR '
        'end_wall_time_micros >= start_wall_time_micros)',
    'CHECK (end_elapsed_nanos IS NULL OR '
        'end_elapsed_nanos >= start_elapsed_nanos)',
    'CHECK (duration_millis IS NULL OR duration_millis >= 0)',
    'CHECK (distance_meters IS NULL OR distance_meters >= 0)',
    'CHECK (telemetry_schema_version > 0)',
    'CHECK (telemetry_confidence IS NULL OR '
        '(telemetry_confidence >= 0 AND telemetry_confidence <= 1))',
  ];
}

class TripChunks extends Table {
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  IntColumn get sequence => integer()();

  TextColumn get storageReference => text()();

  IntColumn get encodingVersion => integer()();

  IntColumn get startElapsedNanos => integer()();

  IntColumn get endElapsedNanos => integer()();

  TextColumn get channelSampleCountsJson => text()();

  TextColumn get compression => text()();

  TextColumn get atomicWriteStrategy => text()();

  TextColumn get checksumAlgorithm => text()();

  TextColumn get checksum => text()();

  IntColumn get byteLength => integer()();

  TextColumn get writeState => text()();

  IntColumn get createdAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {tripId, sequence};

  @override
  List<String> get customConstraints => [
    'CHECK (sequence >= 0)',
    'CHECK (encoding_version > 0)',
    'CHECK (end_elapsed_nanos >= start_elapsed_nanos)',
    'CHECK (byte_length >= 0)',
  ];
}

@TableIndex(
  name: 'trip_events_trip_start',
  columns: {#tripId, #startElapsedNanos},
)
class TripEvents extends Table {
  TextColumn get id => text()();

  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  TextColumn get eventType => text()();

  IntColumn get startElapsedNanos => integer()();

  IntColumn get peakElapsedNanos => integer()();

  IntColumn get endElapsedNanos => integer()();

  RealColumn get severity => real()();

  TextColumn get severityCalibrationVersion => text()();

  RealColumn get confidence => real()();

  TextColumn get qualityFlagsJson => text()();

  TextColumn get primaryMeasurementsJson => text()();

  TextColumn get ruleEvidenceJson => text()();

  TextColumn get mlEvidenceJson => text().nullable()();

  TextColumn get contextTagsJson => text()();

  TextColumn get algorithmVersion => text()();

  IntColumn get createdAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (peak_elapsed_nanos >= start_elapsed_nanos)',
    'CHECK (end_elapsed_nanos >= peak_elapsed_nanos)',
    'CHECK (severity >= 0 AND severity <= 1)',
    'CHECK (confidence >= 0 AND confidence <= 1)',
  ];
}

@TableIndex(
  name: 'trip_scores_trip_version',
  columns: {#tripId, #scoreSchemaVersion, #scoringVersion},
  unique: true,
)
class TripScores extends Table {
  TextColumn get id => text()();

  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  IntColumn get scoreSchemaVersion => integer()();

  TextColumn get scoringVersion => text()();

  TextColumn get dimensionValuesJson => text()();

  RealColumn get overallScore => real().nullable()();

  RealColumn get confidence => real().nullable()();

  TextColumn get eligibilityState => text()();

  TextColumn get auditContributionsJson => text()();

  TextColumn get baselineId => text().nullable().references(
    DriverBaselines,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get modelVersionsJson => text().nullable()();

  IntColumn get createdAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (score_schema_version > 0)',
    'CHECK (overall_score IS NULL OR '
        '(overall_score >= 0 AND overall_score <= 100))',
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
  ];
}

@TableIndex(
  name: 'driver_baselines_owner_vehicle',
  columns: {#ownerNamespace, #vehicleId},
)
class DriverBaselines extends Table {
  TextColumn get id => text()();

  TextColumn get ownerNamespace => text()();

  TextColumn get vehicleId => text().nullable().references(
    Vehicles,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get lifecycleState => text()();

  TextColumn get dimensionStatisticsJson => text()();

  IntColumn get baselineSchemaVersion => integer()();

  TextColumn get scoringVersion => text()();

  IntColumn get validTripCount => integer()();

  IntColumn get windowStartWallTimeMicros => integer().nullable()();

  IntColumn get windowEndWallTimeMicros => integer().nullable()();

  RealColumn get confidence => real().nullable()();

  IntColumn get createdAtMicros => integer()();

  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (baseline_schema_version > 0)',
    'CHECK (valid_trip_count >= 0)',
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
    'CHECK (window_start_wall_time_micros IS NULL OR '
        'window_end_wall_time_micros IS NULL OR '
        'window_end_wall_time_micros >= window_start_wall_time_micros)',
  ];
}

@TableIndex(
  name: 'sync_queue_idempotency_key',
  columns: {#idempotencyKey},
  unique: true,
)
@TableIndex(
  name: 'sync_queue_state_next_attempt',
  columns: {#state, #nextAttemptAtMicros},
)
class SyncQueue extends Table {
  TextColumn get operationId => text()();

  TextColumn get idempotencyKey => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  IntColumn get entityVersion => integer()();

  TextColumn get operationType => text()();

  TextColumn get state => text()();

  TextColumn get payloadJson => text().nullable()();

  IntColumn get attemptCount => integer()();

  IntColumn get nextAttemptAtMicros => integer().nullable()();

  TextColumn get lastErrorCode => text().nullable()();

  IntColumn get createdAtMicros => integer()();

  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};

  @override
  List<String> get customConstraints => [
    'CHECK (entity_version >= 0)',
    'CHECK (attempt_count >= 0)',
  ];
}
