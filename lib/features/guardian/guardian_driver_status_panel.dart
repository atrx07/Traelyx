import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/guardian/guardian_driver_status.dart';

class GuardianDriverStatusPanel extends ConsumerStatefulWidget {
  const GuardianDriverStatusPanel({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<GuardianDriverStatusPanel> createState() =>
      _GuardianDriverStatusPanelState();
}

class _GuardianDriverStatusPanelState
    extends ConsumerState<GuardianDriverStatusPanel>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(guardianDriverStatusProvider(widget.owner).notifier).clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(guardianDriverStatusProvider(widget.owner));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver state at last check',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'This checks only this phone. It does not enable monitoring or send an alert. '
          'Driver activation and sending are unavailable in this test build.',
        ),
        if (check.status != null) ...[
          Semantics(liveRegion: true, child: Text(check.status!.state.label)),
          Text('Checked ${check.checkedAt!.toLocal()}'),
          if (check.status!.expiresAt != null)
            Text('Local consent expires ${check.status!.expiresAt!.toLocal()}'),
        ] else if (!check.busy && check.notice == null)
          const Text('Driver state has not been checked.'),
        const Text(
          'A saved lease or pairing does not mean monitoring is running. '
          'After Android ends the app process or the phone restarts, a new driver review is required. '
          'Experimental evaluation never confirms delivery or emergency assistance.',
        ),
        if (check.notice != null)
          Semantics(liveRegion: true, child: Text(check.notice!)),
        if (check.busy) const LinearProgressIndicator(),
        OutlinedButton(
          onPressed: check.busy
              ? null
              : ref
                    .read(guardianDriverStatusProvider(widget.owner).notifier)
                    .check,
          child: const Text('Check driver state'),
        ),
      ],
    );
  }
}
