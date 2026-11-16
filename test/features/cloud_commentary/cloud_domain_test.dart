import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';
import 'cloud_fixture.dart';

void main() {
  test(
    'dossier is deeply immutable and strips times, identities, measurements and unsupported data',
    () {
      final dossier = CommentaryDossier.fromPlan(fixturePlan());
      expect(
        dossier.payload.keys,
        unorderedEquals([
          'dossierVersion',
          'wordingVersion',
          'tone',
          'evidence',
          'moments',
        ]),
      );
      expect((dossier.payload['moments'] as List).length, 2);
      final text = jsonEncode(dossier.payload);
      for (final forbidden in [
        'startElapsed',
        '10000000000',
        'private',
        'tripId',
        'latitude',
        'confidence',
        'speed',
        'severity',
        'score',
      ]) {
        expect(text, isNot(contains(forbidden)));
      }
      expect(() => dossier.payload['tone'] = 'unsafe', throwsUnsupportedError);
      final moment = (dossier.payload['moments'] as List).first as Map;
      expect(() => moment['category'] = 'unsafe', throwsUnsupportedError);
      expect(
        () => (moment['wordingChoices'] as List).add('unsafe'),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'only one bounded integer choice per moment can cross the output boundary',
    () {
      final dossier = CommentaryDossier.fromPlan(fixturePlan());
      for (final value in [
        null,
        <String, Object?>{},
        {
          'choices': [0],
        },
        {
          'choices': [0, 0],
          'text': 'go faster',
        },
        {
          'choices': [0.0, 1],
        },
        {
          'choices': [true, 0],
        },
        {
          'choices': [-1, 0],
        },
        {
          'choices': [2, 0],
        },
        {
          'choices': ['go faster', 0],
        },
        {'text': 'unsafe untrusted provider prose'},
      ]) {
        expect(() => dossier.apply(value), throwsA(isA<CloudException>()));
      }
    },
  );
  test(
    'all tones retain exact event selection, timing and audit fields after cloud choices',
    () {
      for (final tone in CommentaryTone.values) {
        final plan = fixturePlan(tone: tone);
        if (tone == CommentaryTone.silent) {
          expect(
            () => CommentaryDossier.fromPlan(plan),
            throwsA(isA<CloudException>()),
          );
          continue;
        }
        final result = CommentaryDossier.fromPlan(plan).apply({
          'choices': [1, 0],
        });
        expect(result.tone, plan.tone);
        expect(result.seed, plan.seed);
        expect(result.supportedEventCount, plan.supportedEventCount);
        expect(result.unsupportedEventCount, plan.unsupportedEventCount);
        for (var i = 0; i < plan.moments.length; i++) {
          final original = plan.moments[i];
          final selected = result.moments[i];
          expect(selected.text, plan.choicesFor(original)[i == 0 ? 1 : 0]);
          expect(
            [
              selected.eventIndex,
              selected.eventType,
              selected.anchorTime,
              selected.visibleFrom,
              selected.visibleUntil,
              selected.interestingness,
              selected.contextOrdinal,
            ],
            [
              original.eventIndex,
              original.eventType,
              original.anchorTime,
              original.visibleFrom,
              original.visibleUntil,
              original.interestingness,
              original.contextOrdinal,
            ],
          );
        }
      }
    },
  );
  test(
    'automatic registry selects active-family candidates without a permanent model ID',
    () async {
      final policy = await fixturePolicy();
      final models = policy.eligible(const [
        CloudModel('llama-future-70b', 8192),
        CloudModel('llama-future-8b', 8192),
        CloudModel('whisper-large', 8192),
        CloudModel('llama-small-context', 1024),
        CloudModel('compound', 32768),
      ]);
      expect(models.map((m) => m.id), ['llama-future-8b', 'llama-future-70b']);
      for (final id in [
        '',
        'model\nAuthorization: secret',
        'person@example.com',
        'gsk_fixture_placeholder',
        'sk-fixture-placeholder',
        'x' * 121,
      ]) {
        expect(validCloudModelId(id), false);
      }
    },
  );
}
