import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/settings/drift_non_secret_settings_repository.dart';
import 'package:traelyx/features/cloud_commentary/application/cloud_commentary_service.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';
import 'cloud_fixture.dart';

void main() {
  late AppDatabase db;
  late MemoryCloudVault vault;
  late _Provider provider;
  late CloudCommentaryService service;
  late DriftNonSecretSettingsRepository settings;
  var idle = true;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vault = MemoryCloudVault();
    provider = _Provider();
    idle = true;
    settings = DriftNonSecretSettingsRepository(db);
    service = CloudCommentaryService(
      secureStore: vault,
      settings: settings,
      provider: provider,
      modelPolicy: fixturePolicy,
      isRecorderIdle: () async => idle,
    );
  });
  tearDown(() async {
    service.cancel();
    await db.close();
  });
  Future<void> enable() async {
    await service.saveKey('fixture-placeholder');
    await service.configure(enabled: true, mode: CloudModelMode.automatic);
    await service.refreshModels(parked: true);
  }

  test(
    'default/offline load and local key save never request or expose credentials to Drift',
    () async {
      final initial = await service.load();
      expect(initial.configuration.enabled, false);
      expect(initial.keySaved, false);
      await service.saveKey('fixture-placeholder');
      final saved = await service.load();
      expect(saved.keySaved, true);
      expect(saved.configuration.enabled, false);
      expect(provider.calls, 0);
      expect(
        jsonEncode(
          (await db.select(db.appSettings).get())
              .map((r) => r.toJson())
              .toList(),
        ),
        isNot(contains('fixture-placeholder')),
      );
      await expectLater(
        service.refreshModels(parked: true),
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'off',
            CloudFailure.disabled,
          ),
        ),
      );
      expect(provider.calls, 0);
    },
  );
  test(
    'active/unknown/no parked state and Silent block every network request',
    () async {
      await service.saveKey('fixture-placeholder');
      await service.configure(enabled: true, mode: CloudModelMode.automatic);
      await expectLater(
        service.refreshModels(parked: false),
        throwsA(isA<CloudException>()),
      );
      idle = false;
      await expectLater(
        service.refreshModels(parked: true),
        throwsA(isA<CloudException>()),
      );
      expect(provider.calls, 0);
      idle = true;
      await service.refreshModels(parked: true);
      await expectLater(
        service.prepare(fixturePlan(tone: CommentaryTone.silent), parked: true),
        throwsA(isA<CloudException>()),
      );
      expect(provider.calls, 1);
      final unknown = CloudCommentaryService(
        secureStore: vault,
        settings: settings,
        provider: provider,
        modelPolicy: fixturePolicy,
        isRecorderIdle: () async => throw StateError('unknown'),
      );
      await expectLater(
        unknown.refreshModels(parked: true),
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'unknown',
            CloudFailure.notParked,
          ),
        ),
      );
    },
  );
  test(
    'prepare is local-only, explicit generation retains exact reviewed model/dossier',
    () async {
      await enable();
      final count = provider.calls;
      final review = await service.prepare(fixturePlan(), parked: true);
      expect(provider.calls, count);
      final result = await service.generate(review, parked: true);
      expect(provider.received, review.dossier);
      expect(provider.model, review.model);
      expect(
        result.moments.first.text,
        review.dossier.plan.choicesFor(review.dossier.plan.moments.first)[1],
      );
      expect(provider.calls, count + 1);
    },
  );
  test('a reviewed send is one-use even after provider failure', () async {
    await enable();
    final review = await service.prepare(fixturePlan(), parked: true);
    provider.error = const CloudException(CloudFailure.rateLimit);
    await expectLater(
      service.generate(review, parked: true),
      throwsA(isA<CloudException>()),
    );
    await expectLater(
      service.generate(review, parked: true),
      throwsA(
        isA<CloudException>().having(
          (e) => e.failure,
          'one use',
          CloudFailure.stale,
        ),
      ),
    );
    expect(
      provider.calls,
      2,
    ); // One explicit discovery and one generation attempt.
  });
  test(
    'recorder starting during a pending response independently blocks publication',
    () async {
      await enable();
      final review = await service.prepare(fixturePlan(), parked: true);
      provider.pending = Completer<ProceduralCommentaryPlan>();
      final result = service.generate(review, parked: true);
      final rejected = expectLater(
        result,
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'recorder',
            CloudFailure.notParked,
          ),
        ),
      );
      await provider.started.future;
      idle = false;
      provider.pending!.complete(review.dossier.plan);
      await rejected;
    },
  );
  test(
    'permission/configuration or key replacement invalidates an earlier review',
    () async {
      await enable();
      final review = await service.prepare(fixturePlan(), parked: true);
      await service.configure(enabled: false, mode: CloudModelMode.automatic);
      await expectLater(
        service.generate(review, parked: true),
        throwsA(isA<CloudException>()),
      );
      await service.configure(enabled: true, mode: CloudModelMode.automatic);
      await expectLater(
        service.generate(review, parked: true),
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'revision',
            CloudFailure.stale,
          ),
        ),
      );
      final next = await service.prepare(fixturePlan(), parked: true);
      await service.saveKey('different-fixture-placeholder');
      expect((await service.load()).configuration.enabled, false);
      await service.configure(enabled: true, mode: CloudModelMode.automatic);
      await expectLater(
        service.generate(next, parked: true),
        throwsA(isA<CloudException>()),
      );
      expect(provider.calls, 1);
    },
  );
  test(
    'external withdrawal during a delayed credential read blocks transmission',
    () async {
      await enable();
      final review = await service.prepare(fixturePlan(), parked: true);
      vault.readGate = Completer<void>();
      final result = service.generate(review, parked: true);
      final rejected = expectLater(
        result,
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'withdrawal',
            CloudFailure.stale,
          ),
        ),
      );
      await vault.reading.future;
      await settings.write(
        cloudConfigurationSetting,
        const CloudConfiguration(),
      );
      vault.readGate!.complete();
      await rejected;
      expect(provider.calls, 1);
    },
  );
  test(
    'key removal during a pending response cancels promptly and rejects late publication',
    () async {
      await enable();
      final review = await service.prepare(fixturePlan(), parked: true);
      provider.pending = Completer<ProceduralCommentaryPlan>();
      final result = service.generate(review, parked: true);
      final rejected = expectLater(
        result,
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'cancel',
            CloudFailure.cancelled,
          ),
        ),
      );
      await provider.started.future;
      await expectLater(
        service.generate(review, parked: true),
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'busy',
            CloudFailure.busy,
          ),
        ),
      );
      await service.removeKey();
      await rejected;
      expect(vault.value, null);
      expect((await service.load()).configuration.enabled, false);
      provider.pending!.complete(review.dossier.plan);
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'external settings writer and recorder starting while pending prevent result use',
    () async {
      await enable();
      final review = await service.prepare(fixturePlan(), parked: true);
      provider.pending = Completer<ProceduralCommentaryPlan>();
      final result = service.generate(review, parked: true);
      final rejected = expectLater(result, throwsA(isA<CloudException>()));
      await provider.started.future;
      await settings.write(
        cloudConfigurationSetting,
        const CloudConfiguration(),
      );
      idle = false;
      provider.pending!.complete(review.dossier.plan);
      await rejected;
    },
  );
  test(
    'custom models work without hardcoded catalog and errors never erase offline plans',
    () async {
      await service.saveKey('fixture-placeholder');
      await service.configure(
        enabled: true,
        mode: CloudModelMode.custom,
        model: 'future/text-chat',
      );
      final plan = fixturePlan();
      final review = await service.prepare(plan, parked: true);
      expect(review.model, 'future/text-chat');
      expect(provider.calls, 0);
      provider.error = const CloudException(CloudFailure.rateLimit);
      await expectLater(
        service.generate(review, parked: true),
        throwsA(isA<CloudException>()),
      );
      expect(plan.moments.length, 2);
      expect(provider.calls, 1);
      expect(
        cloudFailureMessage(StateError('private key body')),
        isNot(contains('private')),
      );
    },
  );
  test('configuration rejects a replaced nullable field and extra metadata', () {
    expect(
      () => CloudConfiguration.decode(
        '{"version":1,"enabled":true,"mode":"automatic","revision":1,"extra":"ignored"}',
      ),
      throwsA(
        isA<CloudException>().having(
          (e) => e.failure,
          'schema',
          CloudFailure.storage,
        ),
      ),
    );
  });
  test('storage failures and malformed persisted settings fail closed', () async {
    vault.fail = true;
    await expectLater(
      service.load(),
      throwsA(
        isA<CloudException>().having(
          (e) => e.failure,
          'storage',
          CloudFailure.storage,
        ),
      ),
    );
    await expectLater(
      service.saveKey('fixture-placeholder'),
      throwsA(isA<CloudException>()),
    );
    expect(provider.calls, 0);
    vault.fail = false;
    await db.customStatement(
      "INSERT INTO app_settings VALUES ('commentary.cloud.configuration','{\"version\":1,\"enabled\":true}',1)",
    );
    await expectLater(service.load(), throwsA(isA<CloudException>()));
    expect(provider.calls, 0);
  });
}

class _Provider implements CommentaryProvider {
  @override
  String get id => 'groq';
  int calls = 0;
  String? model;
  CommentaryDossier? received;
  Object? error;
  Completer<ProceduralCommentaryPlan>? pending;
  final started = Completer<void>();
  @override
  Future<List<CloudModel>> listModels(
    String credential,
    CloudCancellation cancellation,
  ) async {
    calls++;
    return const [CloudModel('llama-fixture-8b', 8192)];
  }

  @override
  Future<ProceduralCommentaryPlan> generate({
    required String credential,
    required String model,
    required CommentaryDossier dossier,
    required CloudCancellation cancellation,
  }) async {
    calls++;
    this.model = model;
    received = dossier;
    started.complete();
    if (error != null) throw error!;
    return pending?.future ??
        Future.value(
          dossier.apply({
            'choices': [1, 0],
          }),
        );
  }
}
