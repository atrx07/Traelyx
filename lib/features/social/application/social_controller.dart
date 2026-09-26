import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account_metadata/domain/account_metadata.dart';
import 'package:traelyx/features/social/data/supabase_social_gateway.dart';
import 'package:traelyx/features/social/domain/social.dart';

class SocialState {
  const SocialState({
    this.rows = const [],
    this.person,
    this.loaded = false,
    this.busy = false,
    this.notice,
  });
  final List<SocialEntry> rows;
  final SocialPerson? person;
  final bool loaded;
  final bool busy;
  final String? notice;
}

class SocialController extends StateNotifier<SocialState> {
  SocialController(this.owner, this.gateway, this.account)
    : super(const SocialState());
  final String owner;
  final SocialGateway gateway;
  final AccountGateway account;
  void _check() {
    if (!mounted || account.currentIdentity?.userId != owner) {
      throw const SocialException(
        'The signed-in account changed. Review again.',
      );
    }
  }

  Future<void> _run(Future<SocialState> Function() action) async {
    if (state.busy) return;
    try {
      _check();
      state = SocialState(rows: state.rows, loaded: state.loaded, busy: true);
      final result = await action();
      _check();
      state = result;
    } catch (e) {
      if (mounted) {
        state = SocialState(
          notice: e is SocialException
              ? e.message
              : 'Connection or response unavailable. An action may have completed. Reload before trying again.',
        );
      }
    }
  }

  Future<void> reload() => _run(
    () async => SocialState(rows: await gateway.load(owner), loaded: true),
  );
  Future<void> lookup(String username) => _run(() async {
    final person = await gateway.lookup(owner, username.trim());
    return SocialState(
      rows: state.rows,
      loaded: state.loaded,
      person: person,
      notice: person == null
          ? 'No public profile found for that exact username.'
          : null,
    );
  });
  Future<void> request(SocialPerson person) => _run(() async {
    await gateway.request(owner, person, newMetadataUuid());
    _check();
    return SocialState(
      rows: await gateway.load(owner),
      loaded: true,
      notice: 'Request sent.',
    );
  });
  Future<void> change(SocialEntry entry, SocialAction action) => _run(() async {
    if (!entry.actions.contains(action)) {
      throw const SocialException('Reload before acting again.');
    }
    await gateway.change(owner, entry, action);
    _check();
    return SocialState(
      rows: await gateway.load(owner),
      loaded: true,
      notice: 'Connection updated.',
    );
  });
}

final socialGatewayProvider = Provider<SocialGateway>((ref) {
  final account = ref.watch(accountGatewayProvider);
  return account is SupabaseAccountGateway
      ? SupabaseSocialGateway(account.client)
      : const UnavailableSocialGateway();
});
final socialControllerProvider = StateNotifierProvider.autoDispose
    .family<SocialController, SocialState, String>(
      (ref, owner) => SocialController(
        owner,
        ref.watch(socialGatewayProvider),
        ref.watch(accountGatewayProvider),
      ),
    );
