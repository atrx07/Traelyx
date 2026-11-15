import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/event_corrections/application/event_correction_service.dart';
import 'package:traelyx/features/event_corrections/domain/event_correction.dart';

class EventCorrectionPanel extends ConsumerWidget {
  const EventCorrectionPanel({required this.tripId, super.key});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: OutlinedButton.icon(
      key: const ValueKey('review-detections'),
      icon: const Icon(Icons.rate_review_outlined),
      label: const Text('Review detections after driving'),
      onPressed: () async {
        try {
          if (!await ref
              .read(eventCorrectionServiceProvider)
              .isRecorderIdle()) {
            throw StateError('Recorder is not idle.');
          }
          if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
            return;
          }
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _CorrectionSheet(tripId: tripId),
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Finish driving before reviewing detections. Recorder status must be available.',
                ),
              ),
            );
          }
        }
      },
    ),
  );
}

class _CorrectionSheet extends ConsumerStatefulWidget {
  const _CorrectionSheet({required this.tripId});
  final String tripId;
  @override
  ConsumerState<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends ConsumerState<_CorrectionSheet>
    with WidgetsBindingObserver {
  bool _parked = false;
  bool _busy = false;
  bool _contribute = false;
  CorrectionCatalog? _catalog;
  CorrectionTarget? _selected;
  CorrectionChoice _choice = CorrectionChoice.unsure;
  String? _notice;
  EventCorrectionService get _service =>
      ref.read(eventCorrectionServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() {
        _parked = false;
        _contribute = false;
        _selected = null;
      });
    }
  }

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
        setState(
          () => _notice =
              'Could not complete this action. Finish driving and retry with current evidence and permission.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    final catalog = await _service.load(widget.tripId, parked: _parked);
    if (mounted) {
      setState(() {
        _catalog = catalog;
        _selected = null;
        _contribute = false;
      });
    }
  }

  void _select(CorrectionTarget? target) => setState(() {
    _selected = target;
    _choice = target == null
        ? CorrectionChoice.unsure
        : (_catalog!.noteFor(target)?.choice ?? CorrectionChoice.unsure);
    _contribute = false;
    _notice = null;
  });

  Future<void> _save({bool revoke = false}) => _run(() async {
    final target = _selected!;
    final note = _catalog!.noteFor(target);
    await _service.save(
      target,
      revoke ? note!.choice : _choice,
      parked: _parked,
      expectedRevision: note?.revision ?? 0,
      contribute: !revoke && _contribute,
    );
    await _reload();
    if (mounted) {
      setState(
        () => _notice = revoke
            ? 'Contribution permission turned off. Saved files cannot be recalled.'
            : 'Note saved on this phone. Original detection and scores are unchanged.',
      );
    }
  });

  Future<void> _export() => _run(() async {
    final preview = await _service.preview(widget.tripId, parked: _parked);
    if (!mounted) return;
    var accepted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Review contribution'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${preview.count} unverified user ${preview.count == 1 ? 'report' : 'reports'} for detection research.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Includes detection category, your answer, and detector/telemetry versions. No routes, raw sensors, measurements, IDs or times. Nothing is uploaded or trained automatically.',
                  ),
                  const SizedBox(height: 12),
                  for (final item in preview.payload['labels']! as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${correctionEventLabels[(item as Map)['detectedEvent']]} → ${CorrectionChoice.parse(item['reportedLabel'] as String).label}',
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    key: const ValueKey('confirm-contribution-copy'),
                    value: accepted,
                    onChanged: (value) =>
                        update(() => accepted = value ?? false),
                    title: const Text(
                      'I approve saving these reports for research. Saved copies are outside this app and cannot be withdrawn here.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('save-contribution-file'),
              onPressed: accepted ? () => Navigator.pop(context, true) : null,
              child: const Text('Save contribution file'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final result = await _service.export(
      widget.tripId,
      preview,
      parked: _parked,
    );
    if (mounted) {
      setState(
        () => _notice = result.exported
            ? 'Contribution file saved. Nothing was uploaded by Traelyx.'
            : result.errorCode == 'export_cancelled'
            ? 'Contribution export cancelled.'
            : 'No successful contribution export was confirmed.',
      );
    }
  });

  Future<void> _clear() => _run(() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove all local notes?'),
        content: const Text(
          'Removes these corrections and future export permissions, including notes for older analysis. Original trip evidence and saved export files are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep notes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove notes'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.clear(widget.tripId, parked: _parked);
    await _reload();
  });

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final note = _selected == null ? null : catalog?.noteFor(_selected!);
    final enabled = _parked && !_busy;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review detections',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close review',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Your notes stay on this phone unless you choose a contribution export. They do not change detections, scores, integrity or safety alerts.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              key: const ValueKey('correction-parked'),
              value: _parked,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _parked = value ?? false;
                        _selected = null;
                        _contribute = false;
                      });
                      if (_parked) _run(_reload);
                    },
              title: const Text('I am parked and have finished driving'),
            ),
            if (_busy)
              if (MediaQuery.disableAnimationsOf(context))
                const Text('Correction action in progress…')
              else
                const LinearProgressIndicator(),
            if (_parked && !_busy)
              TextButton(
                onPressed: () => _run(_reload),
                child: const Text('Reload detections'),
              ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _notice!,
                    key: const ValueKey('correction-notice'),
                  ),
                ),
              ),
            if (_parked && catalog != null) ...[
              if (catalog.targets.isEmpty)
                const Text(
                  'No supported detections are available to review for this finalized trip.',
                ),
              if (catalog.targets.isNotEmpty) ...[
                const Text(
                  'Choose a detected moment (up to 128 listed). Your answer is saved as an unverified personal report.',
                ),
                const SizedBox(height: 8),
                DropdownButton<CorrectionTarget>(
                  key: const ValueKey('correction-event'),
                  isExpanded: true,
                  value: _selected,
                  hint: const Text('Choose a moment'),
                  items: [
                    for (var index = 0; index < catalog.targets.length; index++)
                      DropdownMenuItem(
                        value: catalog.targets[index],
                        child: Text(
                          '${index + 1}. ${catalog.targets[index].label} · ${_time(catalog.targets[index].startNanos)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: enabled ? _select : null,
                ),
              ],
              if (_selected != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_selected!.qualityDescription),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${_selected!.label} · ${_time(_selected!.startNanos)}–${_time(_selected!.endNanos)}',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in CorrectionChoice.values)
                      ChoiceChip(
                        label: Text(choice.label),
                        selected: _choice == choice,
                        onSelected: enabled
                            ? (_) => setState(() => _choice = choice)
                            : null,
                      ),
                  ],
                ),
                if (note != null)
                  Text(
                    'Saved note: ${note.choice.label}. Export permission: ${note.contributionAllowed ? 'allowed' : 'off'}.',
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  key: const ValueKey('correction-consent'),
                  value: _contribute,
                  onChanged: enabled
                      ? (value) => setState(() => _contribute = value ?? false)
                      : null,
                  title: const Text(
                    'Allow this note in a contribution export to improve detection',
                  ),
                  subtitle: const Text(
                    'Optional. Saving any edit requires choosing this again. Export needs a separate review; no raw telemetry or routes are included.',
                  ),
                ),
                FilledButton(
                  key: const ValueKey('save-correction'),
                  onPressed: enabled ? _save : null,
                  child: const Text('Save local note'),
                ),
                if (note != null) ...[
                  if (note.contributionAllowed)
                    TextButton(
                      key: const ValueKey('revoke-correction-consent'),
                      onPressed: enabled ? () => _save(revoke: true) : null,
                      child: const Text('Turn off contribution permission'),
                    ),
                  TextButton(
                    key: const ValueKey('remove-correction'),
                    onPressed: enabled
                        ? () => _run(() async {
                            await _service.remove(note, parked: _parked);
                            await _reload();
                          })
                        : null,
                    child: const Text('Remove this local note'),
                  ),
                ],
              ],
              const Divider(height: 32),
              Text(
                '${catalog.notes.length}/128 local notes · ${catalog.staleCount} apply to older evidence and will not be exported.',
              ),
              const Text(
                'Permission only affects future exports. Files already saved are outside this app.',
              ),
              OutlinedButton.icon(
                key: const ValueKey('export-corrections'),
                onPressed:
                    enabled &&
                        catalog.notes.any((note) => note.contributionAllowed)
                    ? _export
                    : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('Review contribution export'),
              ),
              TextButton(
                key: const ValueKey('clear-corrections'),
                onPressed: enabled && catalog.notes.isNotEmpty ? _clear : null,
                child: const Text('Remove all local notes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _time(int nanos) {
  final seconds = nanos ~/ 1000000000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
