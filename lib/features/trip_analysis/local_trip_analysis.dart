import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';

abstract interface class LocalAnalysisGateway {
  Future<Map<String, dynamic>> analyze(String tripId, String forwardAxis);
}

class NativeLocalAnalysisGateway implements LocalAnalysisGateway {
  const NativeLocalAnalysisGateway();
  static const channel = MethodChannel(
    'io.github.atrx07.traelyx/local-analysis/v1',
  );
  @override
  Future<Map<String, dynamic>> analyze(
    String tripId,
    String forwardAxis,
  ) async {
    final value = await channel.invokeMethod<Object?>('analyzeTrip', {
      'tripId': tripId,
      'forwardAxis': forwardAxis,
    });
    // Normalize platform maps once; rejects non-JSON/non-finite values.
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
}

class LocalAnalysisService {
  LocalAnalysisService(this.db, this.gateway);
  final AppDatabase db;
  final LocalAnalysisGateway gateway;
  bool _busy = false;

  Future<void> analyze(String tripId, String forwardAxis) async {
    if (_busy) throw StateError('Local analysis is already running.');
    if (!const [
      'top',
      'bottom',
      'left',
      'right',
      'screen',
      'back',
    ].contains(forwardAxis)) {
      throw const FormatException('Choose the recorded mount direction.');
    }
    _busy = true;
    try {
      final original = await _trip(tripId);
      if (original == null || original.completionState != 'completed') {
        throw StateError('Only completed local trips can be analyzed.');
      }
      if (await _hasScore(tripId)) {
        throw StateError('This trip already has a preserved analysis.');
      }
      final chunks = await _chunks(tripId);
      if (chunks.isEmpty || chunks.any((c) => c.writeState != 'complete')) {
        throw StateError('Complete raw evidence is required.');
      }
      final audit = await gateway.analyze(tripId, forwardAxis);
      _validate(audit, tripId, forwardAxis, chunks);
      final score = audit['score'] as Map<String, dynamic>;
      final integrity = score['integrity'] as Map<String, dynamic>;
      final now = DateTime.now().toUtc().microsecondsSinceEpoch;
      await db.transaction(() async {
        if (await _trip(tripId) != original ||
            jsonEncode(
                  (await _chunks(tripId)).map((c) => c.toJson()).toList(),
                ) !=
                jsonEncode(chunks.map((c) => c.toJson()).toList()) ||
            await _hasScore(tripId)) {
          throw StateError('Trip evidence changed. Review the trip again.');
        }
        // A local audit is never a ranking publication or an account association.
        final savedAudit = {
          ...audit,
          'completionState': original.completionState,
          'recoveryState': original.recoveryState,
          'finalizationQuality': jsonDecode(
            original.telemetryQualitySummaryJson ?? '{}',
          ),
        };
        await db
            .into(db.tripScores)
            .insert(
              TripScoresCompanion.insert(
                id: 'analysis-v1-$tripId',
                tripId: tripId,
                scoreSchemaVersion: 1,
                scoringVersion: '1',
                dimensionValuesJson: jsonEncode(score['dimensions']),
                overallScore: Value(
                  score['overallMilliPoints'] == null
                      ? null
                      : (score['overallMilliPoints'] as num).toDouble() / 1000,
                ),
                eligibilityState: score['state'] as String,
                auditContributionsJson: jsonEncode(savedAudit),
                createdAtMicros: now,
              ),
            );
        for (final event in audit['events'] as List<dynamic>) {
          final e = event as Map<String, dynamic>;
          final ratio = (e['activationRatio'] as num?)?.toDouble();
          await db
              .into(db.tripEvents)
              .insert(
                TripEventsCompanion.insert(
                  id: e['id'] as String,
                  tripId: tripId,
                  eventType: e['type'] as String,
                  startElapsedNanos: e['startNanos'] as int,
                  peakElapsedNanos: e['peakNanos'] as int,
                  endElapsedNanos: e['endNanos'] as int,
                  severity: ratio == null ? 0 : (ratio / 2).clamp(0, 1),
                  severityCalibrationVersion: 'activation-ratio-cap2-v1',
                  // Stored as categorical weights for schema compatibility, never probabilities.
                  confidence: e['confidence'] == 'SUPPORTED' ? 1 : 0.5,
                  qualityFlagsJson: jsonEncode(e['qualityFlags']),
                  primaryMeasurementsJson: jsonEncode(e['measurements']),
                  ruleEvidenceJson: jsonEncode({
                    'rules': e['rules'],
                    'source': e['sourceSummary'],
                    'confidenceCategory': e['confidence'],
                    'activationRatio': ratio,
                  }),
                  contextTagsJson: '[]',
                  algorithmVersion: '1',
                  createdAtMicros: now,
                ),
              );
        }
        await (db.update(db.trips)..where((t) => t.id.equals(tripId))).write(
          TripsCompanion(
            scoringVersion: const Value('1'),
            eventEngineVersion: const Value('1'),
            distanceMeters: Value(
              (audit['distanceMeters'] as num?)?.toDouble(),
            ),
            integrityStatus: Value(integrity['state'] as String),
            updatedAtMicros: Value(now),
          ),
        );
      });
    } finally {
      _busy = false;
    }
  }

