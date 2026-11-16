import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_providers.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_service.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

class LocalCommentaryCard extends ConsumerStatefulWidget {
  const LocalCommentaryCard({super.key});
  @override
  ConsumerState<LocalCommentaryCard> createState() =>
      _LocalCommentaryCardState();
}

class _LocalCommentaryCardState extends ConsumerState<LocalCommentaryCard>
    with WidgetsBindingObserver {
  LocalModelStatus? _status;
  bool _busy = false;
  bool _parked = false;
  String? _notice;
  late final LocalCommentaryService _service;
  @override
  void initState() {
    super.initState();
    _service = ref.read(localCommentaryServiceProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _service.cancel();
      if (mounted) setState(() => _parked = false);
    }
  }

  Future<void> _refresh() => _run(() async {
    final status = await _service.status();
    if (mounted) setState(() => _status = status);
  });
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = null;
          _notice = localFailureMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove local model files?'),
        content: const Text(
          'Remove installed and incomplete local narrator artifacts from this app. The built-in narrator stays available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep files'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove model files'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(() async {
      await _service.removeModels(parked: _parked, confirmed: true);
      final status = await _service.status();
      if (mounted) {
        setState(() {
          _status = status;
          _notice = 'Local model files removed.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Local AI', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Unavailable in this build. No local model or inference runtime has passed acceptance. The built-in narrator remains active.',
        ),
        const SizedBox(height: 8),
        const Text(
          'No model is bundled or downloaded automatically. Future models need a separate size and license review, device checks and verified installation. Local inference will need no account or API key.',
        ),
        if (status != null) ...[
          const SizedBox(height: 8),
          Text(
            'Model files: ${status.inventory.bytes} bytes (${status.inventory.artifacts} installed, ${status.inventory.partials} incomplete).',
            key: const ValueKey('local-model-bytes'),
          ),
          Text(
            'Accepted catalog: ${status.catalogCount} models. Runtime: ${status.runtimeAvailable ? 'present; activation gated' : 'not installed'}.',
            key: const ValueKey('local-model-capabilities'),
          ),
          if (status.inventory.artifacts + status.inventory.partials > 0) ...[
            const Text(
              'File presence does not mean a model is usable. Verification is required before every use.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I am parked'),
              value: _parked,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _parked = v == true),
            ),
            OutlinedButton(
              onPressed: _busy || !_parked ? null : _remove,
              child: const Text('Review removal of model files'),
            ),
          ],
        ],
        if (status == null && _notice == null)
          const Text('Refresh to measure local model files on this device.'),
        if (_notice != null)
          Semantics(
            liveRegion: true,
            child: Text(_notice!, key: const ValueKey('local-model-notice')),
          ),
        TextButton(
          onPressed: _busy ? null : _refresh,
          child: Text(
            _busy
                ? 'Checking local model files…'
                : 'Refresh local model status',
          ),
        ),
      ],
    );
  }
}
