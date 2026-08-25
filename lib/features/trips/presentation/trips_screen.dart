import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tripHistoryProvider);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: history.when(
            loading: () => const _HistoryLoading(),
            error: (error, stackTrace) => _HistoryError(
              onRetry: () => ref.invalidate(tripHistoryProvider),
            ),
            data: (trips) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(tripHistoryProvider);
                await ref.read(tripHistoryProvider.future);
              },
              child: CustomScrollView(
                key: const ValueKey('trips-history-screen'),
                slivers: [
                  const SliverToBoxAdapter(child: _HistoryHeader()),
                  if (trips.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHistory(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        TraelyxSpacing.xl,
                        0,
                        TraelyxSpacing.xl,
                        TraelyxSpacing.section,
                      ),
                      sliver: SliverList.separated(
                        itemCount: trips.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: TraelyxSpacing.md),
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return _TripHistoryCard(
                            trip: trip,
                            onOpen: () =>
                                context.go(TraelyxRoutes.tripResult(trip.id)),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TraelyxSpacing.xl,
        TraelyxSpacing.xl,
        TraelyxSpacing.xl,
        TraelyxSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOCAL HISTORY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.traelyxColors.accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: TraelyxSpacing.xs),
          Text('Your drives', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: TraelyxSpacing.sm),
          Text(
            'Newest first. Stored on this phone and available without an account.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.traelyxColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.trip, required this.onOpen});

  final TripHistoryItem trip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final localStart = trip.startedAtUtc.toLocal();
    final date = _formatDateTime(context, localStart);
    final duration = _formatDuration(trip.duration);
    final distance = _formatDistance(trip.distanceMeters);
    final completion = _completionLabel(trip.completionState);
    final colors = context.traelyxColors;

    return Semantics(
      button: true,
      label:
          '$date. ${trip.vehicleName}. $duration. $distance. $completion. Open drive result.',
      onTap: onOpen,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TraelyxRadii.card),
            side: BorderSide(color: colors.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('trip-history-${trip.id}'),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(TraelyxSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: TraelyxSpacing.xxs),
                            Text(
                              trip.vehicleName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      _StatePill(
                        label: completion,
                        state: trip.completionState,
                      ),
                    ],
                  ),
                  const SizedBox(height: TraelyxSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _HistoryMetric(
                          label: 'DURATION',
                          value: duration,
                        ),
                      ),
                      const SizedBox(width: TraelyxSpacing.lg),
                      Expanded(
                        child: _HistoryMetric(
                          label: 'DISTANCE',
                          value: distance,
                        ),
                      ),
                      const SizedBox(width: TraelyxSpacing.sm),
                      Icon(Icons.chevron_right, color: colors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: TraelyxSpacing.xxs),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.state});

  final String label;
  final TripEvidenceState state;

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TraelyxSpacing.sm,
        vertical: TraelyxSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(TraelyxRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TraelyxSpacing.xl),
      child: Center(
        child: Semantics(
          label:
              'No drives yet. Completed drives will appear here after they are verified and indexed locally.',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 52,
                  color: context.traelyxColors.textSecondary,
                ),
                const SizedBox(height: TraelyxSpacing.lg),
                Text(
                  'No drives yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: TraelyxSpacing.sm),
                Text(
                  'Completed drives will appear here after their evidence is verified and indexed locally.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Loading local trip history',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TraelyxSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.traelyxColors.critical,
            ),
            const SizedBox(height: TraelyxSpacing.lg),
            Text(
              'Local history could not be read',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: TraelyxSpacing.sm),
            const Text(
              'No trip data was changed. Retry the local database read.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TraelyxSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(value)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}

String _formatDuration(Duration? value) {
  if (value == null) return 'Not available';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String _formatDistance(double? meters) {
  if (meters == null) return 'Not available';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _completionLabel(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Completed',
  TripEvidenceState.reviewRequired => 'Review needed',
  TripEvidenceState.limited => 'Limited',
  TripEvidenceState.unavailable => 'Unavailable',
  TripEvidenceState.notAssessed => 'Unknown',
};

Color _stateColor(BuildContext context, TripEvidenceState state) =>
    switch (state) {
      TripEvidenceState.verified => context.traelyxColors.positive,
      TripEvidenceState.limited => context.traelyxColors.caution,
      TripEvidenceState.reviewRequired => context.traelyxColors.critical,
      TripEvidenceState.unavailable => context.traelyxColors.textSecondary,
      TripEvidenceState.notAssessed => context.traelyxColors.information,
    };
