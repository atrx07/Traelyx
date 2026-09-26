import 'dart:convert';

const rankingDimensions = [
  'SCORE_SMOOTHNESS',
  'SCORE_BRAKING_CONTROL',
  'SCORE_ACCELERATION_CONTROL',
  'SCORE_CORNERING_CONTROL',
];
const rankingVehicleClasses = ['car', 'motorcycle', 'other'];
const rankingEventTypes = [
  'EVT_ACCEL_STRONG',
  'EVT_ACCEL_ABRUPT_TRANSITION',
  'EVT_BRAKE_STRONG',
  'EVT_BRAKE_ABRUPT_TRANSITION',
  'EVT_CORNER_HIGH_LOAD_LEFT',
  'EVT_CORNER_HIGH_LOAD_RIGHT',
  'EVT_CORNER_ABRUPT_ENTRY',
  'EVT_CORNER_ABRUPT_EXIT',
  'EVT_ROAD_IMPACT',
];
const rankingVersions = {
  'analysis': 1,
  'raw': 1,
  'encoding': 1,
  'schema': 1,
  'timeline': 1,
  'gnss': 1,
  'calibration': 1,
  'orientation': 1,
  'derived': 1,
  'confidence': 1,
  'taxonomy': 1,
  'merge': 1,
  'integrity': 1,
  'scoring': 1,
};

class RankingCandidate {
  RankingCandidate(this.tripId, this.localDate, Map<String, Object?> evidence)
    : encodedEvidence = jsonEncode(evidence);
  final String tripId;
  final DateTime localDate;
  final String encodedEvidence;
  Map<String, dynamic> get evidence =>
      jsonDecode(encodedEvidence) as Map<String, dynamic>;
  RankingCandidate forVehicleClass(String value) {
    if (!rankingVehicleClasses.contains(value)) {
      throw const FormatException('Unsupported vehicle class.');
    }
    return RankingCandidate(tripId, localDate, {
      ...evidence,
      'vehicle_class': value,
    });
  }

  /// An allowlisted reduction, never a copy of the local audit or existing cloud summary.
  static Map<String, Object?> fromAudit(
    Map<String, dynamic> audit,
    int durationMillis,
  ) {
    final score = audit['score'] as Map<String, dynamic>;
    final integrity = score['integrity'] as Map<String, dynamic>;
    final versions = audit['versions'] as Map<String, dynamic>;
    final quality = audit['finalizationQuality'] as Map<String, dynamic>;
    if (audit['analysisVersion'] != 1 ||
        score['scoringVersion'] != 1 ||
        score['state'] != 'full' ||
        score['rankingStatus'] != 'ELIGIBLE' ||
        integrity['state'] != 'verified' ||
        integrity['version'] != 1 ||
        (integrity['findings'] as List).isNotEmpty ||
        audit['calibrationState'] != 'CALIBRATED' ||
        audit['subsequentCalibrationState'] != 'CALIBRATED' ||
        audit['comparisonState'] != 'CONSISTENT' ||
        audit['completionState'] != 'completed' ||
        audit['recoveryState'] != 'not_needed' ||
        quality['recoveryCount'] != 0 ||
        quality['corruptChunkCount'] != 0 ||
        quality['orphanedWriteCount'] != 0 ||
        quality['orderingViolationCount'] != 0 ||
        (quality['qualityFlags'] as List).isNotEmpty ||
        versions.length != rankingVersions.length ||
        !rankingVersions.entries.every((e) => versions[e.key] == e.value) ||
        durationMillis < 60000 ||
        durationMillis > 7200000 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(audit['sourceDigest'] as String)) {
      throw const FormatException('Not eligible for ranking v1.');
    }
    final dims = score['dimensions'] as Map<String, dynamic>;
    final moving =
        (dims[rankingDimensions.first]['movingNanos'] as int) ~/ 1000000;
    if (moving < 60000 || moving > durationMillis) {
      throw const FormatException('Insufficient moving evidence.');
    }
    final evidence = <List<int>>[];
    for (final name in rankingDimensions) {
      final d = dims[name] as Map<String, dynamic>;
      final opportunity = (d['opportunityNanos'] as int) ~/ 1000000;
      final usable = (d['usableNanos'] as int) ~/ 1000000;
      final full = (d['fullyEligibleNanos'] as int) ~/ 1000000;
      if (d['state'] != 'full' ||
          (d['provisionalReasons'] as List).isNotEmpty ||
          (d['unavailableReasons'] as List).isNotEmpty ||
          (d['movingNanos'] as int) ~/ 1000000 != moving ||
          opportunity < 500 ||
          opportunity > moving ||
          usable > opportunity ||
          full > usable ||
          full * 1000 < opportunity * 800 ||
          (name == rankingDimensions.first && opportunity != moving)) {
        throw const FormatException('Incomplete dimension evidence.');
      }
      evidence.add([opportunity, usable, full]);
    }
    final events =
        (audit['events'] as List).cast<Map<String, dynamic>>().toList()
          ..sort((a, b) {
            final time = (a['startNanos'] as int).compareTo(
              b['startNanos'] as int,
            );
            if (time != 0) return time;
            final type = rankingEventTypes
                .indexOf(a['type'] as String)
                .compareTo(rankingEventTypes.indexOf(b['type'] as String));
            return type != 0
                ? type
                : (a['id'] as String).compareTo(b['id'] as String);
          });
    if (events.length > 1000) {
      throw const FormatException('Too many ranking events.');
    }
    final tuples = <List<int>>[];
    for (final e in events) {
      final type = rankingEventTypes.indexOf(e['type'] as String);
      final ratio = e['activationRatio'];
      if (type < 0 ||
          e['confidence'] != 'SUPPORTED' ||
          ratio is! num ||
          !ratio.isFinite ||
          ratio < 1) {
        throw const FormatException('Limited ranking event.');
      }
      tuples.add([type, (ratio * 1000).round().clamp(1000, 2000), 1000]);
    }
    return {
      'versions': {...rankingVersions, 'validation': 1},
      'source_digest': audit['sourceDigest'],
      'duration_ms': durationMillis,
      'moving_ms': moving,
      'calibration': [1, 1, 1],
      'integrity_counts': List.filled(11, 0),
      'dimensions': evidence,
      'events': tuples,
    };
  }
}

