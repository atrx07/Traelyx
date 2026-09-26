import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/summary_sync/data/supabase_summary_gateway.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

import 'summary_sync_test.dart' show userA, userB, tripA;

void main() {
  test(
    'real SDK sends only allowlisted fields and verifies idempotent snapshots',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? stored;
      var requests = 0;
      var deny = false;
      final posts = <Map<String, dynamic>>[];
      server.listen((request) async {
        requests++;
        expect(request.uri.path, '/rest/v1/trip_summaries');
        request.response.headers.contentType = ContentType.json;
        if (deny) {
          request.response.statusCode = 403;
          request.response.write(
            jsonEncode({'code': '42501', 'message': 'synthetic denied'}),
          );
        } else if (request.method == 'POST') {
          final payload =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          posts.add(payload);
          expect(
            request.headers.value('prefer'),
            contains('resolution=ignore-duplicates'),
          );
          expect(
            request.uri.queryParameters['on_conflict'],
            'user_id,source_trip_id',
          );
          stored ??= payload;
          request.response.statusCode = 201;
        } else {
          expect(request.method, 'GET');
          expect(request.uri.queryParameters['user_id'], 'eq.$userA');
          expect(request.uri.queryParameters['source_trip_id'], 'eq.$tripA');
          request.response.write(jsonEncode(stored));
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-public-client',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final header = base64Url
          .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
          .replaceAll('=', '');
      final claims = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'sub': userA,
                'exp': 4102444800,
                'role': 'authenticated',
              }),
            ),
          )
          .replaceAll('=', '');
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': '$header.$claims.synthetic',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': userA,
            'aud': 'authenticated',
            'role': 'authenticated',
            'app_metadata': <String, Object>{},
            'user_metadata': <String, Object>{},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      final gateway = SupabaseSummaryGateway(client);
      final summary = CompactTripSummary(
        userId: userA,
        tripId: tripA,
        durationSeconds: 12,
      );
      await gateway.upload(summary);
      await gateway.upload(summary);
      expect(requests, 4);
      expect(posts, [summary.toJson(), summary.toJson()]);
      expect(stored, summary.toJson());
      await expectLater(
        gateway.upload(CompactTripSummary(userId: userB, tripId: tripA)),
        throwsA(
          isA<SummarySyncException>().having(
            (e) => e.reason,
            'reason',
            SummaryFailure.accountChanged,
          ),
        ),
      );
      expect(requests, 4);
      stored!['duration_seconds'] = 99;
      await expectLater(
        gateway.upload(summary),
        throwsA(
          isA<SummarySyncException>().having(
            (e) => e.reason,
            'reason',
            SummaryFailure.conflict,
          ),
        ),
      );
      expect(stored!['duration_seconds'], 99);
      deny = true;
      await expectLater(
        gateway.upload(summary),
        throwsA(
          isA<SummarySyncException>().having(
            (e) => e.reason,
            'reason',
            SummaryFailure.accessDenied,
          ),
        ),
      );
    },
  );
}
