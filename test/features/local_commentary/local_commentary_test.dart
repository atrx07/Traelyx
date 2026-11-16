import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/commentary/domain/reviewed_commentary_input.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_service.dart';
import 'package:traelyx/features/local_commentary/data/local_model_store.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

import '../cloud_commentary/cloud_fixture.dart';
import 'local_fixture.dart';
import 'local_model_store_test.dart' show failure;

void main() {
  test(
    'shared reviewed payload preserves cloud bytes and excludes private evidence',
    () {
      final plan = fixturePlan();
      final shared = ReviewedCommentaryInput.fromPlan(plan);
      final cloud = CommentaryDossier.fromPlan(plan);
      expect(shared.reviewedJson, cloud.reviewedJson);
      expect(shared.payload.keys, [
        'dossierVersion',
        'wordingVersion',
        'tone',
        'evidence',
        'moments',
      ]);
      expect(shared.reviewedJson, isNot(contains('private')));
      final selected = shared.apply({
        'choices': [1, 0],
      });
      expect(selected.seed, plan.seed);
      for (var i = 0; i < selected.moments.length; i++) {
        expect(selected.moments[i].anchorTime, plan.moments[i].anchorTime);
        expect(selected.moments[i].visibleFrom, plan.moments[i].visibleFrom);
        expect(selected.moments[i].eventType, plan.moments[i].eventType);
      }
      expect(
        () => shared.apply({
          'choices': [0, 0],
          'prose': 'invented',
        }),
        throwsA(isA<CommentaryContractException>()),
      );
      expect(
        () => ReviewedCommentaryInput.fromPlan(
          fixturePlan(tone: CommentaryTone.silent),
        ),
        throwsA(isA<CommentaryContractException>()),
      );
    },
  );
  test(
    'production catalog is empty and no adapter claims availability',
    () async {
      final catalog = LocalModelCatalog.parse(
        await File(
          'docs/reference/local-commentary-catalog-v1.json',
        ).readAsString(),
      );
      expect(catalog.models, isEmpty);
      expect(catalog.accepts(fixtureManifest()), false);
      expect(const UnavailableLocalRuntime().capabilities, null);
      expect(const UnavailableLocalSource().supports(fixtureManifest()), false);
    },
  );
  final badFields = <String, Object?>{
    'schemaVersion': 2,
    'contractVersion': 1.0,
    'id': '../trip',
    'revision': 'V1',
    'sha256': 'x' * 64,
    'bytes': LocalModelManifest.maximumBytes + 1,
    'format': 'executable',
    'runtime': 'any/runtime',
    'runtimeVersion': '',
    'minAndroidApi': 25,
    'abis': ['unknown'],
    'license': 'http://example.org',
    'source': 'https://secret@example.org',
    'evidence': 'docs/reference/../../secret.json',
  };
  for (final entry in badFields.entries) {
    test('manifest rejects invalid ${entry.key}', () {
      expect(
        () => LocalModelManifest.parse({
          ...fixtureManifestValues(),
          entry.key: entry.value,
        }),
        throwsA(failure(LocalFailure.incompatible)),
      );
    });
  }
  test('catalog rejects unknown, duplicate and oversized manifests', () {
    for (final source in [
      jsonEncode({
        'schemaVersion': 1,
        'models': <Object?>[],
        'endpoint': 'https://example.org',
      }),
      jsonEncode({
        'schemaVersion': 1,
        'models': [fixtureManifestValues(), fixtureManifestValues()],
      }),
      ' ' * 32769,
    ]) {
      expect(
        () => LocalModelCatalog.parse(source),
        throwsA(failure(LocalFailure.incompatible)),
      );
    }
    expect(() => fixtureManifest().values['bytes'] = 0, throwsUnsupportedError);
    expect(() => fixtureManifest().abis.add('x86'), throwsUnsupportedError);
  });

  late Directory root;
  late FixtureSource source;
  late FixtureRuntime runtime;
  late LocalCommentaryService service;
  setUp(() async {
    root = (await Directory.systemTemp.createTemp('m711-service-')).absolute;
    source = FixtureSource();
    runtime = FixtureRuntime();
    service = fixtureService(root, source: source, runtime: runtime);
  });
  tearDown(() async {
    service.cancel();
    await root.delete(recursive: true);
  });
  Future<void> install() async {
    final review = await service.reviewInstall(fixtureManifest(), parked: true);
    expect(review.downloadBytes, fixtureBytes.length);
    expect(
      review.requiredFreeBytes,
      fixtureBytes.length + LocalModelManifest.reserveBytes,
    );
    expect(source.opens, 0);
    await service.install(review, parked: true, acceptedSizeAndLicense: true);
  }

  test(
    'review then install then offline reviewed selection; one-use reviews',
    () async {
      await install();
      final plan = fixturePlan();
      final review = await service.reviewGeneration(
        fixtureManifest(),
        plan,
        parked: true,
      );
      final result = await service.generate(
        review,
        parked: true,
        acceptedReview: true,
      );
      expect(result.moments.first.text, plan.choicesFor(plan.moments.first)[1]);
      expect(runtime.calls, 1);
      expect(source.opens, 1);
      expect(runtime.input, jsonEncode(review.input.payload));
      expect(runtime.input, isNot(contains('private')));
      await expectLater(
        service.generate(review, parked: true, acceptedReview: true),
        throwsA(failure(LocalFailure.stale)),
      );
    },
  );
  test(
    'production unavailability stops before source or runtime work',
    () async {
      service = LocalCommentaryService(
        catalog: () async =>
            LocalModelCatalog.parse('{"schemaVersion":1,"models":[]}'),
        device: () async => fixtureDevice(root),
        runtime: const UnavailableLocalRuntime(),
        source: const UnavailableLocalSource(),
        isRecorderIdle: () async => true,
      );
      await expectLater(
        service.reviewInstall(fixtureManifest(), parked: true),
        throwsA(failure(LocalFailure.unavailable)),
      );
      await expectLater(
        service.reviewGeneration(
          fixtureManifest(),
          fixturePlan(),
          parked: true,
        ),
        throwsA(failure(LocalFailure.unavailable)),
      );
      expect((await service.status()).inventory.bytes, 0);
    },
  );
  test('capability and source gates reject before transfer', () async {
    for (final capabilities in [
      null,
      const LocalRuntimeCapabilities(
        id: 'fixture',
        version: 'v2',
        formats: {'gguf'},
        offline: true,
        cancellable: true,
      ),
      const LocalRuntimeCapabilities(
        id: 'fixture',
        version: 'v1',
        formats: {'gguf'},
        offline: false,
        cancellable: true,
      ),
      const LocalRuntimeCapabilities(
        id: 'fixture',
        version: 'v1',
        formats: {'gguf'},
        offline: true,
        cancellable: false,
      ),
    ]) {
      runtime.capabilities = capabilities;
      await expectLater(
        service.reviewInstall(fixtureManifest(), parked: true),
        throwsA(isA<LocalCommentaryException>()),
      );
    }
    expect(source.opens, 0);
  });
  test('device ABI and disk reserve admission are rechecked', () async {
    var current = fixtureDevice(root);
    service = fixtureService(
      root,
      source: source,
      runtime: runtime,
      device: () async => current,
    );
    final review = await service.reviewInstall(fixtureManifest(), parked: true);
    current = fixtureDevice(root, freeBytes: 1);
    await expectLater(
      service.install(review, parked: true, acceptedSizeAndLicense: true),
      throwsA(failure(LocalFailure.space)),
    );
    current = fixtureDevice(root, abis: ['x86']);
    await expectLater(
      service.reviewInstall(fixtureManifest(), parked: true),
      throwsA(failure(LocalFailure.incompatible)),
    );
    expect(source.opens, 0);
  });
  test('explicit size/license consent and parked/idle are required', () async {
    final review = await service.reviewInstall(fixtureManifest(), parked: true);
    await expectLater(
      service.install(review, parked: true, acceptedSizeAndLicense: false),
      throwsA(failure(LocalFailure.stale)),
    );
    await expectLater(
      service.install(review, parked: false, acceptedSizeAndLicense: true),
      throwsA(failure(LocalFailure.notParked)),
    );
    service = fixtureService(root, source: source, idle: () async => false);
    await expectLater(
      service.reviewInstall(fixtureManifest(), parked: true),
      throwsA(failure(LocalFailure.notParked)),
    );
    expect(source.opens, 0);
  });
  test('cancelled, foreign and reused install reviews fail closed', () async {
    final review = await service.reviewInstall(fixtureManifest(), parked: true);
    final foreign = fixtureService(root);
    await expectLater(
      foreign.install(review, parked: true, acceptedSizeAndLicense: true),
      throwsA(failure(LocalFailure.stale)),
    );
    service.cancel();
    await expectLater(
      service.install(review, parked: true, acceptedSizeAndLicense: true),
      throwsA(failure(LocalFailure.stale)),
    );
    expect(source.opens, 0);
  });
  test('corrupted model never reaches runtime and remains removable', () async {
    await install();
    await File(
      '${root.path}/${fixtureManifest().digest}/weights',
    ).writeAsBytes(List.filled(fixtureBytes.length, 0));
    final review = await service.reviewGeneration(
      fixtureManifest(),
      fixturePlan(),
      parked: true,
    );
    await expectLater(
      service.generate(review, parked: true, acceptedReview: true),
      throwsA(failure(LocalFailure.integrity)),
    );
    expect(runtime.calls, 0);
    expect((await service.status()).inventory.artifacts, 1);
    await service.removeModels(parked: true, confirmed: true);
    expect((await service.status()).inventory.bytes, 0);
  });
  for (final response in [
    '{"choices":[0,0],"text":"invented"}',
    '{"choices":[99,0]}',
    '{"choices":[0.0,0]}',
    'not json',
    'x' * 1025,
  ]) {
    test(
      'runtime output is strictly bounded and validated: ${response.substring(0, response.length.clamp(0, 25))}',
      () async {
        await install();
        runtime.response = response;
        final review = await service.reviewGeneration(
          fixtureManifest(),
          fixturePlan(),
          parked: true,
        );
        await expectLater(
          service.generate(review, parked: true, acceptedReview: true),
          throwsA(failure(LocalFailure.malformed)),
        );
      },
    );
  }
  test('cancellation waits for runtime cleanup and excludes removal', () async {
    await install();
    final started = Completer<void>();
    var released = false;
    runtime.handler = (c) async {
      started.complete();
      await c.whenCancelled;
      released = true;
      c.check();
      return '{}';
    };
    final review = await service.reviewGeneration(
      fixtureManifest(),
      fixturePlan(),
      parked: true,
    );
    final result = expectLater(
      service.generate(review, parked: true, acceptedReview: true),
      throwsA(failure(LocalFailure.cancelled)),
    );
    await started.future;
    await expectLater(
      LocalModelStore(root).removeAll(),
      throwsA(failure(LocalFailure.busy)),
    );
    service.cancel();
    await result;
    expect(released, true);
    await LocalModelStore(root).removeAll();
  });
  test(
    'operation budget cancels cooperative runtime without fallback',
    () async {
      await install();
      service = fixtureService(
        root,
        runtime: runtime,
        budget: const Duration(seconds: 1),
      );
      runtime.handler = (c) async {
        await c.whenCancelled;
        c.check();
        return '{}';
      };
      final review = await service.reviewGeneration(
        fixtureManifest(),
        fixturePlan(),
        parked: true,
      );
      await expectLater(
        service.generate(review, parked: true, acceptedReview: true),
        throwsA(failure(LocalFailure.timeout)),
      );
      expect(runtime.calls, 1);
      expect(source.opens, 1);
    },
  );
  test('recorder becoming active discards selected wording', () async {
    await install();
    var idle = true;
    service = fixtureService(root, runtime: runtime, idle: () async => idle);
    runtime.handler = (c) async {
      idle = false;
      return '{"choices":[0,0]}';
    };
    final review = await service.reviewGeneration(
      fixtureManifest(),
      fixturePlan(),
      parked: true,
    );
    await expectLater(
      service.generate(review, parked: true, acceptedReview: true),
      throwsA(failure(LocalFailure.notParked)),
    );
  });
  test(
    'cancellation releases a stalled metadata request and invalidates reviews',
    () async {
      final started = Completer<void>(), gate = Completer<LocalDevice>();
      service = fixtureService(
        root,
        device: () {
          started.complete();
          return gate.future;
        },
      );
      final result = expectLater(
        service.status(),
        throwsA(failure(LocalFailure.cancelled)),
      );
      await started.future;
      service.cancel();
      await result;
      gate.complete(fixtureDevice(root));
    },
  );
}
