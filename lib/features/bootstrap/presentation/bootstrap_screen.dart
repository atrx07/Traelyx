import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';

class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(bootstrapReadinessProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              children: [
                const _Wordmark(),
                const SizedBox(height: 72),
                Text(
                  'Your drives.\nYour evidence.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'Traelyx is being built local-first. Trip recording stays '
                  'disabled until the native recorder passes its reliability '
                  'gate.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: TraelyxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                _FoundationCard(readiness: readiness),
                const SizedBox(height: 16),
                const _RecorderCard(),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Start drive — available after M1'),
                ),
                const SizedBox(height: 12),
                Text(
                  'No account required · No telemetry uploaded',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: TraelyxColors.brandAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'TRAELYX',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(letterSpacing: 2.8),
        ),
        const Spacer(),
        Text('M0 · FOUNDATION', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard({required this.readiness});

  final AsyncValue<BootstrapReadiness> readiness;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: readiness.when(
          loading: () => const _StatusRow(
            icon: Icons.sync,
            color: TraelyxColors.statusInfo,
            title: 'Checking foundation',
            detail: 'Opening local storage and native bridge…',
          ),
          error: (error, stackTrace) => const _StatusRow(
            icon: Icons.error_outline,
            color: TraelyxColors.statusSevere,
            title: 'Foundation check failed',
            detail: 'Open diagnostics before continuing.',
          ),
          data: (status) => _StatusRow(
            icon: Icons.check_circle_outline,
            color: TraelyxColors.statusGood,
            title: 'Local foundation ready',
            detail:
                'Database v1 · Native bridge v${status.bridgeVersion} · '
                'Recorder ${status.recorderState}',
          ),
        ),
      ),
    );
  }
}

class _RecorderCard extends StatelessWidget {
  const _RecorderCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: _StatusRow(
          icon: Icons.shield_outlined,
          color: TraelyxColors.statusWarning,
          title: 'Recorder intentionally unavailable',
          detail: 'No sensors, location, or background service are active.',
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, semanticLabel: title),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
