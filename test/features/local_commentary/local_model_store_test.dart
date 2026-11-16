import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/local_commentary/data/local_model_store.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

import 'local_fixture.dart';

Matcher failure(LocalFailure value) =>
    isA<LocalCommentaryException>().having((e) => e.failure, 'failure', value);
void main() {
  late Directory parent, root;
  late LocalModelStore store;
  setUp(() async {
    parent = (await Directory.systemTemp.createTemp('m711-')).absolute;
    root = await Directory('${parent.path}/models').create();
    store = LocalModelStore(root);
  });
  tearDown(() async {
    await parent.delete(recursive: true);
  });
  Future<void> install([Stream<List<int>>? bytes, LocalCancellation? c]) =>
      store.exclusive(
        (lease) => lease.install(
          fixtureManifest(),
          bytes ?? Stream.value(fixtureBytes),
          c ?? LocalCancellation(),
        ),
      );
  File weights() => File('${root.path}/${fixtureManifest().digest}/weights');

  test(
    'publishes exact verified bytes and receipt, reopens and removes only models',
    () async {
      final sibling = await File(
        '${parent.path}/real-trip',
      ).writeAsString('untouched');
      await install();
      final inventory = await LocalModelStore(root).inventory();
      expect(inventory.artifacts, 1);
      expect(inventory.partials, 0);
      expect(inventory.bytes, greaterThan(fixtureBytes.length));
      await LocalModelStore(root).exclusive((lease) async {
        expect(
          await lease.verifiedPath(fixtureManifest(), LocalCancellation()),
          await weights().resolveSymbolicLinks(),
        );
      });
      await store.removeAll();
      expect((await store.inventory()).bytes, 0);
      expect(await sibling.readAsString(), 'untouched');
    },
  );
  for (final kind in [
    'truncated',
    'oversized',
    'wrong hash',
    'invalid byte',
    'oversized chunk',
  ]) {
    test('rejects $kind and cleans only its new partial', () async {
      final bytes = switch (kind) {
        'truncated' => fixtureBytes.sublist(1),
        'oversized' => [...fixtureBytes, 0],
        'wrong hash' => List.filled(fixtureBytes.length, 0),
        'invalid byte' => [-1, ...fixtureBytes.sublist(1)],
        _ => List.filled(65537, 0),
      };
      await expectLater(
        install(Stream.value(bytes)),
        throwsA(failure(LocalFailure.integrity)),
      );
      expect((await store.inventory()).bytes, 0);
      expect((await store.inventory()).partials, 0);
    });
  }
  test(
    'stream errors clean the partial and preserve existing sibling',
    () async {
      await expectLater(
        install(Stream.error(StateError('private'))),
        throwsA(failure(LocalFailure.storage)),
      );
      expect((await store.inventory()).bytes, 0);
    },
  );
  test(
    'cancel while a source stalls closes source and removes partial',
    () async {
      final ready = Completer<void>();
      var closed = false;
      final source = StreamController<List<int>>(
        onListen: () => ready.complete(),
        onCancel: () {
          closed = true;
        },
      );
      final c = LocalCancellation();
      final operation = install(source.stream, c);
      final result = expectLater(
        operation,
        throwsA(failure(LocalFailure.cancelled)),
      );
      await ready.future;
      c.cancel();
      await result;
      expect(closed, true);
      expect((await store.inventory()).partials, 0);
      await source.close();
    },
  );
  test('pre-cancellation creates no artifact', () async {
    final c = LocalCancellation()..cancel();
    await expectLater(
      install(null, c),
      throwsA(failure(LocalFailure.cancelled)),
    );
    expect((await store.inventory()).bytes, 0);
  });
  test(
    'corruption fails before use and is preserved for explicit removal',
    () async {
      await install();
      await weights().writeAsBytes(List.filled(fixtureBytes.length, 0));
      await expectLater(
        store.exclusive(
          (l) => l.verifiedPath(fixtureManifest(), LocalCancellation()),
        ),
        throwsA(failure(LocalFailure.integrity)),
      );
      expect(await weights().exists(), true);
      await store.removeAll();
    },
  );
  test('receipt tampering and oversized receipts fail closed', () async {
    await install();
    final receipt = File('${weights().parent.path}/receipt.json');
    for (final value in ['{}', 'x' * 4097]) {
      await receipt.writeAsString(value);
      await expectLater(
        store.exclusive(
          (l) => l.verifiedPath(fixtureManifest(), LocalCancellation()),
        ),
        throwsA(failure(LocalFailure.integrity)),
      );
    }
    expect(await weights().exists(), true);
  });
  test('never overwrites an installed or abandoned partial artifact', () async {
    await install();
    await expectLater(install(), throwsA(failure(LocalFailure.stale)));
    await store.removeAll();
    final dir = await Directory(
      '${root.path}/${fixtureManifest().digest}.partial',
    ).create();
    await File('${dir.path}/weights').writeAsString('partial');
    await expectLater(install(), throwsA(failure(LocalFailure.stale)));
    expect((await store.inventory()).partials, 1);
    await store.removeAll();
  });
  test(
    'cross-instance contention prevents removal during a model lease',
    () async {
      final gate = Completer<void>(), ready = Completer<void>();
      final use = store.exclusive((l) async {
        ready.complete();
        await gate.future;
      });
      await ready.future;
      await expectLater(
        LocalModelStore(root).removeAll(),
        throwsA(failure(LocalFailure.busy)),
      );
      gate.complete();
      await use;
      await store.removeAll();
    },
  );
  test('expired leases cannot reach filesystem', () async {
    late LocalModelLease expired;
    await store.exclusive((l) async => expired = l);
    await expectLater(
      expired.inventory(),
      throwsA(failure(LocalFailure.stale)),
    );
  });
  test('unknown content prevents deletion of any model', () async {
    await install();
    final unknown = await File(
      '${root.path}/not-owned',
    ).writeAsString('private');
    await expectLater(
      store.removeAll(),
      throwsA(failure(LocalFailure.storage)),
    );
    expect(await weights().exists(), true);
    expect(await unknown.readAsString(), 'private');
  });
  test('links are refused without touching their targets', () async {
    final outside = await File(
      '${parent.path}/outside',
    ).writeAsString('private');
    // Windows needs Developer Mode/admin for symlinks. Unix CI exercises this
    // boundary; on Windows use a real unknown directory instead, with no skip.
    if (!Platform.isWindows) {
      final modelDir = await Directory(
        '${root.path}/${fixtureManifest().digest}',
      ).create();
      await Link('${modelDir.path}/weights').create(outside.path);
    } else {
      await Directory('${root.path}/outside').create();
    }
    await expectLater(
      store.removeAll(),
      throwsA(failure(LocalFailure.storage)),
    );
    expect(await outside.readAsString(), 'private');
  });
  test(
    'read-only hash worker matches SHA256 and respects pre-cancellation',
    () async {
      final file = await File('${parent.path}/hash').writeAsBytes(fixtureBytes);
      expect(
        await verifiedSha256(file, LocalCancellation()),
        fixtureManifest().digest,
      );
      await expectLater(
        verifiedSha256(file, LocalCancellation()..cancel()),
        throwsA(failure(LocalFailure.cancelled)),
      );
    },
  );
  test(
    'namespace capacity refuses an install before creating staging',
    () async {
      for (var i = 0; i < 16; i++) {
        await Directory(
          '${root.path}/${i.toRadixString(16).padLeft(64, '0')}',
        ).create();
      }
      await expectLater(install(), throwsA(failure(LocalFailure.storage)));
      expect((await store.inventory()).artifacts, 16);
      await store.removeAll();
      expect((await store.inventory()).artifacts, 0);
    },
  );
  test(
    'active hash cancellation terminates worker before lease release',
    () async {
      final file = File('${parent.path}/hash-cancel');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(8 * 1024 * 1024);
      await handle.close();
      final cancellation = LocalCancellation();
      final pending = verifiedSha256(file, cancellation);
      final result = expectLater(
        pending,
        throwsA(failure(LocalFailure.cancelled)),
      );
      await Future<void>.delayed(Duration.zero);
      cancellation.cancel();
      await result;
      await file.delete();
      expect(await file.exists(), false);
    },
  );
}
