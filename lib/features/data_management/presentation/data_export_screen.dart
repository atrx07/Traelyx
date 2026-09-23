import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/data_management/application/data_management_providers.dart';
import 'package:traelyx/features/data_management/domain/data_management_models.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/application/trip_route_providers.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  String? _busyAction;
  String? _notice;
  bool _noticeIsError = false;

  bool get _busy => _busyAction != null;

  @override
  Widget build(BuildContext context) {
    final diagnostics = ref.watch(diagnosticsReportProvider);
    final trips = ref.watch(storedTripsProvider);
    final policy = ref.watch(rawRetentionPolicyProvider);
    final mapCache = ref.watch(tripMapCacheStatusProvider);
    return SafeArea(
      key: const ValueKey('data-export-screen'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TraelyxSpacing.md,
                TraelyxSpacing.sm,
                TraelyxSpacing.md,
                TraelyxSpacing.section,
              ),
              children: [
                const _Header(),
                const SizedBox(height: TraelyxSpacing.lg),
                const _LocalOnlyNotice(),
                if (_notice != null) ...[
                  const SizedBox(height: TraelyxSpacing.md),
                  _ActionNotice(message: _notice!, isError: _noticeIsError),
                ],
                const SizedBox(height: TraelyxSpacing.xl),
                const _SectionHeading('STORAGE BREAKDOWN'),
                const SizedBox(height: TraelyxSpacing.sm),
                _StorageBreakdown(report: diagnostics),
                const SizedBox(height: TraelyxSpacing.xl),
                const _SectionHeading('RAW RETENTION'),
                const SizedBox(height: TraelyxSpacing.sm),
                _RetentionCard(
                  policy: policy,
                  busy: _busy,
                  onChanged: _setPolicy,
                  onReviewCleanup: _reviewCleanup,
                ),
                const SizedBox(height: TraelyxSpacing.xl),
                const _SectionHeading('MAP CACHE'),
                const SizedBox(height: TraelyxSpacing.sm),
                _MapCacheCard(
                  cache: mapCache,
                  busy: _busy,
                  onClear: _clearMapCache,
                ),
                const SizedBox(height: TraelyxSpacing.xl),
                const _SectionHeading('TRIP DATA & EXPORTS'),
                const SizedBox(height: TraelyxSpacing.sm),
                const _ExportPrivacyNotice(),
                const SizedBox(height: TraelyxSpacing.md),
                trips.when(
                  loading: () =>
                      const _LoadingCard(label: 'Loading stored trip data'),
                  error: (error, stackTrace) => const _UnavailableCard(
                    message:
                        'Stored trip data could not be read. No deletion or export action is available.',
                  ),
                  data: (items) => items.isEmpty
                      ? const _UnavailableCard(
                          message: 'No finalized local trips are stored.',
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < items.length;
                              index++
                            ) ...[
                              _TripDataCard(
                                trip: items[index],
                                busyAction: _busyAction,
                                onRedactedExport: () =>
                                    _exportRedacted(items[index]),
                                onPreciseExport: () =>
                                    _exportPrecise(items[index]),
                                onDeleteRaw: () => _deleteRaw(items[index]),
                                onDeleteTrip: () => _deleteTrip(items[index]),
                              ),
                              if (index != items.length - 1)
                                const SizedBox(height: TraelyxSpacing.md),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(diagnosticsReportProvider);
    ref.invalidate(storedTripsProvider);
    ref.invalidate(tripMapCacheStatusProvider);
    await Future.wait([
      ref.read(diagnosticsReportProvider.future),
      ref.read(storedTripsProvider.future),
    ]);
  }

  Future<void> _setPolicy(RawRetentionPolicy policy) async {
    await _runAction('retention-policy', () async {
      await ref.read(dataManagementServiceProvider).setRetentionPolicy(policy);
      _showNotice(
        'Retention preference saved. M5.9 never deletes in the background.',
      );
    });
  }

  Future<void> _reviewCleanup(RawRetentionPolicy policy) async {
    await _runAction('retention-cleanup', () async {
      final service = ref.read(dataManagementServiceProvider);
      final plan = await service.planCleanup(policy);
      if (!mounted) return;
      if (plan.candidates.isEmpty) {
        _showNotice('No retained raw telemetry currently matches this rule.');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete matching raw telemetry?'),
          content: Text(
            '${plan.candidates.length} finalized trip${plan.candidates.length == 1 ? '' : 's'} '
            'match this rule (${formatDiagnosticBytes(plan.indexedRawBytes)} indexed). '
            'Trip summaries, events, and scores stay, but route replay and future recomputation may become unavailable. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep raw telemetry'),
            ),
            FilledButton(
              key: const ValueKey('confirm-retention-cleanup'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete matching raw'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        _showNotice('Cleanup cancelled. Nothing was deleted.');
        return;
      }
      final result = await service.executeCleanup(policy);
      _refreshAfterMutation();
      if (result.complete) {
        _showNotice(
          'Raw telemetry removed from ${result.deletedTripCount} trip${result.deletedTripCount == 1 ? '' : 's'} (${formatDiagnosticBytes(result.bytesDeleted)}). Summaries were kept.',
        );
      } else {
        _showNotice(
          'Cleanup was incomplete. ${result.deletedTripCount} succeeded and ${result.failureCount} failed; stored summaries were not silently removed.',
          isError: true,
        );
      }
    });
  }

  Future<void> _clearMapCache() async {
    await _runAction('map-cache', () async {
      final controller = await ref.read(tripMapControllerProvider.future);
      final status = ref.read(tripMapCacheStatusProvider).valueOrNull;
      await controller.clearCache();
      ref.invalidate(tripMapCacheStatusProvider);
      ref.invalidate(diagnosticsReportProvider);
      _showNotice(
        status?.isAvailable == true
            ? 'Map cache cleared.'
            : 'No map tile cache exists for the offline canvas. Nothing was deleted.',
      );
    });
  }

  Future<void> _exportRedacted(StoredTripData trip) async {
    await _runAction('redacted-${trip.id}', () async {
      final result = await ref
          .read(dataManagementServiceProvider)
          .exportRedacted(trip.id);
      if (result.exported) {
        _showNotice(
          'Redacted summary exported (${formatDiagnosticBytes(result.byteLength)}). No route or raw telemetry was included.',
        );
      } else if (result.errorCode == 'export_cancelled') {
        _showNotice('Redacted export cancelled. No file was written.');
      } else {
        _showNotice(
          'The redacted summary could not be exported safely.',
          isError: true,
        );
      }
    });
  }

  Future<void> _exportPrecise(StoredTripData trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export precise private archive?'),
        content: const Text(
          'This .tripdebug archive contains the exact route and raw device motion. It is not anonymized. Save it only somewhere private.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-precise-export'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose private location'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction('precise-${trip.id}', () async {
      final result = await ref
          .read(dataManagementServiceProvider)
          .exportPrecise(trip.id);
      if (result.exported) {
        _showNotice(
          'Precise private archive exported and verified (${result.chunkCount} chunks).',
        );
      } else if (result.errorCode == 'export_cancelled') {
        _showNotice('Precise export cancelled. No file was written.');
      } else {
        _showNotice(
          'The precise archive could not be exported safely.',
          isError: true,
        );
      }
    });
  }

  Future<void> _deleteRaw(StoredTripData trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete raw telemetry?'),
        content: Text(
          'Remove ${formatDiagnosticBytes(trip.indexedRawBytes)} of indexed raw telemetry from this trip? Its summary, events, and score stay, but route replay and recomputation may become unavailable. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep raw telemetry'),
          ),
          FilledButton(
            key: ValueKey('confirm-delete-raw-${trip.id}'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete raw telemetry'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction('delete-raw-${trip.id}', () async {
      final bytes = await ref
          .read(dataManagementServiceProvider)
          .deleteRawForTrip(trip.id);
      _refreshAfterMutation();
      _showNotice(
        'Raw telemetry deleted (${formatDiagnosticBytes(bytes)}). The trip summary was kept.',
      );
    });
  }

  Future<void> _deleteTrip(StoredTripData trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entire trip?'),
        content: const Text(
          'This removes the local trip summary, raw telemetry, events, and score. The action is permanent and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep trip'),
          ),
          FilledButton(
            key: ValueKey('confirm-delete-trip-${trip.id}'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete entire trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction('delete-trip-${trip.id}', () async {
      final deleted = await ref
          .read(dataManagementServiceProvider)
          .deleteTrip(trip.id);
      _refreshAfterMutation();
      _showNotice(
        deleted
            ? 'The entire local trip was deleted.'
            : 'The trip no longer exists. Nothing else was deleted.',
      );
    });
  }

  Future<void> _runAction(
    String action,
    Future<void> Function() operation,
  ) async {
    if (_busy) return;
    setState(() {
      _busyAction = action;
      _notice = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        _showNotice(
          'The local data action could not be completed safely. No hidden recovery action was taken.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _refreshAfterMutation() {
    ref.invalidate(diagnosticsReportProvider);
    ref.invalidate(storedTripsProvider);
    ref.invalidate(tripHistoryProvider);
  }

  void _showNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = isError;
    });
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back to You',
          onPressed: () => context.go(TraelyxRoutes.you),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: TraelyxSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOCAL DATA CONTROLS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.traelyxColors.accent,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Data & Export',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.traelyxColors.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _LocalOnlyNotice extends StatelessWidget {
  const _LocalOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: Icons.phonelink_lock_rounded,
      color: context.traelyxColors.positive,
      title: 'Local and user-directed',
      message:
          'Nothing here uploads data or runs cleanup in the background. Deletion and exports require an explicit action.',
    );
  }
}

class _ExportPrivacyNotice extends StatelessWidget {
  const _ExportPrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: Icons.privacy_tip_outlined,
      color: context.traelyxColors.information,
      title: 'Choose the right export',
      message:
          'Redacted summary omits route, raw samples, IDs, vehicle, and wall-clock time, but is not an anonymity guarantee. Precise .tripdebug contains the exact route and raw motion.',
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: _NoticeCard(
        icon: isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline,
        color: isError
            ? context.traelyxColors.critical
            : context.traelyxColors.positive,
        title: isError ? 'Action not completed' : 'Local action complete',
        message: message,
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: TraelyxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: TraelyxSpacing.xxs),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageBreakdown extends StatelessWidget {
  const _StorageBreakdown({required this.report});

  final AsyncValue<DiagnosticsReport> report;

  @override
  Widget build(BuildContext context) {
    return report.when(
      loading: () => const _LoadingCard(label: 'Measuring local storage'),
      error: (error, stackTrace) => const _UnavailableCard(
        message:
            'Storage totals are unavailable. Refresh before deleting data.',
      ),
      data: (value) {
        final storage = value.platform.storage;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(TraelyxSpacing.lg),
            child: Column(
              children: [
                _StorageRow('App package', storage.appBytes),
                _StorageRow('Trip summaries', storage.databaseBytes),
                _StorageRow('Raw telemetry', storage.rawTelemetryBytes),
                _StorageRow('Map cache', storage.mapCacheBytes),
                _StorageRow('Local AI models', storage.localModelBytes),
                Divider(color: context.traelyxColors.outline),
                _StorageRow('Measured total', storage.totalBytes, strong: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow(this.label, this.bytes, {this.strong = false});

  final String label;
  final int bytes;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Semantics(
      label: '$label: ${formatDiagnosticBytes(bytes)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TraelyxSpacing.xs),
          child: Row(
            children: [
              Expanded(child: Text(label, style: style)),
              const SizedBox(width: TraelyxSpacing.md),
              Text(formatDiagnosticBytes(bytes), style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetentionCard extends StatelessWidget {
  const _RetentionCard({
    required this.policy,
    required this.busy,
    required this.onChanged,
    required this.onReviewCleanup,
  });

  final AsyncValue<RawRetentionPolicy> policy;
  final bool busy;
  final ValueChanged<RawRetentionPolicy> onChanged;
  final ValueChanged<RawRetentionPolicy> onReviewCleanup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: policy.when(
          loading: () => const LinearProgressIndicator(
            semanticsLabel: 'Loading retention preference',
          ),
          error: (error, stackTrace) => const Text(
            'Retention preference is unavailable. No cleanup action is enabled.',
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cleanup rule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: TraelyxSpacing.xs),
              const Text(
                'This preference only builds a cleanup preview. It never runs automatically.',
              ),
              const SizedBox(height: TraelyxSpacing.md),
              DropdownButtonFormField<RawRetentionPolicy>(
                key: const ValueKey('raw-retention-policy'),
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Keep full raw telemetry',
                ),
                items: RawRetentionPolicy.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_policyLabel(item)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: busy
                    ? null
                    : (selected) {
                        if (selected != null) onChanged(selected);
                      },
              ),
              const SizedBox(height: TraelyxSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('review-raw-cleanup'),
                  onPressed: busy || value.retentionDays == null
                      ? null
                      : () => onReviewCleanup(value),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review matching cleanup'),
                ),
              ),
              if (value.retentionDays == null) ...[
                const SizedBox(height: TraelyxSpacing.xs),
                Text(
                  value == RawRetentionPolicy.forever
                      ? 'Forever selected. Age-based cleanup is disabled.'
                      : 'Manual selected. Use a trip action below to remove raw data.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCacheCard extends StatelessWidget {
  const _MapCacheCard({
    required this.cache,
    required this.busy,
    required this.onClear,
  });

  final AsyncValue<MapCacheStatus> cache;
  final bool busy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final status = cache.valueOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status == null
                  ? 'Cache status unavailable'
                  : status.isAvailable
                  ? formatDiagnosticBytes(status.bytesUsed)
                  : 'Unavailable · 0 B',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TraelyxSpacing.xs),
            Text(
              status?.isAvailable == true
                  ? 'The active map provider reports a local tile cache.'
                  : 'The offline canvas stores no map tiles. Clear is a safe no-op.',
            ),
            const SizedBox(height: TraelyxSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('clear-data-map-cache'),
              onPressed: busy || status == null ? null : onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear map cache'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripDataCard extends StatelessWidget {
  const _TripDataCard({
    required this.trip,
    required this.busyAction,
    required this.onRedactedExport,
    required this.onPreciseExport,
    required this.onDeleteRaw,
    required this.onDeleteTrip,
  });

  final StoredTripData trip;
  final String? busyAction;
  final VoidCallback onRedactedExport;
  final VoidCallback onPreciseExport;
  final VoidCallback onDeleteRaw;
  final VoidCallback onDeleteTrip;

  @override
  Widget build(BuildContext context) {
    final busy = busyAction != null;
    final date = _dateLabel(trip.startedAtUtc.toLocal());
    final raw = trip.hasRawTelemetry
        ? '${formatDiagnosticBytes(trip.indexedRawBytes)} · ${trip.chunkCount} chunk${trip.chunkCount == 1 ? '' : 's'}'
        : 'Raw telemetry removed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: TraelyxSpacing.xxs),
            Text('${_durationLabel(trip.duration)} · $raw'),
            const SizedBox(height: TraelyxSpacing.md),
            Wrap(
              spacing: TraelyxSpacing.sm,
              runSpacing: TraelyxSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('export-redacted-${trip.id}'),
                  onPressed: busy ? null : onRedactedExport,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Export redacted summary'),
                ),
                OutlinedButton.icon(
                  key: ValueKey('export-precise-${trip.id}'),
                  onPressed: busy || !trip.hasRawTelemetry
                      ? null
                      : onPreciseExport,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Export precise archive'),
                ),
                TextButton.icon(
                  key: ValueKey('delete-raw-${trip.id}'),
                  onPressed: busy || !trip.hasRawTelemetry ? null : onDeleteRaw,
                  icon: const Icon(Icons.layers_clear_outlined),
                  label: const Text('Delete raw only'),
                ),
                TextButton.icon(
                  key: ValueKey('delete-trip-${trip.id}'),
                  onPressed: busy ? null : onDeleteTrip,
                  icon: Icon(
                    Icons.delete_forever_outlined,
                    color: busy ? null : context.traelyxColors.critical,
                  ),
                  label: Text(
                    'Delete entire trip',
                    style: TextStyle(
                      color: busy ? null : context.traelyxColors.critical,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.xl),
        child: Center(child: CircularProgressIndicator(semanticsLabel: label)),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: Icons.info_outline_rounded,
      color: context.traelyxColors.information,
      title: 'Unavailable',
      message: message,
    );
  }
}

String _policyLabel(RawRetentionPolicy policy) => switch (policy) {
  RawRetentionPolicy.manual => 'Until I delete it manually',
  RawRetentionPolicy.sevenDays => '7 days',
  RawRetentionPolicy.thirtyDays => '30 days',
  RawRetentionPolicy.forever => 'Forever',
};

String _durationLabel(Duration? duration) {
  if (duration == null) return 'Duration unavailable';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m ${seconds}s';
}

String _dateLabel(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
