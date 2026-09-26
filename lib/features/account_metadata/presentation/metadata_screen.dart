import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/database/app_database.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account_metadata/application/metadata_providers.dart';
import 'package:traelyx/features/account_metadata/data/metadata_repository.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';

class MetadataScreen extends ConsumerStatefulWidget {
  const MetadataScreen({super.key});
  @override
  ConsumerState<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends ConsumerState<MetadataScreen> {
  bool _busy = false;
  String? _notice;
  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(accountIdentityProvider).valueOrNull;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            key: const ValueKey('account-metadata-screen'),
            padding: const EdgeInsets.all(TraelyxSpacing.xl),
            children: [
              TextButton.icon(
                onPressed: () => context.go(TraelyxRoutes.youAccount),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Account'),
              ),
              Text(
                'Profile & vehicles',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'Save only the profile and vehicle details you choose. Opening this page uses your local cache. Reload cloud checks for changes from another device.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Profiles start private. A public profile shares only username and display name. Vehicles stay private. Trips, routes, raw sensors, registration numbers, and local calibration are excluded.',
              ),
              const SizedBox(height: 16),
              if (identity == null)
                const Text(
                  'Sign in to manage optional profile and vehicle sync.',
                )
              else ...[
                Text('Account: ${identity.email ?? 'your signed-in account'}'),
                ref
                    .watch(metadataEntriesProvider(identity.userId))
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Column(
                        children: [
                          const Text(
                            'Cached details could not be read safely. Local trips are retained.',
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _discard(identity.userId),
                            child: const Text('Discard queued changes'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(identity.userId, () async {
                                    await ref
                                        .read(metadataServiceProvider)
                                        .reload(identity.userId);
                                    return 'Cloud cache reloaded.';
                                  }),
                            child: const Text('Reload cloud'),
                          ),
                        ],
                      ),
                      data: (entries) => _content(identity.userId, entries),
                    ),
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(String owner, List<MetadataEntry> entries) {
    final profile = entries
        .where((e) => e.data.kind == MetadataKind.profile)
        .firstOrNull;
    final pending = entries.where((e) => e.pending != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text('$pending queued changes • cached details'),
        if (profile != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(profile.data.displayName),
            subtitle: Text(
              '@${profile.data.fields['username']} · ${_state(profile)}',
            ),
          ),
        FilledButton(
          key: const ValueKey('edit-cloud-profile'),
          onPressed: _busy || profile?.pending != null
              ? null
              : () => _edit(owner, MetadataKind.profile, entry: profile),
          child: Text(profile == null ? 'Create profile' : 'Edit profile'),
        ),
        const SizedBox(height: 16),
        for (final entry in entries.where(
          (e) => e.data.kind == MetadataKind.vehicle,
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.data.displayName),
            subtitle: Text(
              '${entry.data.fields['vehicle_class']} · ${_state(entry)}',
            ),
            trailing: TextButton(
              onPressed: _busy || entry.pending != null
                  ? null
                  : () => _edit(owner, MetadataKind.vehicle, entry: entry),
              child: const Text('Edit'),
            ),
          ),
        OutlinedButton(
          key: const ValueKey('add-cloud-vehicle'),
          onPressed: _busy || profile == null
              ? null
              : () => _edit(owner, MetadataKind.vehicle),
          child: const Text('Add private vehicle'),
        ),
        TextButton(
          key: const ValueKey('copy-local-vehicle'),
          onPressed: _busy || profile == null
              ? null
              : () => _selectLocal(owner, entries),
          child: const Text('Review a local vehicle copy'),
        ),
        if (profile == null)
          const Text('Save a profile before adding private vehicles.'),
        const Text(
          'These account labels do not change the vehicle used for local recording.',
        ),
        const Divider(height: 32),
        OutlinedButton(
          key: const ValueKey('reload-cloud-metadata'),
          onPressed: _busy || pending > 0
              ? null
              : () => _run(owner, () async {
                  await ref.read(metadataServiceProvider).reload(owner);
                  return 'Cloud details reloaded.';
                }),
          child: const Text('Reload cloud'),
        ),
        OutlinedButton(
          key: const ValueKey('retry-cloud-metadata'),
          onPressed: _busy || pending == 0
              ? null
              : () => _run(owner, () async {
                  final count = await ref
                      .read(metadataServiceProvider)
                      .sync(owner);
                  return '$count changes saved. Remaining changes may need a retry delay or conflict review.';
                }),
          child: const Text('Retry queued changes'),
        ),
        TextButton(
          onPressed: _busy || pending == 0 ? null : () => _discard(owner),
          child: const Text('Discard queued changes'),
        ),
        const Text(
          'Queued visibility changes take effect only when saved to the cloud. Signing out pauses retries. Discarding cannot recall a request already sent; reload to check the cloud state.',
        ),
      ],
    );
  }

  String _state(MetadataEntry entry) {
    if (entry.pending != null) {
      return switch (entry.pending!.state) {
        'blocked' =>
          'Needs review. Discard, reload, and check your edits or username.',
        'retry' => 'Queued; retry after the connection or delay recovers',
        _ => 'Queued; cloud save not confirmed',
      };
    }
    return entry.data.isPublic ? 'Public profile · saved' : 'Private · saved';
  }

  Future<void> _selectLocal(String owner, List<MetadataEntry> entries) async {
    try {
      final vehicles = await ref
          .read(metadataRepositoryProvider)
          .localVehicles();
      if (!mounted) return;
      final selected = await showDialog<Vehicle>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose metadata to review'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Only a chosen label and broad class will be copied. Local vehicle ownership and trip assignments stay unchanged.',
              ),
            ),
            for (final vehicle in vehicles.where(
              (v) => !entries.any((e) => e.sourceLocalVehicleId == v.id),
            ))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, vehicle),
                child: Text(vehicle.displayName),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected != null && mounted) {
        await _edit(owner, MetadataKind.vehicle, local: selected);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'Local vehicle metadata could not be reviewed.',
        );
      }
    }
  }

  Future<void> _edit(
    String owner,
    MetadataKind kind, {
    MetadataEntry? entry,
    Vehicle? local,
  }) async {
    final result = await showDialog<AccountMetadata>(
      context: context,
      builder: (_) => _MetadataEditor(
        owner: owner,
        kind: kind,
        existing: entry?.data,
        local: local,
      ),
    );
    if (result == null || !mounted) return;
    await _run(owner, () async {
      final service = ref.read(metadataServiceProvider);
      await service.queue(
        result,
        sourceLocalVehicleId: entry?.sourceLocalVehicleId ?? local?.id,
      );
      final count = await service.sync(owner);
      return count > 0
          ? 'Cloud save confirmed.'
          : 'Change queued locally. Cloud save is not confirmed; review its status below.';
    });
  }

  Future<void> _discard(String owner) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard queued edits?'),
        content: const Text(
          'Unsaved drafts will be removed. Requests already sent may have completed. Existing cloud details and public visibility remain until changed successfully; reload afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep edits'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard edits'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(owner, () async {
        await ref.read(metadataServiceProvider).discard(owner);
        return 'Queued edits discarded. Reload cloud before editing again.';
      });
    }
  }

  Future<void> _run(String owner, Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => _notice = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _notice =
              error is MetadataException &&
                  error.reason == MetadataFailure.accountChanged
              ? 'The signed-in account changed. Review again.'
              : 'Could not complete safely. Check the queue; discard and reload for a conflict. Local trips are retained.',
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(metadataEntriesProvider(owner));
        setState(() => _busy = false);
      }
    }
  }
}

