import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

import 'correction_fixture.dart';

void main() {
  test(
    'source-bound note and explicit consent survive a database close and reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'traelyx-correction-',
      );
      final file = File('${directory.path}/review.sqlite');
      AppDatabase? db;
      try {
        db = AppDatabase(NativeDatabase(file));
        await seedCorrectionTrip(db);
        var repo = EventCorrectionRepository(db, now: () => 100);
        final target = (await repo.load('private-trip')).targets.single;
        await repo.save(
          target,
          CorrectionChoice.unsure,
          expectedRevision: 0,
          contribute: true,
        );
        final before = await repo.prepare('private-trip');
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        repo = EventCorrectionRepository(db, now: () => 101);
        final note = (await repo.load('private-trip')).notes.single;
        expect(note.target.snapshot, target.snapshot);
        expect(note.revision, 1);
        expect(note.contributionAllowed, true);
        expect(
          (await repo.prepare('private-trip')).reviewToken,
          before.reviewToken,
        );
        await repo.save(note.target, note.choice, expectedRevision: 1);
        expect(
          (await repo.load('private-trip')).notes.single.contributionAllowed,
          false,
        );
      } finally {
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
