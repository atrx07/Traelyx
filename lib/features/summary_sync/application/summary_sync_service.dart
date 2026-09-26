import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/summary_sync/data/summary_sync_repository.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

class SummarySyncService {
  SummarySyncService(
    this.repository,
    this.cloud,
    this.account, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final SummarySyncRepository repository;
  final SummaryCloudGateway cloud;
  final AccountGateway account;
  final DateTime Function() clock;
  bool _running = false;

  void _check(String userId) {
    if (account.currentIdentity?.userId != userId) {
      throw const SummarySyncException(SummaryFailure.accountChanged);
    }
  }

  Future<SummarySyncPreview> preview(String userId) async {
    _check(userId);
    final result = await repository.preview(userId);
    _check(userId);
    return result;
  }

  Future<void> consent(SummarySyncPreview reviewed) async {
    _check(reviewed.userId);
    await repository.enqueue(
      reviewed,
      clock(),
      () => account.currentIdentity?.userId == reviewed.userId,
    );
  }

  Future<void> cancelPending(String userId) async {
    _check(userId);
    await repository.cancelPending(userId);
  }

  Future<SummarySyncResult> syncPending(String userId) async {
    _check(userId);
    if (_running) return const SummarySyncResult(uploaded: 0, failed: 0);
    _running = true;
    var uploaded = 0;
    var failed = 0;
    try {
      for (final row in await repository.due(userId, clock())) {
        _check(userId);
        try {
          final payload = await repository.readyPayload(row, userId);
          _check(userId);
          if (payload == null) continue;
          await cloud.upload(payload);
          _check(userId);
          await repository.markSynced(row, clock());
          uploaded++;
        } catch (error) {
          final reason = error is SummarySyncException
              ? error.reason
              : SummaryFailure.connection;
          if (reason == SummaryFailure.accountChanged) rethrow;
          await repository.markFailure(row, reason, clock());
          failed++;
          if (reason == SummaryFailure.connection ||
              reason == SummaryFailure.accessDenied) {
            break;
          }
        }
      }
      return SummarySyncResult(uploaded: uploaded, failed: failed);
    } finally {
      _running = false;
    }
  }
}
