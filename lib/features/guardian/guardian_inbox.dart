import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/guardian/guardian_alerts.dart';

class GuardianInboxPanel extends ConsumerStatefulWidget {
  const GuardianInboxPanel({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<GuardianInboxPanel> createState() => _GuardianInboxPanelState();
}

class _GuardianInboxPanelState extends ConsumerState<GuardianInboxPanel>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(guardianInboxProvider(widget.owner).notifier).clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guardianInboxProvider(widget.owner));
    final controller = ref.read(guardianInboxProvider(widget.owner).notifier);
    final opened = state.opened;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Guardian alerts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Reload checks current permission. Alerts expire after 10 minutes. '
          'Push acceptance does not mean a person saw an alert. Opening an incoming alert records that action for the driver.',
        ),
        TextButton(
          onPressed: state.busy ? null : controller.reload,
          child: const Text('Reload alerts'),
        ),
        if (state.busy) const LinearProgressIndicator(),
        if (state.notice != null)
          Semantics(liveRegion: true, child: Text(state.notice!)),
        if (state.loaded && state.alerts.isEmpty)
          const Text(
            'No currently accessible alerts. This does not confirm anyone is safe.',
          ),
        for (final row in state.alerts)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title),
                  Text(
                    row.ownEvent
                        ? 'To ${row.guardianName}'
                        : 'From ${row.driverName}',
                  ),
                  Text('${row.occurredAt.toLocal()}'),
                  Text(row.deliveryState.label),
                  if (!row.ownEvent)
                    TextButton(
                      onPressed: state.busy ? null : () => controller.open(row),
                      child: const Text('Open alert'),
                    ),
                ],
              ),
            ),
          ),
        if (opened != null)
          Semantics(
            liveRegion: true,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opened.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Experimental sensor rules can be wrong and miss events. This is not confirmation of a collision or injury. '
                      'Check in with the driver using your usual contact method. No emergency call has been placed.',
                    ),
                    TextButton(
                      onPressed: controller.clear,
                      child: const Text('Close alert details'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
