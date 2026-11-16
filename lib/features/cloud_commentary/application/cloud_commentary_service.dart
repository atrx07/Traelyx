import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/core/settings/non_secret_setting.dart';
import 'package:traelyx/core/settings/non_secret_settings_repository.dart';
import 'package:traelyx/core/settings/secure_value_store.dart';
import 'package:traelyx/core/settings/settings_providers.dart';
import 'package:traelyx/features/cloud_commentary/data/commentary_secure_store.dart';
import 'package:traelyx/features/cloud_commentary/data/groq_commentary_provider.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

enum CloudModelMode { automatic, discovered, custom }

class CloudConfiguration {
  const CloudConfiguration({
    this.enabled = false,
    this.mode = CloudModelMode.automatic,
    this.model,
    this.revision = 0,
  });
  final bool enabled;
  final CloudModelMode mode;
  final String? model;
  final int revision;
  String encode() => jsonEncode({
    'version': 1,
    'enabled': enabled,
    'mode': mode.name,
    'model': model,
    'revision': revision,
  });
  factory CloudConfiguration.decode(String source) {
    try {
      final value = jsonDecode(source) as Map;
      if (value.length != 5 ||
          !const {
            'version',
            'enabled',
            'mode',
            'model',
            'revision',
          }.every(value.containsKey) ||
          value['version'] is! int ||
          value['version'] != 1 ||
          value['enabled'] is! bool ||
          value['revision'] is! int ||
          (value['revision'] as int) < 0) {
        throw const FormatException();
      }
      final mode = CloudModelMode.values.byName(value['mode'] as String);
      final model = value['model'];
      if ((mode == CloudModelMode.automatic && model != null) ||
          (mode != CloudModelMode.automatic &&
              (model is! String || !validCloudModelId(model)))) {
        throw const FormatException();
      }
      return CloudConfiguration(
        enabled: value['enabled'] as bool,
        mode: mode,
        model: model as String?,
        revision: value['revision'] as int,
      );
    } catch (_) {
      throw const CloudException(CloudFailure.storage);
    }
  }
}

final cloudConfigurationSetting = NonSecretSetting<CloudConfiguration>(
  key: 'commentary.cloud.configuration',
  defaultValue: const CloudConfiguration(),
  encode: (v) => v.encode(),
  decode: CloudConfiguration.decode,
);

class CloudSetup {
  const CloudSetup(this.configuration, this.keySaved, this.models);
  final CloudConfiguration configuration;
  final bool keySaved;
  final List<CloudModel> models;
}

class CloudReview {
  CloudReview._(
    this.dossier,
    this.model,
    this.configuration,
    this.generation,
    this._owner,
  );
  final CommentaryDossier dossier;
  final String model;
  final String configuration;
  final int generation;
  final Object _owner;
  bool _used = false;
}

class CloudCommentaryService {
  CloudCommentaryService({
    required this.secureStore,
    required this.settings,
    required this.provider,
    required this.modelPolicy,
    required this.isRecorderIdle,
  });
  static final credentialKey = SecureValueKey('traelyx.commentary.groq.v1');
  final SecureValueStore secureStore;
  final NonSecretSettingsRepository settings;
  final CommentaryProvider provider;
  final Future<CommentaryModelPolicy> Function() modelPolicy;
  final Future<bool> Function() isRecorderIdle;
  List<CloudModel> _models = const [];
  int _generation = 0;
  bool _mutating = false;
  CloudCancellation? _pending;

  Future<CloudConfiguration> _configuration() async {
    try {
      return await settings.read(cloudConfigurationSetting);
    } on CloudException {
      rethrow;
    } catch (_) {
      throw const CloudException(CloudFailure.storage);
    }
  }

  Future<String?> _credential() async {
    try {
      return await secureStore.read(credentialKey);
    } catch (_) {
      throw const CloudException(CloudFailure.storage);
    }
  }

  void cancel() {
    _generation++;
    _pending?.cancel();
  }

  Future<CloudSetup> load() async {
    try {
      final configuration = await _configuration();
      final key = await _credential();
      return CloudSetup(configuration, key != null && key.isNotEmpty, _models);
    } catch (_) {
      throw const CloudException(CloudFailure.storage);
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_mutating) throw const CloudException(CloudFailure.busy);
    _mutating = true;
    cancel();
    try {
      await action();
    } on CloudException {
      rethrow;
    } catch (_) {
      throw const CloudException(CloudFailure.storage);
    } finally {
      _mutating = false;
    }
  }

