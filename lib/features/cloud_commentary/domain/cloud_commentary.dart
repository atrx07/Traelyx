import 'dart:async';
import 'dart:convert';

import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

enum CloudFailure {
  disabled,
  credential,
  storage,
  busy,
  notParked,
  noMoments,
  rateLimit,
  modelUnavailable,
  timeout,
  network,
  server,
  malformed,
  refused,
  unsupported,
  cancelled,
  stale,
}

class CloudException implements Exception {
  const CloudException(this.failure);
  final CloudFailure failure;
  @override
  String toString() => 'CloudCommentary: ${failure.name}';
}

String cloudFailureMessage(Object error) {
  final failure = error is CloudException
      ? error.failure
      : CloudFailure.storage;
  return switch (failure) {
    CloudFailure.credential =>
      'Check or replace your saved key. No credential is shown.',
    CloudFailure.storage =>
      'Secure storage or local settings are unavailable. Cloud is unavailable.',
    CloudFailure.disabled =>
      'Cloud permission is off. The built-in narrator remains available.',
    CloudFailure.busy => 'Another cloud action is in progress.',
    CloudFailure.notParked =>
      'Finish driving and confirm you are parked. Recorder status must be idle.',
    CloudFailure.noMoments =>
      'No supported commentary moments are available. Silent sends nothing.',
    CloudFailure.rateLimit =>
      'Groq reported a quota or rate limit. No automatic retry was made.',
    CloudFailure.modelUnavailable =>
      'The selected model is unavailable. Refresh models or choose another.',
    CloudFailure.timeout =>
      'The request timed out. No automatic retry was made.',
    CloudFailure.network =>
      'The provider could not be reached. Check connectivity before retrying.',
    CloudFailure.server =>
      'The provider is unavailable. No automatic retry was made.',
    CloudFailure.malformed =>
      'The response did not match the reviewed commentary contract.',
    CloudFailure.refused => 'The provider did not return usable commentary.',
    CloudFailure.unsupported =>
      'The model or request capability is unsupported. Choose another model.',
    CloudFailure.cancelled =>
      'The request was cancelled. Already transmitted data cannot be recalled.',
    CloudFailure.stale =>
      'Settings or replay evidence changed. Review a new request.',
  };
}

class CommentaryDossier {
  CommentaryDossier._(this.plan, this.payload);
  factory CommentaryDossier.fromPlan(ProceduralCommentaryPlan plan) {
    if (plan.moments.isEmpty ||
        plan.moments.length > 6 ||
        plan.tone == CommentaryTone.silent) {
      throw const CloudException(CloudFailure.noMoments);
    }
    final payload = Map<String, Object?>.unmodifiable({
      'dossierVersion': 1,
      'wordingVersion': 1,
      'tone': plan.tone.name,
      'evidence': 'persisted_categories_only_quality_not_assessed_by_narrator',
      'moments': List<Map<String, Object?>>.unmodifiable([
        for (final moment in plan.moments)
          Map<String, Object?>.unmodifiable({
            'category': moment.eventLabel,
            'context': moment.contextOrdinal > 1 ? 'repeated' : 'first',
            'wordingChoices': plan.choicesFor(moment),
          }),
      ]),
    });
    if (utf8.encode(jsonEncode(payload)).length > 8192) {
      throw const CloudException(CloudFailure.malformed);
    }
    return CommentaryDossier._(plan, payload);
  }
  final ProceduralCommentaryPlan plan;
  final Map<String, Object?> payload;
  String get reviewedJson =>
      const JsonEncoder.withIndent('  ').convert(payload);
  ProceduralCommentaryPlan apply(Object? value) {
    if (value is! Map || value.length != 1 || !value.containsKey('choices')) {
      throw const CloudException(CloudFailure.malformed);
    }
    final choices = value['choices'];
    if (choices is! List ||
        choices.length != plan.moments.length ||
        choices.any((v) => v is! int)) {
      throw const CloudException(CloudFailure.malformed);
    }
    try {
      return plan.withChoices(choices.cast<int>());
    } catch (_) {
      throw const CloudException(CloudFailure.malformed);
    }
  }
}

bool validCloudModelId(String value) =>
    !value.toLowerCase().startsWith('gsk_') &&
    !value.toLowerCase().startsWith('sk-') &&
    RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._/-]{0,119}$').hasMatch(value);

class CloudModel {
  const CloudModel(this.id, this.contextWindow);
  final String id;
  final int contextWindow;
}

class CommentaryModelPolicy {
  CommentaryModelPolicy._(this.patterns, this.minimumContext);
  factory CommentaryModelPolicy.fromRegistry(String source) {
    final value = jsonDecode(source) as Map;
    if (value['schema_version'] != 1) {
      throw const CloudException(CloudFailure.unsupported);
    }
    final groq = (value['providers'] as List)
        .cast<Map<Object?, Object?>>()
        .singleWhere((v) => v['id'] == 'groq');
    final policy = groq['recommendation'] as Map;
    if (policy['version'] != 1 || policy['minimum_context'] != 4096) {
      throw const CloudException(CloudFailure.unsupported);
    }
    final patterns = (policy['text_model_patterns'] as List).cast<String>();
    if (patterns.isEmpty ||
        patterns.length > 12 ||
        patterns.any((v) => v.length > 80)) {
      throw const CloudException(CloudFailure.unsupported);
    }
    return CommentaryModelPolicy._(
      List.unmodifiable(patterns.map(RegExp.new)),
      4096,
    );
  }
  final List<RegExp> patterns;
  final int minimumContext;
  List<CloudModel> eligible(List<CloudModel> models) {
    final result = models
        .where(
          (m) =>
              m.contextWindow >= minimumContext &&
              patterns.any((p) => p.hasMatch(m.id)),
        )
        .toList();
    int rank(CloudModel m) => patterns.indexWhere((p) => p.hasMatch(m.id));
    result.sort((a, b) {
      final order = rank(a).compareTo(rank(b));
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}

abstract interface class CommentaryProvider {
  String get id;
  Future<List<CloudModel>> listModels(
    String credential,
    CloudCancellation cancellation,
  );
  Future<ProceduralCommentaryPlan> generate({
    required String credential,
    required String model,
    required CommentaryDossier dossier,
    required CloudCancellation cancellation,
  });
}

class CloudCancellation {
  final _completion = Completer<void>();
  bool _cancelled = false;
  void Function()? _abort;
  bool get cancelled => _cancelled;
  Future<void> get whenCancelled => _completion.future;
  void attach(void Function() abort) {
    if (_cancelled) {
      abort();
    } else {
      _abort = abort;
    }
  }

  void check() {
    if (_cancelled) throw const CloudException(CloudFailure.cancelled);
  }

  void cancel() {
    _cancelled = true;
    if (!_completion.isCompleted) _completion.complete();
    _abort?.call();
    _abort = null;
  }

  void detach() {
    _abort = null;
  }
}
