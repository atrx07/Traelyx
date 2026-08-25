import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/maps/offline_route_map.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/application/replay_clock_controller.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';
import 'package:traelyx/features/trips/application/trip_route_providers.dart';
import 'package:traelyx/features/trips/data/trip_route_repository.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/domain/trip_history_models.dart';
import 'package:traelyx/features/trips/presentation/replay_evidence_timeline.dart';

class TripResultScreen extends ConsumerWidget {
  const TripResultScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(tripResultProvider(tripId));
    return SafeArea(
      child: result.when(
        loading: () => const _ResultLoading(),
        error: (error, stackTrace) => _ResultError(
          onBack: () => context.pop(),
          onRetry: () => ref.invalidate(tripResultProvider(tripId)),
        ),
        data: (value) => value == null
            ? _ResultNotFound(onBack: () => context.pop())
            : _ResultContent(result: value, onBack: () => context.pop()),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.result, required this.onBack});

  final TripResult result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final localStart = result.trip.startedAtUtc.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localStart);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localStart),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: CustomScrollView(
          key: const ValueKey('trip-result-screen'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TraelyxSpacing.sm,
                  TraelyxSpacing.sm,
                  TraelyxSpacing.xl,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('trip-result-back'),
                      onPressed: onBack,
                      tooltip: 'Back to Trips',
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: TraelyxSpacing.xs),
                    Expanded(
                      child: Text(
                        'Drive result',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                TraelyxSpacing.xl,
                TraelyxSpacing.lg,
                TraelyxSpacing.xl,
                TraelyxSpacing.section,
              ),
              sliver: SliverList.list(
                children: [
                  _ResultIdentity(
                    vehicleName: result.trip.vehicleName,
                    date: date,
                    time: time,
                  ),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _ScoreHero(score: result.score),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _SectionLabel(label: 'RECORDED TRIP'),
                  const SizedBox(height: TraelyxSpacing.sm),
                  _MetricGrid(
                    metrics: [
                      _MetricData(
                        label: 'Duration',
                        value: _formatDuration(result.trip.duration),
                        detail: result.trip.duration == null
                            ? 'Not recorded in the trip summary'
                            : 'Finalized elapsed time',
                      ),
                      _MetricData(
                        label: 'Distance',
                        value: _formatDistance(result.trip.distanceMeters),
                        detail: result.trip.distanceMeters == null
                            ? 'Not derived for this drive'
                            : 'Persisted trip summary',
                      ),
                      _MetricData(
                        label: 'Completion',
                        value: _completionLabel(result.trip.completionState),
                        detail: _completionDetail(result.trip.completionState),
                        state: result.trip.completionState,
                      ),
                    ],
                  ),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _SectionLabel(label: 'OFFLINE ROUTE'),
                  const SizedBox(height: TraelyxSpacing.sm),
                  _TripRouteSection(
                    tripId: result.trip.id,
                    recordedDuration: result.trip.duration,
                    events: result.events,
                  ),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _SectionLabel(label: 'CONFIDENCE & INTEGRITY'),
                  const SizedBox(height: TraelyxSpacing.sm),
                  _TrustPanel(result: result),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _SectionLabel(label: 'LOCAL EVIDENCE'),
                  const SizedBox(height: TraelyxSpacing.sm),
                  _EvidencePanel(result: result),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _SectionLabel(label: 'NOTABLE MOMENTS'),
                  const SizedBox(height: TraelyxSpacing.sm),
                  _MomentsPanel(events: result.events),
                  const SizedBox(height: TraelyxSpacing.xxl),
                  _PrivacyFooter(schemaVersion: result.telemetrySchemaVersion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultIdentity extends StatelessWidget {
  const _ResultIdentity({
    required this.vehicleName,
    required this.date,
    required this.time,
  });

  final String vehicleName;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Local drive result. $date at $time. $vehicleName.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOCAL DRIVE RESULT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.traelyxColors.accent,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: TraelyxSpacing.xs),
            Text(date, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: TraelyxSpacing.xs),
            Text(
              '$time · $vehicleName',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.score});

  final TripScoreSummary? score;

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    final hasScore = score?.overallScore != null;
    final value = hasScore ? score!.overallScore!.round().toString() : '—';
    final label = hasScore ? 'Overall synthesis' : 'Analysis not available';
    final detail = hasScore
        ? '${_scoreEligibilityLabel(score!.eligibilityState)} · ${score!.scoringVersion}'
        : 'This drive has not been processed into a persisted score. Recorded evidence remains available below.';

    return Semantics(
      label: hasScore ? '$label. $value.' : '$label. $detail',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(TraelyxSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(TraelyxRadii.panel),
            border: Border.all(color: colors.outlineStrong),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.08),
                  border: Border.all(
                    color: hasScore ? colors.accent : colors.outlineStrong,
                    width: 2,
                  ),
                ),
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: hasScore ? colors.accent : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: TraelyxSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: TraelyxSpacing.xs),
                    Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.traelyxColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.detail,
    this.state,
  });

  final String label;
  final String value;
  final String detail;
  final TripEvidenceState? state;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (largeText) {
      return Column(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricCard(metric: metrics[index]),
            if (index != metrics.length - 1)
              const SizedBox(height: TraelyxSpacing.sm),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 && metrics.length == 3) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _MetricCard(metric: metrics[0])),
                    const SizedBox(width: TraelyxSpacing.sm),
                    Expanded(child: _MetricCard(metric: metrics[1])),
                  ],
                ),
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              _MetricCard(metric: metrics[2]),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: _MetricCard(metric: metrics[index])),
                if (index != metrics.length - 1)
                  const SizedBox(width: TraelyxSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    return Semantics(
      label: '${metric.label}: ${metric.value}. ${metric.detail}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(TraelyxSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(TraelyxRadii.card),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: TraelyxSpacing.xs),
              Text(
                metric.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: metric.state == null
                      ? colors.textPrimary
                      : _stateColor(context, metric.state!),
                ),
              ),
              const SizedBox(height: TraelyxSpacing.xxs),
              Text(metric.detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel({required this.result});

  final TripResult result;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        _StatusRow(
          icon: Icons.verified_user_outlined,
          label: 'Integrity',
          value: _integrityLabel(result.trip.integrityState),
          detail: _integrityDetail(result.trip.integrityState),
          state: result.trip.integrityState,
        ),
        const Divider(height: TraelyxSpacing.xxl),
        _StatusRow(
          icon: Icons.monitor_heart_outlined,
          label: 'Telemetry confidence',
          value: result.telemetryConfidenceRecorded
              ? 'Summary recorded'
              : 'Not assessed',
          detail: result.telemetryConfidenceRecorded
              ? 'A bounded schema-v1 summary exists; no uncalibrated percentage is shown.'
              : 'No confidence summary was persisted for this drive.',
          state: result.telemetryConfidenceRecorded
              ? TripEvidenceState.limited
              : TripEvidenceState.notAssessed,
        ),
        const Divider(height: TraelyxSpacing.xxl),
        _StatusRow(
          icon: Icons.restore_outlined,
          label: 'Recorder recovery',
          value: _recoveryLabel(result.trip.recoveryState),
          detail: _recoveryDetail(result.trip.recoveryState),
          state: result.trip.recoveryState,
        ),
      ],
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({required this.result});

  final TripResult result;

  @override
  Widget build(BuildContext context) {
    final evidence = result.evidence;
    final finalization = result.finalization;
    return _Panel(
      children: [
        _StatusRow(
          icon: Icons.inventory_2_outlined,
          label: 'Verified chunks',
          value: '${evidence.chunkCount}',
          detail: '${_formatBytes(evidence.byteCount)} indexed locally',
          state: evidence.chunkCount > 0
              ? TripEvidenceState.verified
              : TripEvidenceState.reviewRequired,
        ),
        const Divider(height: TraelyxSpacing.xxl),
        _StatusRow(
          icon: Icons.satellite_alt_outlined,
          label: 'GNSS samples',
          value: '${evidence.gnssSampleCount}',
          detail: 'Aggregate count; route geometry is read locally on demand.',
          state: evidence.gnssSampleCount > 0
              ? TripEvidenceState.verified
              : TripEvidenceState.unavailable,
        ),
        const Divider(height: TraelyxSpacing.xxl),
        _StatusRow(
          icon: Icons.screen_rotation_alt_outlined,
          label: 'Motion samples',
          value:
              '${evidence.accelerometerSampleCount + evidence.gyroscopeSampleCount}',
          detail:
              '${evidence.accelerometerSampleCount} accelerometer · ${evidence.gyroscopeSampleCount} gyroscope',
          state:
              evidence.accelerometerSampleCount > 0 &&
                  evidence.gyroscopeSampleCount > 0
              ? TripEvidenceState.verified
              : TripEvidenceState.unavailable,
        ),
        const Divider(height: TraelyxSpacing.xxl),
        _StatusRow(
          icon: Icons.fact_check_outlined,
          label: 'Finalization audit',
          value: finalization == null
              ? 'Not available'
              : finalization.hasLimitations
              ? 'Limitations recorded'
              : 'No isolated failures',
          detail: finalization == null
              ? 'No finalization summary was persisted.'
              : 'Logic v${finalization.logicVersion} · ${finalization.recoveryCount} recoveries · ${finalization.corruptChunkCount} corrupt chunks',
          state: finalization == null
              ? TripEvidenceState.unavailable
              : finalization.hasLimitations
              ? TripEvidenceState.limited
              : TripEvidenceState.verified,
        ),
      ],
    );
  }
}

