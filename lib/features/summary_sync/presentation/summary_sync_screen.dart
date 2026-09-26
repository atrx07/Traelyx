import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/summary_sync/application/summary_sync_providers.dart';
import 'package:traelyx/features/summary_sync/domain/compact_trip_summary.dart';

class SummarySyncScreen extends ConsumerStatefulWidget {
  const SummarySyncScreen({super.key});
  @override
  ConsumerState<SummarySyncScreen> createState() => _SummarySyncScreenState();
}

class _SummarySyncScreenState extends ConsumerState<SummarySyncScreen> {
  bool _busy = false;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(accountIdentityProvider).valueOrNull;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            key: const ValueKey('summary-sync-screen'),
            padding: const EdgeInsets.all(TraelyxSpacing.xl),
            children: [
              TextButton.icon(
                onPressed: () => context.go(TraelyxRoutes.youAccount),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Account'),
              ),
              Text(
                'Private summary sync',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: TraelyxSpacing.lg),
              const Text(
                'Review and choose whether to copy existing compact trip summaries to your private account. Local history remains on this device.',
              ),
              const SizedBox(height: TraelyxSpacing.md),
              const Text(
                'Only trip ID, account ownership, known duration, distance, overall score with its version, and aggregate event count are sent. Dates, precise routes, raw sensors, vehicle labels, and email are excluded. Unknown values stay unknown.',
              ),
              const SizedBox(height: TraelyxSpacing.md),
              const Text(
                'New trips need a new review. Retry queued uploads here when connected. Signing out pauses uploads; deleting local data does not delete a cloud copy. An upload already in progress may finish.',
              ),
              const SizedBox(height: TraelyxSpacing.lg),
              if (identity == null)
                const Text('Sign in to review optional summary sync.')
              else ...[
                Text(
                  'Destination: ${identity.email ?? 'your signed-in account'}',
                ),
                const SizedBox(height: TraelyxSpacing.md),
                ref
                    .watch(summarySyncPreviewProvider(identity.userId))
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => Column(
                        children: [
                          const Text(
                            'Local summaries could not be reviewed safely.',
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(
                              summarySyncPreviewProvider(identity.userId),
                            ),
                            child: const Text('Review again'),
                          ),
                        ],
                      ),
                      data: (preview) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${preview.candidates.length} summaries available • ${preview.pending} queued or needing review • ${preview.synced} synced',
                          ),
                          if (preview.otherAccount > 0)
                            Text(
                              '${preview.otherAccount} trips belong to another account and are excluded.',
                            ),
                          if (preview.nextRetryAt != null &&
                              preview.nextRetryAt!.isAfter(DateTime.now()))
                            const Text(
                              'A retry delay is active after a failed request. Try again later.',
                            ),
                          const SizedBox(height: TraelyxSpacing.md),
                          FilledButton(
                            key: const ValueKey('review-summary-upload'),
                            onPressed: _busy || preview.candidates.isEmpty
                                ? null
                                : () => _confirm(preview),
                            child: Text(
                              'Review ${preview.candidates.length} summaries',
                            ),
                          ),
                          OutlinedButton(
                            key: const ValueKey('retry-summary-upload'),
                            onPressed: _busy || preview.pending == 0
                                ? null
                                : () => _run(identity.userId, () async {
                                    final result = await ref
                                        .read(summarySyncServiceProvider)
                                        .syncPending(identity.userId);
                                    return '${result.uploaded} synced this attempt. ${result.failed == 0 ? 'Any remaining queue can be retried here.' : 'Some uploads failed; the local queue is retained.'}';
                                  }),
                            child: const Text('Retry queued uploads'),
                          ),
                          TextButton(
                            key: const ValueKey('cancel-summary-upload'),
                            onPressed: _busy || preview.pending == 0
                                ? null
                                : () => _run(identity.userId, () async {
                                    await ref
                                        .read(summarySyncServiceProvider)
                                        .cancelPending(identity.userId);
                                    return 'Queued uploads cancelled. Existing cloud copies remain; account associations are preserved.';
                                  }),
                            child: const Text('Cancel queued uploads'),
                          ),
                        ],
                      ),
                    ),
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: TraelyxSpacing.lg),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(SummarySyncPreview preview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload ${preview.candidates.length} private summaries?'),
        content: const SingleChildScrollView(
          child: Text(
            'This links the reviewed trips to the account shown on this screen and queues a compact copy for upload. It includes trip IDs, known duration, distance, score/version, and event counts. Precise routes and raw telemetry stay local. This does not enable uploads for future trips. You can cancel queued uploads; completed cloud copies remain.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep local'),
          ),
          FilledButton(
            key: const ValueKey('confirm-summary-upload'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Link and upload'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(preview.userId, () async {
      final service = ref.read(summarySyncServiceProvider);
      await service.consent(preview);
      final result = await service.syncPending(preview.userId);
      return '${result.uploaded} summaries synced. ${result.failed == 0 ? 'Local history is unchanged.' : 'Upload paused after a failure; retry the retained queue here.'}';
    });
  }

  Future<void> _run(String userId, Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final notice = await action();
      if (mounted) setState(() => _notice = notice);
    } catch (error) {
      if (mounted) {
        setState(
          () => _notice =
              error is SummarySyncException &&
                  error.reason == SummaryFailure.accountChanged
              ? 'The signed-in account changed. Review again before uploading.'
              : 'This action could not complete safely. Review again; local trips are retained.',
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(summarySyncPreviewProvider(userId));
        setState(() => _busy = false);
      }
    }
  }
}
