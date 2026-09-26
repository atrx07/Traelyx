import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account_metadata/data/supabase_metadata_gateway.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

import '../summary_sync/summary_sync_test.dart' show userA, userB;
import 'metadata_test.dart' show profile, vehicle;

void main() {
  test(
    'SDK uses exact RPC fields, owner reads, immutable retry ID, and safe conflict errors',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final posts = <Map<String, dynamic>>[];
      final paths = <String>[];
      String? errorCode;
      server.listen((request) async {
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        if (errorCode != null) {
          request.response.statusCode = 409;
          request.response.write(
            jsonEncode({
              'code': errorCode,
              'message': 'private provider details',
            }),
          );
        } else if (request.method == 'POST') {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          posts.add(body);
          final isProfile = request.uri.path.endsWith('save_profile_v1');
          expect(
            request.uri.path,
            isProfile
                ? '/rest/v1/rpc/save_profile_v1'
                : '/rest/v1/rpc/save_vehicle_v1',
          );
          request.response.write(
            jsonEncode({
              'user_id': userA,
              'revision': 1,
              'last_mutation_id': body['mutation_id'],
              if (isProfile) ...{
                'username': body['profile_username'],
                'display_name': body['profile_display_name'],
                'visibility': body['profile_visibility'],
              } else ...{
                'id': body['vehicle_id'],
                'display_name': body['vehicle_display_name'],
                'vehicle_class': body['vehicle_class_name'],
              },
            }),
          );
        } else {
          expect(request.method, 'GET');
          expect(request.uri.queryParameters['user_id'], 'eq.$userA');
          if (request.uri.path.endsWith('profiles')) {
            expect(
              request.uri.queryParameters['select'],
              'user_id,username,display_name,visibility,revision',
            );
            request.response.write(
              jsonEncode({
                'user_id': userA,
                'revision': 1,
                ...profile().fields,
              }),
            );
          } else {
            expect(
              request.uri.queryParameters['select'],
              'user_id,id,display_name,vehicle_class,revision',
            );
            request.response.write('[]');
          }
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
      final gateway = SupabaseMetadataGateway(client);
      final mutation = MetadataMutation(profile(), newMetadataUuid());
      await gateway.save(mutation);
      await gateway.save(mutation);
      expect(posts.first, {
        'expected_user_id': userA,
        'expected_revision': 0,
        'mutation_id': mutation.mutationId,
        'profile_username': 'driver_name',
        'profile_display_name': 'Driver',
        'profile_visibility': 'private',
      });
      expect(posts[1], posts.first);
      final vehicleMutation = MetadataMutation(vehicle(), newMetadataUuid());
      await gateway.save(vehicleMutation);
      expect(posts.last, {
        'expected_user_id': userA,
        'expected_revision': 0,
        'mutation_id': vehicleMutation.mutationId,
        'vehicle_id': vehicleMutation.data.id,
        'vehicle_display_name': 'Chosen label',
        'vehicle_class_name': 'car',
      });
      expect((await gateway.fetch(userA)).single.sameFields(profile()), isTrue);
      final before = paths.length;
      await expectLater(
        gateway.fetch(userB),
        throwsA(isA<MetadataException>()),
      );
      expect(paths.length, before);
      errorCode = '40001';
      await expectLater(
        gateway.save(mutation),
        throwsA(
          isA<MetadataException>().having(
            (e) => e.reason,
            'reason',
            MetadataFailure.conflict,
          ),
        ),
      );
      errorCode = '42501';
      await expectLater(
        gateway.save(mutation),
        throwsA(
          isA<MetadataException>().having(
            (e) => e.reason,
            'reason',
            MetadataFailure.accessDenied,
          ),
        ),
      );
    },
  );
}
