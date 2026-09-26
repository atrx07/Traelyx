import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:traelyx/core/database/app_schema.dart';
import 'package:traelyx/core/database/database_migrations.dart';

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
    TripAccountLinks,
    AccountMetadataCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'traelyx'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > 2 || to != 3) {
        throw StateError('Unsupported local database upgrade.');
      }
      if (from == 1) {
        final bootstrapCreatedAll = await migrateRecognizedDevelopmentSchemas(
          this,
        );
        if (bootstrapCreatedAll) return;
        await migrator.createTable(tripAccountLinks);
      }
      await migrator.createTable(accountMetadataCache);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
