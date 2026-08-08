import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'traelyx'));

  @override
  int get schemaVersion => 1;
}
