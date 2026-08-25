enum DriveDnaDimensionType {
  smoothness,
  brakingControl,
  accelerationControl,
  corneringControl,
  consistency,
}

enum DriveDnaDimensionState { available, insufficientData }

enum DriveDnaProfileState { complete, partial, unavailable }

enum DriveDnaLifecycleState {
  uncalibrated,
  emerging,
  established,
  recalibrating,
}

class DriveDnaDimension {
  const DriveDnaDimension({
    required this.type,
    required this.state,
    required this.valueMilliPoints,
    required this.eligibleTripCount,
    required this.recentDeltaMilliPoints,
  });

  final DriveDnaDimensionType type;
  final DriveDnaDimensionState state;
  final int? valueMilliPoints;
  final int eligibleTripCount;
  final int? recentDeltaMilliPoints;

  double? get value =>
      valueMilliPoints == null ? null : valueMilliPoints! / 1000;

  double? get recentDelta =>
      recentDeltaMilliPoints == null ? null : recentDeltaMilliPoints! / 1000;
}

class DriveDnaSnapshot {
  const DriveDnaSnapshot({
    required this.vehicleLabel,
    required this.lifecycleState,
    required this.validTripCount,
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.baselineSchemaVersion,
    required this.driveDnaVersion,
    required this.scoringVersion,
    required this.confidenceRecorded,
    required this.dimensions,
  });

  final String vehicleLabel;
  final DriveDnaLifecycleState lifecycleState;
  final int validTripCount;
  final DateTime? windowStartUtc;
  final DateTime? windowEndUtc;
  final int baselineSchemaVersion;
  final int driveDnaVersion;
  final String scoringVersion;
  final bool confidenceRecorded;
  final List<DriveDnaDimension> dimensions;

  DriveDnaProfileState get profileState {
    final availableCount = dimensions
        .where(
          (dimension) => dimension.state == DriveDnaDimensionState.available,
        )
        .length;
    if (availableCount == dimensions.length) {
      return DriveDnaProfileState.complete;
    }
    if (availableCount > 0) return DriveDnaProfileState.partial;
    return DriveDnaProfileState.unavailable;
  }
}
