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

enum RecorderPermissionState {
  granted('granted'),
  approximateOnly('approximate_only'),
  requestable('requestable'),
  settingsRequired('settings_required'),
  notRequired('not_required');

  const RecorderPermissionState(this.wireName);

  final String wireName;

  static RecorderPermissionState parse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    throw FormatException('Unknown recorder permission state: $value.');
  }
}

class RecorderPermissionStatus {
  const RecorderPermissionStatus({
    required this.contractVersion,
    required this.platformApiLevel,
    required this.locationState,
    required this.notificationState,
    required this.fineLocationGranted,
    required this.coarseLocationGranted,
    required this.gpsProviderEnabled,
    required this.canRequestLocation,
    required this.canRequestNotification,
    required this.backgroundLocationRequired,
    required this.recordingReady,
    required this.foregroundNotificationVisible,
  });

  factory RecorderPermissionStatus.fromMap(Map<Object?, Object?> value) {
    final contractVersion = _requiredPositiveInt(value, 'contractVersion');
    if (contractVersion != RecorderBridge.supportedPermissionContractVersion) {
      throw const FormatException(
        'Unsupported recorder permission contract version.',
      );
    }
    return RecorderPermissionStatus(
      contractVersion: contractVersion,
      platformApiLevel: _requiredPositiveInt(value, 'platformApiLevel'),
      locationState: RecorderPermissionState.parse(
        _requiredString(value, 'locationState'),
      ),
      notificationState: RecorderPermissionState.parse(
        _requiredString(value, 'notificationState'),
      ),
      fineLocationGranted: _requiredBool(value, 'fineLocationGranted'),
      coarseLocationGranted: _requiredBool(value, 'coarseLocationGranted'),
      gpsProviderEnabled: _requiredBool(value, 'gpsProviderEnabled'),
      canRequestLocation: _requiredBool(value, 'canRequestLocation'),
      canRequestNotification: _requiredBool(value, 'canRequestNotification'),
      backgroundLocationRequired: _requiredBool(
        value,
        'backgroundLocationRequired',
      ),
      recordingReady: _requiredBool(value, 'recordingReady'),
      foregroundNotificationVisible: _requiredBool(
        value,
        'foregroundNotificationVisible',
      ),
    );
  }

  final int contractVersion;
  final int platformApiLevel;
  final RecorderPermissionState locationState;
  final RecorderPermissionState notificationState;
  final bool fineLocationGranted;
  final bool coarseLocationGranted;
  final bool gpsProviderEnabled;
  final bool canRequestLocation;
  final bool canRequestNotification;
  final bool backgroundLocationRequired;
  final bool recordingReady;
  final bool foregroundNotificationVisible;
}

class RecorderFinalizedChunk {
  const RecorderFinalizedChunk({
    required this.sequence,
    required this.storageReference,
    required this.encodingVersion,
    required this.telemetrySchemaVersion,
    required this.startElapsedNanos,
    required this.endElapsedNanos,
    required this.gnssSampleCount,
    required this.accelerometerSampleCount,
    required this.gyroscopeSampleCount,
    required this.compression,
    required this.atomicWriteStrategy,
    required this.checksumAlgorithm,
    required this.checksum,
    required this.byteLength,
    required this.createdAtUtcEpochMillis,
  });

