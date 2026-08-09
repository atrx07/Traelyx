import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_schema.dart';

part 'bootstrap_v1_database.g.dart';

@DriftDatabase(tables: [AppSettings])
class BootstrapV1Database extends _$BootstrapV1Database {
  BootstrapV1Database(super.executor);

  @override
  int get schemaVersion => 1;
}
