import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';

abstract interface class DriveDnaRepository {
  Stream<DriveDnaSnapshot?> watchLatest();
}

class DriftDriveDnaRepository implements DriveDnaRepository {
  const DriftDriveDnaRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<DriveDnaSnapshot?> watchLatest() {
    final query =
        _database.select(_database.driverBaselines).join([
          leftOuterJoin(
            _database.vehicles,
            _database.vehicles.id.equalsExp(
              _database.driverBaselines.vehicleId,
            ),
          ),
        ])..orderBy([
          OrderingTerm.desc(_database.driverBaselines.updatedAtMicros),
          OrderingTerm.desc(_database.driverBaselines.id),
        ]);

    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      final row = rows.first;
      final baseline = row.readTable(_database.driverBaselines);
      final vehicle = row.readTableOrNull(_database.vehicles);
      return _snapshotFromRow(
        baseline,
        vehicleLabel:
            vehicle?.displayName ??
            (baseline.vehicleId == null
                ? 'All local vehicles'
                : 'Previous local vehicle'),
      );
    });
  }
}

DriveDnaSnapshot _snapshotFromRow(
  DriverBaseline baseline, {
  required String vehicleLabel,
}) {
  final payload = _decodeObject(baseline.dimensionStatisticsJson);
  _requireExactKeys(payload, const {'driveDnaVersion', 'dimensions'});
  final driveDnaVersion = _requiredPositiveInt(payload, 'driveDnaVersion');
  final dimensionsValue = payload['dimensions'];
  if (dimensionsValue is! Map<String, Object?>) {
    throw const FormatException('Drive DNA dimensions must be an object.');
  }

  final expectedDimensionKeys = DriveDnaDimensionType.values
      .map(_dimensionStorageKey)
      .toSet();
  _requireExactKeys(dimensionsValue, expectedDimensionKeys);
  final dimensions = <DriveDnaDimension>[];
  for (final type in DriveDnaDimensionType.values) {
    final entry = dimensionsValue[_dimensionStorageKey(type)];
    if (entry is! Map<String, Object?>) {
      throw FormatException('${_dimensionStorageKey(type)} must be an object.');
    }
    dimensions.add(
      _dimensionFromJson(type, entry, validTripCount: baseline.validTripCount),
    );
  }

  final hasWindowStart = baseline.windowStartWallTimeMicros != null;
  final hasWindowEnd = baseline.windowEndWallTimeMicros != null;
  if (hasWindowStart != hasWindowEnd) {
    throw const FormatException(
      'Drive DNA history window must include both bounds or neither.',
    );
  }

  final snapshot = DriveDnaSnapshot(
    vehicleLabel: vehicleLabel,
    lifecycleState: _lifecycleState(baseline.lifecycleState),
    validTripCount: baseline.validTripCount,
    windowStartUtc: hasWindowStart
        ? DateTime.fromMicrosecondsSinceEpoch(
            baseline.windowStartWallTimeMicros!,
            isUtc: true,
          )
        : null,
    windowEndUtc: hasWindowEnd
        ? DateTime.fromMicrosecondsSinceEpoch(
            baseline.windowEndWallTimeMicros!,
            isUtc: true,
          )
        : null,
    baselineSchemaVersion: baseline.baselineSchemaVersion,
    driveDnaVersion: driveDnaVersion,
    scoringVersion: baseline.scoringVersion,
    confidenceRecorded: baseline.confidence != null,
    dimensions: List.unmodifiable(dimensions),
  );
  _validateGovernedSnapshot(snapshot);
  return snapshot;
}

void _validateGovernedSnapshot(DriveDnaSnapshot snapshot) {
  if (snapshot.validTripCount > 30) {
    throw const FormatException(
      'Drive DNA history exceeds the governed cohort limit.',
    );
  }
  if (snapshot.scoringVersion.trim().isEmpty) {
    throw const FormatException('Drive DNA scoring version is empty.');
  }
  if (snapshot.windowStartUtc != null &&
      snapshot.windowEndUtc!.isBefore(snapshot.windowStartUtc!)) {
    throw const FormatException('Drive DNA history window is reversed.');
  }

  final directDimensions = snapshot.dimensions.where(
    (dimension) => dimension.type != DriveDnaDimensionType.consistency,
  );
  for (final dimension in directDimensions) {
    if (dimension.state == DriveDnaDimensionState.available &&
        dimension.eligibleTripCount < 5) {
      throw FormatException(
        '${_dimensionStorageKey(dimension.type)} lacks five eligible drives.',
      );
    }
  }
  final availableDirectCount = directDimensions
      .where((dimension) => dimension.state == DriveDnaDimensionState.available)
      .length;
  final consistency = snapshot.dimensions.singleWhere(
    (dimension) => dimension.type == DriveDnaDimensionType.consistency,
  );
  if (consistency.state == DriveDnaDimensionState.available &&
      availableDirectCount < 3) {
    throw const FormatException(
      'Drive DNA consistency lacks three available direct dimensions.',
    );
  }

  final meetsEstablishedGate =
      snapshot.validTripCount >= 10 &&
      snapshot.profileState == DriveDnaProfileState.complete;
  switch (snapshot.lifecycleState) {
    case DriveDnaLifecycleState.uncalibrated:
      if (snapshot.validTripCount != 0 ||
          snapshot.profileState != DriveDnaProfileState.unavailable) {
        throw const FormatException(
          'Uncalibrated Drive DNA contains current profile evidence.',
        );
      }
      break;
    case DriveDnaLifecycleState.emerging:
      if (snapshot.validTripCount == 0 || meetsEstablishedGate) {
        throw const FormatException(
          'Emerging Drive DNA contradicts its governed lifecycle gate.',
        );
      }
      break;
    case DriveDnaLifecycleState.established:
      if (!meetsEstablishedGate) {
        throw const FormatException(
          'Established Drive DNA has not met its governed lifecycle gate.',
        );
      }
      break;
    case DriveDnaLifecycleState.recalibrating:
      if (meetsEstablishedGate) {
        throw const FormatException(
          'Recalibrating Drive DNA already meets the established gate.',
        );
      }
      break;
  }
}