  factory RecorderFinalizedChunk.fromMap(
    Map<Object?, Object?> value,
    String tripId,
  ) {
    final sequence = _requiredNonNegativeInt(value, 'sequence');
    final storageReference = _requiredString(value, 'storageReference');
    final expectedReference =
        'recorder/trips/$tripId/chunks/${sequence.toString().padLeft(10, '0')}.tlxc';
    if (storageReference != expectedReference) {
      throw const FormatException(
        'Recorder chunk storage reference is invalid.',
      );
    }
    final startElapsedNanos = _requiredNonNegativeInt(
      value,
      'startElapsedNanos',
    );
    final endElapsedNanos = _requiredNonNegativeInt(value, 'endElapsedNanos');
    if (endElapsedNanos < startElapsedNanos) {
      throw const FormatException('Recorder chunk elapsed range is invalid.');
    }
    final checksum = _requiredString(value, 'checksum');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum)) {
      throw const FormatException('Recorder chunk checksum is invalid.');
    }
    final gnssSampleCount = _requiredNonNegativeInt(value, 'gnssSampleCount');
    final accelerometerSampleCount = _requiredNonNegativeInt(
      value,
      'accelerometerSampleCount',
    );
    final gyroscopeSampleCount = _requiredNonNegativeInt(
      value,
      'gyroscopeSampleCount',
    );
    final totalSampleCount =
        gnssSampleCount + accelerometerSampleCount + gyroscopeSampleCount;
    if (totalSampleCount <= 0 || totalSampleCount > 256) {
      throw const FormatException('Recorder chunk sample count is invalid.');
    }
    return RecorderFinalizedChunk(
      sequence: sequence,
      storageReference: storageReference,
      encodingVersion: _requiredPositiveInt(value, 'encodingVersion'),
      telemetrySchemaVersion: _requiredPositiveInt(
        value,
        'telemetrySchemaVersion',
      ),
      startElapsedNanos: startElapsedNanos,
      endElapsedNanos: endElapsedNanos,
      gnssSampleCount: gnssSampleCount,
      accelerometerSampleCount: accelerometerSampleCount,
      gyroscopeSampleCount: gyroscopeSampleCount,
      compression: _requiredString(value, 'compression'),
      atomicWriteStrategy: _requiredString(value, 'atomicWriteStrategy'),
      checksumAlgorithm: _requiredString(value, 'checksumAlgorithm'),
      checksum: checksum,
      byteLength: _requiredPositiveInt(value, 'byteLength'),
      createdAtUtcEpochMillis: _requiredPositiveInt(
        value,
        'createdAtUtcEpochMillis',
      ),
    );
  }

  final int sequence;
  final String storageReference;
  final int encodingVersion;
  final int telemetrySchemaVersion;
  final int startElapsedNanos;
  final int endElapsedNanos;
  final int gnssSampleCount;
  final int accelerometerSampleCount;
  final int gyroscopeSampleCount;
  final String compression;
  final String atomicWriteStrategy;
  final String checksumAlgorithm;
  final String checksum;
  final int byteLength;
  final int createdAtUtcEpochMillis;
}

class RecorderTripFinalization {
  const RecorderTripFinalization({
    required this.contractVersion,
    required this.finalizationLogicVersion,
    required this.tripId,
    required this.startedAtUtcEpochMillis,
    required this.startedAtElapsedRealtimeNanos,
    required this.stoppedAtUtcEpochMillis,
    required this.endElapsedRealtimeNanos,
    required this.durationMillis,
    required this.completionState,
    required this.recoveryState,
    required this.integrityStatus,
    required this.recoveryCount,
    required this.qualityFlags,
    required this.corruptChunkCount,
    required this.orphanedWriteCount,
    required this.orderingViolationCount,
    required this.chunks,
  });

