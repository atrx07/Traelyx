import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/platform/data_management_bridge.dart';
import 'package:traelyx/features/data_management/domain/data_management_models.dart';

abstract interface class DataManagementRepository {
  Stream<List<StoredTripData>> watchStoredTrips();

  Future<RawCleanupPlan> planCleanup(
    RawRetentionPolicy policy,
    DateTime nowUtc,
  );

  Future<RawCleanupResult> executeCleanup(
    RawRetentionPolicy policy,
    DateTime nowUtc,
  );

  Future<int> deleteRawForTrip(String tripId);

  Future<bool> deleteTrip(String tripId);
}

class DriftDataManagementRepository implements DataManagementRepository {
  const DriftDataManagementRepository(this._database, this._platform);

  final AppDatabase _database;
  final DataManagementPlatform _platform;

  @override
  Stream<List<StoredTripData>> watchStoredTrips() {
    return _storedTripsQuery().watch().map(_mapStoredTrips);
  }

  @override
  Future<RawCleanupPlan> planCleanup(
    RawRetentionPolicy policy,
    DateTime nowUtc,
  ) async {
    final retentionDays = policy.retentionDays;
    if (retentionDays == null) {
      return RawCleanupPlan(policy: policy, candidates: const []);
    }
    final cutoff = nowUtc.toUtc().subtract(Duration(days: retentionDays));
    final trips = _mapStoredTrips(await _storedTripsQuery().get());
    return RawCleanupPlan(
      policy: policy,
      candidates: List.unmodifiable(
        trips.where(
          (trip) => trip.hasRawTelemetry && !trip.endedAtUtc.isAfter(cutoff),
        ),
      ),
    );
  }

  @override
  Future<RawCleanupResult> executeCleanup(
    RawRetentionPolicy policy,
    DateTime nowUtc,
  ) async {
    final plan = await planCleanup(policy, nowUtc);
    var deletedTripCount = 0;
    var bytesDeleted = 0;
    var failureCount = 0;
    for (final trip in plan.candidates) {
      try {
        bytesDeleted += await deleteRawForTrip(trip.id);
        deletedTripCount += 1;
      } catch (_) {
        failureCount += 1;
      }
    }
    return RawCleanupResult(
      deletedTripCount: deletedTripCount,
      bytesDeleted: bytesDeleted,
      failureCount: failureCount,
    );
  }

  @override
  Future<int> deleteRawForTrip(String tripId) async {
    final trip = await (_database.select(
      _database.trips,
    )..where((row) => row.id.equals(tripId))).getSingleOrNull();
    if (trip == null || trip.endWallTimeMicros == null) {
      throw const DataManagementFailure('trip_not_finalized');
    }
    final result = await _platform.deleteRawTelemetry(tripId);
    if (!result.deleted) {
      throw DataManagementFailure(result.errorCode ?? 'raw_delete_failed');
    }
    await (_database.delete(
      _database.tripChunks,
    )..where((row) => row.tripId.equals(tripId))).go();
    return result.bytesDeleted;
  }

  @override
  Future<bool> deleteTrip(String tripId) async {
    final trip = await (_database.select(
      _database.trips,
    )..where((row) => row.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return false;
    if (trip.endWallTimeMicros == null) {
      throw const DataManagementFailure('trip_not_finalized');
    }
    final result = await _platform.deleteRawTelemetry(tripId);
    if (!result.deleted) {
      throw DataManagementFailure(result.errorCode ?? 'raw_delete_failed');
    }
    return _database.transaction(() async {
      final deleted = await (_database.delete(
        _database.trips,
      )..where((row) => row.id.equals(tripId))).go();
      return deleted == 1;
    });
  }

  Selectable<QueryRow> _storedTripsQuery() {
    return _database.customSelect(
      '''
SELECT
  t.id,
  t.start_wall_time_micros,
  t.end_wall_time_micros,
  t.duration_millis,
  COUNT(c.sequence) AS chunk_count,
  COALESCE(SUM(c.byte_length), 0) AS indexed_raw_bytes
FROM trips AS t
LEFT JOIN trip_chunks AS c ON c.trip_id = t.id
WHERE t.end_wall_time_micros IS NOT NULL
GROUP BY
  t.id,
  t.start_wall_time_micros,
  t.end_wall_time_micros,
  t.duration_millis
ORDER BY t.start_wall_time_micros DESC
''',
      readsFrom: {_database.trips, _database.tripChunks},
    );
  }
}

List<StoredTripData> _mapStoredTrips(List<QueryRow> rows) {
  return List.unmodifiable(
    rows.map((row) {
      final startMicros = row.read<int>('start_wall_time_micros');
      final endMicros = row.read<int>('end_wall_time_micros');
      final durationMillis = row.readNullable<int>('duration_millis');
      return StoredTripData(
        id: row.read<String>('id'),
        startedAtUtc: DateTime.fromMicrosecondsSinceEpoch(
          startMicros,
          isUtc: true,
        ),
        endedAtUtc: DateTime.fromMicrosecondsSinceEpoch(endMicros, isUtc: true),
        duration: durationMillis == null
            ? null
            : Duration(milliseconds: durationMillis),
        chunkCount: row.read<int>('chunk_count'),
        indexedRawBytes: row.read<int>('indexed_raw_bytes'),
      );
    }),
  );
}
