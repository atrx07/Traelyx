import 'package:traelyx/features/trips/domain/replay_timeline.dart';

enum CommentaryTone {
  analyst(
    label: 'Analyst',
    description: 'Short factual notes from persisted event labels.',
  ),
  chill(
    label: 'Chill',
    description: 'Casual, low-key observations without judgment.',
  ),
  supportive(
    label: 'Supportive',
    description: 'Constructive prompts to review recorded moments.',
  ),
  roast(
    label: 'Roast',
    description: 'Playful criticism without insults or unsafe praise.',
  ),
  unhinged(
    label: 'Unhinged',
    description: 'Chaotic phrasing that still follows safety rules.',
  ),
  silent(label: 'Silent', description: 'No commentary bubbles.');

  const CommentaryTone({required this.label, required this.description});

  final String label;
  final String description;
}

class CommentaryMoment {
  const CommentaryMoment({
    required this.eventIndex,
    required this.eventType,
    required this.eventLabel,
    required this.text,
    required this.anchorTime,
    required this.visibleFrom,
    required this.visibleUntil,
    required this.interestingness,
    required this.contextOrdinal,
    required this.variantIndex,
  });

  final int eventIndex;
  final String eventType;
  final String eventLabel;
  final String text;
  final Duration anchorTime;
  final Duration visibleFrom;
  final Duration visibleUntil;
  final int interestingness;
  final int contextOrdinal;
  final int variantIndex;

  bool isVisibleAt(Duration position) =>
      position >= visibleFrom && position <= visibleUntil;

  double revealProgressAt(Duration position) {
    if (position <= visibleFrom) return 0;
    const revealDuration = Duration(milliseconds: 320);
    final elapsed = position.inMicroseconds - visibleFrom.inMicroseconds;
    return (elapsed / revealDuration.inMicroseconds).clamp(0.0, 1.0);
  }
}

class ProceduralCommentaryPlan {
  const ProceduralCommentaryPlan._({
    required this.tone,
    required this.seed,
    required this.moments,
    required this.supportedEventCount,
    required this.unsupportedEventCount,
    required this.cooldownSuppressedCount,
    required this.limitSuppressedCount,
  });

  static const int commentaryVersion = 1;
  static const Duration cooldown = Duration(seconds: 10);
  static const Duration recentContextWindow = Duration(seconds: 60);
  static const int maximumMoments = 6;

  final CommentaryTone tone;
  final int seed;
  final List<CommentaryMoment> moments;
  final int supportedEventCount;
  final int unsupportedEventCount;
  final int cooldownSuppressedCount;
  final int limitSuppressedCount;

  int get suppressedEventCount =>
      cooldownSuppressedCount + limitSuppressedCount;

  CommentaryMoment? at(Duration position) {
    for (final moment in moments) {
      if (moment.isVisibleAt(position)) return moment;
    }
    return null;
  }

  CommentaryMoment? forEvent(int eventIndex) {
    for (final moment in moments) {
      if (moment.eventIndex == eventIndex) return moment;
    }
    return null;
  }