  factory RecorderTripFinalization.fromMap(Map<Object?, Object?> value) {
    final contractVersion = _requiredPositiveInt(value, 'contractVersion');
    final logicVersion = _requiredPositiveInt(
      value,
      'finalizationLogicVersion',
    );
    if (contractVersion !=
            RecorderBridge.supportedFinalizationContractVersion ||
        logicVersion != RecorderBridge.supportedFinalizationLogicVersion) {
      throw const FormatException(
        'Unsupported recorder finalization contract version.',
      );
    }
    final tripId = _requiredUuid(value, 'tripId');
    final startedAtWall = _requiredPositiveInt(
      value,
      'startedAtUtcEpochMillis',
    );
    final stoppedAtWall = _requiredPositiveInt(
      value,
      'stoppedAtUtcEpochMillis',
    );
    if (stoppedAtWall < startedAtWall) {
      throw const FormatException(
        'Recorder finalization wall-time range is invalid.',
      );
    }
    final completionState = _requiredEnumString(
      value,
      'completionState',
      const {'completed', 'incomplete'},
    );
    final recoveryState = _requiredEnumString(value, 'recoveryState', const {
      'not_needed',
      'recovered',
    });
    final integrityStatus = _requiredEnumString(
      value,
      'integrityStatus',
      const {'unassessed', 'review_required'},
    );
    final qualityFlags = _requiredStringList(value, 'qualityFlags');
    const allowedQualityFlags = {
      'no_valid_chunks',
      'corrupt_chunks_isolated',
      'orphaned_writes_isolated',
      'chunk_ordering_violation',
      'recorder_recovered',
      'recorder_error',
      'wall_clock_regression',
      'elapsed_time_overflow',
    };
    if (!allowedQualityFlags.containsAll(qualityFlags)) {
      throw const FormatException(
        'Recorder finalization contains an unknown quality flag.',
      );
    }
    final chunks = _requiredMapList(value, 'chunks')
        .map((chunk) => RecorderFinalizedChunk.fromMap(chunk, tripId))
        .toList(growable: false);
    for (var index = 1; index < chunks.length; index += 1) {
      if (chunks[index].sequence <= chunks[index - 1].sequence ||
          chunks[index].startElapsedNanos < chunks[index - 1].endElapsedNanos) {
        throw const FormatException(
          'Recorder finalization chunk order is invalid.',
        );
      }
    }
    final endElapsedRealtimeNanos = _nullableNonNegativeInt(
      value,
      'endElapsedRealtimeNanos',
    );
    final durationMillis = _nullableNonNegativeInt(value, 'durationMillis');
    final recoveryCount = _requiredNonNegativeInt(value, 'recoveryCount');
    final corruptChunkCount = _requiredNonNegativeInt(
      value,
      'corruptChunkCount',
    );
    final orphanedWriteCount = _requiredNonNegativeInt(
      value,
      'orphanedWriteCount',
    );
    final orderingViolationCount = _requiredNonNegativeInt(
      value,
      'orderingViolationCount',
    );
    if ((recoveryCount > 0) != (recoveryState == 'recovered') ||
        (recoveryCount > 0) != qualityFlags.contains('recorder_recovered') ||
        chunks.isEmpty != qualityFlags.contains('no_valid_chunks') ||
        (corruptChunkCount > 0) !=
            qualityFlags.contains('corrupt_chunks_isolated') ||
        (orphanedWriteCount > 0) !=
            qualityFlags.contains('orphaned_writes_isolated') ||
        (orderingViolationCount > 0) !=
            qualityFlags.contains('chunk_ordering_violation')) {
      throw const FormatException(
        'Recorder finalization quality evidence is inconsistent.',
      );
    }
    final hasIncompleteEvidence = qualityFlags.any(
      (flag) => flag != 'recorder_recovered',
    );
    if ((completionState == 'incomplete') != hasIncompleteEvidence ||
        (integrityStatus == 'review_required') != hasIncompleteEvidence) {
      throw const FormatException(
        'Recorder finalization state is inconsistent with quality evidence.',
      );
    }
    if (chunks.isEmpty) {
      if (completionState == 'completed' ||
          endElapsedRealtimeNanos != null ||
          durationMillis != null) {
        throw const FormatException(
          'Recorder finalization without chunks must remain incomplete.',
        );
      }
    } else {
      final expectedEndElapsed =
          _requiredNonNegativeInt(value, 'startedAtElapsedRealtimeNanos') +
          chunks.last.endElapsedNanos;
      final elapsedOverflow = qualityFlags.contains('elapsed_time_overflow');
      if ((elapsedOverflow
              ? endElapsedRealtimeNanos != null
              : endElapsedRealtimeNanos != expectedEndElapsed) ||
          durationMillis != chunks.last.endElapsedNanos ~/ 1000000) {
        throw const FormatException(
          'Recorder finalization elapsed summary is inconsistent.',
        );
      }
    }
    return RecorderTripFinalization(
      contractVersion: contractVersion,
      finalizationLogicVersion: logicVersion,
      tripId: tripId,
      startedAtUtcEpochMillis: startedAtWall,
      startedAtElapsedRealtimeNanos: _requiredNonNegativeInt(
        value,
        'startedAtElapsedRealtimeNanos',
      ),
      stoppedAtUtcEpochMillis: stoppedAtWall,
      endElapsedRealtimeNanos: endElapsedRealtimeNanos,
      durationMillis: durationMillis,
      completionState: completionState,
      recoveryState: recoveryState,
      integrityStatus: integrityStatus,
      recoveryCount: recoveryCount,
      qualityFlags: qualityFlags,
      corruptChunkCount: corruptChunkCount,
      orphanedWriteCount: orphanedWriteCount,
      orderingViolationCount: orderingViolationCount,
      chunks: chunks,
    );
  }

  final int contractVersion;
  final int finalizationLogicVersion;
  final String tripId;
  final int startedAtUtcEpochMillis;
  final int startedAtElapsedRealtimeNanos;
  final int stoppedAtUtcEpochMillis;
  final int? endElapsedRealtimeNanos;
  final int? durationMillis;
  final String completionState;
  final String recoveryState;
  final String integrityStatus;
  final int recoveryCount;
  final List<String> qualityFlags;
  final int corruptChunkCount;
  final int orphanedWriteCount;
  final int orderingViolationCount;
  final List<RecorderFinalizedChunk> chunks;
}

class RecorderFinalizationBatch {
  const RecorderFinalizationBatch({
    required this.contractVersion,
    required this.invalidRecordCount,
    required this.finalizations,
  });

