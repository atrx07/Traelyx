import 'dart:async';
import 'dart:convert';

enum LocalFailure {
  unavailable,
  incompatible,
  storage,
  integrity,
  space,
  cancelled,
  busy,
  stale,
  notParked,
  malformed,
  timeout,
}

class LocalCommentaryException implements Exception {
  const LocalCommentaryException(this.failure);
  final LocalFailure failure;
  @override
  String toString() => 'Local commentary: ${failure.name}';
}

String localFailureMessage(Object error) => switch (error) {
  LocalCommentaryException(failure: LocalFailure.integrity) =>
    'Model verification failed. Kept for explicit removal; the built-in narrator remains available.',
  LocalCommentaryException(failure: LocalFailure.space) =>
    'Not enough free storage for this model and its safety reserve.',
  LocalCommentaryException(failure: LocalFailure.cancelled) =>
    'Local action cancelled.',
  LocalCommentaryException(failure: LocalFailure.busy) =>
    'Another local model action is in progress.',
  LocalCommentaryException(failure: LocalFailure.stale) =>
    'The model or review changed. Review again.',
  LocalCommentaryException(failure: LocalFailure.notParked) =>
    'Confirm you are parked and finish recording first.',
  LocalCommentaryException(failure: LocalFailure.malformed) =>
    'The local result did not match the reviewed wording choices.',
  LocalCommentaryException(failure: LocalFailure.timeout) =>
    'Local action timed out. No automatic retry was made.',
  LocalCommentaryException(failure: LocalFailure.incompatible) =>
    'This model and runtime do not support this device or commentary contract.',
  LocalCommentaryException(failure: LocalFailure.unavailable) =>
    'No accepted local model and runtime are available.',
  _ =>
    'Local model storage is unavailable. The built-in narrator remains available.',
};

class LocalCancellation {
  final _done = Completer<void>();
  bool get cancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;
  void cancel() {
    if (!cancelled) _done.complete();
  }

  void check() {
    if (cancelled) throw const LocalCommentaryException(LocalFailure.cancelled);
  }

  Future<T> race<T>(Future<T> work) {
    check();
    return Future.any([
      work,
      whenCancelled.then<T>(
        (_) => throw const LocalCommentaryException(LocalFailure.cancelled),
      ),
    ]);
  }
}

/// A reviewed, bundled data artifact. Source/license links are metadata, never
/// executable endpoints. Trust comes from the app release, not a remote manifest.
class LocalModelManifest {
  LocalModelManifest._(this.values);
  static const maximumBytes = 512 * 1024 * 1024;
  static const reserveBytes = 64 * 1024 * 1024;
  static const _keys = {
    'schemaVersion',
    'id',
    'revision',
    'sha256',
    'bytes',
    'format',
    'runtime',
    'runtimeVersion',
    'minAndroidApi',
    'abis',
    'license',
    'source',
    'evidence',
    'contractVersion',
  };
  final Map<String, Object?> values;
  String get id => values['id']! as String;
  String get revision => values['revision']! as String;
  String get digest => values['sha256']! as String;
  int get bytes => values['bytes']! as int;
  String get format => values['format']! as String;
  String get runtime => values['runtime']! as String;
  String get runtimeVersion => values['runtimeVersion']! as String;
  int get minAndroidApi => values['minAndroidApi']! as int;
  List<String> get abis => values['abis']! as List<String>;
  String get encoded => jsonEncode(values);