  Future<void> saveKey(String value) => _change(() async {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,256}$').hasMatch(value)) {
      throw const CloudException(CloudFailure.credential);
    }
    _models = const [];
    await secureStore.write(credentialKey, value);
    if (await _credential() != value) {
      throw const CloudException(CloudFailure.storage);
    }
    final old = await _configuration();
    await settings.write(
      cloudConfigurationSetting,
      CloudConfiguration(revision: old.revision + 1),
    );
  });
  Future<void> removeKey() => _change(() async {
    _models = const [];
    // Delete credential even if settings storage is unavailable.
    await secureStore.delete(credentialKey);
    if (await _credential() != null) {
      throw const CloudException(CloudFailure.storage);
    }
    final old = await _configuration();
    await settings.write(
      cloudConfigurationSetting,
      CloudConfiguration(revision: old.revision + 1),
    );
  });
  Future<void> configure({
    required bool enabled,
    required CloudModelMode mode,
    String? model,
  }) => _change(() async {
    if ((mode == CloudModelMode.automatic && model != null) ||
        (mode != CloudModelMode.automatic &&
            (model == null || !validCloudModelId(model)))) {
      throw const CloudException(CloudFailure.unsupported);
    }
    final old = await _configuration();
    await settings.write(
      cloudConfigurationSetting,
      CloudConfiguration(
        enabled: enabled,
        mode: mode,
        model: model,
        revision: old.revision + 1,
      ),
    );
  });
  Future<void> _parked(bool parked) async {
    try {
      if (parked && await isRecorderIdle()) return;
    } catch (_) {}
    throw const CloudException(CloudFailure.notParked);
  }

  Future<T> _request<T>(Future<T> Function(CloudCancellation) action) async {
    if (_pending != null || _mutating) {
      throw const CloudException(CloudFailure.busy);
    }
    final token = CloudCancellation();
    final generation = _generation;
    _pending = token;
    try {
      final value =
          await Future.any<T>([
            action(token),
            token.whenCancelled.then<T>(
              (_) => throw const CloudException(CloudFailure.cancelled),
            ),
          ]).timeout(
            const Duration(seconds: 18),
            onTimeout: () {
              token.cancel();
              throw const CloudException(CloudFailure.timeout);
            },
          );
      token.check();
      if (generation != _generation) {
        throw const CloudException(CloudFailure.stale);
      }
      return value;
    } on CloudException {
      rethrow;
    } catch (_) {
      throw const CloudException(CloudFailure.network);
    } finally {
      token.cancel();
      if (identical(_pending, token)) _pending = null;
    }
  }

  Future<List<CloudModel>> refreshModels({required bool parked}) => _request((
    token,
  ) async {
    final generation = _generation;
    await _parked(parked);
    final config = await _configuration();
    if (!config.enabled) throw const CloudException(CloudFailure.disabled);
    final credential = await _credential();
    if (credential == null) throw const CloudException(CloudFailure.credential);
    token.check();
    await _parked(parked);
    if ((await _configuration()).encode() != config.encode() ||
        generation != _generation) {
      throw const CloudException(CloudFailure.stale);
    }
    token.check();
    final models = await provider.listModels(credential, token);
    token.check();
    if (generation != _generation ||
        (await _configuration()).encode() != config.encode()) {
      throw const CloudException(CloudFailure.stale);
    }
    final eligible = (await modelPolicy()).eligible(models);
    if (eligible.isEmpty) {
      throw const CloudException(CloudFailure.modelUnavailable);
    }
    token.check();
    _models = eligible;
    return eligible;
  });
  Future<CloudReview> prepare(
    ProceduralCommentaryPlan plan, {
    required bool parked,
  }) async {
    final generation = _generation;
    await _parked(parked);
    final setup = await load();
    if (!setup.configuration.enabled) {
      throw const CloudException(CloudFailure.disabled);
    }
    if (!setup.keySaved) throw const CloudException(CloudFailure.credential);
    final config = setup.configuration;
    final model = config.mode == CloudModelMode.automatic
        ? (_models.isEmpty ? null : _models.first.id)
        : config.model;
    if (model == null ||
        (config.mode == CloudModelMode.discovered &&
            !_models.any((v) => v.id == model))) {
      throw const CloudException(CloudFailure.modelUnavailable);
    }
    if (generation != _generation || _mutating) {
      throw const CloudException(CloudFailure.stale);
    }
    return CloudReview._(
      CommentaryDossier.fromPlan(plan),
      model,
      config.encode(),
      generation,
      this,
    );
  }

  Future<ProceduralCommentaryPlan> generate(
    CloudReview reviewed, {
    required bool parked,
  }) => _request((token) async {
    await _parked(parked);
    final config = await _configuration();
    if (!config.enabled) throw const CloudException(CloudFailure.disabled);
    if (!identical(reviewed._owner, this) ||
        reviewed._used ||
        reviewed.generation != _generation ||
        config.encode() != reviewed.configuration) {
      throw const CloudException(CloudFailure.stale);
    }
    final key = await _credential();
    if (key == null) throw const CloudException(CloudFailure.credential);
    token.check();
    await _parked(parked);
    if ((await _configuration()).encode() != reviewed.configuration ||
        reviewed.generation != _generation) {
      throw const CloudException(CloudFailure.stale);
    }
    token.check();
    reviewed._used = true;
    final plan = await provider.generate(
      credential: key,
      model: reviewed.model,
      dossier: reviewed.dossier,
      cancellation: token,
    );
    token.check();
    if ((await _configuration()).encode() != reviewed.configuration ||
        reviewed.generation != _generation) {
      throw const CloudException(CloudFailure.stale);
    }
    await _parked(parked);
    if ((await _configuration()).encode() != reviewed.configuration) {
      throw const CloudException(CloudFailure.stale);
    }
    token.check();
    return plan;
  });
}

final cloudCommentaryServiceProvider = Provider<CloudCommentaryService>((ref) {
  final service = CloudCommentaryService(
    secureStore: const CommentarySecureStore(),
    settings: ref.watch(nonSecretSettingsRepositoryProvider),
    provider: GroqCommentaryProvider(GroqHttpTransport()),
    modelPolicy: () async => CommentaryModelPolicy.fromRegistry(
      await rootBundle.loadString('docs/reference/provider-registry.json'),
    ),
    isRecorderIdle: () async {
      final v = (await ref.read(recorderBridgeProvider).getStatus()).lifecycle;
      return v.contractVersion == 1 &&
          v.state == 'idle' &&
          !v.active &&
          v.tripId == null &&
          v.errorCode == null;
    },
  );
  ref.onDispose(service.cancel);
  return service;
});
