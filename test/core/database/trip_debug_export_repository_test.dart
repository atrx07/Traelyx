import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/database/trip_debug_export_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

import '../platform/recorder_bridge_test.dart' show finalizationBatchMap;

void main() {
  late AppDatabase database;
  late DriftTripDebugExportRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTripDebugExportRepository(database);
  });

  tearDown(() => database.close());

  test('returns only the latest finalized local trip identity', () async {
    expect(await repository.latestFinalizedTripId(), isNull);

    final finalization = RecorderFinalizationBatch.fromMap(
      finalizationBatchMap,
    ).finalizations.single;
    await DriftRecorderFinalizationRepository(database).reconcile(finalization);

    expect(await repository.latestFinalizedTripId(), finalization.tripId);
  });
}
