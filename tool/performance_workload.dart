import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/features/trips/data/trip_history_repository.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

const performanceWorkloadVersion = 1;

Map<String, Object> timingDistribution(List<double> milliseconds) {
  if (milliseconds.isEmpty ||
      milliseconds.any((value) => !value.isFinite || value < 0)) {
    throw ArgumentError('Timing observations must be finite and non-negative.');
  }
  final sorted = [...milliseconds]..sort();
  double percentile(double fraction) =>
      sorted[(fraction * sorted.length).ceil().clamp(1, sorted.length) - 1];
  return {
    'count': sorted.length,
    'p50_ms': percentile(.5),
    'p95_ms': percentile(.95),
    'p99_ms': percentile(.99),
    'max_ms': sorted.last,
  };
}

MapRouteGeometry performanceRoute() => MapRouteGeometry(
  processingVersion: 1,
  sourceGnssCount: 3601,
  reduced: true,
  points: List.generate(1000, (index) {
    final angle = index / 50;
    return MapRoutePoint(
      coordinate: MapCoordinate(
        latitude: 1 + index * .00001,
        longitude: 1 + math.sin(angle) * .001,
      ),
      tripOffset: Duration(milliseconds: index * 3600),
      startsNewSegment: index == 0 || index == 500,
    );
  }),
);

ReplayTimeline performanceTimeline(MapRouteGeometry route) =>
    (ReplayTimeline.build(
              recordedDuration: const Duration(hours: 1),
              route: route,
              events: List.generate(
                50,
                (index) => TripEventSummary(
                  type: 'strong_braking',
                  startElapsedNanos: index * 60 * 1000000000,
                  endElapsedNanos: (index * 60 + 2) * 1000000000,
                  normalizedMagnitude: .4,
                  magnitudeCalibrationVersion: 'synthetic-performance-v1',
                  confidenceRecorded: true,
                ),
              ),
            )
            as ReplayTimelineAvailable)
        .timeline;

/// Uses only a caller-owned empty executor. Never opens the ordinary app DB.
Future<Map<String, Object>> benchmarkDatabase(QueryExecutor executor) async {
  final database = AppDatabase(executor);
  const trips = 1000;
  const selected = 'synthetic-trip-999';
  const selectedChunks = 3600;
  try {
    if ((await database.select(database.trips).get()).isNotEmpty) {
      throw StateError('Performance database must be empty.');
    }
    final seed = Stopwatch()..start();
    await database.transaction(() async {
      await database
          .into(database.vehicles)
          .insert(
            VehiclesCompanion.insert(
              id: 'synthetic-vehicle',
              ownerNamespace: 'local:synthetic-performance-v1',
              displayName: 'Synthetic benchmark vehicle',
              vehicleType: 'motorcycle',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      await database.batch((batch) {
        batch.insertAll(
          database.trips,
          List.generate(trips, (index) {
            final start = (index + 1) * 86400000000;
            return TripsCompanion.insert(
              id: 'synthetic-trip-$index',
              vehicleId: 'synthetic-vehicle',
              startWallTimeMicros: start,
              endWallTimeMicros: Value(start + 3600000000),
              startElapsedNanos: 0,
              endElapsedNanos: const Value(3600000000000),
              durationMillis: const Value(3600000),
              completionState: 'completed',
              recoveryState: 'not_needed',
              telemetrySchemaVersion: 1,
              integrityStatus: 'unassessed',
              cloudSyncState: 'local_only',
              createdAtMicros: start,
              updatedAtMicros: start,
            );
          }),
        );
        batch.insertAll(
          database.tripEvents,
          List.generate(trips * 12, (index) {
            final offset = (index % 12) * 300000000000;
            return TripEventsCompanion.insert(
              id: 'synthetic-event-$index',
              tripId: 'synthetic-trip-${index ~/ 12}',
              eventType: 'strong_braking',
              startElapsedNanos: offset,
              peakElapsedNanos: offset + 1000000000,
              endElapsedNanos: offset + 2000000000,
              severity: .4,
              severityCalibrationVersion: 'synthetic-performance-v1',
              confidence: .8,
              qualityFlagsJson: '[]',
              primaryMeasurementsJson: '{}',
              ruleEvidenceJson: '{}',
              contextTagsJson: '[]',
              algorithmVersion: 'synthetic-performance-v1',
              createdAtMicros: 1,
            );
          }),
        );
        batch.insertAll(
          database.tripScores,
          List.generate(
            trips,
            (index) => TripScoresCompanion.insert(
              id: 'synthetic-score-$index',
              tripId: 'synthetic-trip-$index',
              scoreSchemaVersion: 1,
              scoringVersion: 'synthetic-performance-v1',
              dimensionValuesJson: '{}',
              overallScore: const Value(80),
              eligibilityState: 'provisional',
              auditContributionsJson: '[]',
              createdAtMicros: 1,
            ),
          ),
        );
        batch.insertAll(
          database.tripChunks,
          List.generate(
            selectedChunks,
            (index) => TripChunksCompanion.insert(
              tripId: selected,
              sequence: index,
              storageReference: 'synthetic-benchmark/chunks/$index.tlxc',
              encodingVersion: 1,
              startElapsedNanos: index * 1000000000,
              endElapsedNanos: (index + 1) * 1000000000 - 1,
              channelSampleCountsJson:
                  '{"gnss":1,"accelerometer":100,"gyroscope":100}',
              compression: 'deflate',
              atomicWriteStrategy: 'android_atomic_file',
              checksumAlgorithm: 'sha256',
              checksum: '0' * 64,
              byteLength: 4096,
              writeState: 'complete',
              createdAtMicros: 1,
            ),
          ),
        );
      });
    });
    seed.stop();
    final repository = DriftTripHistoryRepository(database);
    Future<void> history() async {
      final result = await repository.watchHistory().first;
      if (result.length != trips || result.first.id != selected) {
        throw StateError(
          'History benchmark result was incomplete or unordered.',
        );
      }
    }

    Future<void> detail() async {
      final result = await repository.loadResult(selected);
      if (result == null ||
          result.events.length != 12 ||
          result.evidence.chunkCount != selectedChunks ||
          result.evidence.accelerometerSampleCount != 360000 ||
          result.score?.overallScore != 80) {
        throw StateError('Detail benchmark lost expected evidence.');
      }
    }

    Future<Map<String, Object>> measure(Future<void> Function() action) async {
      for (var index = 0; index < 3; index++) {
        await action();
      }
      final samples = <double>[];
      for (var index = 0; index < 20; index++) {
        final stopwatch = Stopwatch()..start();
        await action();
        samples.add(stopwatch.elapsedMicroseconds / 1000);
      }
      return timingDistribution(samples);
    }

    final historyTiming = await measure(history);
    final detailTiming = await measure(detail);
    final pageCount =
        (await database.customSelect('PRAGMA page_count').getSingle())
            .read<int>('page_count');
    final pageSize =
        (await database.customSelect('PRAGMA page_size').getSingle()).read<int>(
          'page_size',
        );
    return {
      'workload_version': performanceWorkloadVersion,
      'schema_version': database.schemaVersion,
      'trip_count': trips,
      'event_count': trips * 12,
      'score_count': trips,
      'selected_trip_chunk_count': selectedChunks,
      'raw_telemetry_present': false,
      'warmup_queries_per_operation': 3,
      'seed_ms': seed.elapsedMicroseconds / 1000,
      'database_allocated_bytes': pageCount * pageSize,
      'history_1000_trips': historyTiming,
      'detail_3600_chunks': detailTiming,
    };
  } finally {
    await database.close();
  }
}
