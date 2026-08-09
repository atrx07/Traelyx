import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/diagnostics/diagnostics_providers.dart';
import 'package:traelyx/core/diagnostics/diagnostics_report.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(diagnosticsReportProvider);
    return SafeArea(
      key: const ValueKey('diagnostics-screen'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(diagnosticsReportProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TraelyxSpacing.md,
                TraelyxSpacing.sm,
                TraelyxSpacing.md,
                TraelyxSpacing.section,
              ),
              children: [
                _Header(
                  onRefresh: () => ref.invalidate(diagnosticsReportProvider),
                ),
                const SizedBox(height: TraelyxSpacing.lg),
                const _PrivacyNotice(),
                const SizedBox(height: TraelyxSpacing.lg),
                report.when(
                  loading: () => const _LoadingState(),
                  error: (error, stackTrace) => _ErrorState(
                    onRetry: () => ref.invalidate(diagnosticsReportProvider),
                  ),
                  data: (value) => _ReportBody(report: value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

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
                'LOCAL SYSTEM STATUS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.traelyxColors.accent,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Diagnostics',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh diagnostics',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.traelyxColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: context.traelyxColors.positive),
            const SizedBox(width: TraelyxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Redacted by design',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: TraelyxSpacing.xxs),
                  const Text(
                    'No routes, precise locations, raw samples, filenames, '
                    'device identifiers, credentials, or API keys are shown.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final DiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    final platform = report.platform;
    final recorder = report.recorder;
    return Column(
      children: [
        _DiagnosticsCard(
          title: 'App & build',
          icon: Icons.developer_mode_rounded,
          rows: [
            _DiagnosticRow(
              'Version',
              '${platform.versionName} (${platform.versionCode})',
            ),
            _DiagnosticRow('Package', platform.packageName),
            _DiagnosticRow('Build mode', platform.buildMode),
            _DiagnosticRow(
              'Diagnostics contract',
              'v${platform.contractVersion}',
            ),
            _DiagnosticRow(
              'Database schema',
              'v${report.databaseSchemaVersion}',
            ),
          ],
        ),
        const SizedBox(height: TraelyxSpacing.md),
        _DiagnosticsCard(
          title: 'Recorder',
          icon: Icons.sensors_off_outlined,
          rows: [
            _DiagnosticRow('State', recorder.implementationState),
            _DiagnosticRow('Bridge', 'v${recorder.bridgeVersion}'),
            _DiagnosticRow(
              'Service registered',
              recorder.serviceRegistered ? 'Yes' : 'No',
            ),
            _DiagnosticRow(
              'Recording available',
              recorder.recordingAvailable ? 'Yes' : 'No',
            ),
          ],
          footer: recorder.recordingAvailable
              ? null
              : 'Recorder remains intentionally unavailable; diagnostics do '
                    'not activate sensors or location.',
        ),
        const SizedBox(height: TraelyxSpacing.md),
        _StorageCard(storage: platform.storage),
      ],
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage});

  final DiagnosticsStorageBreakdown storage;

  @override
  Widget build(BuildContext context) {
    return _DiagnosticsCard(
      title: 'Storage breakdown',
      icon: Icons.storage_outlined,
      rows: [
        _DiagnosticRow('App', formatDiagnosticBytes(storage.appBytes)),
        _DiagnosticRow(
          'Trip summaries',
          formatDiagnosticBytes(storage.databaseBytes),
        ),
        _DiagnosticRow(
          'Raw telemetry',
          formatDiagnosticBytes(storage.rawTelemetryBytes),
        ),
        _DiagnosticRow(
          'Map cache',
          formatDiagnosticBytes(storage.mapCacheBytes),
        ),
        _DiagnosticRow(
          'Local AI models',
          formatDiagnosticBytes(storage.localModelBytes),
        ),
        _DiagnosticRow('Total', formatDiagnosticBytes(storage.totalBytes)),
      ],
      footer:
          'Aggregate bytes only. Unimplemented storage categories report zero; '
          'cache controls and export arrive in later roadmap steps.',
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.footer,
  });

  final String title;
  final IconData icon;
  final List<_DiagnosticRow> rows;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.traelyxColors.information),
                const SizedBox(width: TraelyxSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: TraelyxSpacing.md),
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index != rows.length - 1)
                Divider(color: context.traelyxColors.outline),
            ],
            if (footer != null) ...[
              const SizedBox(height: TraelyxSpacing.md),
              Text(footer!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TraelyxSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: TraelyxSpacing.lg),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.traelyxColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(TraelyxSpacing.section),
        child: CircularProgressIndicator(semanticsLabel: 'Loading diagnostics'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: context.traelyxColors.critical,
              size: 32,
            ),
            const SizedBox(height: TraelyxSpacing.sm),
            Text(
              'Diagnostics unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TraelyxSpacing.xxs),
            const Text(
              'The report could not be collected. Internal errors are hidden '
              'because they may contain sensitive local details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TraelyxSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
