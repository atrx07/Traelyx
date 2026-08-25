enum TripEvidenceState {
  verified,
  limited,
  reviewRequired,
  unavailable,
  notAssessed,
}

class TripHistoryItem {
  const TripHistoryItem({
    required this.id,
    required this.vehicleName,
    required this.startedAtUtc,
    required this.duration,
    required this.distanceMeters,
    required this.completionState,
    required this.recoveryState,
    required this.integrityState,
  });

  final String id;
  final String vehicleName;
  final DateTime startedAtUtc;
  final Duration? duration;
  final double? distanceMeters;
  final TripEvidenceState completionState;
  final TripEvidenceState recoveryState;
  final TripEvidenceState integrityState;
}

class TripEvidenceSummary {
  const TripEvidenceSummary({
    required this.chunkCount,
    required this.byteCount,
    required this.gnssSampleCount,
    required this.accelerometerSampleCount,
    required this.gyroscopeSampleCount,
  });

  final int chunkCount;
  final int byteCount;
  final int gnssSampleCount;
  final int accelerometerSampleCount;
  final int gyroscopeSampleCount;
}

class TripFinalizationSummary {
  const TripFinalizationSummary({
    required this.logicVersion,
    required this.recoveryCount,
    required this.corruptChunkCount,
    required this.orphanedWriteCount,
    required this.orderingViolationCount,
    required this.qualityFlags,
  });

  final int logicVersion;
  final int recoveryCount;
  final int corruptChunkCount;
  final int orphanedWriteCount;
  final int orderingViolationCount;
  final List<String> qualityFlags;

  bool get hasLimitations =>
      corruptChunkCount > 0 ||
      orphanedWriteCount > 0 ||
      orderingViolationCount > 0 ||
      qualityFlags.any((flag) => flag != 'recorder_recovered');
}

class TripEventSummary {
  const TripEventSummary({
    required this.type,
    required this.startElapsedNanos,
    required this.endElapsedNanos,
  });

  final String type;
  final int startElapsedNanos;
  final int endElapsedNanos;
}

class TripScoreSummary {
  const TripScoreSummary({
    required this.overallScore,
    required this.eligibilityState,
    required this.scoringVersion,
    required this.confidenceRecorded,
  });

  final double? overallScore;
  final TripEvidenceState eligibilityState;
  final String scoringVersion;
  final bool confidenceRecorded;
}

class TripResult {
  const TripResult({
    required this.trip,
    required this.telemetrySchemaVersion,
    required this.telemetryConfidenceRecorded,
    required this.evidence,
    required this.finalization,
    required this.events,
    required this.score,
  });

  final TripHistoryItem trip;
  final int telemetrySchemaVersion;
  final bool telemetryConfidenceRecorded;
  final TripEvidenceSummary evidence;
  final TripFinalizationSummary? finalization;
  final List<TripEventSummary> events;
  final TripScoreSummary? score;
}
