import 'dart:convert';

import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

class CommentaryContractException implements Exception {
  const CommentaryContractException({this.noMoments = false});
  final bool noMoments;
  @override
  String toString() => 'Commentary input/output contract rejected';
}

class ReviewedCommentaryInput {
  ReviewedCommentaryInput._(this.plan, this.payload);
  factory ReviewedCommentaryInput.fromPlan(ProceduralCommentaryPlan plan) {
    if (plan.moments.isEmpty ||
        plan.moments.length > 6 ||
        plan.tone == CommentaryTone.silent) {
      throw const CommentaryContractException(noMoments: true);
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
      throw const CommentaryContractException();
    }
    return ReviewedCommentaryInput._(plan, payload);
  }
  final ProceduralCommentaryPlan plan;
  final Map<String, Object?> payload;
  String get reviewedJson =>
      const JsonEncoder.withIndent('  ').convert(payload);
  ProceduralCommentaryPlan apply(Object? value) {
    if (value is! Map || value.length != 1 || !value.containsKey('choices')) {
      throw const CommentaryContractException();
    }
    final choices = value['choices'];
    if (choices is! List ||
        choices.length != plan.moments.length ||
        choices.any((v) => v is! int)) {
      throw const CommentaryContractException();
    }
    try {
      return plan.withChoices(choices.cast<int>());
    } catch (_) {
      throw const CommentaryContractException();
    }
  }
}
