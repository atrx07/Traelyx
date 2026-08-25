import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/drive_dna/application/drive_dna_providers.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';
import 'package:traelyx/features/drive_dna/presentation/drive_dna_signature.dart';

class DriveDnaScreen extends ConsumerWidget {
  const DriveDnaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dna = ref.watch(driveDnaProvider);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: dna.when(
            loading: () => const _DnaLoading(),
            error: (error, stackTrace) =>
                _DnaError(onRetry: () => ref.invalidate(driveDnaProvider)),
            data: (snapshot) => snapshot == null
                ? const _EmptyDna()
                : _DnaContent(snapshot: snapshot),
          ),
        ),
      ),
    );
  }
}

class _DnaContent extends StatelessWidget {
  const _DnaContent({required this.snapshot});

  final DriveDnaSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final lifecycle = _lifecycleLabel(snapshot.lifecycleState);
    final profile = _profileLabel(snapshot.profileState);
    return ListView(
      key: const ValueKey('drive-dna-screen'),
      padding: const EdgeInsets.fromLTRB(
        TraelyxSpacing.xl,
        TraelyxSpacing.xxl,
        TraelyxSpacing.xl,
        TraelyxSpacing.section,
      ),
      children: [
        const _DnaHeader(),
        const SizedBox(height: TraelyxSpacing.xxl),
        _SignaturePanel(
          dimensions: snapshot.dimensions,
          centerLabel: profile,
          centerValue: snapshot.validTripCount.toString(),
          title: '$profile signature',
          detail: '$lifecycle · ${snapshot.vehicleLabel}',
          showMarkerLegend: true,
        ),
        const SizedBox(height: TraelyxSpacing.xxl),
        const _SectionLabel('PROFILE DIMENSIONS'),
        const SizedBox(height: TraelyxSpacing.sm),
        _DimensionPanel(dimensions: snapshot.dimensions),
        const SizedBox(height: TraelyxSpacing.xxl),
        const _SectionLabel('BASELINE LIFECYCLE'),
        const SizedBox(height: TraelyxSpacing.sm),
        _LifecyclePanel(snapshot: snapshot),
        const SizedBox(height: TraelyxSpacing.xxl),
        const _SectionLabel('PROVENANCE'),
        const SizedBox(height: TraelyxSpacing.sm),
        _ProvenancePanel(snapshot: snapshot),
        const SizedBox(height: TraelyxSpacing.xxl),
        const _ScopeNote(),
      ],
    );
  }
}

class _EmptyDna extends StatelessWidget {
  const _EmptyDna();

  static final List<DriveDnaDimension> dimensions =
      List<DriveDnaDimension>.unmodifiable(
        DriveDnaDimensionType.values.map(
          (type) => DriveDnaDimension(
            type: type,
            state: DriveDnaDimensionState.insufficientData,
            valueMilliPoints: null,
            eligibleTripCount: 0,
            recentDeltaMilliPoints: null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('drive-dna-screen'),
      padding: const EdgeInsets.fromLTRB(
        TraelyxSpacing.xl,
        TraelyxSpacing.xxl,
        TraelyxSpacing.xl,
        TraelyxSpacing.section,
      ),
      children: [
        const _DnaHeader(),
        const SizedBox(height: TraelyxSpacing.xxl),
        _SignaturePanel(
          dimensions: dimensions,
          centerLabel: 'Uncalibrated',
          centerValue: '0 / 10',
          title: 'Your signature is still forming',
          detail:
              'No governed Drive DNA snapshot has been persisted on this phone.',
          showMarkerLegend: false,
        ),
        const SizedBox(height: TraelyxSpacing.xxl),
        const _SectionLabel('WHAT HAPPENS NEXT'),
        const SizedBox(height: TraelyxSpacing.sm),
        _InfoPanel(
          icon: Icons.fingerprint,
          title: 'Evidence before identity',
          detail:
              'A signature appears only after eligible analyzed drives are saved to a governed local baseline. Recorded trips are never converted into DNA by the UI.',
        ),
        const SizedBox(height: TraelyxSpacing.sm),
        _InfoPanel(
          icon: Icons.layers_outlined,
          title: 'Five explainable dimensions',
          detail:
              'Smoothness, braking control, acceleration control, cornering control, and cross-trip consistency remain individually readable.',
        ),
        const SizedBox(height: TraelyxSpacing.xxl),
        const _ScopeNote(),
      ],
    );
  }
}

class _DnaHeader extends StatelessWidget {
  const _DnaHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DRIVE DNA',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.traelyxColors.accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: TraelyxSpacing.xs),
          Text(
            'Your driving signature',
            key: const ValueKey('destination-DNA'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: TraelyxSpacing.md),
          Text(
            'A local, versioned profile of observed patterns—not a universal judgment of driving ability.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.traelyxColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePanel extends StatelessWidget {
  const _SignaturePanel({
    required this.dimensions,
    required this.centerLabel,
    required this.centerValue,
    required this.title,
    required this.detail,
    required this.showMarkerLegend,
  });

  final List<DriveDnaDimension> dimensions;
  final String centerLabel;
  final String centerValue;
  final String title;
  final String detail;
  final bool showMarkerLegend;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TraelyxSpacing.lg),
      decoration: BoxDecoration(
        color: context.traelyxColors.surfaceRaised,
        borderRadius: BorderRadius.circular(TraelyxRadii.panel),
        border: Border.all(color: context.traelyxColors.outlineStrong),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620 && !largeText;
          final signature = SizedBox(
            width: wide ? 300 : double.infinity,
            child: DriveDnaSignature(
              dimensions: dimensions,
              centerLabel: centerLabel,
              centerValue: centerValue,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(detail, style: Theme.of(context).textTheme.bodyLarge),
              if (showMarkerLegend) ...[
                const SizedBox(height: TraelyxSpacing.md),
                Text(
                  'Colored endpoints show current values. White outline markers show a previous value only when a recent delta was persisted.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
          if (wide) {
            return Row(
              children: [
                signature,
                const SizedBox(width: TraelyxSpacing.xl),
                Expanded(child: copy),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              signature,
              const SizedBox(height: TraelyxSpacing.lg),
              copy,
            ],
          );
        },
      ),
    );
  }
}

class _DimensionPanel extends StatelessWidget {
  const _DimensionPanel({required this.dimensions});

  final List<DriveDnaDimension> dimensions;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        for (var index = 0; index < dimensions.length; index++) ...[
          _DimensionRow(dimension: dimensions[index]),
          if (index != dimensions.length - 1)
            const Divider(height: TraelyxSpacing.xxl),
        ],
      ],
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});

