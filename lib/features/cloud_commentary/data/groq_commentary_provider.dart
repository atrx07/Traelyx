import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

class CloudHttpResponse {
  const CloudHttpResponse(this.status, this.body);
  final int status;
  final String body;
}

abstract interface class CloudHttpTransport {
  Future<CloudHttpResponse> send({
    required String path,
    required String credential,
    String? body,
    required CloudCancellation cancellation,
  });
}

class GroqHttpTransport implements CloudHttpTransport {
  GroqHttpTransport({
    HttpClient Function()? createClient,
    this.timeout = const Duration(seconds: 15),
  }) : _createClient = createClient ?? HttpClient.new;
  final HttpClient Function() _createClient;
  final Duration timeout;
  @override
  Future<CloudHttpResponse> send({
    required String path,
    required String credential,
    String? body,
    required CloudCancellation cancellation,
  }) async {
    if (!const {'models', 'chat/completions'}.contains(path) ||
        (path == 'models') != (body == null) ||
        !RegExp(r'^[A-Za-z0-9_-]{8,256}$').hasMatch(credential) ||
        (body != null && utf8.encode(body).length > 16384)) {
      throw const CloudException(CloudFailure.unsupported);
    }
    cancellation.check();
    final client = _createClient();
    void abort() => client.close(force: true);
    cancellation.attach(abort);
    try {
      return await (() async {
        final request = await client.openUrl(
          body == null ? 'GET' : 'POST',
          Uri.https('api.groq.com', '/openai/v1/$path'),
        );
        cancellation.check();
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $credential',
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(body);
        }
        final response = await request.close();
        if (response.contentLength > 65536) {
          throw const CloudException(CloudFailure.malformed);
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          cancellation.check();
          if (bytes.length + chunk.length > 65536) {
            throw const CloudException(CloudFailure.malformed);
          }
          bytes.addAll(chunk);
        }
        cancellation.check();
        return CloudHttpResponse(response.statusCode, utf8.decode(bytes));
      })().timeout(
        timeout,
        onTimeout: () {
          abort();
          throw const CloudException(CloudFailure.timeout);
        },
      );
    } on CloudException {
      rethrow;
    } catch (_) {
      cancellation.check();
      throw const CloudException(CloudFailure.network);
    } finally {
      cancellation.detach();
      abort();
    }
  }
}

class GroqCommentaryProvider implements CommentaryProvider {
  const GroqCommentaryProvider(this.transport);
  final CloudHttpTransport transport;
  @override
  String get id => 'groq';
  Future<Map<String, dynamic>> _request({
    required String path,
    required String credential,
    String? body,
    required CloudCancellation cancellation,
  }) async {
    final response = await transport.send(
      path: path,
      credential: credential,
      body: body,
      cancellation: cancellation,
    );
    cancellation.check();
    final error = switch (response.status) {
      200 => null,
      401 || 403 => CloudFailure.credential,
      429 => CloudFailure.rateLimit,
      404 => CloudFailure.modelUnavailable,
      408 || 504 => CloudFailure.timeout,
      400 || 422 => CloudFailure.unsupported,
      >= 500 => CloudFailure.server,
      _ => CloudFailure.network,
    };
    if (error != null) throw CloudException(error);
    if (utf8.encode(response.body).length > 65536) {
      throw const CloudException(CloudFailure.malformed);
    }
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } catch (_) {
      throw const CloudException(CloudFailure.malformed);
    }
  }

  @override
  Future<List<CloudModel>> listModels(
    String credential,
    CloudCancellation cancellation,
  ) async {
    final response = await _request(
      path: 'models',
      credential: credential,
      cancellation: cancellation,
    );
    final data = response['data'];
    if (response['object'] != 'list' || data is! List || data.length > 256) {
      throw const CloudException(CloudFailure.malformed);
    }
    final models = <CloudModel>[];
    final ids = <String>{};
    for (final row in data) {
      if (row is! Map ||
          row['id'] is! String ||
          !validCloudModelId(row['id'] as String) ||
          !ids.add(row['id'] as String)) {
        throw const CloudException(CloudFailure.malformed);
      }
      if (row['active'] == false) continue;
      if (row['active'] != true ||
          row['context_window'] is! int ||
          (row['context_window'] as int) < 0) {
        continue;
      }
      models.add(CloudModel(row['id'] as String, row['context_window'] as int));
    }
    return List.unmodifiable(models);
  }

  @override
  Future<ProceduralCommentaryPlan> generate({
    required String credential,
    required String model,
    required CommentaryDossier dossier,
    required CloudCancellation cancellation,
  }) async {
    if (!validCloudModelId(model)) {
      throw const CloudException(CloudFailure.unsupported);
    }
    final response = await _request(
      path: 'chat/completions',
      credential: credential,
      cancellation: cancellation,
      body: jsonEncode({
        'model': model,
        'stream': false,
        'temperature': 0.3,
        'max_completion_tokens': 256,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'Choose reviewed commentary wording for each moment in order. Use context and tone to avoid repetition. Return only JSON with one key choices: an array of zero-based integer wordingChoices indices, one per moment. Never add facts, commentary text, tools, reasoning or other fields.',
          },
          {'role': 'user', 'content': jsonEncode(dossier.payload)},
        ],
      }),
    );
    try {
      final choices = response['choices'];
      if (response['model'] != model ||
          choices is! List ||
          choices.length != 1) {
        throw const FormatException();
      }
      final row = choices.single as Map;
      final message = row['message'] as Map;
      if (message['refusal'] != null ||
          row['finish_reason'] == 'content_filter') {
        throw const CloudException(CloudFailure.refused);
      }
      if (row['finish_reason'] != 'stop' ||
          message['role'] != 'assistant' ||
          message['content'] is! String ||
          (message['tool_calls'] != null &&
              (message['tool_calls'] is! List ||
                  (message['tool_calls'] as List).isNotEmpty))) {
        throw const FormatException();
      }
      cancellation.check();
      return dossier.apply(jsonDecode(message['content'] as String));
    } on CloudException {
      rethrow;
    } catch (_) {
      throw const CloudException(CloudFailure.malformed);
    }
  }
}
