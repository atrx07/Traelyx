import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

class LocalModelInventory {
  const LocalModelInventory(this.bytes, this.artifacts, this.partials);
  final int bytes;
  final int artifacts;
  final int partials;
}

/// Only this fixed no-backup namespace is owned here. Never recursively deletes,
/// follows links, adopts user files or publishes unverified data. No network IO.
class LocalModelStore {
  LocalModelStore(Directory root) : root = _normalized(root);
  static Directory _normalized(Directory root) {
    var path = Directory.fromUri(root.absolute.uri.normalizePath()).path;
    while (path.length > 3 && path.endsWith(Platform.pathSeparator)) {
      path = path.substring(0, path.length - 1);
    }
    return Directory(path);
  }

  final Directory root;
  static final _busyRoots = <String>{};
  static final _directoryName = RegExp(r'^[a-f0-9]{64}(\.partial)?$');
  static const _fileNames = {'weights', 'receipt.json'};

  Future<T> exclusive<T>(
    Future<T> Function(LocalModelLease lease) action,
  ) async {
    final path = root.absolute.path;
    if (!_busyRoots.add(path)) {
      throw const LocalCommentaryException(LocalFailure.busy);
    }
    RandomAccessFile? lock;
    var locked = false;
    try {
      if (await FileSystemEntity.type(path, followLinks: false) !=
              FileSystemEntityType.directory ||
          await root.resolveSymbolicLinks() != path) {
        throw const LocalCommentaryException(LocalFailure.storage);
      }
      final lockFile = File('$path${Platform.pathSeparator}.lock');
      final type = await FileSystemEntity.type(
        lockFile.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const LocalCommentaryException(LocalFailure.storage);
      }
      lock = await lockFile.open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException {
        throw const LocalCommentaryException(LocalFailure.busy);
      }
      final lease = LocalModelLease._(root);
      try {
        return await action(lease);
      } finally {
        lease._active = false;
      }
    } on LocalCommentaryException {
      rethrow;
    } on FileSystemException {
      throw const LocalCommentaryException(LocalFailure.storage);
    } finally {
      try {
        if (locked) await lock?.unlock();
      } finally {
        try {
          await lock?.close();
        } finally {
          _busyRoots.remove(path);
        }
      }
    }
  }

  Future<LocalModelInventory> inventory() =>
      exclusive((lease) => lease.inventory());
  Future<void> removeAll() => exclusive((lease) => lease.removeAll());
}

/// An exclusive lease spans verification AND runtime use; removal cannot race
/// an open model. The lease cannot be used after its owning action completes.
class LocalModelLease {
  LocalModelLease._(this._root);
  final Directory _root;
  bool _active = true;
  void _check() {
    if (!_active) throw const LocalCommentaryException(LocalFailure.stale);
  }

