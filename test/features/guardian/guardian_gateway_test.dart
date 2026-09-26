import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/guardian/guardian_gateway.dart';
import 'package:traelyx/features/guardian/guardian_models.dart';
import '../summary_sync/summary_sync_test.dart' show userA, userB;
import 'guardian_test.dart';

void main() {
  test('SDK guarded exact payloads, safe failures and account changes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final calls = <Map<String, dynamic>>[];
    String? error;
    Future<void> Function()? afterRequest;
    final expires = DateTime.now()
        .add(const Duration(minutes: 10))
        .toUtc()
        .toIso8601String();
    final invite = {
      'id': guardianTestId,
      'expires_at': expires,
      'permissions': guardianTestPermissions.toJson(),
    };
    server.listen((request) async {
      calls.add({
        'path': request.uri.path,
        ...jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      });
      request.response.headers.contentType = ContentType.json;
      await afterRequest?.call();
      if (error != null) {
        request.response.statusCode = 400;
        request.response.write(
          jsonEncode({'code': error, 'message': 'secret $guardianTestToken'}),
        );
      } else {
        final response = switch (request.uri.path.split('/').last) {
          'list_guardian_v1' => {
            'profile': {'username': 'my_name', 'display_name': 'My name'},
            'invite': null,
            'connections': <Object?>[],
          },
          'create_guardian_invite_v1' => {
            ...invite,
            'token': guardianTestToken,
          },
          'preview_guardian_invite_v1' => {
            ...invite,
            'username': 'driver_name',
            'display_name': 'Driver',
            'own_username': 'my_name',
            'own_display_name': 'My name',
          },
          _ => null,
        };
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-client',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    Future<void> signIn(String owner) async {
      String encoded(Object o) =>
          base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final jwt =
          '${encoded({'alg': 'HS256', 'typ': 'JWT'})}.${encoded({'sub': owner, 'exp': 4102444800, 'role': 'authenticated'})}.synthetic';
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': jwt,
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'role': 'authenticated',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
    }

    await signIn(userA);
    final gateway = SupabaseGuardianGateway(client);
    expect((await gateway.load(userA)).username, 'my_name');
    expect(calls.last, {
      'path': '/rest/v1/rpc/list_guardian_v1',
      'expected_user_id': userA,
    });
    final created = await gateway.create(
      userA,
      'my_name',
      'My name',
      guardianTestPermissions,
    );
    expect(created.token, guardianTestToken);
    expect(calls.last, {
      'path': '/rest/v1/rpc/create_guardian_invite_v1',
      'expected_user_id': userA,
      'expected_username': 'my_name',
      'expected_display_name': 'My name',
      'requested_permissions': guardianTestPermissions.toJson(),
    });
    await gateway.cancel(userA, created.id);
    expect(calls.last, {
      'path': '/rest/v1/rpc/cancel_guardian_invite_v1',
      'expected_user_id': userA,
      'invite_id': guardianTestId,
    });
    final preview = await gateway.preview(userA, guardianTestToken);
    expect(calls.last, {
      'path': '/rest/v1/rpc/preview_guardian_invite_v1',
      'expected_user_id': userA,
      'invite_token': guardianTestToken,
    });
    await gateway.accept(userA, preview!, guardianTestToken);
    expect(calls.last, {
      'path': '/rest/v1/rpc/accept_guardian_invite_v1',
      'expected_user_id': userA,
      'invite_id': guardianTestId,
      'invite_token': guardianTestToken,
      'expected_username': 'my_name',
      'expected_display_name': 'My name',
    });
    await gateway.change(userA, connection(), GuardianAction.confirm);
    expect(calls.last, {
      'path': '/rest/v1/rpc/change_guardian_connection_v1',
      'expected_user_id': userA,
      'connection_id': guardianTestId,
      'expected_revision': 1,
      'action_name': 'confirm',
      'requested_permissions': null,
    });
    await gateway.change(
      userA,
      connection(state: 'active'),
      GuardianAction.permissions,
      permissions: const GuardianPermissions(crash: false),
    );
    expect(
      calls.last['requested_permissions'],
      const GuardianPermissions(crash: false).toJson(),
    );
    final count = calls.length;
    await expectLater(
      gateway.preview(userA, 'bad'),
      throwsA(isA<GuardianException>()),
    );
    await expectLater(gateway.load(userB), throwsA(isA<GuardianException>()));
    expect(calls, hasLength(count));
    error = '40001';
    await expectLater(
      gateway.load(userA),
      throwsA(
        isA<GuardianException>().having(
          (e) => e.message,
          'message',
          isNot(contains(guardianTestToken)),
        ),
      ),
    );
    error = null;
    afterRequest = () => signIn(userB);
    await expectLater(
      gateway.create(userA, 'my_name', 'My name', guardianTestPermissions),
      throwsA(isA<GuardianException>()),
    );
  });
}
