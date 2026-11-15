import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/features/event_corrections/data/event_correction_repository.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

class CorrectionExportResult {
  const CorrectionExportResult({
    required this.exported,
    required this.errorCode,
  });
  final bool exported;
  final String? errorCode;
}

abstract interface class CorrectionExporter {
  Future<CorrectionExportResult> export(
    Map<String, Object?> payload, {
    required Future<bool> Function() authorize,
  });
}

class NativeCorrectionExporter implements CorrectionExporter {
  const NativeCorrectionExporter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);
  static const channelName = 'io.github.atrx07.traelyx/event_corrections/v1';
  final MethodChannel _channel;
  static final _pendingChannels = <String>{};
  static int _sequence = 0;

  @override
  Future<CorrectionExportResult> export(
    Map<String, Object?> payload, {
    required Future<bool> Function() authorize,
  }) async {
    final validated = validateCorrectionContribution(payload);
    if (!_pendingChannels.add(_channel.name)) {
      throw StateError('Another contribution export is in progress.');
    }
    final authorizationId = '${++_sequence}';
    var requested = false;
    var authorized = false;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'authorizeContribution' ||
          call.arguments != authorizationId ||
          requested) {
        return false;
      }
      requested = true;
      try {
        authorized = await authorize();
      } catch (_) {
        authorized = false;
      }
      return authorized;
    });
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'exportContribution',
        {'authorizationId': authorizationId, 'payload': validated},
      );
      if (value == null ||
          value.length != 4 ||
          !const {
            'contractVersion',
            'exported',
            'byteLength',
            'errorCode',
          }.every(value.containsKey) ||
          value['contractVersion'] is! int ||
          value['contractVersion'] != 1 ||
          value['exported'] is! bool ||
          value['byteLength'] is! int ||
          (value['byteLength']! as int) < 0 ||
          (value['byteLength']! as int) > 65536 ||
          (value['errorCode'] != null &&
              (value['errorCode'] is! String ||
                  !RegExp(
                    r'^[a-z][a-z0-9_]{0,63}$',
                  ).hasMatch(value['errorCode']! as String))) ||
          ((value['exported'] == true) != (value['errorCode'] == null)) ||
          (value['exported'] == true &&
              (value['byteLength'] == 0 || !authorized))) {
        throw const FormatException('Invalid contribution export result.');
      }
      return CorrectionExportResult(
        exported: value['exported']! as bool,
        errorCode: value['errorCode'] as String?,
      );
    } finally {
      _channel.setMethodCallHandler(null);
      _pendingChannels.remove(_channel.name);
    }
  }
}

class EventCorrectionService {
  EventCorrectionService({
    required this.repository,
    required this.isRecorderIdle,
    required this.exporter,
  });
  final EventCorrectionRepository repository;
  final Future<bool> Function() isRecorderIdle;
  final CorrectionExporter exporter;
  bool _busy = false;

  Future<T> _action<T>(bool parked, Future<T> Function() action) async {
    if (_busy) throw StateError('Another correction action is in progress.');
    _busy = true;
    try {
      if (!parked || !await isRecorderIdle()) {
        throw StateError('Finish driving before reviewing detections.');
      }
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<CorrectionCatalog> load(String tripId, {required bool parked}) =>
      _action(parked, () => repository.load(tripId));
  Future<void> save(
    CorrectionTarget target,
    CorrectionChoice choice, {
    required bool parked,
    required int expectedRevision,
    bool contribute = false,
  }) => _action(
    parked,
    () => repository.save(
      target,
      choice,
      expectedRevision: expectedRevision,
      contribute: contribute,
    ),
  );
  Future<void> remove(CorrectionNote note, {required bool parked}) =>
      _action(parked, () => repository.remove(note));
  Future<void> clear(String tripId, {required bool parked}) =>
      _action(parked, () => repository.clear(tripId));
  Future<CorrectionContribution> preview(
    String tripId, {
    required bool parked,
  }) => _action(parked, () => repository.prepare(tripId));
  Future<CorrectionExportResult> export(
    String tripId,
    CorrectionContribution reviewed, {
    required bool parked,
  }) => _action(parked, () async {
    final fresh = await repository.prepare(tripId);
    if (fresh.reviewToken != reviewed.reviewToken ||
        jsonEncode(fresh.payload) != jsonEncode(reviewed.payload)) {
      throw StateError(
        'Permission or evidence changed; review the export again.',
      );
    }
    if (!await isRecorderIdle()) {
      throw StateError('Finish driving before exporting.');
    }
    return exporter.export(
      fresh.payload,
      authorize: () async {
        try {
          if (!await isRecorderIdle()) return false;
          final current = await repository.prepare(tripId);
          return current.reviewToken == reviewed.reviewToken &&
              jsonEncode(current.payload) == jsonEncode(reviewed.payload);
        } catch (_) {
          return false;
        }
      },
    );
  });
}

final eventCorrectionServiceProvider = Provider<EventCorrectionService>(
  (ref) => EventCorrectionService(
    repository: EventCorrectionRepository(ref.watch(appDatabaseProvider)),
    isRecorderIdle: () async {
      final lifecycle =
          (await ref.read(recorderBridgeProvider).getStatus()).lifecycle;
      return lifecycle.contractVersion == 1 &&
          lifecycle.state == 'idle' &&
          !lifecycle.active &&
          lifecycle.tripId == null &&
          lifecycle.errorCode == null;
    },
    exporter: const NativeCorrectionExporter(),
  ),
);
