import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:traelyx/features/commentary/domain/reviewed_commentary_input.dart';
import 'package:traelyx/features/local_commentary/data/local_model_store.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

class LocalModelStatus {
  const LocalModelStatus(
    this.inventory,
    this.catalogCount,
    this.runtimeAvailable,
    this.device,
  );
  final LocalModelInventory inventory;
  final int catalogCount;
  final bool runtimeAvailable;
  final LocalDevice device;
}

class LocalInstallReview {
  LocalInstallReview._(this.model, this.root, this._owner, this._epoch);
  final LocalModelManifest model;
  final String root;
  int get downloadBytes => model.bytes;
  int get requiredFreeBytes => model.bytes + LocalModelManifest.reserveBytes;
  final Object _owner;
  final int _epoch;
  bool _used = false;
}

class LocalGenerationReview {
  LocalGenerationReview._(this.model, this.input, this._owner, this._epoch);
  final LocalModelManifest model;
  final ReviewedCommentaryInput input;
  final Object _owner;
  final int _epoch;
  bool _used = false;
}

/// Optional local-only orchestration. No cloud/credential dependency or fallback.
/// Production adapters have no runtime/source/catalog entries until acceptance.
class LocalCommentaryService {
  LocalCommentaryService({
    required this.catalog,
    required this.device,
    required this.runtime,
    required this.source,
    required this.isRecorderIdle,
    this.operationBudget = const Duration(minutes: 2),
  });
  final Future<LocalModelCatalog> Function() catalog;
  final Future<LocalDevice> Function() device;
  final LocalCommentaryRuntime runtime;
  final LocalArtifactSource source;
  final Future<bool> Function() isRecorderIdle;
  final Duration operationBudget;
  final _owner = Object();
  int _epoch = 0;
  LocalCancellation? _pending;
  void cancel() {
    _epoch++;
    _pending?.cancel();
  }

  Future<void> _parked(bool parked, LocalCancellation c) async {
    if (!parked || !await c.race(isRecorderIdle())) {
      throw const LocalCommentaryException(LocalFailure.notParked);
    }
  }

  Future<T> _run<T>(
    Future<T> Function(LocalCancellation cancellation) action,
  ) async {
    if (_pending != null) {
      throw const LocalCommentaryException(LocalFailure.busy);
    }
    final cancellation = LocalCancellation();
    _pending = cancellation;
    var timedOut = false;
    final timer = Timer(operationBudget, () {
      timedOut = true;
      cancellation.cancel();
    });
    try {
      final result = await action(cancellation);
      cancellation.check();
      return result;
    } on LocalCommentaryException catch (error) {
      if (timedOut) throw const LocalCommentaryException(LocalFailure.timeout);
      if (cancellation.cancelled) {
        throw const LocalCommentaryException(LocalFailure.cancelled);
      }
      throw LocalCommentaryException(error.failure);
    } on CommentaryContractException {
      throw const LocalCommentaryException(LocalFailure.malformed);
    } catch (_) {
      throw const LocalCommentaryException(LocalFailure.storage);
    } finally {
      timer.cancel();
      _pending = null;
    }
  }

  Future<void> _admit(
    LocalModelManifest model,
    LocalDevice current,
    LocalCancellation c, {
    bool install = false,
  }) async {
    if (!(await c.race(catalog())).accepts(model) ||
        runtime.capabilities == null) {
      throw const LocalCommentaryException(LocalFailure.unavailable);
    }
    if (!runtime.capabilities!.supports(model, current)) {
      throw const LocalCommentaryException(LocalFailure.incompatible);
    }
    if (install && !source.supports(model)) {
      throw const LocalCommentaryException(LocalFailure.unavailable);
    }
    if (install &&
        current.freeBytes < model.bytes + LocalModelManifest.reserveBytes) {
      throw const LocalCommentaryException(LocalFailure.space);
    }
  }

  Future<LocalModelStatus> status() => _run((c) async {
    final current = await c.race(device());
    c.check();
    final inventory = await LocalModelStore(
      Directory(current.root),
    ).inventory();
    return LocalModelStatus(
      inventory,
      (await c.race(catalog())).models.length,
      runtime.capabilities != null,
      current,
    );
  });
  Future<LocalInstallReview> reviewInstall(
    LocalModelManifest model, {
    required bool parked,
  }) => _run((c) async {
    await _parked(parked, c);
    final current = await c.race(device());
    await _admit(model, current, c, install: true);
    c.check();
    return LocalInstallReview._(model, current.root, _owner, _epoch);
  });
  Future<void> install(
    LocalInstallReview review, {
    required bool parked,
    required bool acceptedSizeAndLicense,
  }) => _run((c) async {
    if (review._used ||
        review._owner != _owner ||
        review._epoch != _epoch ||
        !acceptedSizeAndLicense) {
      throw const LocalCommentaryException(LocalFailure.stale);
    }
    review._used = true;
    _epoch++;
    await _parked(parked, c);
    final current = await c.race(device());
    if (current.root != review.root) {
      throw const LocalCommentaryException(LocalFailure.stale);
    }
    await _admit(review.model, current, c, install: true);
    c.check();
    await LocalModelStore(Directory(current.root)).exclusive((lease) async {
      await lease.install(review.model, source.open(review.model, c), c);
    });
  });
  Future<void> removeModels({required bool parked, required bool confirmed}) =>
      _run((c) async {
        if (!confirmed) {
          throw const LocalCommentaryException(LocalFailure.stale);
        }
        _epoch++;
        await _parked(parked, c);
        final current = await c.race(device());
        c.check();
        await LocalModelStore(Directory(current.root)).removeAll();
      });
  Future<LocalGenerationReview> reviewGeneration(
    LocalModelManifest model,
    ProceduralCommentaryPlan plan, {
    required bool parked,
  }) => _run((c) async {
    await _parked(parked, c);
    final current = await c.race(device());
    await _admit(model, current, c);
    final input = ReviewedCommentaryInput.fromPlan(plan);
    c.check();
    return LocalGenerationReview._(model, input, _owner, _epoch);
  });
  Future<ProceduralCommentaryPlan> generate(
    LocalGenerationReview review, {
    required bool parked,
    required bool acceptedReview,
  }) => _run((c) async {
    if (review._used ||
        review._owner != _owner ||
        review._epoch != _epoch ||
        !acceptedReview) {
      throw const LocalCommentaryException(LocalFailure.stale);
    }
    review._used = true;
    await _parked(parked, c);
    final current = await c.race(device());
    await _admit(review.model, current, c);
    c.check();
    return LocalModelStore(Directory(current.root)).exclusive((lease) async {
      final path = await lease.verifiedPath(review.model, c);
      await _parked(parked, c);
      c.check();
      final response = await runtime.select(
        artifactPath: path,
        inputJson: jsonEncode(review.input.payload),
        cancellation: c,
      );
      c.check();
      await _parked(parked, c);
      c.check();
      if (response.length > 1024 || utf8.encode(response).length > 1024) {
        throw const LocalCommentaryException(LocalFailure.malformed);
      }
      Object? value;
      try {
        value = jsonDecode(response);
      } catch (_) {
        throw const LocalCommentaryException(LocalFailure.malformed);
      }
      return review.input.apply(value);
    });
  });
}