  static ProceduralCommentaryPlan build({
    required ReplayTimeline timeline,
    required CommentaryTone tone,
    int seed = 0,
  }) {
    final candidates = <_CommentaryCandidate>[];
    var unsupportedEventCount = 0;
    _CommentaryEventKind? previousKind;
    String? previousCategory;
    for (var index = 0; index < timeline.events.length; index++) {
      final event = timeline.events[index];
      final kind = _kindFor(event.type);
      if (kind == null) {
        unsupportedEventCount += 1;
        continue;
      }
      final novelty =
          (previousKind == kind ? 0 : 2) +
          (previousCategory == kind.category ? 0 : 1);
      candidates.add(
        _CommentaryCandidate(
          eventIndex: index,
          event: event,
          kind: kind,
          interestingness: kind.baseInterestingness + novelty,
        ),
      );
      previousKind = kind;
      previousCategory = kind.category;
    }

    if (tone == CommentaryTone.silent || candidates.isEmpty) {
      return ProceduralCommentaryPlan._(
        tone: tone,
        seed: seed,
        moments: const [],
        supportedEventCount: candidates.length,
        unsupportedEventCount: unsupportedEventCount,
        cooldownSuppressedCount: 0,
        limitSuppressedCount: 0,
      );
    }

    final cooldownSelection = <_CommentaryCandidate>[];
    var cooldownSuppressedCount = 0;
    _CommentaryCandidate? pending;
    for (final candidate in candidates) {
      final current = pending;
      if (current == null) {
        pending = candidate;
        continue;
      }
      if (candidate.event.midpoint - current.event.midpoint < cooldown) {
        cooldownSuppressedCount += 1;
        if (candidate.interestingness > current.interestingness) {
          pending = candidate;
        }
      } else {
        cooldownSelection.add(current);
        pending = candidate;
      }
    }
    if (pending != null) cooldownSelection.add(pending);

    var limitSuppressedCount = 0;
    var selected = cooldownSelection;
    if (selected.length > maximumMoments) {
      limitSuppressedCount = selected.length - maximumMoments;
      selected = [...selected]
        ..sort((left, right) {
          final score = right.interestingness.compareTo(left.interestingness);
          return score != 0
              ? score
              : left.event.midpoint.compareTo(right.event.midpoint);
        });
      selected = selected.take(maximumMoments).toList()
        ..sort(
          (left, right) => left.event.midpoint.compareTo(right.event.midpoint),
        );
    }

    final moments = <CommentaryMoment>[];
    for (final candidate in selected) {
      var contextOrdinal = 1;
      for (final previous in selected) {
        if (previous == candidate ||
            previous.event.midpoint >= candidate.event.midpoint) {
          break;
        }
        if (previous.kind.category == candidate.kind.category &&
            candidate.event.midpoint - previous.event.midpoint <=
                recentContextWindow) {
          contextOrdinal += 1;
        }
      }
      final templates = _templatesFor(
        tone: tone,
        kind: candidate.kind,
        repeated: contextOrdinal > 1,
      );
      final variantIndex = _stableVariant(
        seed: seed,
        eventIndex: candidate.eventIndex,
        eventType: candidate.event.type,
        contextOrdinal: contextOrdinal,
        variantCount: templates.length,
      );
      final anchor = candidate.event.midpoint;
      final visibleFromMicros = _maximum(
        candidate.event.start.inMicroseconds,
        anchor.inMicroseconds - const Duration(seconds: 1).inMicroseconds,
      );
      final visibleUntilMicros = _minimum(
        timeline.duration.inMicroseconds,
        anchor.inMicroseconds + const Duration(seconds: 4).inMicroseconds,
      );
      moments.add(
        CommentaryMoment(
          eventIndex: candidate.eventIndex,
          eventType: candidate.event.type,
          eventLabel: candidate.kind.label,
          text: templates[variantIndex],
          anchorTime: anchor,
          visibleFrom: Duration(microseconds: visibleFromMicros),
          visibleUntil: Duration(microseconds: visibleUntilMicros),
          interestingness: candidate.interestingness,
          contextOrdinal: contextOrdinal,
          variantIndex: variantIndex,
        ),
      );
    }

    return ProceduralCommentaryPlan._(
      tone: tone,
      seed: seed,
      moments: List.unmodifiable(moments),
      supportedEventCount: candidates.length,
      unsupportedEventCount: unsupportedEventCount,
      cooldownSuppressedCount: cooldownSuppressedCount,
      limitSuppressedCount: limitSuppressedCount,
    );
  }
}

class _CommentaryCandidate {
  const _CommentaryCandidate({
    required this.eventIndex,
    required this.event,
    required this.kind,
    required this.interestingness,
  });

  final int eventIndex;
  final ReplayEventRange event;
  final _CommentaryEventKind kind;
  final int interestingness;
}