  factory RecorderFinalizationBatch.fromMap(Map<Object?, Object?> value) {
    final contractVersion = _requiredPositiveInt(value, 'contractVersion');
    if (contractVersion !=
        RecorderBridge.supportedFinalizationContractVersion) {
      throw const FormatException(
        'Unsupported recorder finalization batch contract version.',
      );
    }
    final finalizations = _requiredMapList(
      value,
      'finalizations',
    ).map(RecorderTripFinalization.fromMap).toList(growable: false);
    if (finalizations.map((item) => item.tripId).toSet().length !=
        finalizations.length) {
      throw const FormatException(
        'Recorder finalization batch contains duplicates.',
      );
    }
    return RecorderFinalizationBatch(
      contractVersion: contractVersion,
      invalidRecordCount: _requiredNonNegativeInt(value, 'invalidRecordCount'),
      finalizations: finalizations,
    );
  }

  final int contractVersion;
  final int invalidRecordCount;
  final List<RecorderTripFinalization> finalizations;
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
  static const supportedPermissionContractVersion = 1;
  static const supportedFinalizationContractVersion = 1;
  static const supportedFinalizationLogicVersion = 1;

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

  Future<RecorderPermissionStatus> getPermissionStatus() =>
      _invokePermissionStatus('getPermissionStatus');

  Future<RecorderPermissionStatus> requestLocationPermission() =>
      _invokePermissionStatus('requestLocationPermission');

  Future<RecorderPermissionStatus> requestNotificationPermission() =>
      _invokePermissionStatus('requestNotificationPermission');

  Future<RecorderPermissionStatus> openAppSettings() =>
      _invokePermissionStatus('openAppSettings');

  Future<RecorderPermissionStatus> openLocationSettings() =>
      _invokePermissionStatus('openLocationSettings');

  Future<RecorderStatus> startTrip() => _invokeStatus('startTrip');

  Future<RecorderStatus> stopTrip() => _invokeStatus('stopTrip');

  Future<RecorderStatus> recoverTrip() => _invokeStatus('recoverTrip');

  Future<RecorderFinalizationBatch> getPendingFinalizations() async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'getPendingFinalizations',
    );
    if (value == null) {
      throw const FormatException(
        'Recorder bridge returned no pending-finalization batch.',
      );
    }
    return RecorderFinalizationBatch.fromMap(value);
  }

  Future<void> acknowledgeTripFinalization(String tripId) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'acknowledgeTripFinalization',
      {'tripId': tripId},
    );
    if (value == null ||
        _requiredPositiveInt(value, 'contractVersion') !=
            supportedFinalizationContractVersion ||
        _requiredUuid(value, 'tripId') != tripId ||
        !_requiredBool(value, 'acknowledged')) {
      throw const FormatException(
        'Recorder bridge did not acknowledge trip finalization.',
      );
    }
    final errorCode = _nullableErrorCode(value, 'errorCode');
    if (errorCode != null) {
      throw FormatException(
        'Recorder finalization acknowledgement: $errorCode.',
      );
    }
  }

  Future<RecorderStatus> _invokeStatus(String method) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(method);
    if (value == null) {
      throw FormatException('Recorder bridge returned no status for $method.');
    }
    return RecorderStatus.fromMap(value);
  }

  Future<RecorderPermissionStatus> _invokePermissionStatus(
    String method,
  ) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(method);
    if (value == null) {
      throw FormatException(
        'Recorder bridge returned no permission status for $method.',
      );
    }
    return RecorderPermissionStatus.fromMap(value);
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

String _requiredUuid(Map<Object?, Object?> value, String key) {
  final parsed = _requiredString(value, key);
  if (RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(parsed)) {
    return parsed;
  }
  throw FormatException('Recorder status field $key must be a UUID.');
}

String _requiredEnumString(
  Map<Object?, Object?> value,
  String key,
  Set<String> allowed,
) {
  final parsed = _requiredString(value, key);
  if (allowed.contains(parsed)) return parsed;
  throw FormatException('Recorder status field $key is not allowlisted.');
}

List<Map<Object?, Object?>> _requiredMapList(
  Map<Object?, Object?> value,
  String key,
) {
  final raw = value[key];
  if (raw is! List<Object?>) {
    throw FormatException('Recorder status field $key must be a list.');
  }
  return raw
      .map((item) {
        if (item is Map<Object?, Object?>) return item;
        throw FormatException('Recorder status field $key must contain maps.');
      })
      .toList(growable: false);
}

List<String> _requiredStringList(Map<Object?, Object?> value, String key) {
  final raw = value[key];
  if (raw is! List<Object?>) {
    throw FormatException('Recorder status field $key must be a list.');
  }
  final parsed = raw
      .map((item) {
        if (item is String && RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(item)) {
          return item;
        }
        throw FormatException(
          'Recorder status field $key contains an invalid label.',
        );
      })
      .toList(growable: false);
  if (parsed.toSet().length != parsed.length) {
    throw FormatException('Recorder status field $key contains duplicates.');
  }
  return parsed;
}
