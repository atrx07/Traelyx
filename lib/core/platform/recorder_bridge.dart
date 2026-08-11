import 'package:flutter/services.dart';

class RecorderCapabilities {
  const RecorderCapabilities({
    required this.bridgeVersion,
    required this.implementationState,
    required this.recordingAvailable,
    required this.serviceRegistered,
    this.statusContractVersion = 0,
    this.commandsAvailable = false,
    this.healthAvailable = false,
    this.permissionOnboardingAvailable = false,
  });

  factory RecorderCapabilities.fromMap(Map<Object?, Object?> value) {
    return RecorderCapabilities(
      bridgeVersion: _optionalInt(value, 'bridgeVersion'),
      statusContractVersion: _optionalInt(value, 'statusContractVersion'),
      implementationState: _optionalString(
        value,
        'implementationState',
        fallback: 'unknown',
      ),
      recordingAvailable: _optionalBool(value, 'recordingAvailable'),
      serviceRegistered: _optionalBool(value, 'serviceRegistered'),
      commandsAvailable: _optionalBool(value, 'commandsAvailable'),
      healthAvailable: _optionalBool(value, 'healthAvailable'),
      permissionOnboardingAvailable: _optionalBool(
        value,
        'permissionOnboardingAvailable',
      ),
    );
  }

  final int bridgeVersion;
  final int statusContractVersion;
  final String implementationState;
  final bool recordingAvailable;
  final bool serviceRegistered;
  final bool commandsAvailable;
  final bool healthAvailable;
  final bool permissionOnboardingAvailable;
}

class RecorderLifecycleStatus {
  const RecorderLifecycleStatus({
    required this.contractVersion,
    required this.state,
    required this.active,
    required this.tripId,
    required this.recoveryCount,
    required this.errorCode,
  });

  factory RecorderLifecycleStatus.fromMap(Map<Object?, Object?> value) {
    return RecorderLifecycleStatus(
      contractVersion: _requiredPositiveInt(value, 'contractVersion'),
      state: _requiredString(value, 'state'),
      active: _requiredBool(value, 'active'),
      tripId: _nullableString(value, 'tripId'),
      recoveryCount: _requiredNonNegativeInt(value, 'recoveryCount'),
      errorCode: _nullableErrorCode(value, 'errorCode'),
    );
  }

  final int contractVersion;
  final String state;
  final bool active;
  final String? tripId;
  final int recoveryCount;
  final String? errorCode;
}

class RecorderGnssHealth {
  const RecorderGnssHealth({
    required this.contractVersion,
    required this.state,
    required this.provider,
    required this.requestedIntervalMillis,
    required this.acceptedSampleCount,
    required this.rejectedSampleCount,
    required this.lowAccuracySampleCount,
    required this.clockDiscontinuityCount,
    required this.mockSignalCount,
    required this.providerDisabledCount,
    required this.registrationFailureCount,
    required this.lastFixHadSpeed,
    required this.lastFixHadBearing,
    required this.errorCode,
  });

  factory RecorderGnssHealth.fromMap(Map<Object?, Object?> value) {
    return RecorderGnssHealth(
      contractVersion: _requiredPositiveInt(value, 'contractVersion'),
      state: _requiredString(value, 'state'),
      provider: _requiredString(value, 'provider'),
      requestedIntervalMillis: _requiredPositiveInt(
        value,
        'requestedIntervalMillis',
      ),
      acceptedSampleCount: _requiredNonNegativeInt(
        value,
        'acceptedSampleCount',
      ),
      rejectedSampleCount: _requiredNonNegativeInt(
        value,
        'rejectedSampleCount',
      ),
      lowAccuracySampleCount: _requiredNonNegativeInt(
        value,
        'lowAccuracySampleCount',
      ),
      clockDiscontinuityCount: _requiredNonNegativeInt(
        value,
        'clockDiscontinuityCount',
      ),
      mockSignalCount: _requiredNonNegativeInt(value, 'mockSignalCount'),
      providerDisabledCount: _requiredNonNegativeInt(
        value,
        'providerDisabledCount',
      ),
      registrationFailureCount: _requiredNonNegativeInt(
        value,
        'registrationFailureCount',
      ),
      lastFixHadSpeed: _requiredBool(value, 'lastFixHadSpeed'),
      lastFixHadBearing: _requiredBool(value, 'lastFixHadBearing'),
      errorCode: _nullableErrorCode(value, 'errorCode'),
    );
  }