enum _CommentaryEventKind {
  strongAcceleration(
    label: 'Strong acceleration',
    category: 'longitudinal_acceleration',
    baseInterestingness: 3,
  ),
  abruptAcceleration(
    label: 'Abrupt acceleration transition',
    category: 'longitudinal_acceleration',
    baseInterestingness: 5,
  ),
  strongBraking(
    label: 'Strong braking',
    category: 'longitudinal_braking',
    baseInterestingness: 3,
  ),
  abruptBraking(
    label: 'Abrupt braking transition',
    category: 'longitudinal_braking',
    baseInterestingness: 5,
  ),
  leftCorner(
    label: 'High lateral-load left corner',
    category: 'cornering',
    baseInterestingness: 3,
  ),
  rightCorner(
    label: 'High lateral-load right corner',
    category: 'cornering',
    baseInterestingness: 3,
  ),
  abruptCornerEntry(
    label: 'Abrupt corner entry',
    category: 'cornering',
    baseInterestingness: 5,
  ),
  abruptCornerExit(
    label: 'Abrupt corner exit',
    category: 'cornering',
    baseInterestingness: 5,
  ),
  roadImpact(
    label: 'Road impact or bump',
    category: 'road_device',
    baseInterestingness: 6,
  ),
  phoneMoved(
    label: 'Device moved during trip',
    category: 'road_device',
    baseInterestingness: 7,
  );

  const _CommentaryEventKind({
    required this.label,
    required this.category,
    required this.baseInterestingness,
  });

  final String label;
  final String category;
  final int baseInterestingness;
}

_CommentaryEventKind? _kindFor(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'evt_accel_strong' ||
    'strong_acceleration' ||
    'accel_strong' => _CommentaryEventKind.strongAcceleration,
    'evt_accel_abrupt_transition' ||
    'abrupt_acceleration_transition' ||
    'accel_abrupt_transition' => _CommentaryEventKind.abruptAcceleration,
    'evt_brake_strong' ||
    'strong_braking' ||
    'brake_strong' => _CommentaryEventKind.strongBraking,
    'evt_brake_abrupt_transition' ||
    'abrupt_braking_transition' ||
    'brake_abrupt_transition' => _CommentaryEventKind.abruptBraking,
    'evt_corner_high_load_left' ||
    'high_lateral_load_left' ||
    'corner_high_load_left' => _CommentaryEventKind.leftCorner,
    'evt_corner_high_load_right' ||
    'high_lateral_load_right' ||
    'corner_high_load_right' => _CommentaryEventKind.rightCorner,
    'evt_corner_abrupt_entry' ||
    'abrupt_corner_entry' => _CommentaryEventKind.abruptCornerEntry,
    'evt_corner_abrupt_exit' ||
    'abrupt_corner_exit' => _CommentaryEventKind.abruptCornerExit,
    'evt_road_impact' ||
    'road_impact' ||
    'road_impact_or_bump' => _CommentaryEventKind.roadImpact,
    'evt_phone_moved' ||
    'phone_moved' ||
    'device_moved_during_trip' => _CommentaryEventKind.phoneMoved,
    _ => null,
  };
}

