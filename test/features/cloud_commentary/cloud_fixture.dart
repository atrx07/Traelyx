import 'dart:async';
import 'dart:io';

import 'package:traelyx/core/settings/secure_value_store.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

ProceduralCommentaryPlan fixturePlan({
  CommentaryTone tone = CommentaryTone.chill,
}) => ProceduralCommentaryPlan.build(
  timeline:
      (ReplayTimeline.build(
                recordedDuration: const Duration(seconds: 90),
                route: null,
                events: const [
                  TripEventSummary(
                    type: 'EVT_BRAKE_STRONG',
                    startElapsedNanos: 10000000000,
                    endElapsedNanos: 12000000000,
                  ),
                  TripEventSummary(
                    type: 'EVT_BRAKE_STRONG',
                    startElapsedNanos: 30000000000,
                    endElapsedNanos: 32000000000,
                  ),
                  TripEventSummary(
                    type: 'private untrusted trip user route raw data',
                    startElapsedNanos: 50000000000,
                    endElapsedNanos: 52000000000,
                  ),
                ],
              )
              as ReplayTimelineAvailable)
          .timeline,
  tone: tone,
);
Future<CommentaryModelPolicy> fixturePolicy() async =>
    CommentaryModelPolicy.fromRegistry(
      File('docs/reference/provider-registry.json').readAsStringSync(),
    );

class MemoryCloudVault implements SecureValueStore {
  String? value;
  bool fail = false;
  Completer<void>? readGate;
  final reading = Completer<void>();
  @override
  Future<String?> read(SecureValueKey key) async {
    if (fail) throw StateError('private storage detail');
    if (readGate != null) {
      if (!reading.isCompleted) reading.complete();
      await readGate!.future;
    }
    return value;
  }

  @override
  Future<void> write(SecureValueKey key, String v) async {
    if (fail) throw StateError('private storage detail');
    value = v;
  }

  @override
  Future<void> delete(SecureValueKey key) async {
    if (fail) throw StateError('private storage detail');
    value = null;
  }
}
