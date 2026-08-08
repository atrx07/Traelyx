import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('schema version 1 stores local settings', () async {
    expect(database.schemaVersion, 1);

    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'privacy.accountless',
            value: 'true',
            updatedAtMicros: 0,
          ),
        );

    final row = await database.select(database.appSettings).getSingle();
    expect(row.key, 'privacy.accountless');
    expect(row.value, 'true');
  });
}
