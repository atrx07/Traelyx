import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';

abstract interface class TripDebugExportRepository {
  Future<String?> latestFinalizedTripId();
}

class DriftTripDebugExportRepository implements TripDebugExportRepository {
  const DriftTripDebugExportRepository(this._database);

  final AppDatabase _database;

  @override
  Future<String?> latestFinalizedTripId() async {
    final query = _database.select(_database.trips)
      ..where((row) => row.endWallTimeMicros.isNotNull())
      ..orderBy([
        (row) => OrderingTerm.desc(row.updatedAtMicros),
        (row) => OrderingTerm.desc(row.startWallTimeMicros),
      ])
      ..limit(1);
    return (await query.getSingleOrNull())?.id;
  }
}