class RankingSnapshot {
  RankingSnapshot({
    required this.rows,
    required this.submittedIds,
    this.username,
    this.displayName,
    this.vehicleClasses = const [],
  });
  final List<RankingRow> rows;
  final Set<String> submittedIds;
  final String? username;
  final String? displayName;
  final List<String> vehicleClasses;
  factory RankingSnapshot.fromJson(Map<String, dynamic> j) {
    if (j.length != 4 ||
        !j.keys.every(
          const {
            'profile',
            'rows',
            'submitted_trip_ids',
            'vehicle_classes',
          }.contains,
        )) {
      throw const FormatException('Unexpected ranking response fields.');
    }
    final profile = j['profile'] as Map<String, dynamic>?;
    final rows = (j['rows'] as List)
        .map((e) => RankingRow.fromJson(e as Map<String, dynamic>))
        .toList();
    final ids = (j['submitted_trip_ids'] as List).cast<String>().toSet();
    final classes = (j['vehicle_classes'] as List).cast<String>();
    if (rows.length > 1001 ||
        classes.length > 3 ||
        !classes.every(rankingVehicleClasses.contains) ||
        ids.length > 1000 ||
        !ids.every(
          (id) => RegExp(
            r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
          ).hasMatch(id),
        ) ||
        (profile != null &&
            (profile.length != 2 ||
                !_username(profile['username']) ||
                !_label(profile['display_name'])))) {
      throw const FormatException('Invalid ranking projection.');
    }
    return RankingSnapshot(
      rows: List.unmodifiable(rows),
      submittedIds: Set.unmodifiable(ids),
      username: profile?['username'] as String?,
      displayName: profile?['display_name'] as String?,
      vehicleClasses: List.unmodifiable(classes),
    );
  }
}

class RankingRow {
  const RankingRow(
    this.username,
    this.displayName,
    this.isSelf,
    this.sampleCount,
    this.smoothness,
    this.consistency,
    this.improvement,
    this.vehicleClass,
  );
  final String username, displayName;
  final String vehicleClass;
  final bool isSelf;
  final int sampleCount;
  final double? smoothness, consistency, improvement;
  factory RankingRow.fromJson(Map<String, dynamic> j) {
    if (j.length != 8 ||
        !j.keys.every(
          const {
            'username',
            'display_name',
            'is_self',
            'sample_count',
            'smoothness',
            'consistency',
            'improvement',
            'vehicle_class',
          }.contains,
        )) {
      throw const FormatException('Unexpected ranking row fields.');
    }
    final count = j['sample_count'] as int;
    final values = [j['smoothness'], j['consistency'], j['improvement']];
    if (!_username(j['username']) ||
        !rankingVehicleClasses.contains(j['vehicle_class']) ||
        !_label(j['display_name']) ||
        count < 1 ||
        count > 10 ||
        (count < 10 && values.any((v) => v != null)) ||
        (count == 10 &&
            values.any(
              (v) => v is! num || !v.isFinite || v < -100 || v > 100,
            )) ||
        (count == 10 && ((values[0] as num) < 0 || (values[1] as num) < 0))) {
      throw const FormatException('Invalid ranking result.');
    }
    return RankingRow(
      j['username'] as String,
      j['display_name'] as String,
      j['is_self'] as bool,
      count,
      (j['smoothness'] as num?)?.toDouble(),
      (j['consistency'] as num?)?.toDouble(),
      (j['improvement'] as num?)?.toDouble(),
      j['vehicle_class'] as String,
    );
  }
}

bool _username(Object? v) =>
    v is String && RegExp(r'^[a-z][a-z0-9_]{2,29}$').hasMatch(v);
bool _label(Object? v) =>
    v is String && v.trim() == v && v.isNotEmpty && v.length <= 80;

abstract interface class RankingGateway {
  Future<RankingSnapshot> load(String owner);
  Future<void> submit(
    String owner,
    String username,
    String displayName,
    RankingCandidate candidate,
  );
  Future<void> withdraw(String owner);
}