  final DriveDnaDimension dimension;

  @override
  Widget build(BuildContext context) {
    final label = driveDnaDimensionLabel(dimension.type);
    final value = dimension.value;
    final valueLabel = value == null
        ? 'Insufficient data'
        : '${value.round()} / 100';
    final trend = dimension.recentDelta;
    final trendLabel = trend == null
        ? 'No recent direction recorded'
        : _shortTrend(trend);
    final detail = value == null
        ? '${dimension.eligibleTripCount} eligible drives; value withheld.'
        : '${dimension.eligibleTripCount} eligible drives · $trendLabel';
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final marker = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.traelyxColors.surfaceRaised,
        border: Border.all(color: context.traelyxColors.outlineStrong),
      ),
      child: Text(
        value == null ? '—' : value.round().toString(),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: TraelyxSpacing.xxs),
        Text(valueLabel, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: TraelyxSpacing.xxs),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Semantics(
      label: '$label: $valueLabel. $detail',
      child: ExcludeSemantics(
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  marker,
                  const SizedBox(height: TraelyxSpacing.sm),
                  copy,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  marker,
                  const SizedBox(width: TraelyxSpacing.md),
                  Expanded(child: copy),
                ],
              ),
      ),
    );
  }
}

class _LifecyclePanel extends StatelessWidget {
  const _LifecyclePanel({required this.snapshot});

  final DriveDnaSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final lifecycle = _lifecycleLabel(snapshot.lifecycleState);
    final targetProgress = (snapshot.validTripCount / 10).clamp(0.0, 1.0);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final lifecycleIcon = Icon(
      _lifecycleIcon(snapshot.lifecycleState),
      color: _lifecycleColor(context, snapshot.lifecycleState),
    );
    final lifecycleTitle = Text(
      lifecycle,
      style: Theme.of(context).textTheme.titleLarge,
    );
    final lifecycleCount = Text(
      snapshot.validTripCount >= 10
          ? '${snapshot.validTripCount} eligible'
          : '${snapshot.validTripCount} / 10',
      style: Theme.of(context).textTheme.labelLarge,
    );
    return _Panel(
      children: [
        Semantics(
          label:
              '$lifecycle lifecycle. ${snapshot.validTripCount} eligible drives. ${_lifecycleDetail(snapshot.lifecycleState)}',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (largeText)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      lifecycleIcon,
                      const SizedBox(height: TraelyxSpacing.sm),
                      lifecycleTitle,
                      const SizedBox(height: TraelyxSpacing.xs),
                      lifecycleCount,
                    ],
                  )
                else
                  Row(
                    children: [
                      lifecycleIcon,
                      const SizedBox(width: TraelyxSpacing.sm),
                      Expanded(child: lifecycleTitle),
                      lifecycleCount,
                    ],
                  ),
                const SizedBox(height: TraelyxSpacing.md),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: targetProgress),
                  duration: TraelyxMotion.effectiveDuration(
                    context,
                    TraelyxMotion.standard,
                  ),
                  builder: (context, progress, child) =>
                      LinearProgressIndicator(value: progress),
                ),
                const SizedBox(height: TraelyxSpacing.sm),
                Text(
                  _lifecycleDetail(snapshot.lifecycleState),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProvenancePanel extends StatelessWidget {
  const _ProvenancePanel({required this.snapshot});

  final DriveDnaSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final window = snapshot.windowStartUtc == null
        ? 'History window not recorded'
        : '${localizations.formatMediumDate(snapshot.windowStartUtc!.toLocal())}–${localizations.formatMediumDate(snapshot.windowEndUtc!.toLocal())}';
    return _Panel(
      children: [
        _ProvenanceRow(label: 'Vehicle scope', value: snapshot.vehicleLabel),
        const Divider(height: TraelyxSpacing.xxl),
        _ProvenanceRow(label: 'Eligible history', value: window),
        const Divider(height: TraelyxSpacing.xxl),
        _ProvenanceRow(
          label: 'Versions',
          value:
              'DNA v${snapshot.driveDnaVersion} · baseline schema v${snapshot.baselineSchemaVersion} · ${snapshot.scoringVersion}',
        ),
        const Divider(height: TraelyxSpacing.xxl),
        _ProvenanceRow(
          label: 'Confidence',
          value: snapshot.confidenceRecorded
              ? 'Bounded summary recorded; percentage hidden'
              : 'Not recorded',
        ),
      ],
    );
  }
}

