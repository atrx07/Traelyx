import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/domain/account_email.dart';
import 'package:traelyx/features/account/domain/account_link_failure.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    final email = normalizeAccountEmail(_emailController.text);
    if (email == null) {
      setState(() {
        _isError = true;
        _message = 'Enter a valid email address.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(accountGatewayProvider).sendSignInLink(email);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message =
            'Check your email for the sign-in link. Open it on this device.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        final reason = error is AccountLinkException
            ? error.reason
            : AccountLinkFailure.unknown;
        _message = switch (reason) {
          AccountLinkFailure.network =>
            'Could not reach the sign-in service. Check your connection and try again.',
          AccountLinkFailure.rateLimited =>
            'The sign-in service has temporarily limited email requests. Wait before requesting another link.',
          AccountLinkFailure.service =>
            'The sign-in service is temporarily unavailable. Try again later.',
          AccountLinkFailure.rejected =>
            'The sign-in service could not accept this email request. Check the email address or contact the app maintainer.',
          AccountLinkFailure.unknown =>
            'Could not send a sign-in link. Try again. If this continues, contact the app maintainer.',
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(accountGatewayProvider).signOut();
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = 'Signed out on this device. Local trips are still here.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = 'Could not sign out. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshSession() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(accountGatewayProvider).refreshSession();
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = 'Sign-in refreshed on this device.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message =
            'Could not refresh sign-in. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    final gateway = ref.watch(accountGatewayProvider);
    final account = ref.watch(accountIdentityProvider);
    final identity = account.valueOrNull;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            key: const ValueKey('account-screen'),
            padding: const EdgeInsets.all(TraelyxSpacing.xl),
            children: [
              TextButton.icon(
                key: const ValueKey('account-back'),
                onPressed: () => context.go(TraelyxRoutes.you),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('You'),
              ),
              const SizedBox(height: TraelyxSpacing.xl),
              Icon(
                Icons.person_outline_rounded,
                color: colors.accent,
                size: 38,
              ),
              const SizedBox(height: TraelyxSpacing.lg),
              Text('Account', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: TraelyxSpacing.md),
              Text(
                'Sign in for future online features. Recording, history, '
                'replay, and export work without an account.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: TraelyxSpacing.xl),
              if (identity != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(TraelyxSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signed in',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: TraelyxSpacing.sm),
                        Text(identity.email ?? 'Account active'),
                        const SizedBox(height: TraelyxSpacing.md),
                        const Text(
                          'Your existing trips stay on this device. Signing in '
                          'does not upload them; summary sync is not active yet.',
                        ),
                        const SizedBox(height: TraelyxSpacing.lg),
                        TextButton(
                          key: const ValueKey('account-refresh'),
                          onPressed: _busy ? null : _refreshSession,
                          child: const Text('Refresh sign-in'),
                        ),
                        const SizedBox(height: TraelyxSpacing.sm),
                        OutlinedButton(
                          key: const ValueKey('account-sign-out'),
                          onPressed: _busy ? null : _signOut,
                          child: const Text('Sign out on this device'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (!gateway.isAvailable) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(TraelyxSpacing.lg),
                    child: const Text(
                      'Online account sign-in is unavailable in this build. '
                      'You can keep using Traelyx locally.',
                    ),
                  ),
                ),
              ] else if (account.isLoading) ...[
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                Text(
                  'Sign in or create an account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: TraelyxSpacing.sm),
                const Text(
                  'Enter your email to receive a one-time link. An account '
                  'will be created if you do not have one. Nothing from your '
                  'local drives is uploaded by this step.',
                ),
                const SizedBox(height: TraelyxSpacing.lg),
                TextField(
                  key: const ValueKey('account-email'),
                  controller: _emailController,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSubmitted: (_) => _busy ? null : _sendLink(),
                ),
                const SizedBox(height: TraelyxSpacing.lg),
                FilledButton(
                  key: const ValueKey('account-send-link'),
                  onPressed: _busy ? null : _sendLink,
                  child: Text(_busy ? 'Sending…' : 'Email me a sign-in link'),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: TraelyxSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    key: const ValueKey('account-feedback'),
                    style: TextStyle(
                      color: _isError ? colors.caution : colors.positive,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: TraelyxSpacing.xl),
              TextButton(
                key: const ValueKey('account-continue-locally'),
                onPressed: () => context.go(TraelyxRoutes.drive),
                child: const Text('Continue locally'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