  Directory _directory(String digest, {bool partial = false}) {
    _check();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const LocalCommentaryException(LocalFailure.integrity);
    }
    return Directory(
      '${_root.path}${Platform.pathSeparator}$digest${partial ? '.partial' : ''}',
    );
  }

  File _file(Directory dir, String name) =>
      File('${dir.path}${Platform.pathSeparator}$name');

  Future<List<Directory>> _directories() async {
    _check();
    final result = <Directory>[];
    await for (final entity in _root.list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name == '.lock' && entity is File && await entity.length() == 0) {
        continue;
      }
      if (entity is! Directory ||
          !LocalModelStore._directoryName.hasMatch(name) ||
          result.length >= 16) {
        throw const LocalCommentaryException(LocalFailure.storage);
      }
      result.add(entity);
    }
    return result;
  }

  Future<List<File>> _files(Directory dir) async {
    _check();
    if (await FileSystemEntity.type(dir.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const LocalCommentaryException(LocalFailure.storage);
    }
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File ||
          !LocalModelStore._fileNames.contains(
            entity.path.split(Platform.pathSeparator).last,
          )) {
        throw const LocalCommentaryException(LocalFailure.storage);
      }
      files.add(entity);
    }
    return files;
  }

  Future<LocalModelInventory> inventory() async {
    var bytes = 0, artifacts = 0, partials = 0;
    for (final dir in await _directories()) {
      if (dir.path.endsWith('.partial')) {
        partials++;
      } else {
        artifacts++;
      }
      for (final file in await _files(dir)) {
        bytes += await file.length();
      }
    }
    return LocalModelInventory(bytes, artifacts, partials);
  }

  Future<void> _remove(Directory dir) async {
    final files = await _files(dir);
    for (final file in files) {
      await file.delete();
    }
    await dir.delete();
  }

  Future<void> removeAll() async {
    final dirs = await _directories();
    // Validate every child before deleting any; refuse unowned/link contents.
    for (final dir in dirs) {
      await _files(dir);
    }
    for (final dir in dirs) {
      await _remove(dir);
    }
  }

  Future<void> install(
    LocalModelManifest model,
    Stream<List<int>> source,
    LocalCancellation cancellation,
  ) async {
    _check();
    cancellation.check();
    final current = await inventory();
    if (current.artifacts + current.partials >= 16) {
      throw const LocalCommentaryException(LocalFailure.storage);
    }
    final target = _directory(model.digest);
    final stage = _directory(model.digest, partial: true);
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(stage.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw const LocalCommentaryException(LocalFailure.stale);
    }
    await stage.create();
    RandomAccessFile? file;
    final iterator = StreamIterator(source);
    var published = false;
    try {
      file = await _file(stage, 'weights').open(mode: FileMode.write);
      var bytes = 0;
      while (await cancellation.race(iterator.moveNext())) {
        cancellation.check();
        final chunk = iterator.current;
        if (chunk.isEmpty) {
          throw const LocalCommentaryException(LocalFailure.integrity);
        }
        if (chunk.length > 65536 ||
            chunk.any((v) => v < 0 || v > 255) ||
            bytes + chunk.length > model.bytes) {
          throw const LocalCommentaryException(LocalFailure.integrity);
        }
        bytes += chunk.length;
        await file.writeFrom(chunk);
      }
      if (bytes != model.bytes) {
        throw const LocalCommentaryException(LocalFailure.integrity);
      }
      await file.flush();
      await file.close();
      file = null;
      if (await verifiedSha256(_file(stage, 'weights'), cancellation) !=
          model.digest) {
        throw const LocalCommentaryException(LocalFailure.integrity);
      }
      await _file(
        stage,
        'receipt.json',
      ).writeAsString(model.encoded, flush: true);
      cancellation.check();
      await stage.rename(target.path);
      published = true;
    } on LocalCommentaryException {
      rethrow;
    } catch (_) {
      throw const LocalCommentaryException(LocalFailure.storage);
    } finally {
      // A production source must honour cancellation and close promptly.
      try {
        await iterator.cancel();
      } finally {
        try {
          await file?.close();
        } finally {
          if (!published) await _remove(stage);
        }
      }
    }
  }

  Future<String> verifiedPath(
    LocalModelManifest model,
    LocalCancellation cancellation,
  ) async {
    _check();
    cancellation.check();
    final dir = _directory(model.digest);
    final files = await _files(dir);
    final receipt = _file(dir, 'receipt.json');
    final weights = _file(dir, 'weights');
    if (files.length != 2 ||
        await receipt.length() > 4096 ||
        await weights.length() != model.bytes ||
        await receipt.readAsString() != model.encoded ||
        await verifiedSha256(weights, cancellation) != model.digest) {
      throw const LocalCommentaryException(LocalFailure.integrity);
    }
    cancellation.check();
    return weights.path;
  }
}

/// The read-only worker owns and explicitly closes its file before acknowledging
/// cancellation or completion. Isolate exit alone does not guarantee that native
/// file finalizers have run (notably on Windows). Keep the lease until both ACK
/// and exit; never abandon a live verifier or force-kill it with an open file.
Future<String> verifiedSha256(File file, LocalCancellation cancellation) async {
  cancellation.check();
  final port = ReceivePort(), exitPort = ReceivePort();
  final exited = exitPort.first;
  final completion = Completer<Object>();
  SendPort? control;
  var timedOut = false;
  final subscription = port.listen((message) {
    if (message is SendPort) {
      control = message;
      if (cancellation.cancelled || timedOut) control!.send(null);
    } else if (!completion.isCompleted) {
      completion.complete(message ?? false);
    }
  });
  unawaited(cancellation.whenCancelled.then((_) => control?.send(null)));
  final timer = Timer(const Duration(minutes: 2), () {
    timedOut = true;
    control?.send(null);
  });
  Isolate? worker;
  try {
    worker = await Isolate.spawn(
      _hashWorker,
      [file.path, port.sendPort],
      onError: port.sendPort,
      onExit: exitPort.sendPort,
    );
    final result = await completion.future;
    if (timedOut) {
      throw const LocalCommentaryException(LocalFailure.timeout);
    }
    cancellation.check();
    if (result is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(result)) {
      throw const LocalCommentaryException(LocalFailure.integrity);
    }
    return result;
  } finally {
    timer.cancel();
    try {
      if (worker != null) await exited;
    } finally {
      await subscription.cancel();
      port.close();
      exitPort.close();
    }
  }
}

class _HashDigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest value) {
    digest = value;
  }

  @override
  void close() {}
}

void _hashWorker(List<Object> arguments) async {
  final parent = arguments[1] as SendPort;
  final control = ReceivePort();
  var cancelled = false;
  final subscription = control.listen((_) => cancelled = true);
  parent.send(control.sendPort);
  RandomAccessFile? file;
  Object result = false;
  try {
    file = await File(arguments[0] as String).open();
    final sink = _HashDigestSink();
    final hash = sha256.startChunkedConversion(sink);
    while (!cancelled) {
      final bytes = await file.read(65536);
      if (cancelled || bytes.isEmpty) break;
      hash.add(bytes);
    }
    hash.close();
    result = cancelled ? 'cancelled' : sink.digest!.toString();
  } catch (_) {
    result = false;
  } finally {
    await file?.close();
    await subscription.cancel();
    control.close();
  }
  parent.send(result);
}