DriveDnaDimension _dimensionFromJson(
  DriveDnaDimensionType type,
  Map<String, Object?> value, {
  required int validTripCount,
}) {
  const allowedKeys = {
    'state',
    'valueMilliPoints',
    'eligibleTripCount',
    'recentDeltaMilliPoints',
  };
  if (value.keys.any((key) => !allowedKeys.contains(key))) {
    throw FormatException('${_dimensionStorageKey(type)} has unknown fields.');
  }
  final state = switch (value['state']) {
    'available' => DriveDnaDimensionState.available,
    'insufficient_data' => DriveDnaDimensionState.insufficientData,
    _ => throw FormatException(
      '${_dimensionStorageKey(type)} has an unknown evidence state.',
    ),
  };
  final eligibleTripCount = _requiredNonNegativeInt(value, 'eligibleTripCount');
  if (eligibleTripCount > validTripCount) {
    throw FormatException(
      '${_dimensionStorageKey(type)} exceeds the valid trip count.',
    );
  }

  final valueMilliPoints = _optionalBoundedInt(
    value,
    'valueMilliPoints',
    minimum: 0,
    maximum: 100000,
  );
  final recentDeltaMilliPoints = _optionalBoundedInt(
    value,
    'recentDeltaMilliPoints',
    minimum: -100000,
    maximum: 100000,
  );
  if (state == DriveDnaDimensionState.available && valueMilliPoints == null) {
    throw FormatException(
      '${_dimensionStorageKey(type)} is available without a value.',
    );
  }
  if (state == DriveDnaDimensionState.insufficientData &&
      (valueMilliPoints != null || recentDeltaMilliPoints != null)) {
    throw FormatException(
      '${_dimensionStorageKey(type)} has values without sufficient evidence.',
    );
  }

  return DriveDnaDimension(
    type: type,
    state: state,
    valueMilliPoints: valueMilliPoints,
    eligibleTripCount: eligibleTripCount,
    recentDeltaMilliPoints: recentDeltaMilliPoints,
  );
}

Map<String, Object?> _decodeObject(String source) {
  final value = jsonDecode(source);
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a Drive DNA JSON object.');
  }
  return value;
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException('Drive DNA snapshot fields are malformed.');
  }
}

int _requiredNonNegativeInt(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! int || field < 0) {
    throw FormatException('$key must be a non-negative integer.');
  }
  return field;
}

int _requiredPositiveInt(Map<String, Object?> value, String key) {
  final field = _requiredNonNegativeInt(value, key);
  if (field == 0) throw FormatException('$key must be positive.');
  return field;
}

int? _optionalBoundedInt(
  Map<String, Object?> value,
  String key, {
  required int minimum,
  required int maximum,
}) {
  final field = value[key];
  if (field == null) return null;
  if (field is! int || field < minimum || field > maximum) {
    throw FormatException('$key is outside its governed range.');
  }
  return field;
}

DriveDnaLifecycleState _lifecycleState(String value) => switch (value) {
  'uncalibrated' => DriveDnaLifecycleState.uncalibrated,
  'emerging' => DriveDnaLifecycleState.emerging,
  'established' => DriveDnaLifecycleState.established,
  'recalibrating' => DriveDnaLifecycleState.recalibrating,
  _ => throw const FormatException('Unknown Drive DNA lifecycle state.'),
};

String _dimensionStorageKey(DriveDnaDimensionType type) => switch (type) {
  DriveDnaDimensionType.smoothness => 'smoothness',
  DriveDnaDimensionType.brakingControl => 'braking_control',
  DriveDnaDimensionType.accelerationControl => 'acceleration_control',
  DriveDnaDimensionType.corneringControl => 'cornering_control',
  DriveDnaDimensionType.consistency => 'consistency',
};
