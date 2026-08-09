import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:traelyx/core/database/app_schema.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppSettings,
    Vehicles,
    Trips,
    TripChunks,
    TripEvents,
    TripScores,
    DriverBaselines,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'traelyx'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
