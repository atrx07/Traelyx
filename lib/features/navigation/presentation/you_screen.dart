import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.traelyxColors;
    final account = ref.watch(accountIdentityProvider).valueOrNull;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(TraelyxSpacing.xl),
            children: [
              const SizedBox(height: TraelyxSpacing.section),
              Icon(
                Icons.person_outline_rounded,
                color: colors.accent,
                size: 36,
              ),
              const SizedBox(height: TraelyxSpacing.xl),
              Text(
                'YOUR CONTROLS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.accent,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                'You',
                key: const ValueKey('destination-You'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Text(
                'Manage your account, private vehicle details, privacy controls, '
                'and local data here.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: TraelyxSpacing.xxl),
              Card(
                child: ListTile(
                  key: const ValueKey('open-account'),
                  contentPadding: const EdgeInsets.all(TraelyxSpacing.md),
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: colors.accent,
                  ),
                  title: const Text('Account'),
                  subtitle: Text(
                    account == null
                        ? 'Continue locally or sign in for optional account features.'
                        : 'Signed in as ${account.email ?? 'your account'}. Local drives stay on this device.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(TraelyxRoutes.youAccount),
                ),
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Card(
                child: ListTile(
                  key: const ValueKey('open-data-export'),
                  contentPadding: const EdgeInsets.all(TraelyxSpacing.md),
                  leading: Icon(Icons.storage_rounded, color: colors.positive),
                  title: const Text('Data & Export'),
                  subtitle: const Text(
                    'Review local storage, retention, cache, exports, and deletion.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(TraelyxRoutes.youDataExport),
                ),
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Card(
                child: ListTile(
                  key: const ValueKey('open-diagnostics'),
                  contentPadding: const EdgeInsets.all(TraelyxSpacing.md),
                  leading: Icon(
                    Icons.monitor_heart_outlined,
                    color: colors.information,
                  ),
                  title: const Text('Developer / Diagnostics'),
                  subtitle: const Text(
                    'Inspect redacted app, database, recorder, and storage '
                    'status.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(TraelyxRoutes.youDiagnostics),
                ),
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(TraelyxSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.construction_outlined, color: colors.caution),
                      const SizedBox(width: TraelyxSpacing.md),
                      const Expanded(
                        child: Text(
                          'Profile and private vehicle details are available in Account. '
                          'Recording vehicle selection is not available yet.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