  Future<Trip?> _trip(String id) =>
      (db.select(db.trips)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<bool> _hasScore(String id) async => (await (db.select(
    db.tripScores,
  )..where((s) => s.tripId.equals(id))).get()).isNotEmpty;
  Future<List<TripChunk>> _chunks(String id) =>
      (db.select(db.tripChunks)
            ..where((c) => c.tripId.equals(id))
            ..orderBy([(c) => OrderingTerm.asc(c.sequence)]))
          .get();

  void _validate(
    Map<String, dynamic> a,
    String id,
    String axis,
    List<TripChunk> chunks,
  ) {
    final score = a['score'] as Map<String, dynamic>;
    final integrity = score['integrity'] as Map<String, dynamic>;
    final dimensions = score['dimensions'] as Map<String, dynamic>;
    final overall = score['overallMilliPoints'];
    final distance = a['distanceMeters'];
    final sourceChunks = a['sourceChunks'] as List;
    if (a['analysisVersion'] != 1 ||
        a['tripId'] != id ||
        a['forwardAxis'] != axis ||
        a['sourceChunkCount'] != chunks.length ||
        sourceChunks.length != chunks.length ||
        a['sourceStartNanos'] != chunks.first.startElapsedNanos ||
        a['sourceEndNanos'] != chunks.last.endElapsedNanos ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(a['sourceDigest'] as String) ||
        score['scoringVersion'] != 1 ||
        integrity['version'] != 1 ||
        !const [
          'verified',
          'limited_confidence',
          'questionable',
          'unranked',
        ].contains(integrity['state']) ||
        !const [
          'full',
          'provisional',
          'unavailable',
          'unranked',
        ].contains(score['state']) ||
        (overall != null &&
            (overall is! int || overall < 0 || overall > 100000)) ||
        (distance != null &&
            (distance is! num || !distance.isFinite || distance < 0)) ||
        dimensions.length != 5 ||
        (a['events'] as List).length > 10000) {
      throw const FormatException('Invalid local analysis response.');
    }
    for (var i = 0; i < chunks.length; i++) {
      final source = sourceChunks[i] as List;
      final indexed = chunks[i];
      if (source.length != 9 ||
          source[0] != indexed.sequence ||
          source[1] != indexed.startElapsedNanos ||
          source[2] != indexed.endElapsedNanos ||
          source[3] != indexed.checksum ||
          source[4] != indexed.byteLength) {
        throw const FormatException(
          'Raw evidence differs from the finalized chunk index.',
        );
      }
    }
    for (final dimension in dimensions.values) {
      final d = dimension as Map<String, dynamic>;
      final moving = d['movingNanos'] as int;
      final opportunity = d['opportunityNanos'] as int;
      final usable = d['usableNanos'] as int;
      final full = d['fullyEligibleNanos'] as int;
      if (full < 0 ||
          usable < full ||
          opportunity < usable ||
          moving < opportunity) {
        throw const FormatException('Invalid analysis evidence durations.');
      }
    }
    final ids = <String>{};
    for (final event in a['events'] as List) {
      final e = event as Map<String, dynamic>;
      final start = e['startNanos'] as int;
      final peak = e['peakNanos'] as int;
      final end = e['endNanos'] as int;
      final ratio = e['activationRatio'];
      if (!ids.add(e['id'] as String) ||
          start < 0 ||
          peak < start ||
          end < peak ||
          end > (a['sourceEndNanos'] as int) ||
          !const ['SUPPORTED', 'LIMITED'].contains(e['confidence']) ||
          (ratio != null && (ratio is! num || !ratio.isFinite || ratio < 1))) {
        throw const FormatException('Invalid analysis event.');
      }
    }
  }
}

final localAnalysisGatewayProvider = Provider<LocalAnalysisGateway>(
  (ref) => const NativeLocalAnalysisGateway(),
);
final localAnalysisServiceProvider = Provider<LocalAnalysisService>(
  (ref) => LocalAnalysisService(
    ref.watch(appDatabaseProvider),
    ref.watch(localAnalysisGatewayProvider),
  ),
);
