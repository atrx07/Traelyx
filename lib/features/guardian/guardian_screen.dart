import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/guardian/guardian_controller.dart';
import 'package:traelyx/features/guardian/guardian_models.dart';

class GuardianScreen extends ConsumerWidget {
  const GuardianScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountIdentityProvider).valueOrNull?.userId;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: owner == null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Guardian pairing',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Text(
                      'Sign in to pair with a trusted person. Recording and local analysis need no account.',
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
              : _GuardianContent(key: ValueKey(owner), owner: owner),
        ),
      ),
    );
  }
}

class _GuardianContent extends ConsumerStatefulWidget {
  const _GuardianContent({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_GuardianContent> createState() => _GuardianContentState();
}

class _GuardianContentState extends ConsumerState<_GuardianContent>
    with WidgetsBindingObserver {
  final _code = TextEditingController();
  GuardianPermissions _permissions = const GuardianPermissions();
  GuardianController get controller =>
      ref.read(guardianControllerProvider(widget.owner).notifier);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _code.clear();
      controller.clearSecrets();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _code.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String content, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
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
  Future<void> _create(GuardianSnapshot snapshot) async {
    final permissions = _permissions;
    if (await _confirm(
          'Create a private invite?',
          'Anyone with this code and a signed-in profile can review ${snapshot.displayName} (@${snapshot.username}) '
              'and these requested permissions:\n\n${permissions.summary}\n\n'
              'The code expires in 10 minutes and can be accepted once. Creating it cancels your previous code. '
              'After acceptance, you must reload and confirm the person within 24 hours. '
              'No trip data is shared. Keep the code private; do not post it publicly.',
          'Create invite',
        ) &&
        mounted) {
      await controller.create(permissions);
    }
  }

  Future<void> _accept(GuardianPreview preview) async {
    if (await _confirm(
          'Accept this driver?',
          'Driver: ${preview.displayName} (@${preview.username}).\n'
              'Share your saved name ${preview.ownDisplayName} (@${preview.ownUsername}) with this driver, '
              'even if your profile is private.\n\n${preview.invite.permissions.summary}\n\n'
              'The driver must still confirm you. Either person can disconnect. '
              'Pairing does not grant friendship or access to routes, speed or trip history.',
          'Accept invite',
        ) &&
        mounted) {
      await controller.accept(preview);
    }
  }

  Future<void> _change(GuardianConnection row, GuardianAction action) async {
    GuardianPermissions? selected;
    if (action == GuardianAction.permissions) {
      var edited = row.permissions;
      selected = await showDialog<GuardianPermissions>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Permission preferences'),
            content: SingleChildScrollView(
              child: GuardianPermissionFields(
                value: edited,
                onChanged: (p) => setDialogState(() => edited = p),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep unchanged'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, edited),
                child: const Text('Review changes'),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
    }
    final detail = switch (action) {
      GuardianAction.confirm =>
        'Confirm this is the trusted person you invited. ${row.permissions.summary}',
      GuardianAction.permissions =>
        'Save these preferences for this connection: ${selected!.summary}',
      GuardianAction.disconnect =>
        'End this connection and revoke its permissions on the server. Your local trips and other connections remain.',
      GuardianAction.block =>
        'End this connection and prevent this account from pairing with you in either direction. Only you can remove your block. This Guardian block does not change Social friendships.',
      GuardianAction.unblock =>
        'Allow a new invitation. This does not restore the connection or its permissions.',
    };
    if (await _confirm(
          '${_actionLabel(action)}?',
          '${row.displayName} (@${row.username})\n\n$detail\n\n'
              'A connection or permission change is confirmed only after a successful server response.',
          _actionLabel(action),
        ) &&
        mounted) {
      await controller.change(row, action, permissions: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guardianControllerProvider(widget.owner));
    final snapshot = state.snapshot;
    final invite = state.issued ?? snapshot?.invite;
    final preview = state.preview;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Guardian pairing',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Pair with a trusted person and review permission preferences. '
          'Alerts, live safety state and emergency delivery are not available in this version. '
          'Pairing must not be relied on for emergency assistance.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Opening this screen sends nothing. Use Reload to see the latest server state. '
          'One driver/guardian direction is supported per pair. To reverse roles, disconnect and pair again.',
        ),
        FilledButton(
          onPressed: state.busy ? null : controller.reload,
          child: const Text('Reload Guardian'),
        ),
        if (state.notice != null)
          Semantics(liveRegion: true, child: Text(state.notice!)),
        if (state.busy) const LinearProgressIndicator(),
        if (state.loaded && snapshot?.username == null)
          TextButton(
            onPressed: () => context.go(TraelyxRoutes.youMetadata),
            child: const Text('Save a profile to pair'),
          ),
        if (state.loaded && snapshot?.username != null) ...[
          const SizedBox(height: 20),
          Text(
            'Invite someone to be your Guardian',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          GuardianPermissionFields(
            value: _permissions,
            onChanged: state.busy
                ? null
                : (p) => setState(() => _permissions = p),
          ),
          FilledButton(
            onPressed: state.busy ? null : () => _create(snapshot!),
            child: const Text('Review new invite'),
          ),
          const Text(
            'Limits: 10 new codes and 10 accepted invites per 24 hours, 60 code reviews per 24 hours, '
            'and 100 retained relationships. Connection changes require a reload after an uncertain response.',
          ),
        ],
        if (invite != null && state.loaded) ...[
          const SizedBox(height: 16),
          Text('Invite expires ${invite.expiresAt.toLocal()}'),
          if (invite.token != null) ...[
            const Text(
              'Code shown only now. Backgrounding, leaving, reloading or expiry clears it from this screen. '
              'Copying places it on the system clipboard; share it privately and clear the clipboard afterward.',
            ),
            SelectableText(invite.token!),
            TextButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      if (invite.expiresAt.isAfter(DateTime.now())) {
                        await Clipboard.setData(
                          ClipboardData(text: invite.token!),
                        );
                      }
                    },
              child: const Text('Copy invite code'),
            ),
          ] else
            const Text(
              'The code cannot be retrieved. Cancel or create a new invite if you lost it.',
            ),
          TextButton(
            onPressed: state.busy
                ? null
                : () async {
                    if (await _confirm(
                          'Cancel invite?',
                          'Prevent any further acceptance of this invite. '
                              'If someone already accepted it, disconnect that pending relationship separately.',
                          'Cancel invite',
                        ) &&
                        mounted) {
                      await controller.cancel(invite);
                    }
                  },
            child: const Text('Cancel invite'),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Become someone’s Guardian',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Enter a code that the driver shared privately. Reviewing it fetches their name and requested permissions. '
          'Your name is shared only if you confirm acceptance.',
        ),
        TextField(
          controller: _code,
          enabled: !state.busy,
          maxLength: 64,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Private invite code'),
        ),
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  final code = _code.text;
                  _code.clear();
                  controller.preview(code);
                },
          child: const Text('Review invite code'),
        ),
        if (preview != null) ...[
          Text('${preview.displayName} (@${preview.username})'),
          Text(preview.invite.permissions.summary),
          TextButton(
            onPressed: state.busy ? null : () => _accept(preview),
            child: const Text('Review acceptance'),
          ),
          TextButton(
            onPressed: state.busy ? null : controller.clearSecrets,
            child: const Text('Ignore invite'),
          ),
        ],
        const SizedBox(height: 20),
        Text('Your connections', style: Theme.of(context).textTheme.titleLarge),
        if (state.loaded && snapshot!.connections.isEmpty)
          const Text('No Guardian connections.'),
        if (state.loaded)
          for (final row in snapshot!.connections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.displayName} (@${row.username})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Your role: ${row.role}. ${_statusLabel(row.status)}'),
                    Text('Saved preferences: ${row.permissions.summary}'),
                    if (row.status != 'active')
                      const Text('These preferences grant no active access.'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final action in row.actions)
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () => _change(row, action),
                            child: Text(_actionLabel(action)),
                          ),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text('Recent permission history'),
                      children: [
                        for (final item in row.history)
                          ListTile(
                            title: Text('${item.action} · ${item.actor}'),
                            subtitle: Text(
                              '${item.at.toLocal()}\n${item.permissions.summary}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        TextButton(
          onPressed: () => context.go('/social'),
          child: const Text('Back to Social'),
        ),
      ],
    );
  }
}

String _actionLabel(GuardianAction action) => switch (action) {
  GuardianAction.confirm => 'Confirm trusted person',
  GuardianAction.disconnect => 'Disconnect',
  GuardianAction.block => 'Block',
  GuardianAction.unblock => 'Unblock',
  GuardianAction.permissions => 'Edit permissions',
};
String _statusLabel(String state) => switch (state) {
  'active' => 'Paired. Delivery not available yet.',
  'confirm' => 'Awaiting your identity confirmation (24-hour limit).',
  'waiting' => 'Waiting for driver confirmation (24-hour limit).',
  'blocked' => 'Blocked by you.',
  _ => 'Disconnected or unavailable.',
};

class GuardianPermissionFields extends StatelessWidget {
  const GuardianPermissionFields({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final GuardianPermissions value;
  final ValueChanged<GuardianPermissions>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SwitchListTile(
        title: const Text('Possible-crash alerts'),
        subtitle: const Text('Permission preference; delivery unavailable'),
        value: value.crash,
        onChanged: onChanged == null
            ? null
            : (v) => onChanged!(
                GuardianPermissions(
                  crash: v,
                  severe: value.severe,
                  state: value.state,
                ),
              ),
      ),
      SwitchListTile(
        title: const Text('Severe-drive alerts'),
        subtitle: const Text('Permission preference; delivery unavailable'),
        value: value.severe,
        onChanged: onChanged == null
            ? null
            : (v) => onChanged!(
                GuardianPermissions(
                  crash: value.crash,
                  severe: v,
                  state: value.state,
                ),
              ),
      ),
      SwitchListTile(
        title: const Text('Coarse safety state'),
        subtitle: const Text('Permission preference; viewing unavailable'),
        value: value.state,
        onChanged: onChanged == null
            ? null
            : (v) => onChanged!(
                GuardianPermissions(
                  crash: value.crash,
                  severe: value.severe,
                  state: v,
                ),
              ),
      ),
      const Text(
        'Live location, current speed and trip history are off and unavailable.',
      ),
    ],
  );
}
