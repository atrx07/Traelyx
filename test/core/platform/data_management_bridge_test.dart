import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/platform/data_management_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(DataManagementBridge.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('raw deletion result rejects unsafe or inconsistent evidence', () {
    expect(
      () => RawTelemetryDeletionResult.fromMap(const {
        'contractVersion': 1,
        'tripId': tripId,
        'deleted': true,
        'bytesDeleted': 2048,
        'errorCode': null,
      }),
      returnsNormally,
    );
    expect(
      () => RawTelemetryDeletionResult.fromMap(const {
        'contractVersion': 1,
        'tripId': tripId,
        'deleted': true,
        'bytesDeleted': -1,
        'errorCode': null,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RawTelemetryDeletionResult.fromMap(const {
        'contractVersion': 1,
        'tripId': tripId,
        'deleted': true,
        'bytesDeleted': 1,
        'errorCode': null,
        'unexpected': true,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RawTelemetryDeletionResult.fromMap(const {
        'contractVersion': 1,
        'tripId': tripId,
        'deleted': false,
        'bytesDeleted': 1,
        'errorCode': 'raw_delete_failed',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('redacted payload is bounded and omits identifying fields', () {
    final map = payload.toMap();

    expect(map.keys, {
      'durationMillis',
      'distanceMeters',
      'completionState',
      'recoveryState',
      'integrityState',
      'telemetrySchemaVersion',
      'eventCount',
      'overallScore',
      'scoreEligibility',
      'scoringVersion',
    });
    expect(map, isNot(contains('tripId')));
    expect(map, isNot(contains('startedAt')));
    expect(map, isNot(contains('vehicle')));
    expect(map, isNot(contains('route')));
    expect(map, isNot(contains('rawTelemetry')));
  });

  test('redacted payload rejects partial scores and unknown states', () {
    expect(
      () => const RedactedTripExportPayload(
        durationMillis: 1000,
        distanceMeters: 25,
        completionState: 'verified',
        recoveryState: 'verified',
        integrityState: 'verified',
        telemetrySchemaVersion: 1,
        eventCount: 0,
        overallScore: 80,
        scoreEligibility: null,
        scoringVersion: null,
      ).toMap(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => const RedactedTripExportPayload(
        durationMillis: 1000,
        distanceMeters: 25,
        completionState: 'complete',
        recoveryState: 'verified',
        integrityState: 'verified',
        telemetrySchemaVersion: 1,
        eventCount: 0,
        overallScore: null,
        scoreEligibility: null,
        scoringVersion: null,
      ).toMap(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'bridge sends an exact trip id and validates the native response',
    () async {
      MethodCall? observed;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            observed = call;
            return const <Object?, Object?>{
              'contractVersion': 1,
              'tripId': tripId,
              'deleted': true,
              'bytesDeleted': 2048,
              'errorCode': null,
            };
          });

      final result = await const DataManagementBridge().deleteRawTelemetry(
        tripId,
      );

      expect(observed?.method, 'deleteRawTelemetry');
      expect(observed?.arguments, {'tripId': tripId});
      expect(result.deleted, isTrue);
      expect(result.bytesDeleted, 2048);
    },
  );

  test('bridge exports only the validated redacted payload', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          observed = call;
          return const <Object?, Object?>{
            'contractVersion': 1,
            'formatVersion': 1,
            'exported': true,
            'containsPreciseLocation': false,
            'containsRawTelemetry': false,
            'privacyClass': 'redacted_summary',
            'byteLength': 420,
            'errorCode': null,
          };
        });

    final result = await const DataManagementBridge().exportRedactedTripSummary(
      payload,
    );

    expect(observed?.method, 'exportRedactedTripSummary');
    expect(observed?.arguments, payload.toMap());
    expect(result.exported, isTrue);
    expect(result.byteLength, 420);
  });
}

const tripId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

const payload = RedactedTripExportPayload(
  durationMillis: 90000,
  distanceMeters: 1450,
  completionState: 'verified',
  recoveryState: 'verified',
  integrityState: 'limited',
  telemetrySchemaVersion: 1,
  eventCount: 2,
  overallScore: 81,
  scoreEligibility: 'verified',
  scoringVersion: 'scoring-v1',
);