  factory LocalModelManifest.parse(Object? input) {
    bool slug(Object? v) =>
        v is String && RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(v);
    bool link(Object? v) {
      if (v is! String || v.length > 300) return false;
      final uri = Uri.tryParse(v);
      return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment;
    }

    if (input is! Map ||
        input.length != _keys.length ||
        !_keys.every(input.containsKey) ||
        input['schemaVersion'] is! int ||
        input['schemaVersion'] != 1 ||
        input['contractVersion'] is! int ||
        input['contractVersion'] != 1 ||
        ![
          'id',
          'revision',
          'runtime',
          'runtimeVersion',
        ].every((k) => slug(input[k])) ||
        input['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(input['sha256'] as String) ||
        input['bytes'] is! int ||
        (input['bytes'] as int) <= 0 ||
        (input['bytes'] as int) > maximumBytes ||
        !const ['gguf', 'litertlm'].contains(input['format']) ||
        input['minAndroidApi'] is! int ||
        (input['minAndroidApi'] as int) < 26 ||
        (input['minAndroidApi'] as int) > 100 ||
        input['abis'] is! List ||
        (input['abis'] as List).isEmpty ||
        (input['abis'] as List).length > 4 ||
        (input['abis'] as List).any(
          (v) =>
              !const ['arm64-v8a', 'x86_64', 'armeabi-v7a', 'x86'].contains(v),
        ) ||
        (input['abis'] as List).toSet().length !=
            (input['abis'] as List).length ||
        !link(input['license']) ||
        !link(input['source']) ||
        input['evidence'] is! String ||
        !RegExp(
          r'^docs/reference/[a-z0-9][a-z0-9_-]{0,99}\.json$',
        ).hasMatch(input['evidence'] as String)) {
      throw const LocalCommentaryException(LocalFailure.incompatible);
    }
    return LocalModelManifest._(
      Map.unmodifiable({
        for (final key in _keys)
          key: key == 'abis'
              ? List<String>.unmodifiable((input[key] as List).cast<String>())
              : input[key],
      }),
    );
  }
}

class LocalModelCatalog {
  LocalModelCatalog._(this.models);
  final List<LocalModelManifest> models;
  factory LocalModelCatalog.parse(String source) {
    try {
      if (utf8.encode(source).length > 32768) throw const FormatException();
      final value = jsonDecode(source);
      if (value is! Map ||
          value.length != 2 ||
          value['schemaVersion'] is! int ||
          value['schemaVersion'] != 1 ||
          value['models'] is! List ||
          (value['models'] as List).length > 8) {
        throw const FormatException();
      }
      final models = (value['models'] as List)
          .map(LocalModelManifest.parse)
          .toList();
      if (models.map((m) => m.id).toSet().length != models.length ||
          models.map((m) => m.digest).toSet().length != models.length) {
        throw const FormatException();
      }
      return LocalModelCatalog._(List.unmodifiable(models));
    } catch (_) {
      throw const LocalCommentaryException(LocalFailure.incompatible);
    }
  }
  bool accepts(LocalModelManifest model) =>
      models.any((m) => m.encoded == model.encoded);
}

class LocalDevice {
  LocalDevice({
    required this.root,
    required this.androidApi,
    required List<String> abis,
    required this.freeBytes,
  }) : abis = List.unmodifiable(abis);
  final String root;
  final int androidApi;
  final List<String> abis;
  final int freeBytes;
}

class LocalRuntimeCapabilities {
  const LocalRuntimeCapabilities({
    required this.id,
    required this.version,
    required this.formats,
    required this.offline,
    required this.cancellable,
  });
  final String id;
  final String version;
  final Set<String> formats;
  final bool offline;
  final bool cancellable;
  bool supports(LocalModelManifest m, LocalDevice d) =>
      offline &&
      cancellable &&
      id == m.runtime &&
      version == m.runtimeVersion &&
      formats.contains(m.format) &&
      d.androidApi >= m.minAndroidApi &&
      d.abis.any(m.abis.contains);
}

abstract interface class LocalArtifactSource {
  /// Must be data-only, pinned to the bundled manifest and cancellable. A future
  /// network adapter needs its own endpoint/redirect/timeout review.
  bool supports(LocalModelManifest manifest);
  Stream<List<int>> open(
    LocalModelManifest manifest,
    LocalCancellation cancellation,
  );
}

abstract interface class LocalCommentaryRuntime {
  LocalRuntimeCapabilities? get capabilities;

  /// Owns its worker/session and must release it before this Future completes,
  /// including cancellation. The returned UTF-8 JSON is bounded to 1024 bytes.
  Future<String> select({
    required String artifactPath,
    required String inputJson,
    required LocalCancellation cancellation,
  });
}

class UnavailableLocalRuntime implements LocalCommentaryRuntime {
  const UnavailableLocalRuntime();
  @override
  LocalRuntimeCapabilities? get capabilities => null;
  @override
  Future<String> select({
    required String artifactPath,
    required String inputJson,
    required LocalCancellation cancellation,
  }) async => throw const LocalCommentaryException(LocalFailure.unavailable);
}

class UnavailableLocalSource implements LocalArtifactSource {
  const UnavailableLocalSource();
  @override
  bool supports(LocalModelManifest manifest) => false;
  @override
  Stream<List<int>> open(
    LocalModelManifest manifest,
    LocalCancellation cancellation,
  ) => Stream.error(const LocalCommentaryException(LocalFailure.unavailable));
}
