import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';

class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(bootstrapReadinessProvider);
    final colors = context.traelyxColors;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TraelyxSpacing.xl,
              TraelyxSpacing.xxl,
              TraelyxSpacing.xl,
              TraelyxSpacing.section,
            ),
            children: [
              const _Wordmark(),
              const SizedBox(height: TraelyxSpacing.hero),
              Text(
                'Your drives.\nYour evidence.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Text(
                'Traelyx is being built local-first. Trip recording stays '
                'disabled until the native recorder passes its reliability '
                'gate.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: TraelyxSpacing.xxl),
              _FoundationCard(readiness: readiness),
              const SizedBox(height: TraelyxSpacing.md),
              const _RecorderCard(),
              const SizedBox(height: TraelyxSpacing.xxl),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Start drive — available after M2'),
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                'No account required · No telemetry uploaded',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
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
    final colors = context.traelyxColors;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: TraelyxSpacing.sm),
        Expanded(
          child: Text(
            'TRAELYX',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(letterSpacing: 2.8),
          ),
        ),
        const SizedBox(width: TraelyxSpacing.sm),
        Text(
          'M1 · FOUNDATION',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium,
        ),
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
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: readiness.when(
          loading: () => _StatusRow(
            icon: Icons.sync,
            color: context.traelyxColors.information,
            title: 'Checking foundation',
            detail: 'Opening local storage and native bridge…',
          ),
          error: (error, stackTrace) => _StatusRow(
            icon: Icons.error_outline,
            color: context.traelyxColors.critical,
            title: 'Foundation check failed',
            detail: 'Open diagnostics before continuing.',
          ),
          data: (status) => _StatusRow(
            icon: Icons.check_circle_outline,
            color: context.traelyxColors.positive,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: _StatusRow(
          icon: Icons.shield_outlined,
          color: context.traelyxColors.caution,
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
        const SizedBox(width: TraelyxSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: TraelyxSpacing.xxs),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
