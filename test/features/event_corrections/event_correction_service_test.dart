import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/event_corrections/application/event_correction_service.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

import 'correction_fixture.dart';

void main() {
  late AppDatabase db;
  late EventCorrectionRepository repo;
  late EventCorrectionService service;
  late _Exporter exporter;
  var idle = true;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedCorrectionTrip(db);
    repo = EventCorrectionRepository(db, now: () => 100);
    exporter = _Exporter();
    idle = true;
    service = EventCorrectionService(
      repository: repo,
      isRecorderIdle: () async => idle,
      exporter: exporter,
    );
  });
  tearDown(() => db.close());

  test(
    'no parked acknowledgment or active/unknown recorder means no correction',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await expectLater(
        service.save(
          target,
          CorrectionChoice.correct,
          parked: false,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      idle = false;
      await expectLater(
        service.load('private-trip', parked: true),
        throwsStateError,
      );
      await expectLater(
        service.save(
          target,
          CorrectionChoice.correct,
          parked: true,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      expect(await db.select(db.tripEventCorrections).get(), isEmpty);
      service = EventCorrectionService(
        repository: repo,
        isRecorderIdle: () async => throw StateError('unknown'),
        exporter: exporter,
      );
      await expectLater(
        service.load('private-trip', parked: true),
        throwsStateError,
      );
    },
  );

  test('revocation between preview and confirmation prevents export', () async {
    final target = (await repo.load('private-trip')).targets.single;
    await repo.save(
      target,
      CorrectionChoice.unsure,
      expectedRevision: 0,
      contribute: true,
    );
    final preview = await service.preview('private-trip', parked: true);
    await repo.save(target, CorrectionChoice.unsure, expectedRevision: 1);
    await expectLater(
      service.export('private-trip', preview, parked: true),
      throwsStateError,
    );
    expect(exporter.calls, 0);
  });

  test(
    'reconsenting the same category still requires reviewing the new revision',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.unsure,
        expectedRevision: 0,
        contribute: true,
      );
      final preview = await service.preview('private-trip', parked: true);
      await repo.save(
        target,
        CorrectionChoice.unsure,
        expectedRevision: 1,
        contribute: true,
      );
      await expectLater(
        service.export('private-trip', preview, parked: true),
        throwsStateError,
      );
      expect(exporter.calls, 0);
    },
  );

  test(
    'export serializes app edits/revocation until the picker completes',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.unsure,
        expectedRevision: 0,
        contribute: true,
      );
      final preview = await service.preview('private-trip', parked: true);
      exporter.pending = Completer<CorrectionExportResult>();
      final result = service.export('private-trip', preview, parked: true);
      await exporter.started.future;
      await expectLater(
        service.clear('private-trip', parked: true),
        throwsStateError,
      );
      await expectLater(
        service.save(
          target,
          CorrectionChoice.correct,
          parked: true,
          expectedRevision: 1,
        ),
        throwsStateError,
      );
      exporter.pending!.complete(
        const CorrectionExportResult(
          exported: false,
          errorCode: 'export_cancelled',
        ),
      );
      expect((await result).exported, false);
      await service.save(
        target,
        CorrectionChoice.unsure,
        parked: true,
        expectedRevision: 1,
      );
      expect(
        (await repo.load('private-trip')).notes.single.contributionAllowed,
        false,
      );
    },
  );

  test(
    'picker return rejects withdrawal or changed recorder from another writer',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.unsure,
        expectedRevision: 0,
        contribute: true,
      );
      final preview = await service.preview('private-trip', parked: true);
      exporter.pending = Completer<CorrectionExportResult>();
      final result = service.export('private-trip', preview, parked: true);
      await exporter.started.future;
      expect(await exporter.authorize!(), true);
      idle = false;
      expect(await exporter.authorize!(), false);
      idle = true;
      // Simulate a separate view/database writer while the picker is pending.
      await repo.clear('private-trip');
      expect(await exporter.authorize!(), false);
      exporter.pending!.complete(
        const CorrectionExportResult(
          exported: false,
          errorCode: 'export_authorization_failed',
        ),
      );
      expect((await result).exported, false);
    },
  );

  test(
    'recorder becoming active after review prevents opening an export',
    () async {
      final target = (await repo.load('private-trip')).targets.single;
      await repo.save(
        target,
        CorrectionChoice.correct,
        expectedRevision: 0,
        contribute: true,
      );
      final preview = await service.preview('private-trip', parked: true);
      idle = false;
      await expectLater(
        service.export('private-trip', preview, parked: true),
        throwsStateError,
      );
      expect(exporter.calls, 0);
    },
  );
}

class _Exporter implements CorrectionExporter {
  int calls = 0;
  final started = Completer<void>();
  Completer<CorrectionExportResult>? pending;
  Future<bool> Function()? authorize;
  @override
  Future<CorrectionExportResult> export(
    Map<String, Object?> payload, {
    required Future<bool> Function() authorize,
  }) async {
    this.authorize = authorize;
    calls++;
    started.complete();
    return pending?.future ??
        const CorrectionExportResult(exported: true, errorCode: null);
  }
}
