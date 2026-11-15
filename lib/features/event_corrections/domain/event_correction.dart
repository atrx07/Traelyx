import 'dart:convert';

const correctionEventLabels = <String, String>{
  'EVT_ACCEL_STRONG': 'Strong acceleration',
  'EVT_ACCEL_ABRUPT_TRANSITION': 'Abrupt acceleration transition',
  'EVT_BRAKE_STRONG': 'Strong braking',
  'EVT_BRAKE_ABRUPT_TRANSITION': 'Abrupt braking transition',
  'EVT_CORNER_HIGH_LOAD_LEFT': 'High lateral-load left corner',
  'EVT_CORNER_HIGH_LOAD_RIGHT': 'High lateral-load right corner',
  'EVT_CORNER_ABRUPT_ENTRY': 'Abrupt corner entry',
  'EVT_CORNER_ABRUPT_EXIT': 'Abrupt corner exit',
  'EVT_ROAD_IMPACT': 'Road impact or bump',
  'EVT_PHONE_MOVED': 'Device moved during trip',
};

enum CorrectionChoice {
  correct('correct', 'This detection looks right'),
  notThisEvent('not_this_event', 'Not this event'),
  roadImpact('road_impact', 'Road impact or bump'),
  deviceMoved('device_moved', 'Device moved'),
  unsure('unsure', 'Unsure');

  const CorrectionChoice(this.wireName, this.label);
  final String wireName;
  final String label;

  static CorrectionChoice parse(String value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw const FormatException('Unknown correction choice.'),
  );
}

class CorrectionTarget {
  CorrectionTarget({required this.snapshot}) {
    if (utf8.encode(snapshot).length > 16384) {
      throw const FormatException(
        'Event snapshot exceeds the correction limit.',
      );
    }
    final decoded = jsonDecode(snapshot);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 18 ||
        !_snapshotKeys.every(decoded.containsKey)) {
      throw const FormatException('Unsupported correction source snapshot.');
    }
    final value = Map<String, Object?>.unmodifiable(decoded);
    for (final key in ['tripId', 'eventId']) {
      if (value[key] is! String ||
          (value[key] as String).isEmpty ||
          (value[key] as String).length > 256) {
        throw const FormatException('Invalid correction source identity.');
      }
    }
    if (!correctionEventLabels.containsKey(value['eventType']) ||
        value['algorithmVersion'] != '1' ||
        value['telemetrySchemaVersion'] is! int ||
        value['telemetrySchemaVersion'] != 1 ||
        value['snapshotVersion'] is! int ||
        value['snapshotVersion'] != 1) {
      throw const FormatException('Unsupported correction detector version.');
    }
    for (final key in [
      'startNanos',
      'peakNanos',
      'endNanos',
      'createdAtMicros',
    ]) {
      if (value[key] is! int || (value[key] as int) < 0) {
        throw const FormatException('Invalid source time.');
      }
    }
    if ((value['peakNanos'] as int) < (value['startNanos'] as int) ||
        (value['endNanos'] as int) < (value['peakNanos'] as int)) {
      throw const FormatException('Invalid correction source range.');
    }
    for (final key in ['severity', 'confidence']) {
      final number = value[key];
      if (number is! num || !number.isFinite || number < 0 || number > 1) {
        throw const FormatException('Invalid source magnitude.');
      }
    }
    for (final key in [
      'severityCalibrationVersion',
      'qualityFlagsJson',
      'primaryMeasurementsJson',
      'ruleEvidenceJson',
      'contextTagsJson',
    ]) {
      if (value[key] is! String) {
        throw const FormatException('Invalid source audit.');
      }
    }
    if (value['mlEvidenceJson'] != null) {
      throw const FormatException('Unsupported correction model lineage.');
    }
    for (final key in ['qualityFlagsJson', 'contextTagsJson']) {
      if (jsonDecode(value[key]! as String) is! List) {
        throw const FormatException('Invalid source categorical audit.');
      }
    }
    for (final key in ['ruleEvidenceJson', 'primaryMeasurementsJson']) {
      if (jsonDecode(value[key]! as String) is! Map) {
        throw const FormatException('Invalid source measurement audit.');
      }
    }
    _values = value;
  }

  final String snapshot;
  late final Map<String, Object?> _values;
  String get tripId => _values['tripId']! as String;
  String get eventId => _values['eventId']! as String;
  String get eventType => _values['eventType']! as String;
  String get label => correctionEventLabels[eventType]!;
  int get startNanos => _values['startNanos']! as int;
  int get endNanos => _values['endNanos']! as int;
  String get qualityDescription {
    final evidence = jsonDecode(_values['ruleEvidenceJson']! as String) as Map;
    return switch (evidence['confidenceCategory']) {
      'SUPPORTED' => 'Source evidence: supported category, not a probability.',
      'LIMITED' =>
        'Source evidence is limited. Treat this detection cautiously.',
      _ => 'Source evidence quality is not available.',
    };
  }
}

