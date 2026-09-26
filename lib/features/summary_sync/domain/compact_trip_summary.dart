class CompactTripSummary {
  CompactTripSummary({
    required this.userId,
    required this.tripId,
    this.durationSeconds,
    this.distanceMeters,
    this.overallScore,
    this.scoringVersion,
    this.eventCount,
  }) {
    if (!isUuid(userId) ||
        !isUuid(tripId) ||
        !_integerInRange(durationSeconds) ||
        !_integerInRange(eventCount) ||
        !_numberInRange(distanceMeters, 99999999999.9) ||
        !_numberInRange(overallScore, 100) ||
        (overallScore == null) != (scoringVersion == null) ||
        (scoringVersion != null &&
            !RegExp(r'^[A-Za-z0-9._-]{1,40}$').hasMatch(scoringVersion!))) {
      throw const FormatException('Invalid compact summary.');
    }
  }

  final String userId;
  final String tripId;
  final int? durationSeconds;
  final double? distanceMeters;
  final double? overallScore;
  final String? scoringVersion;
  final int? eventCount;

  static bool isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(value);

  static bool _integerInRange(int? value) =>
      value == null || (value >= 0 && value <= 2147483647);
  static bool _numberInRange(double? value, double max) =>
      value == null || (value.isFinite && value >= 0 && value <= max);

  Map<String, Object?> toJson() => {
    'user_id': userId,
    'source_trip_id': tripId,
    'summary_version': 1,
    'duration_seconds': durationSeconds,
    'distance_m': distanceMeters,
    'score_overall': overallScore,
    'scoring_version': scoringVersion,
    'event_count': eventCount,
  };

  factory CompactTripSummary.fromJson(Map<String, Object?> json) {
    const keys = {
      'user_id',
      'source_trip_id',
      'summary_version',
      'duration_seconds',
      'distance_m',
      'score_overall',
      'scoring_version',
      'event_count',
    };
    if (json.length != keys.length ||
        !json.keys.every(keys.contains) ||
        json['summary_version'] != 1) {
      throw const FormatException('Unsupported compact summary fields.');
    }
    return CompactTripSummary(
      userId: json['user_id'] as String,
      tripId: json['source_trip_id'] as String,
      durationSeconds: json['duration_seconds'] as int?,
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
      overallScore: (json['score_overall'] as num?)?.toDouble(),
      scoringVersion: json['scoring_version'] as String?,
      eventCount: json['event_count'] as int?,
    );
  }

  bool sameContent(CompactTripSummary other) {
    final right = other.toJson();
    return toJson().entries.every((entry) => entry.value == right[entry.key]);
  }
}

class SummarySyncPreview {
  SummarySyncPreview({
    required this.userId,
    required List<CompactTripSummary> candidates,
    required this.pending,
    required this.synced,
    required this.otherAccount,
    this.nextRetryAt,
  }) : candidates = List.unmodifiable(candidates);
  final String userId;
  final List<CompactTripSummary> candidates;
  final int pending;
  final int synced;
  final int otherAccount;
  final DateTime? nextRetryAt;
}

enum SummaryFailure {
  connection,
  accessDenied,
  accountChanged,
  conflict,
  invalidData,
}

class SummarySyncException implements Exception {
  const SummarySyncException(this.reason);
  final SummaryFailure reason;
}

abstract interface class SummaryCloudGateway {
  Future<void> upload(CompactTripSummary summary);
}

class SummarySyncResult {
  const SummarySyncResult({required this.uploaded, required this.failed});
  final int uploaded;
  final int failed;
}
