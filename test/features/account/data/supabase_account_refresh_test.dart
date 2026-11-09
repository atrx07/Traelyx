import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';

const owner = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> sessionJson(String user, int expires) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': user, 'exp': expires, 'role': 'authenticated'})}.synthetic',
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expires,
    'user': {
      'id': user,
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

void main() {
  test(
    'retryable SDK refresh failure never becomes an identity-stream error',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        expect(request.uri.path, '/auth/v1/token');
        request.response.statusCode = 503;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'message': 'synthetic unavailable'}),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-public-client',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode(
          sessionJson(
            owner,
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        ),
      );
      final account = SupabaseAccountGateway(client);
      final identities = <AccountIdentity?>[];
      final errors = <Object>[];
      final subscription = account.identityChanges.listen(
        identities.add,
        onError: errors.add,
      );
      addTearDown(subscription.cancel);
      await expectLater(
        account.refreshSession(),
        throwsA(isA<AuthRetryableFetchException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(account.currentIdentity?.userId, owner);
      expect(identities.where((value) => value == null), isEmpty);
      expect(errors, isEmpty);
    },
  );
}