class _TripRouteSection extends ConsumerWidget {
  const _TripRouteSection({
    required this.tripId,
    required this.recordedDuration,
    required this.events,
  });

  final String tripId;
  final Duration? recordedDuration;
  final List<TripEventSummary> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(tripRouteProvider(tripId));
    final cache = ref.watch(tripMapCacheStatusProvider);
    final routeResult = route.valueOrNull;
    final geometry = routeResult?.state == TripRouteState.available
        ? routeResult?.geometry
        : null;
    final timelineResult = ReplayTimeline.build(
      recordedDuration: recordedDuration,
      route: geometry,
      events: events,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        route.when(
          loading: () => const _RouteStatePanel(
            key: ValueKey('trip-route-loading'),
            icon: Icons.route_outlined,
            title: 'Reading verified route',
            detail: 'Processing local evidence on this phone.',
            loading: true,
          ),
          error: (error, stackTrace) => _RouteStatePanel(
            key: const ValueKey('trip-route-error'),
            icon: Icons.warning_amber_outlined,
            title: 'Route could not be read',
            detail: 'No partial route is shown and no trip data was changed.',
            action: TextButton.icon(
              onPressed: () => ref.invalidate(tripRouteProvider(tripId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry route'),
            ),
          ),
          data: (result) => switch (result.state) {
            TripRouteState.available => const SizedBox.shrink(),
            TripRouteState.unavailable => const _RouteStatePanel(
              key: ValueKey('trip-route-unavailable'),
              icon: Icons.route_outlined,
              title: 'Route not available',
              detail:
                  'This drive does not contain enough verified GNSS points for a route.',
            ),
            TripRouteState.invalid => const _RouteStatePanel(
              key: ValueKey('trip-route-invalid'),
              icon: Icons.gpp_maybe_outlined,
              title: 'Route could not be verified',
              detail:
                  'Local route evidence is incomplete or contradictory, so no partial path is shown.',
            ),
          },
        ),
        if (timelineResult case ReplayTimelineAvailable(:final timeline)) ...[
          if (routeResult?.state != TripRouteState.available)
            const SizedBox(height: TraelyxSpacing.sm),
          _ReplayWorkspace(timeline: timeline),
        ] else ...[
          const SizedBox(height: TraelyxSpacing.sm),
          const _RouteStatePanel(
            key: ValueKey('replay-timeline-unavailable'),
            icon: Icons.av_timer_outlined,
            title: 'Replay timeline not available',
            detail:
                'This drive has no positive recorded duration, verified route timing, or persisted event range.',
          ),
        ],
        const SizedBox(height: TraelyxSpacing.sm),
        _MapCachePanel(
          status: cache.valueOrNull,
          onClear: () async {
            final controller = await ref.read(tripMapControllerProvider.future);
            await controller.clearCache();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No offline map tiles were stored.'),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _ReplayWorkspace extends StatefulWidget {
  const _ReplayWorkspace({required this.timeline});

  final ReplayTimeline timeline;

  @override
  State<_ReplayWorkspace> createState() => _ReplayWorkspaceState();
}

class _ReplayWorkspaceState extends State<_ReplayWorkspace> {
  late ReplayClockController _clock;

  @override
  void initState() {
    super.initState();
    _clock = ReplayClockController(widget.timeline);
  }

  @override
  void didUpdateWidget(covariant _ReplayWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeline != widget.timeline) {
      final position = _clock.snapshot.position;
      _clock.dispose();
      _clock = ReplayClockController(widget.timeline)..seek(position);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, child) {
        final timeline = _clock.timeline;
        final snapshot = _clock.snapshot;
        final geometry = timeline.route;
        return Column(
          key: const ValueKey('trip-replay-workspace'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (geometry != null) ...[
              OfflineRouteMap(
                key: const ValueKey('trip-route-available'),
                geometry: geometry,
                replayMarker: snapshot.routeMarker?.coordinate,
                replayMarkerAfterPointIndex:
                    snapshot.routeMarker?.afterPointIndex,
                replayPosition: snapshot.position,
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Wrap(
                spacing: TraelyxSpacing.lg,
                runSpacing: TraelyxSpacing.xs,
                children: [
                  const _RouteLegend(
                    icon: Icons.radio_button_checked,
                    label: 'Start',
                  ),
                  const _RouteLegend(
                    icon: Icons.diamond_outlined,
                    label: 'End',
                  ),
                  if (geometry.segmentCount > 1)
                    _RouteLegend(
                      icon: Icons.space_bar,
                      label:
                          '${geometry.segmentCount - 1} ${geometry.segmentCount == 2 ? 'gap' : 'gaps'}',
                    ),
                ],
              ),
              const SizedBox(height: TraelyxSpacing.xs),
              Text(
                '${geometry.points.length} display points · GNSS processing v${geometry.processingVersion}${geometry.reduced ? ' · reduced for display' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: TraelyxSpacing.md),
            ],
            _Panel(
              children: [
                Text(
                  'Manual replay timeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: TraelyxSpacing.xxs),
                Text(
                  'One cursor controls the verified map position, evidence graph, and persisted events. Playback and speed controls arrive in a later step.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: TraelyxSpacing.md),
                Row(
                  children: [
                    Text(
                      formatReplayOffset(snapshot.position),
                      key: const ValueKey('replay-current-time'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatReplayOffset(timeline.duration),
                      key: const ValueKey('replay-total-time'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Semantics(
                  key: const ValueKey('replay-timeline-semantics'),
                  container: true,
                  explicitChildNodes: true,
                  label: 'Replay timeline position',
                  value:
                      '${formatReplayOffset(snapshot.position)} of ${formatReplayOffset(timeline.duration)}',
                  hint: 'Adjust to inspect recorded evidence at another time.',
                  increasedValue: formatReplayOffset(
                    Duration(
                      microseconds:
                          (timeline.duration.inMicroseconds *
                                  (_clock.fraction + 0.01).clamp(0.0, 1.0))
                              .round(),
                    ),
                  ),
                  decreasedValue: formatReplayOffset(
                    Duration(
                      microseconds:
                          (timeline.duration.inMicroseconds *
                                  (_clock.fraction - 0.01).clamp(0.0, 1.0))
                              .round(),
                    ),
                  ),
                  onIncrease: () => _clock.seekFraction(_clock.fraction + 0.01),
                  onDecrease: () => _clock.seekFraction(_clock.fraction - 0.01),
                  child: ExcludeSemantics(
                    child: Slider(
                      key: const ValueKey('replay-timeline-slider'),
                      value: _clock.fraction,
                      onChanged: _clock.seekFraction,
                    ),
                  ),
                ),
                ReplayEvidenceTimeline(timeline: timeline, snapshot: snapshot),
                const SizedBox(height: TraelyxSpacing.sm),
                Text(
                  snapshot.routeMarker == null
                      ? 'No verified route position at this time.'
                      : 'Verified route position available at this time.',
                  key: const ValueKey('replay-marker-state'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (timeline.events.isEmpty) ...[
                  const SizedBox(height: TraelyxSpacing.xs),
                  Text(
                    'No governed event ranges are persisted for this drive.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: TraelyxSpacing.sm),
                  Wrap(
                    spacing: TraelyxSpacing.xs,
                    runSpacing: TraelyxSpacing.xs,
                    children: [
                      for (
                        var index = 0;
                        index < timeline.events.length;
                        index++
                      )
                        OutlinedButton(
                          key: ValueKey('replay-event-$index'),
                          onPressed: () => _clock.seekToEvent(index),
                          style: snapshot.activeEventIndexes.contains(index)
                              ? OutlinedButton.styleFrom(
                                  foregroundColor:
                                      context.traelyxColors.caution,
                                )
                              : null,
                          child: Text(
                            '${_eventLabel(timeline.events[index].type)} · ${formatReplayOffset(timeline.events[index].start)}',
                          ),
                        ),
                    ],
                  ),
                ],
                if (timeline.discardedEventCount > 0) ...[
                  const SizedBox(height: TraelyxSpacing.xs),
                  Text(
                    '${timeline.discardedEventCount} contradictory event ${timeline.discardedEventCount == 1 ? 'range was' : 'ranges were'} excluded from replay.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.traelyxColors.caution,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: context.traelyxColors.textSecondary),
        const SizedBox(width: TraelyxSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RouteStatePanel extends StatelessWidget {
  const _RouteStatePanel({
    required this.icon,
    required this.title,
    required this.detail,
    this.loading = false,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        Semantics(
          liveRegion: loading,
          label: '$title. $detail',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loading)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: context.traelyxColors.textSecondary),
                const SizedBox(width: TraelyxSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: TraelyxSpacing.xxs),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: TraelyxSpacing.xs),
          Align(alignment: Alignment.centerLeft, child: action!),
        ],
      ],
    );
  }
}

class _MapCachePanel extends StatelessWidget {
  const _MapCachePanel({required this.status, required this.onClear});

  final MapCacheStatus? status;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final bytes = status?.bytesUsed ?? 0;
    final available = status?.isAvailable == true;
    return Container(
      key: const ValueKey('map-cache-status'),
      padding: const EdgeInsets.all(TraelyxSpacing.md),
      decoration: BoxDecoration(
        color: context.traelyxColors.surface,
        borderRadius: BorderRadius.circular(TraelyxRadii.control),
        border: Border.all(color: context.traelyxColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Offline canvas · no network required'),
          const SizedBox(height: TraelyxSpacing.xxs),
          Text(
            available
                ? 'Tile cache · ${_formatBytes(bytes)}'
                : 'Tile cache unavailable · 0 B',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: TraelyxSpacing.xs),
          OutlinedButton.icon(
            key: const ValueKey('clear-map-cache'),
            onPressed: onClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear tile cache'),
          ),
        ],
      ),
    );
  }
}

class _MomentsPanel extends StatelessWidget {
  const _MomentsPanel({required this.events});

  final List<TripEventSummary> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _Panel(
        children: [
          _StatusRow(
            icon: Icons.timeline_outlined,
            label: 'Analyzed moments',
            value: 'Not available',
            detail:
                'No governed event results have been persisted for this drive.',
            state: TripEvidenceState.unavailable,
          ),
        ],
      );
    }
    return _Panel(
      children: [
        for (var index = 0; index < events.length; index++) ...[
          _StatusRow(
            icon: Icons.bolt_outlined,
            label: 'Moment ${index + 1}',
            value: _eventLabel(events[index].type),
            detail: _relativeRange(events[index]),
            state: TripEvidenceState.limited,
          ),
          if (index != events.length - 1)
            const Divider(height: TraelyxSpacing.xxl),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TraelyxSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TraelyxRadii.card),
        border: Border.all(color: colors.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.state,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final TripEvidenceState state;

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(context, state);
    return Semantics(
      label: '$label: $value. $detail',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: TraelyxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: TraelyxSpacing.xxs),
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: TraelyxSpacing.xxs),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter({required this.schemaVersion});

  final int schemaVersion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Local-only result. Telemetry schema version $schemaVersion. Route geometry is read transiently on this phone. Raw samples and storage details are not shown.',
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
                'Local-only result · Telemetry schema v$schemaVersion · Route geometry stays on this phone · Raw samples and storage details are not shown',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultLoading extends StatelessWidget {
  const _ResultLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Loading local drive result',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _ResultError extends StatelessWidget {
  const _ResultError({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ResultState(
      icon: Icons.warning_amber_outlined,
      title: 'Drive result could not be verified',
      detail:
          'The local evidence summary was missing or malformed. No trip data was changed.',
      onBack: onBack,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }
}

class _ResultNotFound extends StatelessWidget {
  const _ResultNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _ResultState(
      icon: Icons.route_outlined,
      title: 'Drive not found',
      detail:
          'This local drive is no longer indexed on this phone, or the link is invalid.',
      onBack: onBack,
    );
  }
}

class _ResultState extends StatelessWidget {
  const _ResultState({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onBack,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TraelyxSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back to Trips',
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 52, color: context.traelyxColors.caution),
                  const SizedBox(height: TraelyxSpacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: TraelyxSpacing.sm),
                  Text(detail, textAlign: TextAlign.center),
                  if (action != null) ...[
                    const SizedBox(height: TraelyxSpacing.lg),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

String _completionLabel(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Completed',
  TripEvidenceState.reviewRequired => 'Review needed',
  TripEvidenceState.limited => 'Limited',
  TripEvidenceState.unavailable => 'Unavailable',
  TripEvidenceState.notAssessed => 'Not assessed',
};

String _completionDetail(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Recorder finalization completed',
  TripEvidenceState.reviewRequired => 'Finalization retained limitations',
  _ => 'Completion state was not recognized',
};

String _integrityLabel(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Verified',
  TripEvidenceState.limited => 'Limited',
  TripEvidenceState.reviewRequired => 'Review required',
  TripEvidenceState.unavailable => 'Unavailable',
  TripEvidenceState.notAssessed => 'Not assessed',
};

String _integrityDetail(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Persisted integrity assessment is verified.',
  TripEvidenceState.limited => 'Persisted integrity evidence has limitations.',
  TripEvidenceState.reviewRequired =>
    'Persisted evidence requires review; this is not an accusation of intent.',
  TripEvidenceState.unavailable => 'Integrity evidence is unavailable.',
  TripEvidenceState.notAssessed =>
    'The recorder preserved evidence but no M4 integrity audit was persisted.',
};

String _recoveryLabel(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Not needed',
  TripEvidenceState.limited => 'Recovered',
  TripEvidenceState.reviewRequired => 'Review required',
  TripEvidenceState.unavailable => 'Unavailable',
  TripEvidenceState.notAssessed => 'Not assessed',
};

String _recoveryDetail(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'The recorder finalized without recovery.',
  TripEvidenceState.limited =>
    'The recorder recovered preserved evidence before finalization.',
  _ => 'Recorder recovery state was not available.',
};

String _scoreEligibilityLabel(TripEvidenceState state) => switch (state) {
  TripEvidenceState.verified => 'Eligible',
  TripEvidenceState.limited => 'Provisional',
  TripEvidenceState.reviewRequired => 'Not rankable',
  TripEvidenceState.unavailable => 'Unavailable',
  TripEvidenceState.notAssessed => 'Eligibility not assessed',
};

String _eventLabel(String type) {
  final normalized = type
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  return normalized.isEmpty ? 'Recorded event' : normalized;
}

String _relativeRange(TripEventSummary event) {
  final start = Duration(microseconds: event.startElapsedNanos ~/ 1000);
  final end = Duration(microseconds: event.endElapsedNanos ~/ 1000);
  return '${_formatOffset(start)}–${_formatOffset(end)} from recorder timeline';
}

String _formatOffset(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Color _stateColor(BuildContext context, TripEvidenceState state) =>
    switch (state) {
      TripEvidenceState.verified => context.traelyxColors.positive,
      TripEvidenceState.limited => context.traelyxColors.caution,
      TripEvidenceState.reviewRequired => context.traelyxColors.critical,
      TripEvidenceState.unavailable => context.traelyxColors.textSecondary,
      TripEvidenceState.notAssessed => context.traelyxColors.information,
    };