  final int contractVersion;
  final String state;
  final String provider;
  final int requestedIntervalMillis;
  final int acceptedSampleCount;
  final int rejectedSampleCount;
  final int lowAccuracySampleCount;
  final int clockDiscontinuityCount;
  final int mockSignalCount;
  final int providerDisabledCount;
  final int registrationFailureCount;
  final bool lastFixHadSpeed;
  final bool lastFixHadBearing;
  final String? errorCode;
}

class RecorderImuHealth {
  const RecorderImuHealth({
    required this.contractVersion,
    required this.state,
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
    required this.accelerometerBatchingAvailable,
    required this.gyroscopeBatchingAvailable,
    required this.accelerometerAcceptedSampleCount,
    required this.gyroscopeAcceptedSampleCount,
    required this.rejectedSampleCount,
    required this.unreliableAccuracySampleCount,
    required this.clockDiscontinuityCount,
    required this.dropoutCount,
    required this.accuracyChangeCount,
    required this.registrationFailureCount,
    required this.errorCode,
  });

  factory RecorderImuHealth.fromMap(Map<Object?, Object?> value) {
    return RecorderImuHealth(
      contractVersion: _requiredPositiveInt(value, 'contractVersion'),
      state: _requiredString(value, 'state'),
      accelerometerAvailable: _requiredBool(value, 'accelerometerAvailable'),
      gyroscopeAvailable: _requiredBool(value, 'gyroscopeAvailable'),
      accelerometerBatchingAvailable: _requiredBool(
        value,
        'accelerometerBatchingAvailable',
      ),
      gyroscopeBatchingAvailable: _requiredBool(
        value,
        'gyroscopeBatchingAvailable',
      ),
      accelerometerAcceptedSampleCount: _requiredNonNegativeInt(
        value,
        'accelerometerAcceptedSampleCount',
      ),
      gyroscopeAcceptedSampleCount: _requiredNonNegativeInt(
        value,
        'gyroscopeAcceptedSampleCount',
      ),
      rejectedSampleCount: _requiredNonNegativeInt(
        value,
        'rejectedSampleCount',
      ),
      unreliableAccuracySampleCount: _requiredNonNegativeInt(
        value,
        'unreliableAccuracySampleCount',
      ),
      clockDiscontinuityCount: _requiredNonNegativeInt(
        value,
        'clockDiscontinuityCount',
      ),
      dropoutCount: _requiredNonNegativeInt(value, 'dropoutCount'),
      accuracyChangeCount: _requiredNonNegativeInt(
        value,
        'accuracyChangeCount',
      ),
      registrationFailureCount: _requiredNonNegativeInt(
        value,
        'registrationFailureCount',
      ),
      errorCode: _nullableErrorCode(value, 'errorCode'),
    );
  }

  final int contractVersion;
  final String state;
  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;
  final bool accelerometerBatchingAvailable;
  final bool gyroscopeBatchingAvailable;
  final int accelerometerAcceptedSampleCount;
  final int gyroscopeAcceptedSampleCount;
  final int rejectedSampleCount;
  final int unreliableAccuracySampleCount;
  final int clockDiscontinuityCount;
  final int dropoutCount;
  final int accuracyChangeCount;
  final int registrationFailureCount;
  final String? errorCode;
}

class RecorderBufferHealth {
  const RecorderBufferHealth({
    required this.contractVersion,
    required this.state,
    required this.queueCapacity,
    required this.reorderBufferCapacity,
    required this.queueDepth,
    required this.bufferedSampleCount,
    required this.completedChunkCount,
    required this.persistedGnssSampleCount,
    required this.persistedAccelerometerSampleCount,
    required this.persistedGyroscopeSampleCount,
    required this.persistedByteCount,
    required this.recoveredValidChunkCount,
    required this.corruptChunkCount,
    required this.orphanedWriteCount,
    required this.orderingViolationCount,
    required this.overflowCount,
    required this.invalidTripTimeCount,
    required this.lateSampleCount,
    required this.writeFailureCount,
    required this.lastCompletedSequence,
    required this.hasCommittedElapsedBoundary,
    required this.errorCode,
  });