class _MetadataEditor extends StatefulWidget {
  const _MetadataEditor({
    required this.owner,
    required this.kind,
    this.existing,
    this.local,
  });
  final String owner;
  final MetadataKind kind;
  final AccountMetadata? existing;
  final Vehicle? local;
  @override
  State<_MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<_MetadataEditor> {
  late final _name = TextEditingController(
    text: widget.existing?.displayName ?? widget.local?.displayName ?? '',
  );
  late final _username = TextEditingController(
    text: widget.existing?.fields['username'] as String? ?? '',
  );
  late bool _public = widget.existing?.isPublic ?? false;
  late String _class =
      widget.existing?.fields['vehicle_class'] as String? ??
      (AccountMetadata.vehicleClasses.contains(widget.local?.vehicleType)
          ? widget.local!.vehicleType
          : 'unspecified');
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.kind == MetadataKind.profile
          ? 'Review profile'
          : 'Review private vehicle',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('metadata-display-name'),
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Display name',
              helperText:
                  'Use a label you are comfortable storing in your account.',
            ),
          ),
          if (widget.kind == MetadataKind.profile) ...[
            TextField(
              key: const ValueKey('metadata-username'),
              controller: _username,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText:
                    '3–30 lowercase letters, digits or _. Start with a letter.',
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('metadata-public-choice'),
              value: _public,
              onChanged: (value) => setState(() => _public = value!),
              title: const Text('Publish username and display name'),
              subtitle: const Text(
                'Anyone who knows the exact username can look up these two fields. Vehicles and trips remain private.',
              ),
            ),
          ] else
            DropdownButtonFormField<String>(
              initialValue: _class,
              decoration: const InputDecoration(
                labelText: 'Broad vehicle class',
              ),
              items: [
                for (final value in AccountMetadata.vehicleClasses)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) => setState(() => _class = value!),
            ),
          const Text(
            'Save queues these reviewed fields and attempts cloud sync. It does not upload trips or raw telemetry.',
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('confirm-metadata-save'),
        onPressed: () {
          try {
            final data = AccountMetadata(
              userId: widget.owner,
              kind: widget.kind,
              id:
                  widget.existing?.id ??
                  (widget.kind == MetadataKind.profile
                      ? widget.owner
                      : newMetadataUuid()),
              revision: widget.existing?.revision ?? 0,
              fields: {
                'display_name': _name.text.trim(),
                if (widget.kind == MetadataKind.profile) ...{
                  'username': _username.text.trim(),
                  'visibility': _public ? 'public' : 'private',
                } else
                  'vehicle_class': _class,
              },
            );
            Navigator.pop(context, data);
          } on FormatException {
            setState(
              () => _error =
                  'Check the name, username, and selected class. Control characters are not allowed.',
            );
          }
        },
        child: Text(
          widget.kind == MetadataKind.profile && _public
              ? 'Save public profile'
              : 'Save privately',
        ),
      ),
    ],
  );
}
