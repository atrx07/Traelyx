import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';

import 'guardian_driver_activation_test.dart'
    show ownerA, ownerB, activation, capability;

void main() {
  test(
    'v2 SDK wire contract preserves bigint and exact cleanup identity',
    () async {
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => http.close(force: true));
      final calls = <Map<String, Object?>>[];
      Object? revisionReply = {'revision': '9007199254740993'};
      Future<void> Function()? afterRequest;
      final expiry = DateTime.now().toUtc().add(const Duration(hours: 7));
      http.listen((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        calls.add({'path': request.uri.path, ...body});
        await afterRequest?.call();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.endsWith('get_guardian_driver_revision_v2')
                ? revisionReply
                : body['credential'] == null
                ? {'enabled': false}
                : {
                    'enabled': true,
                    'activation_id': activation,
                    'expires_at': expiry.toIso8601String(),
                  },
          ),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${http.port}',
        'synthetic-public-client',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      Future<void> signIn(String owner) async {
        String encode(Object o) =>
            base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
        final jwt =
            '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': owner, 'exp': 4102444800, 'role': 'authenticated'})}.synthetic';
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

      await signIn(ownerA);
      final gateway = SupabaseGuardianDriverSessionGateway(client);
      // Construction/startup performs no revision read or session mutation.
      expect(calls, isEmpty);
      final revision = await gateway.revision(ownerA);
      expect(revision.value, '9007199254740993');
      expect(calls.single, {
        'path': '/rest/v1/rpc/get_guardian_driver_revision_v2',
        'expected_user_id': ownerA,
      });
      final draft = GuardianActivationDraft(
        ownerId: ownerA,
        activationId: activation,
        credential: capability,
        forwardAxis: '+y',
      );
      expect(
        (await gateway.activate(
          draft,
          DateTime.now().toUtc(),
          revision,
        )).activationId,
        activation,
      );
      expect(calls.last, {
        'path': '/rest/v1/rpc/set_guardian_driver_session_v2',
        'expected_user_id': ownerA,
        'activation': activation,
        'credential': capability,
        'expected_revision': '9007199254740993',
      });
      await gateway.revoke(ownerA, activation);
      expect(calls.last, {
        'path': '/rest/v1/rpc/set_guardian_driver_session_v2',
        'expected_user_id': ownerA,
        'activation': activation,
        'credential': null,
        'expected_revision': null,
      });
      revisionReply = {'revision': 9007199254740993};
      await expectLater(gateway.revision(ownerA), throwsFormatException);
      revisionReply = {'revision': '0'};
      for (final operation in <Future<Object?> Function()>[
        () => gateway.revision(ownerA),
        () => gateway.activate(draft, DateTime.now().toUtc(), revision),
        () async {
          await gateway.revoke(ownerA, activation);
          return null;
        },
      ]) {
        await signIn(ownerA);
        afterRequest = () => signIn(ownerB);
        await expectLater(
          operation(),
          throwsA(isA<GuardianActivationException>()),
        );
        afterRequest = null;
      }
      final count = calls.length;
      await expectLater(
        gateway.revision(ownerA),
        throwsA(isA<GuardianActivationException>()),
      );
      await expectLater(
        gateway.activate(draft, DateTime.now().toUtc(), revision),
        throwsA(isA<GuardianActivationException>()),
      );
      await expectLater(
        gateway.revoke(ownerA, activation),
        throwsA(isA<GuardianActivationException>()),
      );
      expect(calls.length, count);
    },
  );
}
