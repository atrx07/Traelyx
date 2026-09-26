// Explicit alternate debug entrypoint for maintainer-authorized hosted QA.
// Uses the phone's existing session without exporting it. Only a disposable,
// randomly identified synthetic summary is written and then deleted.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';
import 'package:traelyx/features/summary_sync/data/supabase_summary_gateway.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final checks = <String>[];
  var success = false;
  try {
    final account = await initializeAccount();
    final owner = account.currentIdentity?.userId;
    if (owner == null) throw StateError('Existing sign-in required');
    final client = Supabase.instance.client;
    final testId = _uuid();
    final otherOwner = _uuid();
    final summary = CompactTripSummary(
      userId: owner,
      tripId: testId,
      durationSeconds: 1,
      distanceMeters: 0,
    );
    var inserted = false;
    try {
      final gateway = SupabaseSummaryGateway(client);
      // Mark cleanup necessary before the request: its acknowledgement can fail.
      inserted = true;
      await gateway.upload(summary);
      checks.add('Owner insert and exact readback passed');
      await gateway.upload(summary);
      checks.add('Idempotent duplicate passed');
      try {
        await gateway.upload(
          CompactTripSummary(userId: owner, tripId: testId, durationSeconds: 2),
        );
        throw StateError('Conflict was not rejected');
      } on SummarySyncException catch (error) {
        if (error.reason != SummaryFailure.conflict) rethrow;
        checks.add('Snapshot conflict rejection passed');
      }
      try {
        await client
            .from('trip_summaries')
            .insert(
              CompactTripSummary(userId: otherOwner, tripId: _uuid()).toJson(),
            );
        throw StateError('Forged ownership accepted');
      } on PostgrestException catch (error) {
        if (error.code != '42501') rethrow;
        checks.add('Cross-owner insert denied');
      }
      final anonymous = SupabaseClient(
        const String.fromEnvironment('TRAELYX_SUPABASE_URL'),
        const String.fromEnvironment('TRAELYX_SUPABASE_PUBLISHABLE_KEY'),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        try {
          await anonymous
              .from('trip_summaries')
              .select('source_trip_id')
              .eq('source_trip_id', testId);
          throw StateError('Anonymous read accepted');
        } on PostgrestException catch (error) {
          if (error.code != '42501') rethrow;
          checks.add('Anonymous read denied');
        }
      } finally {
        await anonymous.dispose();
      }
    } finally {
      if (inserted) {
        await client
            .from('trip_summaries')
            .delete()
            .eq('user_id', owner)
            .eq('source_trip_id', testId);
        final remaining = await client
            .from('trip_summaries')
            .select('source_trip_id')
            .eq('user_id', owner)
            .eq('source_trip_id', testId);
        if (remaining.isNotEmpty) {
          throw StateError('Synthetic cleanup incomplete');
        }
        checks.add('Synthetic row cleanup verified');
      }
    }
    success = true;
  } catch (_) {
    checks.add(
      'Hosted QA incomplete; inspect access/configuration without logging credentials',
    );
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                Text(
                  success
                      ? 'Hosted summary QA passed'
                      : 'Hosted summary QA incomplete',
                ),
                for (final check in checks) Text(check),
                const Text(
                  'No local trip data was uploaded. Restore the normal Traelyx build after this check.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
