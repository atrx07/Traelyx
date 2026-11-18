import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:traelyx/core/database/app_schema.dart';
import 'package:traelyx/core/database/database_migrations.dart';

part 'app_database.g.dart';

const localDatabaseUpgradePolicyVersion = 1;

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
    TripEventCorrections,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'traelyx'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > 3 || to != 4) {
        throw StateError('Unsupported local database upgrade.');
      }
      await transaction(() async {
        final bootstrapCreatedAll =
            from == 1 && await migrateRecognizedDevelopmentSchemas(this);
        if (!bootstrapCreatedAll) {
          if (from == 1) await migrator.createTable(tripAccountLinks);
          if (from < 3) await migrator.createTable(accountMetadataCache);
          await migrator.createTable(tripEventCorrections);
        }
        // Drift publishes this after onUpgrade returns. Stamp it inside the same
        // transaction as DDL so interruption before that later write is safe.
        await customStatement('PRAGMA user_version = $to');
      });
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
