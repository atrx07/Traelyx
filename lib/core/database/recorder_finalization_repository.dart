import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

const recorderPlaceholderVehicleId = 'local-recorder-vehicle-v1';
const recorderPlaceholderOwnerNamespace = 'local:anonymous';

abstract interface class RecorderFinalizationRepository {
  Future<void> reconcile(RecorderTripFinalization finalization);
}

class DriftRecorderFinalizationRepository
    implements RecorderFinalizationRepository {
  const DriftRecorderFinalizationRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> reconcile(RecorderTripFinalization finalization) async {
    final telemetrySchemaVersion = _telemetrySchemaVersion(finalization);
    final startWallMicros = finalization.startedAtUtcEpochMillis * 1000;
    final stoppedWallMicros = finalization.stoppedAtUtcEpochMillis * 1000;
    final qualitySummary = jsonEncode(<String, Object>{
      'finalizationLogicVersion': finalization.finalizationLogicVersion,
      'recoveryCount': finalization.recoveryCount,
      'validChunkCount': finalization.chunks.length,
      'corruptChunkCount': finalization.corruptChunkCount,
      'orphanedWriteCount': finalization.orphanedWriteCount,
      'orderingViolationCount': finalization.orderingViolationCount,
      'qualityFlags': finalization.qualityFlags,
    });

    await _database.transaction(() async {
      await _database
          .into(_database.vehicles)
          .insert(
            VehiclesCompanion.insert(
              id: recorderPlaceholderVehicleId,
              ownerNamespace: recorderPlaceholderOwnerNamespace,
              displayName: 'Local vehicle',
              vehicleType: 'unspecified',
              createdAtMicros: startWallMicros,
              updatedAtMicros: startWallMicros,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final existingTrip = await (_database.select(
        _database.trips,
      )..where((row) => row.id.equals(finalization.tripId))).getSingleOrNull();
      await _database
          .into(_database.trips)
          .insertOnConflictUpdate(
            TripsCompanion.insert(
              id: finalization.tripId,
              vehicleId:
                  existingTrip?.vehicleId ?? recorderPlaceholderVehicleId,
              startWallTimeMicros: startWallMicros,
              endWallTimeMicros: Value(stoppedWallMicros),
              startElapsedNanos: finalization.startedAtElapsedRealtimeNanos,
              endElapsedNanos: Value(finalization.endElapsedRealtimeNanos),
              durationMillis: Value(finalization.durationMillis),
              completionState: finalization.completionState,
              recoveryState: finalization.recoveryState,
              telemetrySchemaVersion: telemetrySchemaVersion,
              integrityStatus: finalization.integrityStatus,
              telemetryQualitySummaryJson: Value(qualitySummary),
              cloudSyncState: 'local_only',
              createdAtMicros: existingTrip?.createdAtMicros ?? startWallMicros,
              updatedAtMicros: stoppedWallMicros,
            ),
          );

      await (_database.delete(
        _database.tripChunks,
      )..where((row) => row.tripId.equals(finalization.tripId))).go();
      if (finalization.chunks.isNotEmpty) {
        await _database.batch((batch) {
          batch.insertAll(
            _database.tripChunks,
            finalization.chunks.map(
              (chunk) => TripChunksCompanion.insert(
                tripId: finalization.tripId,
                sequence: chunk.sequence,
                storageReference: chunk.storageReference,
                encodingVersion: chunk.encodingVersion,
                startElapsedNanos: chunk.startElapsedNanos,
                endElapsedNanos: chunk.endElapsedNanos,
                channelSampleCountsJson: jsonEncode(<String, int>{
                  'gnss': chunk.gnssSampleCount,
                  'accelerometer': chunk.accelerometerSampleCount,
                  'gyroscope': chunk.gyroscopeSampleCount,
                }),
                compression: chunk.compression,
                atomicWriteStrategy: chunk.atomicWriteStrategy,
                checksumAlgorithm: chunk.checksumAlgorithm,
                checksum: chunk.checksum,
                byteLength: chunk.byteLength,
                writeState: 'complete',
                createdAtMicros: chunk.createdAtUtcEpochMillis * 1000,
              ),
            ),
          );
        });
      }
    });
  }

  int _telemetrySchemaVersion(RecorderTripFinalization finalization) {
    if (finalization.chunks.isEmpty) return 1;
    final versions = finalization.chunks
        .map((chunk) => chunk.telemetrySchemaVersion)
        .toSet();
    if (versions.length != 1) {
      throw const FormatException(
        'Finalized chunks contain mixed telemetry schema versions.',
      );
    }
    return versions.single;
  }
}
