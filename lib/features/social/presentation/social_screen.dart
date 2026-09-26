import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/social/application/social_controller.dart';
import 'package:traelyx/features/social/domain/social.dart';

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountIdentityProvider).valueOrNull?.userId;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: owner == null
              ? ListView(
                  key: const ValueKey('destination-Social'),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Social',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sign in to manage optional friendships. Recording, history, and replay remain available locally.',
                    ),
                    TextButton(
                      onPressed: () => context.go(TraelyxRoutes.youAccount),
                      child: const Text('Open Account'),
                    ),
                  ],
                )
              : _SignedInSocial(key: ValueKey(owner), owner: owner),
        ),
      ),
    );
  }
}

class _SignedInSocial extends ConsumerStatefulWidget {
  const _SignedInSocial({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_SignedInSocial> createState() => _SignedInSocialState();
}

class _SignedInSocialState extends ConsumerState<_SignedInSocial> {
  final _username = TextEditingController();
  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(detail)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep unchanged'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialControllerProvider(widget.owner));
    final controller = ref.read(
      socialControllerProvider(widget.owner).notifier,
    );
    return ListView(
      key: const ValueKey('destination-Social'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Social', style: Theme.of(context).textTheme.displaySmall),
        TextButton(
          onPressed: () => context.go('/social/rankings'),
          child: const Text('Safe comparisons'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Connect by exact public username. Requests and acceptance share only username and display name with that person, even if your profile is private. Trips, routes, vehicles, and scores stay private.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Names are saved when a request is sent. Requests expire after 7 days. Sending is limited to 30 requests per 24 hours; closed connections have a 7-day request cooldown. Blocking ends a connection and prevents requests in either direction.',
        ),
        TextButton(
          onPressed: state.busy
              ? null
              : () => context.go(TraelyxRoutes.youMetadata),
          child: const Text('Manage my profile'),
        ),
        FilledButton(
          onPressed: state.busy ? null : controller.reload,
          child: const Text('Reload connections'),
        ),
        if (!state.loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reload to view your current connections. A saved profile is required to send requests.',
            ),
          ),
        TextField(
          controller: _username,
          enabled: !state.busy,
          maxLength: 30,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Exact public username'),
        ),
        OutlinedButton(
          onPressed: state.busy
              ? null
              : () => controller.lookup(_username.text),
          child: const Text('Find public profile'),
        ),
        if (state.person case final person?)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(person.displayName),
                  Text('@${person.username}'),
                  FilledButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            if (await _confirm(
                              'Send friend request?',
                              'Share your saved username and display name with @${person.username}. This also applies when your profile is private. No trip data or Guardian access is shared.',
                            )) {
                              if (mounted) await controller.request(person);
                            }
                          },
                    child: const Text('Send friend request'),
                  ),
                ],
              ),
            ),
          ),
        if (state.busy) const LinearProgressIndicator(),
        if (state.notice case final notice?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(notice)),
          ),
        if (state.loaded && state.rows.isEmpty)
          const Text('No current requests, friends, or blocked connections.'),
        for (final entry in state.rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(entry.person.displayName),
                  Text('@${entry.person.username}'),
                  Text(switch (entry.status) {
                    SocialStatus.incoming => 'Incoming request',
                    SocialStatus.outgoing => 'Request sent',
                    SocialStatus.friend => 'Friend',
                    SocialStatus.blocked => 'Blocked by you',
                  }),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final action in entry.actions)
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  final detail = switch (action) {
                                    SocialAction.accept =>
                                      'Share your username and display name with this person and become friends. Trips, vehicles, scores, and Guardian access stay private.',
                                    SocialAction.block =>
                                      'End this connection and prevent requests in either direction. Unblocking does not restore friendship.',
                                    SocialAction.unblock =>
                                      'Remove your block. This does not restore friendship. A new request can be sent after the 7-day cooldown if the other person is discoverable and has not blocked you.',
                                    _ =>
                                      'End this request or connection. A new request has a 7-day cooldown. No trip data is changed.',
                                  };
                                  if (await _confirm(
                                    '${_label(action)} @${entry.person.username}?',
                                    detail,
                                  )) {
                                    if (mounted) {
                                      await controller.change(entry, action);
                                    }
                                  }
                                },
                          child: Text(_label(action)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _label(SocialAction action) => switch (action) {
    SocialAction.accept => 'Accept',
    SocialAction.decline => 'Decline',
    SocialAction.cancel => 'Cancel request',
    SocialAction.remove => 'Remove friend',
    SocialAction.block => 'Block',
    SocialAction.unblock => 'Unblock',
  };
}
