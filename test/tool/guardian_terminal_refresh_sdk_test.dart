import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';

import '../../tool/guardian_terminal_refresh_probe.dart';
import '../features/account/data/supabase_account_refresh_test.dart'
    show owner, sessionJson;
import '../features/guardian/guardian_sdk_refresh_test.dart'
    show NativeOwner, ServerRevoker, receipt;

void main() {
  for (final code in [
    'refresh_token_not_found',
    'session_not_found',
    'unrecognized_error',
  ]) {
    test(
      'pinned SDK own-session transport and terminal classification: $code',
      () async {
        final paths = <String>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final generated = sessionJson(
          owner,
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        );
        server.listen((request) async {
          paths.add(request.uri.path);
          expect(request.method, 'POST');
          await request.drain<void>();
          if (request.uri.path == '/auth/v1/logout') {
            expect(request.uri.queryParameters, {'scope': 'local'});
            expect(
              request.headers.value('authorization'),
              'Bearer ${generated['access_token']}',
            );
            request.response.statusCode = 204;
          } else {
            expect(request.uri.path, '/auth/v1/token');
            expect(request.uri.queryParameters, {
              'grant_type': 'refresh_token',
            });
            request.response.statusCode = 400;
            request.response.headers.set(
              'x-supabase-api-version',
              '2024-01-01',
            );
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'code': code,
                'message': 'private provider diagnostic',
              }),
            );
          }
          await request.response.close();
        });
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'synthetic-public',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);
        await client.auth.setInitialSession(jsonEncode(generated));
        final raw = SupabaseAccountGateway(client),
            native = NativeOwner(),
            revoker = ServerRevoker();
        final bound = GuardianBoundAccountGateway(
          raw,
          native,
          deviceRevoker: revoker,
        );
        addTearDown(bound.dispose);
        expect(await bound.ensureCurrentOwnerBound(), true);
        final source = SdkTerminalSessionSource(client, raw),
            marker = source.sessionMarker!;
        await source.revokeCurrentServerSession(marker);
        expect(source.owner, owner);
        expect(identical(source.sessionMarker, marker), true);
        expect(native.local, receipt);
        expect(native.pending, isEmpty);
        final result = await source.refreshOnce(marker);
        expect(
          result,
          code == 'unrecognized_error'
              ? TerminalRefreshResult.uncertain
              : TerminalRefreshResult.rejected,
        );
        if (result == TerminalRefreshResult.rejected) {
          expect(await bound.ensureCurrentOwnerBound(), true);
          expect(native.local, isNull);
          expect(native.pending, [receipt]);
          expect(revoker.calls, isEmpty);
        }
        expect(paths, ['/auth/v1/logout', '/auth/v1/token']);
        await expectLater(
          source.revokeCurrentServerSession(Object()),
          throwsA(isA<FormatException>()),
        );
        expect(paths.length, 2);
      },
    );
  }
}
