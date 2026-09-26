import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/trip_analysis/local_trip_analysis.dart';
import 'package:traelyx/features/trips/application/trip_history_providers.dart';

class LocalAnalysisPanel extends ConsumerStatefulWidget {
  const LocalAnalysisPanel({required this.tripId, super.key});
  final String tripId;
  @override
  ConsumerState<LocalAnalysisPanel> createState() => _LocalAnalysisPanelState();
}

class _LocalAnalysisPanelState extends ConsumerState<LocalAnalysisPanel> {
  String? _axis;
  String? _notice;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze on this phone',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Only analyze when parked. Choose the part of the phone that pointed '
            'toward the front of the vehicle throughout this trip. If you are unsure, '
            'or the phone moved in its mount, leave this trip unanalyzed. '
            'Stationary sensor evidence is also required. Analysis stays local and '
            'does not submit a ranking. Existing results are preserved.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(
              labelText: 'Recorded phone mount',
            ),
            initialValue: _axis,
            items: const [
              DropdownMenuItem(
                value: 'top',
                child: Text('Top edge faced forward'),
              ),
              DropdownMenuItem(
                value: 'bottom',
                child: Text('Bottom edge faced forward'),
              ),
              DropdownMenuItem(
                value: 'left',
                child: Text('Left edge faced forward'),
              ),
              DropdownMenuItem(
                value: 'right',
                child: Text('Right edge faced forward'),
              ),
              DropdownMenuItem(
                value: 'screen',
                child: Text('Screen faced forward'),
              ),
              DropdownMenuItem(
                value: 'back',
                child: Text('Back faced forward'),
              ),
            ],
            onChanged: _busy ? null : (value) => setState(() => _axis = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _axis == null ? null : _analyze,
            child: Text(_busy ? 'Analyzing locally…' : 'Save local analysis'),
          ),
          if (_notice != null)
            Semantics(liveRegion: true, child: Text(_notice!)),
        ],
      ),
    ),
  );

  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await ref
          .read(localAnalysisServiceProvider)
          .analyze(widget.tripId, _axis!);
      if (!mounted) return;
      ref.invalidate(tripResultProvider(widget.tripId));
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'Analysis could not be saved. The trip may already have a result, or its '
              'raw evidence may be missing, changed, invalid, or too large (32 MiB / 2 hours). '
              'Your trip has not been deleted.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
