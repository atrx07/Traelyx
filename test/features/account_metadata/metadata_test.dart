import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/features/account_metadata/application/metadata_service.dart';
import 'package:traelyx/features/account_metadata/data/metadata_repository.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

import '../summary_sync/summary_sync_test.dart'
    show TestAccount, userA, userB, tripA, seedTrip;

AccountMetadata profile({
  String owner = userA,
  int revision = 0,
  String name = 'Driver',
  bool public = false,
}) => AccountMetadata(
  userId: owner,
  kind: MetadataKind.profile,
  id: owner,
  revision: revision,
  fields: {
    'username': 'driver_name',
    'display_name': name,
    'visibility': public ? 'public' : 'private',
  },
);
AccountMetadata vehicle({String owner = userA, String? id}) => AccountMetadata(
  userId: owner,
  kind: MetadataKind.vehicle,
  id: id ?? tripA,
  fields: {'display_name': 'Chosen label', 'vehicle_class': 'car'},
);

void main() {
  late AppDatabase db;
  late MetadataRepository repo;
  late MetadataService service;
  late TestAccount account;
  late MetadataCloud cloud;
  var now = DateTime.utc(2026, 9, 26);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MetadataRepository(db);
    account = TestAccount();
    cloud = MetadataCloud();
    now = DateTime.utc(2026, 9, 26);
    service = MetadataService(repo, cloud, account, clock: () => now);
  });
  tearDown(() => db.close());

  test(
    'profile backoff holds dependent vehicle edits without sending them',
    () async {
      cloud.loseAck = true;
      await service.queue(profile());
      await service.queue(vehicle());
      expect(await service.sync(userA), 0);
      expect(await service.sync(userA), 0);
      expect(cloud.calls, hasLength(1));
      expect(
        (await repo.queued(
          userA,
        )).where((q) => q.operationType == 'vehicle').single.state,
        'pending',
      );
      now = now.add(const Duration(seconds: 31));
      expect(await service.sync(userA), 2);
    },
  );

  test('mismatched owner inside cached payload is never displayed', () async {
    await service.queue(profile());
    await service.sync(userA);
    await db
        .update(db.accountMetadataCache)
        .write(
          AccountMetadataCacheCompanion(
            payloadJson: Value(
              jsonEncode(profile(owner: userB, revision: 1).toJson()),
            ),
          ),
        );
    await expectLater(
      service.entries(userA),
      throwsA(isA<MetadataException>()),
    );
    await service.reload(userA);
    expect((await service.entries(userA)).single.data.userId, userA);
  });

  test(
    'strict metadata rejects private extra fields and unsupported versions',
    () {
      expect(AccountMetadata.fromJson(profile().toJson()).isPublic, isFalse);
      for (final extra in [
        'email',
        'route',
        'registration',
        'raw',
        'calibration',
      ]) {
        expect(
          () => AccountMetadata(
            userId: userA,
            kind: MetadataKind.profile,
            id: userA,
            fields: {...profile().fields, extra: 'private'},
          ),
          throwsFormatException,
        );
      }
      expect(() => profile(name: 'bad\nlabel'), throwsFormatException);
      expect(
        () => AccountMetadata.fromJson({...profile().toJson(), 'version': 2}),
        throwsFormatException,
      );
      expect(
        () => MetadataMutation.fromJson({
          'version': 1,
          'mutation_id': newMetadataUuid(),
          'data': profile().toJson(),
          'route': [],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'opening cache sends nothing; explicit queue/save never touches trips',
    () async {
      await seedTrip(db, tripA);
      final trips = await db.select(db.trips).get();
      expect(await service.entries(userA), isEmpty);
      expect(cloud.calls, isEmpty);
      await service.queue(profile());
      expect(cloud.calls, isEmpty);
      expect((await repo.queued(userA)), hasLength(1));
      expect(await service.sync(userA), 1);
      expect((await service.entries(userA)).single.data.revision, 1);
      expect(await repo.queued(userA), isEmpty);
      expect(await db.select(db.trips).get(), trips);
      expect(await db.select(db.tripAccountLinks).get(), isEmpty);
    },
  );

  test(
    'selected vehicle copies only chosen metadata and preserves local ownership',
    () async {
      await seedTrip(db, tripA);
      final before = await db.select(db.vehicles).getSingle();
      await service.queue(profile());
      await service.sync(userA);
      await service.queue(vehicle(), sourceLocalVehicleId: 'local-vehicle');
      final mutation = repo.decode((await repo.queued(userA)).single, userA);
      expect(mutation.data.fields.keys.toSet(), {
        'display_name',
        'vehicle_class',
      });
      expect(jsonEncode(mutation.toJson()), isNot(contains('precise-private')));
      await service.sync(userA);
      expect(await db.select(db.vehicles).getSingle(), before);
      expect((await db.select(db.trips).getSingle()).vehicleId, before.id);
      await expectLater(
        service.queue(
          vehicle(id: newMetadataUuid()),
          sourceLocalVehicleId: 'local-vehicle',
        ),
        throwsA(isA<MetadataException>()),
      );
    },
  );

  test(
    'lost acknowledgement retries same mutation after persisted backoff',
    () async {
      cloud.loseAck = true;
      await service.queue(profile());
      expect(await service.sync(userA), 0);
      final row = (await repo.queued(userA)).single;
      expect(row.state, 'retry');
      expect(await service.sync(userA), 0);
      expect(cloud.calls, hasLength(1));
      now = now.add(const Duration(seconds: 31));
      expect(await service.sync(userA), 1);
      expect(cloud.calls.last.mutationId, cloud.calls.first.mutationId);
      expect(cloud.rows.values.single.revision, 1);
    },
  );

  test(
    'cloud conflict keeps draft and requires discard/reload before retry',
    () async {
      await service.queue(profile());
      await service.sync(userA);
      cloud.rows[userA] = profile(revision: 2, name: 'Other device');
      await service.queue(profile(revision: 1, name: 'My edit'));
      expect(await service.sync(userA), 0);
      expect((await repo.queued(userA)).single.state, 'blocked');
      await expectLater(
        service.reload(userA),
        throwsA(isA<MetadataException>()),
      );
      expect(cloud.rows[userA]!.displayName, 'Other device');
      await service.discard(userA);
      await service.reload(userA);
      expect(
        (await service.entries(userA)).single.data.displayName,
        'Other device',
      );
    },
  );

  test(
    'newer local edits reject stale reviewed revisions and duplicate queues',
    () async {
      await service.queue(profile());
      await expectLater(
        service.queue(profile(name: 'Second')),
        throwsA(isA<MetadataException>()),
      );
      await service.sync(userA);
      await expectLater(
        service.queue(profile()),
        throwsA(isA<MetadataException>()),
      );
      expect((await service.entries(userA)).single.data.displayName, 'Driver');
    },
  );

  test(
    'switch before consent and during network reply isolates accounts',
    () async {
      account.user = userB;
      await expectLater(
        service.queue(profile()),
        throwsA(isA<MetadataException>()),
      );
      expect(await repo.queued(userA), isEmpty);
      account.user = userA;
      await service.queue(profile());
      cloud.onSave = () {
        account.user = userB;
      };
      await expectLater(service.sync(userA), throwsA(isA<MetadataException>()));
      expect(await service.entries(userB), isEmpty);
      expect(await service.sync(userB), 0);
      expect(await repo.queued(userA), hasLength(1));
      expect(cloud.calls, hasLength(1));
    },
  );

  test(
    'reload rejects another owner and preserves complete existing cache',
    () async {
      await service.queue(profile());
      await service.sync(userA);
      cloud.fetchOverride = [profile(owner: userB, revision: 1)];
      await expectLater(
        service.reload(userA),
        throwsA(isA<MetadataException>()),
      );
      expect((await service.entries(userA)).single.data.userId, userA);
    },
  );

  test(
    'discard then requeue cannot be completed by an old acknowledgement',
    () async {
      await service.queue(profile());
      final old = (await repo.queued(userA)).single;
      await service.discard(userA);
      await service.queue(profile(name: 'Replacement'));
      await repo.acknowledge(old, profile(revision: 1));
      expect(
        (await repo.queued(userA)).single.idempotencyKey,
        isNot(old.idempotencyKey),
      );
      expect(
        (await service.entries(userA)).single.data.displayName,
        'Replacement',
      );
    },
  );

  test('malformed queue blocks without sending data', () async {
    await service.queue(profile());
    await db
        .update(db.syncQueue)
        .write(
          const SyncQueueCompanion(payloadJson: Value('{"route":"secret"}')),
        );
    expect(await service.sync(userA), 0);
    expect(cloud.calls, isEmpty);
    expect((await repo.queued(userA)).single.state, 'blocked');
    await service.discard(userA);
    expect(await service.entries(userA), isEmpty);
  });

  test('disk reopen preserves account cache and queued mutations', () async {
    final directory = await Directory.systemTemp.createTemp(
      'traelyx-metadata-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fixture.sqlite');
    var stored = AppDatabase(NativeDatabase(file));
    var persisted = MetadataService(MetadataRepository(stored), cloud, account);
    await persisted.queue(profile());
    final before = (await persisted.repository.queued(
      userA,
    )).single.idempotencyKey;
    await stored.close();
    stored = AppDatabase(NativeDatabase(file));
    persisted = MetadataService(MetadataRepository(stored), cloud, account);
    expect(
      (await persisted.repository.queued(userA)).single.idempotencyKey,
      before,
    );
    expect(await persisted.sync(userA), 1);
    await stored.close();
  });
}

class MetadataCloud implements MetadataGateway {
  final rows = <String, AccountMetadata>{};
  final mutations = <String, AccountMetadata>{};
  final calls = <MetadataMutation>[];
  bool loseAck = false;
  List<AccountMetadata>? fetchOverride;
  void Function()? onSave;
  @override
  Future<List<AccountMetadata>> fetch(String userId) async =>
      fetchOverride ?? rows.values.where((r) => r.userId == userId).toList();
  @override
  Future<AccountMetadata> save(MetadataMutation mutation) async {
    calls.add(mutation);
    final data = mutation.data;
    final acknowledged = mutations[mutation.mutationId];
    if (acknowledged != null) return acknowledged;
    if ((rows[data.id]?.revision ?? 0) != data.revision) {
      throw const MetadataException(MetadataFailure.conflict);
    }
    final result = data.withRevision(data.revision + 1);
    rows[data.id] = result;
    mutations[mutation.mutationId] = result;
    onSave?.call();
    if (loseAck) {
      loseAck = false;
      throw const MetadataException(MetadataFailure.connection);
    }
    return result;
  }
}
