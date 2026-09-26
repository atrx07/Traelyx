import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/rankings/ranking_models.dart';

class SupabaseRankingGateway implements RankingGateway {
  const SupabaseRankingGateway(this.client);
  final SupabaseClient client;
  Future<Object?> _rpc(
    String owner,
    String name,
    Map<String, Object?> parameters,
  ) async {
    void check() {
      if (client.auth.currentUser?.id != owner) {
        throw StateError('Account changed.');
      }
    }

    check();
    final Object? result = await client.rpc(
      name,
      params: {'expected_user_id': owner, ...parameters},
    );
    check();
    return result;
  }

  @override
  Future<RankingSnapshot> load(String owner) async => RankingSnapshot.fromJson(
    (await _rpc(owner, 'read_rankings_v1', {}))! as Map<String, dynamic>,
  );
  @override
  Future<void> submit(
    String owner,
    String username,
    String displayName,
    RankingCandidate candidate,
  ) async {
    await _rpc(owner, 'submit_ranking_v1', {
      'expected_username': username,
      'expected_display_name': displayName,
      'trip_id': candidate.tripId,
      'evidence': candidate.evidence,
    });
  }

  @override
  Future<void> withdraw(String owner) async {
    await _rpc(owner, 'withdraw_rankings_v1', {});
  }
}

class RankingService {
  RankingService(this.db, this.account, this.gateway);
  final AppDatabase db;
  final AccountGateway account;
  final RankingGateway? gateway;
  bool _busy = false;
  void _check(String owner) {
    if (account.currentIdentity?.userId != owner || gateway == null) {
      throw StateError('Account unavailable.');
    }
  }

  Future<RankingSnapshot> load(String owner) async {
    _check(owner);
    final result = await gateway!.load(owner);
    _check(owner);
    return result;
  }

  Future<List<RankingCandidate>> candidates(String owner) async {
    _check(owner);
    final rows = await (db.select(
      db.tripScores,
    )..where((s) => s.id.like('analysis-v1-%'))).get();
    final candidates = <RankingCandidate>[];
    for (final row in rows) {
      final trip = await (db.select(
        db.trips,
      )..where((t) => t.id.equals(row.tripId))).getSingleOrNull();
      final link = await (db.select(
        db.tripAccountLinks,
      )..where((l) => l.tripId.equals(row.tripId))).getSingleOrNull();
      if (trip == null ||
          trip.durationMillis == null ||
          trip.completionState != 'completed' ||
          trip.recoveryState != 'not_needed' ||
          trip.integrityStatus != 'verified' ||
          trip.scoringVersion != '1' ||
          trip.eventEngineVersion != '1' ||
          row.scoringVersion != '1' ||
          row.eligibilityState != 'full' ||
          (link != null && link.userId != owner)) {
        continue;
      }
      try {
        final audit =
            jsonDecode(row.auditContributionsJson) as Map<String, dynamic>;
        final dossier = RankingCandidate.fromAudit(audit, trip.durationMillis!);
        candidates.add(
          RankingCandidate(
            row.tripId,
            DateTime.fromMicrosecondsSinceEpoch(
              trip.startWallTimeMicros,
            ).toLocal(),
            dossier,
          ),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    candidates.sort((a, b) => a.localDate.compareTo(b.localDate));
    _check(owner);
    return List.unmodifiable(candidates);
  }

  // Foreground only: after an uncertain response, reload and explicitly review/retry.
  // Immutable account association persists before the request, but creates no summary outbox.
  Future<void> submit(
    String owner,
    RankingSnapshot reviewed,
    RankingCandidate candidate, {
    required String vehicleClass,
  }) async {
    _check(owner);
    if (_busy ||
        reviewed.username == null ||
        reviewed.displayName == null ||
        !reviewed.vehicleClasses.contains(vehicleClass)) {
      throw StateError('Review required.');
    }
    _busy = true;
    try {
      await db.transaction(() async {
        final fresh = await candidates(owner);
        if (!fresh.any(
          (c) =>
              c.tripId == candidate.tripId &&
              c.encodedEvidence == candidate.encodedEvidence,
        )) {
          throw StateError('Local evidence changed.');
        }
        await db
            .into(db.tripAccountLinks)
            .insert(
              TripAccountLinksCompanion.insert(
                tripId: candidate.tripId,
                userId: owner,
                consentedAtMicros: DateTime.now().microsecondsSinceEpoch,
                summaryVersion: 1,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        _check(owner);
      });
      _check(owner);
      await gateway!.submit(
        owner,
        reviewed.username!,
        reviewed.displayName!,
        candidate.forVehicleClass(vehicleClass),
      );
      _check(owner);
    } finally {
      _busy = false;
    }
  }

  Future<void> withdraw(String owner) async {
    _check(owner);
    if (_busy) throw StateError('Wait for the current request.');
    _busy = true;
    try {
      await gateway!.withdraw(owner);
      _check(owner);
    } finally {
      _busy = false;
    }
  }
}

final rankingGatewayProvider = Provider<RankingGateway?>((ref) {
  final account = ref.watch(accountGatewayProvider);
  return account is SupabaseAccountGateway
      ? SupabaseRankingGateway(account.client)
      : null;
});
final rankingServiceProvider = Provider<RankingService>(
  (ref) => RankingService(
    ref.watch(appDatabaseProvider),
    ref.watch(accountGatewayProvider),
    ref.watch(rankingGatewayProvider),
  ),
);
