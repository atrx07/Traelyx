enum RawRetentionPolicy { manual, sevenDays, thirtyDays, forever }

extension RawRetentionPolicyContract on RawRetentionPolicy {
  String get encoded => switch (this) {
    RawRetentionPolicy.manual => 'manual',
    RawRetentionPolicy.sevenDays => '7_days',
    RawRetentionPolicy.thirtyDays => '30_days',
    RawRetentionPolicy.forever => 'forever',
  };

  int? get retentionDays => switch (this) {
    RawRetentionPolicy.sevenDays => 7,
    RawRetentionPolicy.thirtyDays => 30,
    RawRetentionPolicy.manual || RawRetentionPolicy.forever => null,
  };

  static RawRetentionPolicy decode(String value) => switch (value) {
    'manual' => RawRetentionPolicy.manual,
    '7_days' => RawRetentionPolicy.sevenDays,
    '30_days' => RawRetentionPolicy.thirtyDays,
    'forever' => RawRetentionPolicy.forever,
    _ => throw const FormatException('Unknown raw-retention policy.'),
  };
}

class StoredTripData {
  const StoredTripData({
    required this.id,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.duration,
    required this.chunkCount,
    required this.indexedRawBytes,
  });

  final String id;
  final DateTime startedAtUtc;
  final DateTime endedAtUtc;
  final Duration? duration;
  final int chunkCount;
  final int indexedRawBytes;

  bool get hasRawTelemetry => chunkCount > 0;
}

class RawCleanupPlan {
  const RawCleanupPlan({required this.policy, required this.candidates});

  final RawRetentionPolicy policy;
  final List<StoredTripData> candidates;

  int get indexedRawBytes =>
      candidates.fold(0, (total, trip) => total + trip.indexedRawBytes);
}

class RawCleanupResult {
  const RawCleanupResult({
    required this.deletedTripCount,
    required this.bytesDeleted,
    required this.failureCount,
  });

  final int deletedTripCount;
  final int bytesDeleted;
  final int failureCount;

  bool get complete => failureCount == 0;
}

class DataManagementFailure implements Exception {
  const DataManagementFailure(this.code);

  final String code;

  @override
  String toString() => 'DataManagementFailure($code)';
}