  factory RecorderBufferHealth.fromMap(Map<Object?, Object?> value) {
    return RecorderBufferHealth(
      contractVersion: _requiredPositiveInt(value, 'contractVersion'),
      state: _requiredString(value, 'state'),
      queueCapacity: _requiredPositiveInt(value, 'queueCapacity'),
      reorderBufferCapacity: _requiredPositiveInt(
        value,
        'reorderBufferCapacity',
      ),
      queueDepth: _requiredNonNegativeInt(value, 'queueDepth'),
      bufferedSampleCount: _requiredNonNegativeInt(
        value,
        'bufferedSampleCount',
      ),
      completedChunkCount: _requiredNonNegativeInt(
        value,
        'completedChunkCount',
      ),
      persistedGnssSampleCount: _requiredNonNegativeInt(
        value,
        'persistedGnssSampleCount',
      ),
      persistedAccelerometerSampleCount: _requiredNonNegativeInt(
        value,
        'persistedAccelerometerSampleCount',
      ),
      persistedGyroscopeSampleCount: _requiredNonNegativeInt(
        value,
        'persistedGyroscopeSampleCount',
      ),
      persistedByteCount: _requiredNonNegativeInt(value, 'persistedByteCount'),
      recoveredValidChunkCount: _requiredNonNegativeInt(
        value,
        'recoveredValidChunkCount',
      ),
      corruptChunkCount: _requiredNonNegativeInt(value, 'corruptChunkCount'),
      orphanedWriteCount: _requiredNonNegativeInt(value, 'orphanedWriteCount'),
      orderingViolationCount: _requiredNonNegativeInt(
        value,
        'orderingViolationCount',
      ),
      overflowCount: _requiredNonNegativeInt(value, 'overflowCount'),
      invalidTripTimeCount: _requiredNonNegativeInt(
        value,
        'invalidTripTimeCount',
      ),
      lateSampleCount: _requiredNonNegativeInt(value, 'lateSampleCount'),
      writeFailureCount: _requiredNonNegativeInt(value, 'writeFailureCount'),
      lastCompletedSequence: _nullableNonNegativeInt(
        value,
        'lastCompletedSequence',
      ),
      hasCommittedElapsedBoundary: _requiredBool(
        value,
        'hasCommittedElapsedBoundary',
      ),
      errorCode: _nullableErrorCode(value, 'errorCode'),
    );
  }

  final int contractVersion;
  final String state;
  final int queueCapacity;
  final int reorderBufferCapacity;
  final int queueDepth;
  final int bufferedSampleCount;
  final int completedChunkCount;
  final int persistedGnssSampleCount;
  final int persistedAccelerometerSampleCount;
  final int persistedGyroscopeSampleCount;
  final int persistedByteCount;
  final int recoveredValidChunkCount;
  final int corruptChunkCount;
  final int orphanedWriteCount;
  final int orderingViolationCount;
  final int overflowCount;
  final int invalidTripTimeCount;
  final int lateSampleCount;
  final int writeFailureCount;
  final int? lastCompletedSequence;
  final bool hasCommittedElapsedBoundary;
  final String? errorCode;
}

class RecorderStatus {
  const RecorderStatus({
    required this.contractVersion,
    required this.bridgeVersion,
    required this.lifecycle,
    required this.gnss,
    required this.imu,
    required this.buffer,
  });

