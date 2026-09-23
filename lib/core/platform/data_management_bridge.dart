import 'package:flutter/services.dart';

class RawTelemetryDeletionResult {
  const RawTelemetryDeletionResult({
    required this.tripId,
    required this.deleted,
    required this.bytesDeleted,
    required this.errorCode,
  });

  factory RawTelemetryDeletionResult.fromMap(Map<Object?, Object?> value) {
    if (value.keys.toSet().difference(_rawDeletionResultKeys).isNotEmpty ||
        _rawDeletionResultKeys.difference(value.keys.toSet()).isNotEmpty ||
        _requiredInt(value, 'contractVersion') != 1) {
      throw const FormatException('Unsupported data-management contract.');
    }
    final result = RawTelemetryDeletionResult(
      tripId: _requiredUuid(value, 'tripId'),
      deleted: _requiredBool(value, 'deleted'),
      bytesDeleted: _requiredInt(value, 'bytesDeleted'),
      errorCode: _optionalError(value, 'errorCode'),
    );
    if (result.bytesDeleted < 0 ||
        (result.deleted && result.errorCode != null) ||
        (!result.deleted &&
            (result.errorCode == null || result.bytesDeleted != 0))) {
      throw const FormatException('Invalid raw-telemetry deletion result.');
    }
    return result;
  }

  final String tripId;
  final bool deleted;
  final int bytesDeleted;
  final String? errorCode;
}

class RedactedTripExportPayload {
  const RedactedTripExportPayload({
    required this.durationMillis,
    required this.distanceMeters,
    required this.completionState,
    required this.recoveryState,
    required this.integrityState,
    required this.telemetrySchemaVersion,
    required this.eventCount,
    required this.overallScore,
    required this.scoreEligibility,
    required this.scoringVersion,
  });

  final int? durationMillis;
  final double? distanceMeters;
  final String completionState;
  final String recoveryState;
  final String integrityState;
  final int telemetrySchemaVersion;
  final int eventCount;
  final double? overallScore;
  final String? scoreEligibility;
  final String? scoringVersion;

  Map<String, Object?> toMap() {
    final allowedStates = {
      'verified',
      'limited',
      'review_required',
      'unavailable',
      'not_assessed',
    };
    final scoreFields = [overallScore, scoreEligibility, scoringVersion];
    if ((durationMillis != null && durationMillis! < 0) ||
        (distanceMeters != null &&
            (!distanceMeters!.isFinite || distanceMeters! < 0)) ||
        !allowedStates.contains(completionState) ||
        !allowedStates.contains(recoveryState) ||
        !allowedStates.contains(integrityState) ||
        telemetrySchemaVersion <= 0 ||
        eventCount < 0 ||
        (overallScore != null &&
            (!overallScore!.isFinite ||
                overallScore! < 0 ||
                overallScore! > 100)) ||
        (scoreFields.any((field) => field != null) &&
            scoreFields.any((field) => field == null)) ||
        (scoreEligibility != null &&
            !allowedStates.contains(scoreEligibility)) ||
        (scoringVersion != null &&
            !RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(scoringVersion!))) {
      throw const FormatException('Invalid redacted-trip export payload.');
    }
    return {
      'durationMillis': durationMillis,
      'distanceMeters': distanceMeters,
      'completionState': completionState,
      'recoveryState': recoveryState,
      'integrityState': integrityState,
      'telemetrySchemaVersion': telemetrySchemaVersion,
      'eventCount': eventCount,
      'overallScore': overallScore,
      'scoreEligibility': scoreEligibility,
      'scoringVersion': scoringVersion,
    };
  }
}

class RedactedTripExportResult {
  const RedactedTripExportResult({
    required this.exported,
    required this.byteLength,
    required this.errorCode,
  });

  factory RedactedTripExportResult.fromMap(Map<Object?, Object?> value) {
    if (value.keys.toSet().difference(_redactedExportResultKeys).isNotEmpty ||
        _redactedExportResultKeys.difference(value.keys.toSet()).isNotEmpty ||
        _requiredInt(value, 'contractVersion') != 1 ||
        _requiredInt(value, 'formatVersion') != 1 ||
        _requiredBool(value, 'containsPreciseLocation') ||
        _requiredBool(value, 'containsRawTelemetry') ||
        _requiredString(value, 'privacyClass') != 'redacted_summary') {
      throw const FormatException('Unsupported redacted export contract.');
    }
    final result = RedactedTripExportResult(
      exported: _requiredBool(value, 'exported'),
      byteLength: _requiredInt(value, 'byteLength'),
      errorCode: _optionalError(value, 'errorCode'),
    );
    if (result.byteLength < 0 ||
        (result.exported &&
            (result.byteLength == 0 || result.errorCode != null)) ||
        (!result.exported && result.errorCode == null)) {
      throw const FormatException('Invalid redacted export result.');
    }
    return result;
  }

  final bool exported;
  final int byteLength;
  final String? errorCode;
}

abstract interface class DataManagementPlatform {
  Future<RawTelemetryDeletionResult> deleteRawTelemetry(String tripId);

  Future<RedactedTripExportResult> exportRedactedTripSummary(
    RedactedTripExportPayload payload,
  );
}

class DataManagementBridge implements DataManagementPlatform {
  const DataManagementBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'io.github.atrx07.traelyx/data_management/v1';

  final MethodChannel _channel;

  @override
  Future<RawTelemetryDeletionResult> deleteRawTelemetry(String tripId) async {
    _validateUuid(tripId);
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'deleteRawTelemetry',
      {'tripId': tripId},
    );
    if (value == null) {
      throw const FormatException('Data-management bridge returned no result.');
    }
    final result = RawTelemetryDeletionResult.fromMap(value);
    if (result.tripId != tripId) {
      throw const FormatException(
        'Data-management bridge returned wrong trip.',
      );
    }
    return result;
  }

  @override
  Future<RedactedTripExportResult> exportRedactedTripSummary(
    RedactedTripExportPayload payload,
  ) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'exportRedactedTripSummary',
      payload.toMap(),
    );
    if (value == null) {
      throw const FormatException('Data-management bridge returned no export.');
    }
    return RedactedTripExportResult.fromMap(value);
  }
}

int _requiredInt(Map<Object?, Object?> value, String key) {
  final field = value[key];
  if (field is int) return field;
  throw FormatException('Data-management field $key must be an integer.');
}

bool _requiredBool(Map<Object?, Object?> value, String key) {
  final field = value[key];
  if (field is bool) return field;
  throw FormatException('Data-management field $key must be a boolean.');
}

String _requiredString(Map<Object?, Object?> value, String key) {
  final field = value[key];
  if (field is String && field.isNotEmpty) return field;
  throw FormatException('Data-management field $key must be a string.');
}

String _requiredUuid(Map<Object?, Object?> value, String key) {
  final uuid = _requiredString(value, key);
  _validateUuid(uuid);
  return uuid;
}

void _validateUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    throw const FormatException('Trip ID must be a UUID.');
  }
}

String? _optionalError(Map<Object?, Object?> value, String key) {
  final field = value[key];
  if (field == null) return null;
  if (field is String && RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(field)) {
    return field;
  }
  throw FormatException('Data-management field $key is invalid.');
}

const _rawDeletionResultKeys = <Object?>{
  'contractVersion',
  'tripId',
  'deleted',
  'bytesDeleted',
  'errorCode',
};

const _redactedExportResultKeys = <Object?>{
  'contractVersion',
  'formatVersion',
  'exported',
  'containsPreciseLocation',
  'containsRawTelemetry',
  'privacyClass',
  'byteLength',
  'errorCode',
};
