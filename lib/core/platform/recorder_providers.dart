import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/database/recorder_finalization_repository.dart';
import 'package:traelyx/core/database/trip_debug_export_repository.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';

final recorderBridgeProvider = Provider<RecorderBridge>(
  (ref) => const RecorderBridge(),
);

final recorderCapabilitiesProvider = FutureProvider<RecorderCapabilities>((
  ref,
) {
  return ref.watch(recorderBridgeProvider).getCapabilities();
});

final recorderStatusProvider = FutureProvider<RecorderStatus>((ref) {
  return ref.watch(recorderBridgeProvider).getStatus();
});

final recorderStatusPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

final recorderStatusPollingProvider = Provider<void>((ref) {
  final isActive =
      ref.watch(recorderStatusProvider).valueOrNull?.lifecycle.active ?? false;
  if (!isActive) return;

  final timer = Timer.periodic(
    ref.watch(recorderStatusPollIntervalProvider),
    (_) => ref.invalidate(recorderStatusProvider),
  );
  ref.onDispose(timer.cancel);
});

final recorderPermissionStatusProvider =
    FutureProvider<RecorderPermissionStatus>((ref) {
      return ref.watch(recorderBridgeProvider).getPermissionStatus();
    });

final recorderFinalizationRepositoryProvider =
    Provider<RecorderFinalizationRepository>((ref) {
      return DriftRecorderFinalizationRepository(
        ref.watch(appDatabaseProvider),
      );
    });

final recorderFinalizationReconcilerProvider =
    Provider<RecorderFinalizationReconciler>((ref) {
      return RecorderFinalizationReconciler(
        bridge: ref.watch(recorderBridgeProvider),
        repository: ref.watch(recorderFinalizationRepositoryProvider),
      );
    });

final recorderFinalizationSyncProvider =
    FutureProvider<RecorderFinalizationSyncResult>((ref) {
      return ref
          .watch(recorderFinalizationReconcilerProvider)
          .reconcilePending();
    });

final tripDebugExportRepositoryProvider = Provider<TripDebugExportRepository>((
  ref,
) {
  return DriftTripDebugExportRepository(ref.watch(appDatabaseProvider));
});

final latestTripDebugExportTripIdProvider = FutureProvider<String?>((
  ref,
) async {
  await ref.watch(recorderFinalizationSyncProvider.future);
  return ref.watch(tripDebugExportRepositoryProvider).latestFinalizedTripId();
});

final recorderTripDebugExporterProvider = Provider<RecorderTripDebugExporter>((
  ref,
) {
  return RecorderTripDebugExportController(ref.watch(recorderBridgeProvider));
});

abstract interface class RecorderTripDebugExporter {
  Future<TripDebugExportResult> exportTrip(String tripId);
}

class RecorderTripDebugExportController implements RecorderTripDebugExporter {
  const RecorderTripDebugExportController(this._bridge);

  final RecorderBridge _bridge;

  @override
  Future<TripDebugExportResult> exportTrip(String tripId) =>
      _bridge.exportTripDebug(tripId);
}

final recorderCommandControllerProvider = Provider<RecorderCommands>((ref) {
  return RecorderCommandController(ref);
});

abstract interface class RecorderCommands {
  Future<RecorderStatus> startTrip();

  Future<RecorderStatus> stopTrip();

  Future<RecorderStatus> recoverTrip();
}

class RecorderCommandController implements RecorderCommands {
  const RecorderCommandController(this._ref);

  final Ref _ref;

  @override
  Future<RecorderStatus> startTrip() =>
      _run(_ref.read(recorderBridgeProvider).startTrip);

  @override
  Future<RecorderStatus> stopTrip() async {
    final bridge = _ref.read(recorderBridgeProvider);
    final beforeStop = await bridge.getStatus();
    try {
      await bridge.stopTrip();
      final tripId = beforeStop.lifecycle.tripId;
      if (tripId != null) {
        await _ref
            .read(recorderFinalizationReconcilerProvider)
            .reconcileAfterStop(tripId);
      }
      return await bridge.getStatus();
    } finally {
      if (_ref.exists(recorderFinalizationSyncProvider)) {
        _ref.invalidate(recorderFinalizationSyncProvider);
      }
      if (_ref.exists(latestTripDebugExportTripIdProvider)) {
        _ref.invalidate(latestTripDebugExportTripIdProvider);
      }
      _refresh();
    }
  }

  @override
  Future<RecorderStatus> recoverTrip() =>
      _run(_ref.read(recorderBridgeProvider).recoverTrip);

  Future<RecorderStatus> _run(Future<RecorderStatus> Function() command) async {
    final status = await command();
    _refresh();
    return status;
  }

  void _refresh() {
    _ref.invalidate(recorderStatusProvider);
  }
}

final recorderPermissionControllerProvider =
    Provider<RecorderPermissionActions>((ref) {
      return RecorderPermissionController(ref);
    });

abstract interface class RecorderPermissionActions {
  Future<RecorderPermissionStatus> requestLocation();

  Future<RecorderPermissionStatus> requestNotification();

  Future<RecorderPermissionStatus> openAppSettings();

  Future<RecorderPermissionStatus> openLocationSettings();

  void refresh();
}

class RecorderPermissionController implements RecorderPermissionActions {
  const RecorderPermissionController(this._ref);

  final Ref _ref;

  @override
  Future<RecorderPermissionStatus> requestLocation() =>
      _run(_ref.read(recorderBridgeProvider).requestLocationPermission);

  @override
  Future<RecorderPermissionStatus> requestNotification() =>
      _run(_ref.read(recorderBridgeProvider).requestNotificationPermission);

  @override
  Future<RecorderPermissionStatus> openAppSettings() =>
      _run(_ref.read(recorderBridgeProvider).openAppSettings);

  @override
  Future<RecorderPermissionStatus> openLocationSettings() =>
      _run(_ref.read(recorderBridgeProvider).openLocationSettings);

  @override
  void refresh() {
    _ref.invalidate(recorderPermissionStatusProvider);
    _ref.invalidate(recorderCapabilitiesProvider);
    _ref.invalidate(recorderStatusProvider);
  }

  Future<RecorderPermissionStatus> _run(
    Future<RecorderPermissionStatus> Function() action,
  ) async {
    final status = await action();
    refresh();
    return status;
  }
}
