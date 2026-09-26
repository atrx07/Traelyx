import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/rankings/ranking_models.dart';
import 'package:traelyx/features/rankings/ranking_service.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountIdentityProvider).valueOrNull?.userId;
    return SafeArea(
      child: owner == null
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Safe comparisons',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Sign in to compare separately shared results with friends. Local trip analysis needs no account.',
                ),
                TextButton(
                  onPressed: () => context.go('/you/account'),
                  child: const Text('Open Account'),
                ),
                TextButton(
                  onPressed: () => context.go('/social'),
                  child: const Text('Back to Social'),
                ),
              ],
            )
          : _RankingContent(key: ValueKey(owner), owner: owner),
    );
  }
}

class _RankingContent extends ConsumerStatefulWidget {
  const _RankingContent({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_RankingContent> createState() => _RankingContentState();
}

class _RankingContentState extends ConsumerState<_RankingContent> {
  RankingSnapshot? _snapshot;
  List<RankingCandidate> _candidates = [];
  String? _notice;
  bool _busy = false;
  int _metric = 0;
  double? _value(RankingRow r) => switch (_metric) {
    0 => r.smoothness,
    1 => r.consistency,
    _ => r.improvement,
  };
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _snapshot = null;
          _candidates = [];
          _notice =
              'Could not confirm the result. A submission or withdrawal may have completed. '
              'Reload before reviewing a retry. Check your connection, account and profile; '
              'limits are 30 submissions per 24 hours and 1,000 retained submissions.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final service = ref.read(rankingServiceProvider);
    final snapshot = await service.load(widget.owner);
    final candidates = await service.candidates(widget.owner);
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
        _candidates = candidates
            .where((c) => !snapshot.submittedIds.contains(c.tripId))
            .toList();
      });
    }
  }

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep unchanged'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _submit(RankingCandidate candidate) async {
    final reviewed = _snapshot!;
    final vehicleClass = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vehicle used for this trip'),
        content: const Text(
          'Confirm the broad class used during this recorded trip. Only classes from '
          'your saved vehicles are available. A comparison history uses one class; withdraw it before changing class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          for (final value in reviewed.vehicleClasses)
            TextButton(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value),
            ),
        ],
      ),
    );
    if (vehicleClass == null || !mounted) return;
    final accepted = await _confirm(
      'Share this comparison?',
      'Share ${reviewed.displayName} (@${reviewed.username}), the $vehicleClass class and aggregate comparison results '
          'with your current and future accepted friends. Your profile stays private unless you publish it separately.\n\n'
          'Privately store this trip’s opaque ID and digest, algorithm versions, total/moving durations, '
          'dimension coverage, calibration/integrity checks, and event categories with bounded severity/confidence weights. '
          'No coordinates, raw samples, exact dates, vehicle labels, speed or G values are sent.\n\n'
          'This links the trip to this account and is separate from summary-sync consent. '
          'The server checks supplied evidence and recomputes scores; it cannot prove driver identity or sensor authenticity. '
          'Local deletion and sign-out do not withdraw shared results. Use Withdraw all comparisons to remove them.',
      'Share selected trip',
    );
    if (!accepted || !mounted) return;
    await _run(() async {
      await ref
          .read(rankingServiceProvider)
          .submit(
            widget.owner,
            reviewed,
            candidate,
            vehicleClass: vehicleClass,
          );
      await _load();
      if (mounted) setState(() => _notice = 'Submission accepted.');
    });
  }

  Future<void> _withdraw() async {
    if (!await _confirm(
          'Withdraw all comparisons?',
          'Remove this account’s ranking evidence and shared comparison results from the server. '
              'Local trips, scores, friendships and summary sync remain. This affects submissions made on other devices too.',
          'Withdraw all',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await ref.read(rankingServiceProvider).withdraw(widget.owner);
      await _load();
      if (mounted) setState(() => _notice = 'All ranking evidence withdrawn.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = [...?_snapshot?.rows]
      ..sort((a, b) {
        final comparison = (_value(b) ?? -101).compareTo(_value(a) ?? -101);
        return comparison != 0 ? comparison : a.username.compareTo(b.username);
      });
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          key: const ValueKey('safe-rankings'),
          padding: const EdgeInsets.all(24),
          children: [
            TextButton(
              onPressed: () => context.go('/social'),
              child: const Text('Back to Social'),
            ),
            Text(
              'Safe comparisons',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Experimental • accepted friends only',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comparisons use separately shared trips with full supported evidence. '
              'They are not proof of safe driving, driver identity or authentic sensors. '
              'Scoring v1 has synthetic fixture validation, not population calibration. '
              'Never drive extra or change your driving to obtain a rank.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Ten accepted submissions are required. Smoothness averages the latest five; '
              'consistency is 100 minus their mean absolute deviation; improvement compares those five '
              'with the preceding five. Order is server acceptance order, not trip dates. '
              'Self-selected trips and different driving conditions limit comparisons. '
              'Names are snapshots from sharing time; reload to refresh friendship visibility.',
            ),
            FilledButton(
              onPressed: _busy ? null : () => _run(_load),
              child: Text(_busy ? 'Working…' : 'Reload comparisons'),
            ),
            if (_notice != null)
              Semantics(liveRegion: true, child: Text(_notice!)),
            if (_snapshot == null)
              const Text(
                'Nothing is fetched or shared until you choose an action.',
              ),
            if (_snapshot != null) ...[
              DropdownButtonFormField<int>(
                initialValue: _metric,
                decoration: const InputDecoration(labelText: 'Compare'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Smoothness')),
                  DropdownMenuItem(value: 1, child: Text('Consistency')),
                  DropdownMenuItem(value: 2, child: Text('Improvement')),
                ],
                onChanged: (v) => setState(() => _metric = v ?? 0),
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No shared comparison results. Friendships alone do not share scores.',
                  ),
                ),
              for (final vehicleClass in rankingVehicleClasses) ...[
                if (rows.any((r) => r.vehicleClass == vehicleClass))
                  Text(
                    '$vehicleClass comparisons',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                for (final row in rows.where(
                  (r) => r.vehicleClass == vehicleClass,
                ))
                  ListTile(
                    title: Text(
                      '${row.displayName}${row.isSelf ? ' · You' : ''}',
                    ),
                    subtitle: Text(
                      _value(row) == null
                          ? 'Insufficient shared evidence (${row.sampleCount}/10)'
                          : '@${row.username}',
                    ),
                    trailing: Text(
                      _value(row) == null
                          ? '—'
                          : '${_value(row)!.toStringAsFixed(2)}${_metric == 2 ? ' pts' : ''}',
                    ),
                  ),
              ],
              const Divider(),
              Text(
                'Review local trips',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Analyze a completed trip from Trips first. Admission requires verified integrity, '
                'full evidence for all four scored dimensions, at least 60 seconds moving, '
                'a supported stationary orientation check and no recovery/data-quality flags. '
                'Missing or uncertain evidence stays ineligible.',
              ),
              if (_snapshot!.username == null)
                TextButton(
                  onPressed: () => context.go('/you/account/profile'),
                  child: const Text('Save a profile before sharing'),
                ),
              if (_snapshot!.vehicleClasses.isEmpty)
                TextButton(
                  onPressed: () => context.go('/you/account/profile'),
                  child: const Text('Save a vehicle class before sharing'),
                ),
              if (_candidates.isEmpty)
                const Text(
                  'No unsubmitted eligible local trips. Nothing will upload automatically.',
                ),
              for (final c in _candidates)
                ListTile(
                  title: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(c.localDate),
                  ),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(c.localDate)),
                  ),
                  trailing: TextButton(
                    onPressed:
                        _busy ||
                            _snapshot!.username == null ||
                            _snapshot!.vehicleClasses.isEmpty
                        ? null
                        : () => _submit(c),
                    child: const Text('Review'),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy ? null : _withdraw,
                child: const Text('Withdraw all comparisons'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
