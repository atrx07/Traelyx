import 'dart:async';

import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';

class RecorderFinalizationSyncResult {
  const RecorderFinalizationSyncResult({
    required this.reconciledTripIds,
    required this.invalidNativeRecordCount,
  });

  final List<String> reconciledTripIds;
  final int invalidNativeRecordCount;
}

class RecorderFinalizationReconciler {
  const RecorderFinalizationReconciler({
    required RecorderBridge bridge,
    required RecorderFinalizationRepository repository,
    Future<void> Function(Duration) delay = Future<void>.delayed,
    int stopPollAttempts = 150,
    Duration stopPollInterval = const Duration(milliseconds: 100),
  }) : this._(bridge, repository, delay, stopPollAttempts, stopPollInterval);

  const RecorderFinalizationReconciler._(
    this._bridge,
    this._repository,
    this._delay,
    this._stopPollAttempts,
    this._stopPollInterval,
  );

  final RecorderBridge _bridge;
  final RecorderFinalizationRepository _repository;
  final Future<void> Function(Duration) _delay;
  final int _stopPollAttempts;
  final Duration _stopPollInterval;

  Future<RecorderFinalizationSyncResult> reconcilePending() async {
    final batch = await _bridge.getPendingFinalizations();
    return _reconcileBatch(batch);
  }

  Future<RecorderFinalizationSyncResult> reconcileAfterStop(
    String tripId,
  ) async {
    for (var attempt = 0; attempt < _stopPollAttempts; attempt += 1) {
      final batch = await _bridge.getPendingFinalizations();
      if (batch.finalizations.any((item) => item.tripId == tripId)) {
        return _reconcileBatch(batch);
      }
      await _delay(_stopPollInterval);
    }
    throw TimeoutException(
      'Native recorder did not expose a finalization handoff.',
      _stopPollInterval * _stopPollAttempts,
    );
  }

  Future<RecorderFinalizationSyncResult> _reconcileBatch(
    RecorderFinalizationBatch batch,
  ) async {
    if (batch.invalidRecordCount > 0) {
      throw StateError('Native recorder has invalid finalization metadata.');
    }
    final reconciled = <String>[];
    for (final finalization in batch.finalizations) {
      await _repository.reconcile(finalization);
      await _bridge.acknowledgeTripFinalization(finalization.tripId);
      reconciled.add(finalization.tripId);
    }
    return RecorderFinalizationSyncResult(
      reconciledTripIds: List.unmodifiable(reconciled),
      invalidNativeRecordCount: batch.invalidRecordCount,
    );
  }
}