class _ProvenanceRow extends StatelessWidget {
  const _ProvenanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium,
    );
    final valueWidget = Text(
      value,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelWidget,
                  const SizedBox(height: TraelyxSpacing.xs),
                  valueWidget,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: labelWidget),
                  const SizedBox(width: TraelyxSpacing.md),
                  Expanded(child: valueWidget),
                ],
              ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.traelyxColors.accent),
            const SizedBox(width: TraelyxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: TraelyxSpacing.xs),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScopeNote extends StatelessWidget {
  const _ScopeNote();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Local-only Drive DNA. This is an observed-behavior profile, not a legal, medical, insurance, or universal competence assessment.',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              size: 20,
              color: context.traelyxColors.textSecondary,
            ),
            const SizedBox(width: TraelyxSpacing.sm),
            Expanded(
              child: Text(
                'Local-only · Observed patterns, not a legal, medical, insurance, or universal competence assessment',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TraelyxSpacing.lg),
      decoration: BoxDecoration(
        color: context.traelyxColors.surface,
        borderRadius: BorderRadius.circular(TraelyxRadii.card),
        border: Border.all(color: context.traelyxColors.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(letterSpacing: 1.6),
      ),
    );
  }
}

class _DnaLoading extends StatelessWidget {
  const _DnaLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading local Drive DNA',
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DnaError extends StatelessWidget {
  const _DnaError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('drive-dna-screen'),
      padding: const EdgeInsets.all(TraelyxSpacing.xl),
      children: [
        const _DnaHeader(),
        const SizedBox(height: TraelyxSpacing.xxl),
        _InfoPanel(
          icon: Icons.warning_amber_outlined,
          title: 'Drive DNA could not be verified',
          detail:
              'The local baseline snapshot was malformed or unreadable. No profile claim is shown and no data was changed.',
        ),
        const SizedBox(height: TraelyxSpacing.md),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry local baseline'),
        ),
      ],
    );
  }
}

String _profileLabel(DriveDnaProfileState state) => switch (state) {
  DriveDnaProfileState.complete => 'Complete',
  DriveDnaProfileState.partial => 'Partial',
  DriveDnaProfileState.unavailable => 'Unavailable',
};

String _lifecycleLabel(DriveDnaLifecycleState state) => switch (state) {
  DriveDnaLifecycleState.uncalibrated => 'Uncalibrated',
  DriveDnaLifecycleState.emerging => 'Emerging',
  DriveDnaLifecycleState.established => 'Established',
  DriveDnaLifecycleState.recalibrating => 'Recalibrating',
};

String _lifecycleDetail(DriveDnaLifecycleState state) => switch (state) {
  DriveDnaLifecycleState.uncalibrated =>
    'No eligible evidence has entered the current baseline.',
  DriveDnaLifecycleState.emerging =>
    'The local baseline is forming. Personal comparisons remain uncertain.',
  DriveDnaLifecycleState.established =>
    'At least ten current eligible drives and a complete profile are present.',
  DriveDnaLifecycleState.recalibrating =>
    'A vehicle, mount, sensor, or long-gap change started a fresh evidence window.',
};

IconData _lifecycleIcon(DriveDnaLifecycleState state) => switch (state) {
  DriveDnaLifecycleState.uncalibrated => Icons.hourglass_empty,
  DriveDnaLifecycleState.emerging => Icons.auto_graph,
  DriveDnaLifecycleState.established => Icons.verified_outlined,
  DriveDnaLifecycleState.recalibrating => Icons.sync,
};

Color _lifecycleColor(BuildContext context, DriveDnaLifecycleState state) =>
    switch (state) {
      DriveDnaLifecycleState.uncalibrated =>
        context.traelyxColors.textSecondary,
      DriveDnaLifecycleState.emerging => context.traelyxColors.information,
      DriveDnaLifecycleState.established => context.traelyxColors.positive,
      DriveDnaLifecycleState.recalibrating => context.traelyxColors.caution,
    };

String _shortTrend(double delta) {
  final rounded = delta.round();
  if (rounded > 0) return 'Recent +$rounded';
  if (rounded < 0) return 'Recent −${rounded.abs()}';
  return 'Recent steady';
}
