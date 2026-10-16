import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent_review.dart';
import 'package:traelyx/features/guardian/guardian_driver_controls.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

class GuardianDriverControlsPanel extends ConsumerStatefulWidget {
  const GuardianDriverControlsPanel({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<GuardianDriverControlsPanel> createState() =>
      _GuardianDriverControlsPanelState();
}

class _GuardianDriverControlsPanelState
    extends ConsumerState<GuardianDriverControlsPanel>
    with WidgetsBindingObserver {
  Object? _reviewAttempt;
  bool get _reviewOpen => _reviewAttempt != null;
  int _reviewEpoch = 0;
  GuardianDriverControlsController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _reviewEpoch++;
      _controller?.interrupt();
    }
  }

  @override
  void dispose() {
    _reviewEpoch++;
    _controller?.abandon();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _review() async {
    if (_reviewOpen) return;
    final attempt = Object();
    setState(() => _reviewAttempt = attempt);
    final epoch = _reviewEpoch;
    final controller = _controller!;
    try {
      if (!await controller.canReview() || !mounted || epoch != _reviewEpoch) {
        return;
      }
      final review = await showGuardianDriverConsentReview(
        context,
        widget.owner,
      );
      if (review == null || !mounted || epoch != _reviewEpoch) return;
      ref.read(guardianDriverStatusProvider(widget.owner).notifier).clear();
      await controller.activate(review);
    } finally {
      if (mounted && identical(attempt, _reviewAttempt)) {
        setState(() => _reviewAttempt = null);
      }
    }
  }

  Future<void> _stop() async {
    _reviewEpoch++;
    ref.read(guardianDriverStatusProvider(widget.owner).notifier).clear();
    await _controller!.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(guardianDriverPilotProvider)) return const SizedBox.shrink();
    final provider = guardianDriverControlsControllerProvider(widget.owner);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    _controller = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Driver alerts', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Review only while parked. Consent allows experimental local evaluation during a recorded trip. '
          'Alert sending is unavailable in this build.',
        ),
        if (!controller.available)
          const Text('Driver controls require a configured signed-in account.'),
        if (state.expiresAt != null)
          Text('Local consent expires ${state.expiresAt!.toLocal()}'),
        if (state.notice != null)
          Semantics(liveRegion: true, child: Text(state.notice!)),
        if (state.activating || state.stopping) const LinearProgressIndicator(),
        FilledButton(
          onPressed:
              !controller.available ||
                  _reviewOpen ||
                  state.activating ||
                  state.stopping
              ? null
              : _review,
          child: const Text('Review driver alerts'),
        ),
        OutlinedButton(
          onPressed: !controller.available || state.stopping ? null : _stop,
          child: const Text('Stop driver alerts'),
        ),
        const Text(
          'Stop removes Guardian authority on this phone before checking server revocation. '
          'Trip recording continues. Already handed-off notices cannot be retracted.',
        ),
      ],
    );
  }
}
