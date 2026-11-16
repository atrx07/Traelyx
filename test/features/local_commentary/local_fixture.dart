import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_service.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

final fixtureBytes = List<int>.generate(137, (i) => i % 256);
Map<String, Object?> fixtureManifestValues() => {
  'schemaVersion': 1,
  'id': 'generated-fixture',
  'revision': 'v1',
  'sha256': sha256.convert(fixtureBytes).toString(),
  'bytes': fixtureBytes.length,
  'format': 'gguf',
  'runtime': 'fixture',
  'runtimeVersion': 'v1',
  'minAndroidApi': 26,
  'abis': ['arm64-v8a', 'x86_64'],
  'license': 'https://example.org/license',
  'source': 'https://example.org/source',
  'evidence': 'docs/reference/generated-fixture.json',
  'contractVersion': 1,
};
LocalModelManifest fixtureManifest() =>
    LocalModelManifest.parse(fixtureManifestValues());
LocalModelCatalog fixtureCatalog() => LocalModelCatalog.parse(
  jsonEncode({
    'schemaVersion': 1,
    'models': [fixtureManifestValues()],
  }),
);

class FixtureSource implements LocalArtifactSource {
  int opens = 0;
  bool supported = true;
  @override
  bool supports(LocalModelManifest m) => supported;
  @override
  Stream<List<int>> open(LocalModelManifest m, LocalCancellation c) async* {
    opens++;
    c.check();
    yield fixtureBytes;
  }
}

class FixtureRuntime implements LocalCommentaryRuntime {
  int calls = 0;
  String? input;
  String response = '{"choices":[1,0]}';
  Future<String> Function(LocalCancellation)? handler;
  @override
  LocalRuntimeCapabilities? capabilities = const LocalRuntimeCapabilities(
    id: 'fixture',
    version: 'v1',
    formats: {'gguf'},
    offline: true,
    cancellable: true,
  );
  @override
  Future<String> select({
    required String artifactPath,
    required String inputJson,
    required LocalCancellation cancellation,
  }) async {
    calls++;
    input = inputJson;
    if (!await File(artifactPath).exists()) throw StateError('Missing fixture');
    return handler != null ? handler!(cancellation) : response;
  }
}

LocalDevice fixtureDevice(
  Directory root, {
  int? freeBytes,
  int api = 37,
  List<String> abis = const ['x86_64'],
}) => LocalDevice(
  root: root.path,
  androidApi: api,
  abis: abis,
  freeBytes: freeBytes ?? 1024 * 1024 * 1024,
);
LocalCommentaryService fixtureService(
  Directory root, {
  FixtureRuntime? runtime,
  FixtureSource? source,
  Future<bool> Function()? idle,
  Future<LocalModelCatalog> Function()? catalog,
  Future<LocalDevice> Function()? device,
  Duration? budget,
}) => LocalCommentaryService(
  catalog: catalog ?? () async => fixtureCatalog(),
  device: device ?? () async => fixtureDevice(root),
  runtime: runtime ?? FixtureRuntime(),
  source: source ?? FixtureSource(),
  isRecorderIdle: idle ?? () async => true,
  operationBudget: budget ?? const Duration(seconds: 10),
);