List<String> _templatesFor({
  required CommentaryTone tone,
  required _CommentaryEventKind kind,
  required bool repeated,
}) {
  if (repeated) {
    return switch (tone) {
      CommentaryTone.analyst => [
        '${kind.label} repeated in recent replay context.',
        'Another ${kind.label.toLowerCase()} event was persisted nearby.',
      ],
      CommentaryTone.chill => [
        '${kind.label} again—this event family is repeating.',
        'Another ${kind.label.toLowerCase()} moment showed up nearby.',
      ],
      CommentaryTone.supportive => [
        'Another ${kind.label.toLowerCase()} moment—compare it with the previous one.',
        'This ${kind.label.toLowerCase()} pattern is worth reviewing again.',
      ],
      CommentaryTone.roast => [
        'Another one. ${_roastLine(kind)}',
        'The replay brought receipts again: ${kind.label.toLowerCase()}.',
      ],
      CommentaryTone.unhinged => [
        'AGAIN. ${_unhingedLine(kind)}',
        'The sequel arrived: ${kind.label.toLowerCase()}, part two.',
      ],
      CommentaryTone.silent => const [],
    };
  }
  return switch (tone) {
    CommentaryTone.analyst => [
      '${kind.label} recorded.',
      'Persisted event: ${kind.label}.',
    ],
    CommentaryTone.chill => [
      '${kind.label} showed up here.',
      'Replay note: ${kind.label.toLowerCase()}.',
    ],
    CommentaryTone.supportive => [
      'Worth reviewing: ${kind.label.toLowerCase()}.',
      'A useful moment to inspect: ${kind.label.toLowerCase()}.',
    ],
    CommentaryTone.roast => [
      _roastLine(kind),
      '${kind.label} brought extra punctuation to the timeline.',
    ],
    CommentaryTone.unhinged => [
      _unhingedLine(kind),
      'Timeline plot twist: ${kind.label.toLowerCase()}.',
    ],
    CommentaryTone.silent => const [],
  };
}

String _roastLine(_CommentaryEventKind kind) => switch (kind) {
  _CommentaryEventKind.strongAcceleration =>
    'The accelerator submitted a strongly worded memo.',
  _CommentaryEventKind.abruptAcceleration =>
    'That throttle transition skipped the small talk.',
  _CommentaryEventKind.strongBraking =>
    'The brake pedal called a very serious meeting.',
  _CommentaryEventKind.abruptBraking =>
    'That braking transition arrived without knocking.',
  _CommentaryEventKind.leftCorner =>
    'That left corner brought its own dramatic soundtrack.',
  _CommentaryEventKind.rightCorner =>
    'That right corner brought its own dramatic soundtrack.',
  _CommentaryEventKind.abruptCornerEntry =>
    'That corner entry forgot the gentle introduction.',
  _CommentaryEventKind.abruptCornerExit =>
    'That corner exit left the chat abruptly.',
  _CommentaryEventKind.roadImpact =>
    'The road added an unsolicited plot twist.',
  _CommentaryEventKind.phoneMoved =>
    'The phone changed seats without filing paperwork.',
};

String _unhingedLine(_CommentaryEventKind kind) => switch (kind) {
  _CommentaryEventKind.strongAcceleration =>
    'Throttle chapter: suddenly ALL CAPS.',
  _CommentaryEventKind.abruptAcceleration =>
    'The throttle transition just changed genres.',
  _CommentaryEventKind.strongBraking =>
    'Brakes entered the timeline in ALL CAPS.',
  _CommentaryEventKind.abruptBraking =>
    'The braking plot twist had no opening credits.',
  _CommentaryEventKind.leftCorner =>
    'That left corner briefly became the main character.',
  _CommentaryEventKind.rightCorner =>
    'That right corner briefly became the main character.',
  _CommentaryEventKind.abruptCornerEntry =>
    'Corner entry just activated surprise mode.',
  _CommentaryEventKind.abruptCornerExit =>
    'Corner exit hit the scene-change button.',
  _CommentaryEventKind.roadImpact =>
    'The road deployed a surprise expansion pack.',
  _CommentaryEventKind.phoneMoved =>
    'The phone announced a mid-trip seating reshuffle.',
};

int _stableVariant({
  required int seed,
  required int eventIndex,
  required String eventType,
  required int contextOrdinal,
  required int variantCount,
}) {
  var hash = 0x811c9dc5;
  for (final value in <int>[
    seed,
    eventIndex,
    contextOrdinal,
    ...eventType.codeUnits,
  ]) {
    hash ^= value;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash % variantCount;
}

int _minimum(int left, int right) => left < right ? left : right;

int _maximum(int left, int right) => left > right ? left : right;
