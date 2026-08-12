import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';

import 'recorder_bridge_test.dart' show finalizationBatchMap, tripId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('recorder-finalization-test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('acknowledges native handoff only after repository commit', () async {
    final calls = <String>[];
    final repository = _FakeRepository(calls);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'getPendingFinalizations') {
            return finalizationBatchMap;
          }
          return <Object?, Object?>{
            'contractVersion': 1,
            'tripId': tripId,
            'acknowledged': true,
            'errorCode': null,
          };
        });
    final reconciler = RecorderFinalizationReconciler(
      bridge: const RecorderBridge(channel: channel),
      repository: repository,
    );

    final result = await reconciler.reconcilePending();

    expect(result.reconciledTripIds, [tripId]);
    expect(calls, [
      'getPendingFinalizations',
      'repository:$tripId',
      'acknowledgeTripFinalization',
    ]);
  });

  test('repository failure leaves native handoff unacknowledged', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return finalizationBatchMap;
        });
    final reconciler = RecorderFinalizationReconciler(
      bridge: const RecorderBridge(channel: channel),
      repository: _FakeRepository(calls, fail: true),
    );

    await expectLater(reconciler.reconcilePending(), throwsStateError);

    expect(calls, ['getPendingFinalizations', 'repository:$tripId']);
  });

  test('invalid native metadata fails before any reconciliation', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return const <Object?, Object?>{
            'contractVersion': 1,
            'invalidRecordCount': 1,
            'finalizations': <Object?>[],
          };
        });
    final reconciler = RecorderFinalizationReconciler(
      bridge: const RecorderBridge(channel: channel),
      repository: _FakeRepository(calls),
    );

    await expectLater(reconciler.reconcilePending(), throwsStateError);

    expect(calls, ['getPendingFinalizations']);
  });

  test(
    'default stop polling tolerates a handoff beyond five seconds',
    () async {
      var polls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getPendingFinalizations') {
              polls += 1;
              if (polls <= 60) {
                return const <Object?, Object?>{
                  'contractVersion': 1,
                  'invalidRecordCount': 0,
                  'finalizations': <Object?>[],
                };
              }
              return finalizationBatchMap;
            }
            return <Object?, Object?>{
              'contractVersion': 1,
              'tripId': tripId,
              'acknowledged': true,
              'errorCode': null,
            };
          });
      final reconciler = RecorderFinalizationReconciler(
        bridge: const RecorderBridge(channel: channel),
        repository: _FakeRepository(<String>[]),
        delay: (_) async {},
      );

      final result = await reconciler.reconcileAfterStop(tripId);

      expect(result.reconciledTripIds, [tripId]);
      expect(polls, 61);
    },
  );
}

class _FakeRepository implements RecorderFinalizationRepository {
  _FakeRepository(this.calls, {this.fail = false});

  final List<String> calls;
  final bool fail;

  @override
  Future<void> reconcile(RecorderTripFinalization finalization) async {
    calls.add('repository:${finalization.tripId}');
    if (fail) throw StateError('database failure');
  }
}
