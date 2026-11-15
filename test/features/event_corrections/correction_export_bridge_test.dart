import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/event_corrections/application/event_correction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('correction-test');
  const exporter = NativeCorrectionExporter(channel: channel);
  final payload = <String, Object?>{
    'format': 'traelyx_event_corrections',
    'formatVersion': 1,
    'consentVersion': 1,
    'consentPurpose': 'detection_research',
    'consentDeclared': true,
    'labelProvenance': 'user_report_unverified',
    'trainingUse': 'quarantine_only',
    'containsPreciseLocation': false,
    'containsRawTelemetry': false,
    'labels': [
      {
        'detectedEvent': 'EVT_ROAD_IMPACT',
        'reportedLabel': 'unsure',
        'eventEngineVersion': 1,
        'telemetrySchemaVersion': 1,
      },
    ],
  };
  Future<Object?> nativeAuthorization(Object? id) async {
    final response = await TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            MethodCall('authorizeContribution', id),
          ),
          null,
        );
    return channel.codec.decodeEnvelope(response!);
  }

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'validated categorical payload and success bind a strict export result',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'exportContribution');
            final envelope = call.arguments as Map;
            expect(
              envelope.keys,
              unorderedEquals(['authorizationId', 'payload']),
            );
            expect(envelope['payload'], payload);
            expect(
              await nativeAuthorization(envelope['authorizationId']),
              true,
            );
            return {
              'contractVersion': 1,
              'exported': true,
              'byteLength': 400,
              'errorCode': null,
            };
          });
      expect(
        (await exporter.export(payload, authorize: () async => true)).exported,
        true,
      );
    },
  );
  test(
    'cancellation is explicit and malformed or expanded responses fail closed',
    () async {
      final responses = [
        null,
        {
          'contractVersion': 1.0,
          'exported': true,
          'byteLength': 4,
          'errorCode': null,
        },
        {
          'contractVersion': 2,
          'exported': true,
          'byteLength': 4,
          'errorCode': null,
        },
        {
          'contractVersion': 1,
          'exported': true,
          'byteLength': 0,
          'errorCode': null,
        },
        {
          'contractVersion': 1,
          'exported': true,
          'byteLength': 4,
          'unexpected': null,
        },
        {
          'contractVersion': 1,
          'exported': false,
          'byteLength': 0,
          'errorCode': null,
        },
      ];
      for (final response in responses) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => response);
        await expectLater(
          exporter.export(payload, authorize: () async => true),
          throwsFormatException,
        );
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => {
              'contractVersion': 1,
              'exported': false,
              'byteLength': 0,
              'errorCode': 'export_cancelled',
            },
          );
      expect(
        (await exporter.export(payload, authorize: () async => true)).errorCode,
        'export_cancelled',
      );
    },
  );
  test(
    'authorization is one-use, request-bound and fails closed on errors',
    () async {
      for (final failAuthorization in [false, true]) {
        var calls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final id = (call.arguments as Map)['authorizationId'];
              expect(await nativeAuthorization('wrong'), false);
              expect(await nativeAuthorization(id), !failAuthorization);
              expect(await nativeAuthorization(id), false);
              return {
                'contractVersion': 1,
                'exported': false,
                'byteLength': 0,
                'errorCode': 'export_authorization_failed',
              };
            });
        await exporter.export(
          payload,
          authorize: () async {
            calls++;
            if (failAuthorization) throw StateError('closed database');
            return true;
          },
        );
        expect(calls, 1);
      }
    },
  );
  test(
    'concurrent exporter cannot replace a pending authorization handler',
    () async {
      final pending = Completer<void>();
      final started = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            started.complete();
            await pending.future;
            expect(
              await nativeAuthorization(
                (call.arguments as Map)['authorizationId'],
              ),
              true,
            );
            return {
              'contractVersion': 1,
              'exported': true,
              'byteLength': 400,
              'errorCode': null,
            };
          });
      final result = exporter.export(payload, authorize: () async => true);
      await started.future;
      await expectLater(
        exporter.export(payload, authorize: () async => true),
        throwsStateError,
      );
      pending.complete();
      expect((await result).exported, true);
    },
  );
  test(
    'unconsented or privacy-expanded data never reaches native export',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => fail('unsafe payload reached native'),
          );
      await expectLater(
        exporter.export({
          ...payload,
          'tripId': 'private',
        }, authorize: () async => true),
        throwsFormatException,
      );
      await expectLater(
        exporter.export({
          ...payload,
          'consentDeclared': false,
        }, authorize: () async => true),
        throwsFormatException,
      );
    },
  );
}
