import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/features/cloud_commentary/application/cloud_commentary_service.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/trips/domain/procedural_commentary.dart';

class CloudReplayControl extends ConsumerStatefulWidget {
  const CloudReplayControl({
    required this.plan,
    required this.onApply,
    required this.onBuiltin,
    required this.pause,
    super.key,
  });
  final ProceduralCommentaryPlan plan;
  final ValueChanged<ProceduralCommentaryPlan> onApply;
  final VoidCallback onBuiltin;
  final VoidCallback pause;
  @override
  ConsumerState<CloudReplayControl> createState() => _CloudReplayControlState();
}

class _CloudReplayControlState extends ConsumerState<CloudReplayControl>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _parked = false;
  String? _notice;
  CloudCommentaryService? _usedService;
  ProceduralCommentaryPlan? _applied;
  CloudCommentaryService get _service {
    _usedService ??= ref.read(cloudCommentaryServiceProvider);
    return _usedService!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CloudReplayControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan) {
      _usedService?.cancel();
      _parked = false;
      if (!identical(widget.plan, _applied)) _notice = null;
      _applied = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usedService?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _usedService?.cancel();
      if (mounted) setState(() => _parked = false);
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    widget.pause();
    final plan = widget.plan;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final review = await _service.prepare(plan, parked: _parked);
      if (!mounted || !identical(widget.plan, plan)) return;
      var accepted = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Review Groq request'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Provider: Groq\nModel: ${review.model}'),
                    const Text(
                      'This sends the exact categorical dossier below and a fixed instruction to choose reviewed wording. Groq also receives your saved key for authentication and network metadata. Account costs/retention apply. No route, raw sensors, measurements, IDs or times. Data already transmitted cannot be recalled.',
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      review.dossier.reviewedJson,
                      key: const ValueKey('cloud-dossier-review'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      key: const ValueKey('cloud-send-consent'),
                      title: const Text(
                        'Send this reviewed dossier to Groq once',
                      ),
                      value: accepted,
                      onChanged: (v) => update(() => accepted = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep built-in'),
              ),
              FilledButton(
                key: const ValueKey('cloud-confirm-send'),
                onPressed: accepted ? () => Navigator.pop(context, true) : null,
                child: const Text('Send once'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        widget.onBuiltin();
        return;
      }
      if (!_parked || !identical(widget.plan, plan)) {
        throw const CloudException(CloudFailure.stale);
      }
      final result = await _service.generate(review, parked: _parked);
      if (!mounted || !_parked || !identical(widget.plan, plan)) return;
      _applied = result;
      widget.onApply(result);
      if (mounted) {
        setState(
          () => _notice =
              'Groq selected reviewed wording for this replay session. Event timing and evidence are unchanged.',
        );
      }
    } catch (error) {
      if (mounted) {
        widget.onBuiltin();
        setState(
          () => _notice =
              '${cloudFailureMessage(error)} Built-in narration is available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(
        'Optional cloud wording',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const Text(
        'Built-in narration is the default. Cloud can select reviewed lines for existing moments; it never supplies new event facts.',
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        key: const ValueKey('cloud-replay-parked'),
        title: const Text('I am parked and have finished driving'),
        value: _parked,
        onChanged: _busy
            ? null
            : (v) {
                widget.pause();
                setState(() => _parked = v ?? false);
              },
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            key: const ValueKey('cloud-review-request'),
            onPressed: _busy || !_parked || widget.plan.moments.isEmpty
                ? null
                : _generate,
            child: const Text('Review cloud request'),
          ),
          TextButton(
            onPressed: () {
              _service.cancel();
              widget.onBuiltin();
              setState(
                () => _notice =
                    'Using built-in narration. Already sent data cannot be recalled.',
              );
            },
            child: const Text('Use built-in / cancel'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    widget.pause();
                    context.push(TraelyxRoutes.youCommentary);
                  },
            child: const Text('Cloud settings'),
          ),
        ],
      ),
      if (_busy) const Text('Waiting for reviewed wording…'),
      if (_notice != null)
        Semantics(
          liveRegion: true,
          child: Text(_notice!, key: const ValueKey('cloud-replay-notice')),
        ),
    ],
  );
}
