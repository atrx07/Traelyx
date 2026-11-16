import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/cloud_commentary/data/groq_commentary_provider.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'cloud_fixture.dart';

void main() {
  const credential = 'fixture-placeholder';
  Map<String, Object?> reply(Object? content) => {
    'model': 'llama-fixture',
    'choices': [
      {
        'finish_reason': 'stop',
        'message': {'role': 'assistant', 'content': jsonEncode(content)},
      },
    ],
  };
  test(
    'Groq request is fixed, bounded, non-streamed, and accepts only reviewed wording',
    () async {
      final transport = _Transport(
        CloudHttpResponse(
          200,
          jsonEncode(
            reply({
              'choices': [1, 0],
            }),
          ),
        ),
      );
      final provider = GroqCommentaryProvider(transport);
      final dossier = CommentaryDossier.fromPlan(fixturePlan());
      final result = await provider.generate(
        credential: credential,
        model: 'llama-fixture',
        dossier: dossier,
        cancellation: CloudCancellation(),
      );
      expect(
        result.moments.first.text,
        dossier.plan.choicesFor(dossier.plan.moments.first)[1],
      );
      expect(transport.path, 'chat/completions');
      final body = jsonDecode(transport.body!) as Map;
      expect(body['max_completion_tokens'], 256);
      expect(body['stream'], false);
      expect(body['messages'][1]['content'], jsonEncode(dossier.payload));
      expect(jsonEncode(body), isNot(contains(credential)));
      expect(body.containsKey('tools'), false);
    },
  );
  test(
    'all provider failures normalize without echoing arbitrary error bodies',
    () async {
      const failures = {
        401: CloudFailure.credential,
        403: CloudFailure.credential,
        429: CloudFailure.rateLimit,
        404: CloudFailure.modelUnavailable,
        400: CloudFailure.unsupported,
        422: CloudFailure.unsupported,
        408: CloudFailure.timeout,
        504: CloudFailure.timeout,
        503: CloudFailure.server,
        302: CloudFailure.network,
      };
      for (final entry in failures.entries) {
        final transport = _Transport(
          CloudHttpResponse(entry.key, 'private echoed credential and route'),
        );
        await expectLater(
          GroqCommentaryProvider(
            transport,
          ).listModels(credential, CloudCancellation()),
          throwsA(
            isA<CloudException>()
                .having((e) => e.failure, 'normalized', entry.value)
                .having(
                  (e) => e.toString(),
                  'no echo',
                  isNot(contains('private')),
                ),
          ),
        );
        expect(transport.calls, 1);
      }
    },
  );
  test(
    'malformed/refused/injected/wrong model/truncated outputs never enter narration',
    () async {
      final invalid = <Object?>[
        'not json',
        <Object?>[],
        {'model': 'other', 'choices': <Object?>[]},
        reply({
          'choices': [0, 0],
          'text': 'unsafe',
        }),
        reply({
          'choices': [99, 0],
        }),
        {
          'model': 'llama-fixture',
          'choices': [
            {
              'finish_reason': 'length',
              'message': {'role': 'assistant', 'content': '{}'},
            },
          ],
        },
        {
          'model': 'llama-fixture',
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {
                'role': 'assistant',
                'content': '{}',
                'tool_calls': [<String, Object?>{}],
              },
            },
          ],
        },
        {
          'model': 'llama-fixture',
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {
                'role': 'assistant',
                'content': '{}',
                'refusal': 'private',
              },
            },
          ],
        },
        reply({
          'choices': [0, 0],
        }),
      ];
      for (var i = 0; i < invalid.length - 1; i++) {
        final transport = _Transport(
          CloudHttpResponse(
            200,
            invalid[i] is String
                ? invalid[i]! as String
                : jsonEncode(invalid[i]),
          ),
        );
        await expectLater(
          GroqCommentaryProvider(transport).generate(
            credential: credential,
            model: 'llama-fixture',
            dossier: CommentaryDossier.fromPlan(fixturePlan()),
            cancellation: CloudCancellation(),
          ),
          throwsA(isA<CloudException>()),
        );
      }
    },
  );
  test(
    'catalog validates types, active state and duplicate IDs without trusting capability',
    () async {
      final transport = _Transport(
        const CloudHttpResponse(
          200,
          '{"object":"list","data":[{"id":"llama-future","active":true,"context_window":8192},{"id":"old","active":false}]}',
        ),
      );
      expect(
        (await GroqCommentaryProvider(
          transport,
        ).listModels(credential, CloudCancellation())).single.id,
        'llama-future',
      );
      for (final body in [
        '{}',
        '{"object":"list","data":[{"id":"bad\\nsecret"}]}',
        '{"object":"list","data":[{"id":"same"},{"id":"same"}]}',
      ]) {
        transport.response = CloudHttpResponse(200, body);
        await expectLater(
          GroqCommentaryProvider(
            transport,
          ).listModels(credential, CloudCancellation()),
          throwsA(isA<CloudException>()),
        );
      }
    },
  );
  test(
    'transport fixes HTTPS origin, sets auth only in headers and never follows redirects',
    () async {
      final client = _Client(_Response(302, [utf8.encode('redirect')]));
      final transport = GroqHttpTransport(createClient: () => client);
      await transport.send(
        path: 'models',
        credential: credential,
        cancellation: CloudCancellation(),
      );
      expect(client.uri, Uri.parse('https://api.groq.com/openai/v1/models'));
      expect(client.method, 'GET');
      expect(client.request.followRedirects, false);
      expect(
        client.request.headers.values[HttpHeaders.authorizationHeader],
        'Bearer $credential',
      );
      expect(client.closed, true);
    },
  );
  test(
    'transport rejects expanded paths/headers and caps streamed body size',
    () async {
      final client = _Client(
        _Response(200, [List.filled(32768, 32), List.filled(32769, 32)]),
      );
      final transport = GroqHttpTransport(createClient: () => client);
      await expectLater(
        transport.send(
          path: 'https://evil.test',
          credential: credential,
          cancellation: CloudCancellation(),
        ),
        throwsA(isA<CloudException>()),
      );
      expect(client.uri, null);
      await expectLater(
        transport.send(
          path: 'models',
          credential: 'bad\nheader',
          cancellation: CloudCancellation(),
        ),
        throwsA(isA<CloudException>()),
      );
      await expectLater(
        transport.send(
          path: 'models',
          credential: credential,
          cancellation: CloudCancellation(),
        ),
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'size',
            CloudFailure.malformed,
          ),
        ),
      );
      expect(client.closed, true);
    },
  );
  test(
    'cancelling an open HTTP operation aborts the client and reports cancellation',
    () async {
      final client = _Client(_Response(200, const []))
        ..opening = Completer<HttpClientRequest>();
      final token = CloudCancellation();
      final operation = GroqHttpTransport(
        createClient: () => client,
      ).send(path: 'models', credential: credential, cancellation: token);
      final rejected = expectLater(
        operation,
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'cancelled',
            CloudFailure.cancelled,
          ),
        ),
      );
      token.cancel();
      await rejected;
      expect(client.closed, true);
    },
  );
  test(
    'transport timeout closes the socket and cancellation aborts in-flight reads',
    () async {
      final client = _Client(_Response(200, const []))
        ..opening = Completer<HttpClientRequest>();
      await expectLater(
        GroqHttpTransport(
          createClient: () => client,
          timeout: const Duration(milliseconds: 5),
        ).send(
          path: 'models',
          credential: credential,
          cancellation: CloudCancellation(),
        ),
        throwsA(
          isA<CloudException>().having(
            (e) => e.failure,
            'timeout',
            CloudFailure.timeout,
          ),
        ),
      );
      expect(client.closed, true);
      final token = CloudCancellation();
      var aborted = false;
      token.attach(() => aborted = true);
      token.cancel();
      expect(aborted, true);
      expect(() => token.check(), throwsA(isA<CloudException>()));
      final before = _Client(_Response(200, const []));
      await expectLater(
        GroqHttpTransport(
          createClient: () => before,
        ).send(path: 'models', credential: credential, cancellation: token),
        throwsA(isA<CloudException>()),
      );
      expect(before.uri, null);
    },
  );
}

class _Transport implements CloudHttpTransport {
  _Transport(this.response);
  CloudHttpResponse response;
  String? path;
  String? body;
  int calls = 0;
  @override
  Future<CloudHttpResponse> send({
    required String path,
    required String credential,
    String? body,
    required CloudCancellation cancellation,
  }) async {
    calls++;
    this.path = path;
    this.body = body;
    return response;
  }
}

class _Client implements HttpClient {
  _Client(this.response);
  final _Response response;
  final request = _Request();
  Uri? uri;
  String? method;
  bool closed = false;
  Completer<HttpClientRequest>? opening;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    this.method = method;
    uri = url;
    request.response = response;
    return opening?.future ?? Future.value(request);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    if (opening != null && !opening!.isCompleted) {
      opening!.completeError(StateError('request closed'));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  late _Response response;
  @override
  final _Headers headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  void write(Object? value) {}
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  set contentType(ContentType? value) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.chunks);
  final List<List<int>> chunks;
  @override
  final int statusCode;
  @override
  int get contentLength => -1;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.fromIterable(chunks).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
