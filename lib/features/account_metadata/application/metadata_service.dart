import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account_metadata/data/metadata_repository.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

class MetadataService {
  MetadataService(
    this.repository,
    this.gateway,
    this.account, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final MetadataRepository repository;
  final MetadataGateway gateway;
  final AccountGateway account;
  final DateTime Function() clock;
  bool _busy = false;
  void _check(String owner) {
    if (account.currentIdentity?.userId != owner) {
      throw const MetadataException(MetadataFailure.accountChanged);
    }
  }

  void _enter(String owner) {
    _check(owner);
    if (_busy) throw const MetadataException(MetadataFailure.conflict);
    _busy = true;
  }

  Future<List<MetadataEntry>> entries(String owner) async {
    _check(owner);
    final result = await repository.entries(owner);
    _check(owner);
    return result;
  }

  Future<void> queue(
    AccountMetadata data, {
    String? sourceLocalVehicleId,
  }) async {
    _enter(data.userId);
    try {
      await repository.enqueue(
        data,
        newMetadataUuid(),
        clock(),
        () => account.currentIdentity?.userId == data.userId,
        sourceLocalVehicleId: sourceLocalVehicleId,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> reload(String owner) async {
    _enter(owner);
    try {
      if ((await repository.queued(owner)).isNotEmpty) {
        throw const MetadataException(MetadataFailure.conflict);
      }
      final rows = await gateway.fetch(owner);
      _check(owner);
      await repository.replaceFromCloud(
        owner,
        rows,
        () => account.currentIdentity?.userId == owner,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> discard(String owner) async {
    _enter(owner);
    try {
      await repository.discard(owner);
    } finally {
      _busy = false;
    }
  }

  Future<int> sync(String owner) async {
    _enter(owner);
    var saved = 0;
    try {
      final rows = await repository.queued(owner);
      // A new vehicle requires the owner's profile to exist first.
      rows.sort((a, b) => a.operationType.compareTo(b.operationType));
      var profilePending = rows.any((row) => row.operationType == 'profile');
      var attempted = 0;
      for (final row in rows) {
        _check(owner);
        if (row.operationType == 'vehicle' && profilePending) break;
        if (row.state == 'blocked' ||
            (row.nextAttemptAtMicros ?? 0) > clock().microsecondsSinceEpoch) {
          continue;
        }
        if (attempted++ == 50) break;
        try {
          final mutation = repository.decode(row, owner);
          if (!await repository.stillPending(row)) continue;
          _check(owner);
          final result = await gateway.save(mutation);
          _check(owner);
          if (!result.sameFields(mutation.data) ||
              result.revision <= mutation.data.revision) {
            throw const MetadataException(MetadataFailure.invalidData);
          }
          await repository.acknowledge(row, result);
          if (row.operationType == 'profile') profilePending = false;
          saved++;
        } catch (error) {
          final reason = error is MetadataException
              ? error.reason
              : MetadataFailure.connection;
          if (reason == MetadataFailure.accountChanged) rethrow;
          await repository.fail(row, reason, clock());
          break;
        }
      }
      return saved;
    } finally {
      _busy = false;
    }
  }
}
