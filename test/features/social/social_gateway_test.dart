import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/social/data/supabase_social_gateway.dart';
import 'package:traelyx/features/social/domain/social.dart';
import '../summary_sync/summary_sync_test.dart' show userA, userB;
import 'social_test.dart' show person, entry;

void main() {
  test(
    'SDK exact payloads, projection, account guard and safe errors',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final calls = <Map<String, dynamic>>[];
      String? error;
      server.listen((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        calls.add({'path': request.uri.path, ...body});
        request.response.headers.contentType = ContentType.json;
        if (error != null) {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({'code': error, 'message': 'sensitive provider detail'}),
          );
        } else if (request.uri.path.endsWith('lookup_public_profile_v1')) {
          request.response.write(
            jsonEncode([
              {'username': person.username, 'display_name': person.displayName},
            ]),
          );
        } else if (request.uri.path.endsWith('list_social_v1')) {
          request.response.write(
            jsonEncode([
              {
                'id': entry(SocialStatus.incoming).id,
                'revision': 2,
                'username': person.username,
                'display_name': person.displayName,
                'state': 'incoming',
              },
            ]),
          );
        } else {
          request.response.write('null');
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

      final gateway = SupabaseSocialGateway(client);
      expect(
        (await gateway.lookup(userA, person.username))?.username,
        person.username,
      );
      expect(calls.last, {
        'path': '/rest/v1/rpc/lookup_public_profile_v1',
        'profile_username': person.username,
      });
      final rows = await gateway.load(userA);
      expect(rows.single.status, SocialStatus.incoming);
      expect(calls.last, {
        'path': '/rest/v1/rpc/list_social_v1',
        'expected_user_id': userA,
      });
      await gateway.request(
        userA,
        person,
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      expect(calls.last, {
        'path': '/rest/v1/rpc/request_friend_v1',
        'expected_user_id': userA,
        'target_username': person.username,
        'target_display_name': person.displayName,
        'mutation_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      });
      await gateway.change(userA, rows.single, SocialAction.accept);
      expect(calls.last, {
        'path': '/rest/v1/rpc/change_friend_v1',
        'expected_user_id': userA,
        'relationship_id': rows.single.id,
        'expected_revision': 2,
        'action_name': 'accept',
      });
      final before = calls.length;
      await expectLater(gateway.load(userB), throwsA(isA<SocialException>()));
      expect(calls.length, before);
      await expectLater(
        gateway.lookup(userA, 'wild%'),
        throwsA(isA<SocialException>()),
      );
      expect(calls.length, before);
      for (final code in ['40001', 'P0002', 'P0001', '42501', 'other']) {
        error = code;
        await expectLater(
          gateway.load(userA),
          throwsA(
            isA<SocialException>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('sensitive provider')),
            ),
          ),
        );
      }
    },
  );
}