  factory RecorderStatus.fromMap(Map<Object?, Object?> value) {
    final status = RecorderStatus(
      contractVersion: _requiredPositiveInt(value, 'contractVersion'),
      bridgeVersion: _requiredPositiveInt(value, 'bridgeVersion'),
      lifecycle: RecorderLifecycleStatus.fromMap(
        _requiredMap(value, 'lifecycle'),
      ),
      gnss: RecorderGnssHealth.fromMap(_requiredMap(value, 'gnss')),
      imu: RecorderImuHealth.fromMap(_requiredMap(value, 'imu')),
      buffer: RecorderBufferHealth.fromMap(_requiredMap(value, 'buffer')),
    );
    if (status.bridgeVersion != RecorderBridge.supportedBridgeVersion ||
        status.contractVersion !=
            RecorderBridge.supportedStatusContractVersion ||
        status.lifecycle.contractVersion != 1 ||
        status.gnss.contractVersion != 1 ||
        status.imu.contractVersion != 1 ||
        status.buffer.contractVersion != 1) {
      throw const FormatException(
        'Unsupported recorder bridge contract version.',
      );
    }
    return status;
  }

  final int contractVersion;
  final int bridgeVersion;
  final RecorderLifecycleStatus lifecycle;
  final RecorderGnssHealth gnss;
  final RecorderImuHealth imu;
  final RecorderBufferHealth buffer;
}

class RecorderBridge {
  const RecorderBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'io.github.atrx07.traelyx/recorder/v1';
  static const supportedBridgeVersion = 1;
  static const supportedStatusContractVersion = 1;

  final MethodChannel _channel;

  Future<RecorderCapabilities> getCapabilities() async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'getCapabilities',
    );
    if (value == null) {
      throw const FormatException('Recorder bridge returned no capabilities.');
    }
    return RecorderCapabilities.fromMap(value);
  }

  Future<RecorderStatus> getStatus() => _invokeStatus('getStatus');

  Future<RecorderStatus> startTrip() => _invokeStatus('startTrip');

  Future<RecorderStatus> stopTrip() => _invokeStatus('stopTrip');

  Future<RecorderStatus> recoverTrip() => _invokeStatus('recoverTrip');

  Future<RecorderStatus> _invokeStatus(String method) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(method);
    if (value == null) {
      throw FormatException('Recorder bridge returned no status for $method.');
    }
    return RecorderStatus.fromMap(value);
  }
}

Map<Object?, Object?> _requiredMap(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw is Map<Object?, Object?>) return raw;
  throw FormatException('Recorder status field $key must be a map.');
}

int _optionalInt(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  return raw is int && raw >= 0 ? raw : 0;
}

String _optionalString(
  Map<Object?, Object?> value,
  String key, {
  required String fallback,
}) {
  final raw = value[key];
  return raw is String && raw.isNotEmpty ? raw : fallback;
}

bool _optionalBool(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  return raw is bool ? raw : false;
}

int _requiredPositiveInt(Map<Object?, Object?> value, String key) {
  final parsed = _requiredInt(value, key);
  if (parsed <= 0) {
    throw FormatException('Recorder status field $key must be positive.');
  }
  return parsed;
}

int _requiredNonNegativeInt(Map<Object?, Object?> value, String key) {
  final parsed = _requiredInt(value, key);
  if (parsed < 0) {
    throw FormatException('Recorder status field $key must be non-negative.');
  }
  return parsed;
}

int? _nullableNonNegativeInt(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw == null) return null;
  if (raw is int && raw >= 0) return raw;
  throw FormatException(
    'Recorder status field $key must be null or non-negative.',
  );
}

int _requiredInt(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw is int) return raw;
  throw FormatException('Recorder status field $key must be an integer.');
}

String _requiredString(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw is String && raw.isNotEmpty) return raw;
  throw FormatException(
    'Recorder status field $key must be a non-empty string.',
  );
}

String? _nullableString(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw == null || raw is String) return raw as String?;
  throw FormatException('Recorder status field $key must be null or a string.');
}

String? _nullableErrorCode(Map<Object?, Object?> value, String key) {
  final parsed = _nullableString(value, key);
  if (parsed == null || RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(parsed)) {
    return parsed;
  }
  throw FormatException(
    'Recorder status field $key is not an allowlisted error code.',
  );
}

bool _requiredBool(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw is bool) return raw;
  throw FormatException('Recorder status field $key must be a boolean.');
}
