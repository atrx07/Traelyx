import 'package:drift/drift.dart';

const _bootstrapV1Tables = {'app_settings'};

const _completeV1Tables = {
  'app_settings',
  'driver_baselines',
  'sync_queue',
  'trip_chunks',
  'trip_events',
  'trip_scores',
  'trips',
  'vehicles',
};

const _bootstrapV1Columns = [
  'key|TEXT|1|1',
  'value|TEXT|1|0',
  'updated_at_micros|INTEGER|1|0',
];

Future<void> migrateRecognizedDevelopmentSchemas(
  GeneratedDatabase database,
) async {
  final userVersionRow = await database
      .customSelect('PRAGMA user_version')
      .getSingle();
  final userVersion = userVersionRow.read<int>('user_version');
  if (userVersion != 1) {
    return;
  }

  final tableRows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  final tableNames = tableRows.map((row) => row.read<String>('name')).toSet();

  if (_sameSet(tableNames, _completeV1Tables)) {
    return;
  }

  if (_sameSet(tableNames, _bootstrapV1Tables) &&
      await _hasExactBootstrapV1SettingsShape(database)) {
    await database.transaction(() async {
      await Migrator(database).createAll();
    });
    return;
  }

  throw StateError(
    'Unrecognized Traelyx schema shape for SQLite user version 1. '
    'Refusing an implicit repair so local data remains auditable.',
  );
}

Future<bool> _hasExactBootstrapV1SettingsShape(
  GeneratedDatabase database,
) async {
  final rows = await database
      .customSelect('PRAGMA table_info(app_settings)')
      .get();
  final signatures = rows
      .map(
        (row) => [
          row.read<String>('name'),
          row.read<String>('type').toUpperCase(),
          row.read<int>('notnull'),
          row.read<int>('pk'),
        ].join('|'),
      )
      .toList();
  return _sameList(signatures, _bootstrapV1Columns);
}

bool _sameSet(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