const _snapshotKeys = {
  'snapshotVersion',
  'tripId',
  'eventId',
  'telemetrySchemaVersion',
  'eventType',
  'startNanos',
  'peakNanos',
  'endNanos',
  'severity',
  'confidence',
  'severityCalibrationVersion',
  'algorithmVersion',
  'createdAtMicros',
  'qualityFlagsJson',
  'primaryMeasurementsJson',
  'ruleEvidenceJson',
  'mlEvidenceJson',
  'contextTagsJson',
};

class CorrectionNote {
  const CorrectionNote({
    required this.target,
    required this.choice,
    required this.revision,
    required this.createdAtMicros,
    required this.updatedAtMicros,
    required this.consentVersion,
    required this.consentedAtMicros,
  });
  final CorrectionTarget target;
  final CorrectionChoice choice;
  final int revision;
  final int createdAtMicros;
  final int updatedAtMicros;
  final int? consentVersion;
  final int? consentedAtMicros;
  bool get contributionAllowed =>
      consentVersion == 1 && consentedAtMicros != null;
}

class CorrectionCatalog {
  const CorrectionCatalog({
    required this.targets,
    required this.notes,
    required this.staleCount,
  });
  final List<CorrectionTarget> targets;
  final List<CorrectionNote> notes;
  final int staleCount;
  CorrectionNote? noteFor(CorrectionTarget target) {
    for (final note in notes) {
      if (note.target.snapshot == target.snapshot) return note;
    }
    return null;
  }
}

class CorrectionContribution {
  CorrectionContribution({
    required this.reviewToken,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(validateCorrectionContribution(payload));
  final String reviewToken;
  final Map<String, Object?> payload;
  int get count => (payload['labels']! as List).length;
}

Map<String, Object?> validateCorrectionContribution(
  Map<String, Object?> value,
) {
  const header = <String, Object?>{
    'format': 'traelyx_event_corrections',
    'formatVersion': 1,
    'consentVersion': 1,
    'consentPurpose': 'detection_research',
    'consentDeclared': true,
    'labelProvenance': 'user_report_unverified',
    'trainingUse': 'quarantine_only',
    'containsPreciseLocation': false,
    'containsRawTelemetry': false,
  };
  if (value.length != header.length + 1 ||
      !header.entries.every(
        (entry) =>
            value[entry.key] == entry.value &&
            value[entry.key].runtimeType == entry.value.runtimeType,
      )) {
    throw const FormatException('Unsupported correction contribution.');
  }
  final labels = value['labels'];
  if (labels is! List || labels.isEmpty || labels.length > 128) {
    throw const FormatException('Invalid contribution count.');
  }
  final checked = <Map<String, Object?>>[];
  for (final item in labels) {
    if (item is! Map ||
        item.length != 4 ||
        !const {
          'detectedEvent',
          'reportedLabel',
          'eventEngineVersion',
          'telemetrySchemaVersion',
        }.every(item.containsKey) ||
        !correctionEventLabels.containsKey(item['detectedEvent']) ||
        item['reportedLabel'] is! String ||
        item['eventEngineVersion'] is! int ||
        item['eventEngineVersion'] != 1 ||
        item['telemetrySchemaVersion'] is! int ||
        item['telemetrySchemaVersion'] != 1) {
      throw const FormatException('Invalid contribution label.');
    }
    CorrectionChoice.parse(item['reportedLabel'] as String);
    checked.add(Map.unmodifiable(Map<String, Object?>.from(item)));
  }
  final result = <String, Object?>{
    ...header,
    'labels': List<Map<String, Object?>>.unmodifiable(checked),
  };
  if (utf8.encode(jsonEncode(result)).length > 65536) {
    throw const FormatException('Contribution exceeds size limit.');
  }
  return result;
}

Map<String, Object?> correctionContributionPayload(List<CorrectionNote> notes) {
  if (notes.any((note) => !note.contributionAllowed)) {
    throw StateError('Contribution permission required.');
  }
  return validateCorrectionContribution({
    'format': 'traelyx_event_corrections',
    'formatVersion': 1,
    'consentVersion': 1,
    'consentPurpose': 'detection_research',
    'consentDeclared': true,
    'labelProvenance': 'user_report_unverified',
    'trainingUse': 'quarantine_only',
    'containsPreciseLocation': false,
    'containsRawTelemetry': false,
    'labels': [
      for (final note in notes)
        {
          'detectedEvent': note.target.eventType,
          'reportedLabel': note.choice.wireName,
          'eventEngineVersion': 1,
          'telemetrySchemaVersion': 1,
        },
    ],
  });
}
