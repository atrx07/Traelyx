import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/rankings/ranking_models.dart';
import 'package:traelyx/features/rankings/ranking_service.dart';
import '../summary_sync/summary_sync_test.dart' show userA, userB, tripA;
import 'ranking_test.dart' show eligibleAudit;

void main() {
  test(
    'SDK sends only guarded minimized RPC payloads and rejects account changes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final calls = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-client',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      Future<void> signIn(String owner) async {
        String part(Map<String, Object> j) =>
            base64Url.encode(utf8.encode(jsonEncode(j))).replaceAll('=', '');
        final token =
            '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': owner, 'exp': 4102444800, 'role': 'authenticated'})}.synthetic';
        await client.auth.recoverSession(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'synthetic',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'aud': 'authenticated',
              'role': 'authenticated',
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
        );
      }

      var switchDuringResponse = false;
      server.listen((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        calls.add({'path': request.uri.path, ...body});
        request.response.headers.contentType = ContentType.json;
        if (switchDuringResponse) await signIn(userB);
        request.response.write(
          request.uri.path.endsWith('read_rankings_v1')
              ? jsonEncode({
                  'rows': <Object?>[],
                  'profile': {
                    'username': 'rank_alice',
                    'display_name': 'Alice',
                  },
                  'submitted_trip_ids': <Object?>[],
                  'vehicle_classes': ['car'],
                })
              : 'null',
        );
        await request.response.close();
      });
      await signIn(userA);
      final gateway = SupabaseRankingGateway(client);
      final snapshot = await gateway.load(userA);
      expect(snapshot.username, 'rank_alice');
      expect(calls.last, {
        'path': '/rest/v1/rpc/read_rankings_v1',
        'expected_user_id': userA,
      });
      final candidate = RankingCandidate(
        tripA,
        DateTime(2026),
        RankingCandidate.fromAudit(eligibleAudit(), 120000),
      ).forVehicleClass('car');
      await gateway.submit(userA, 'rank_alice', 'Alice', candidate);
      expect(calls.last, {
        'path': '/rest/v1/rpc/submit_ranking_v1',
        'expected_user_id': userA,
        'expected_username': 'rank_alice',
        'expected_display_name': 'Alice',
        'trip_id': tripA,
        'evidence': candidate.evidence,
      });
      await gateway.withdraw(userA);
      expect(calls.last, {
        'path': '/rest/v1/rpc/withdraw_rankings_v1',
        'expected_user_id': userA,
      });
      final before = calls.length;
      await expectLater(
        gateway.submit(userB, 'rank_alice', 'Alice', candidate),
        throwsStateError,
      );
      expect(calls.length, before);
      switchDuringResponse = true;
      await expectLater(gateway.load(userA), throwsStateError);
    },
  );
}
