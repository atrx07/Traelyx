import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_account_gateway.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_gateway.dart';
import 'package:traelyx/features/guardian/guardian_models.dart';

class GuardianState {
  const GuardianState({
    this.snapshot,
    this.issued,
    this.preview,
    this.loaded = false,
    this.busy = false,
    this.notice,
  });
  final GuardianSnapshot? snapshot;
  final GuardianInvite? issued;
  final GuardianPreview? preview;
  final bool loaded, busy;
  final String? notice;
}

class GuardianController extends StateNotifier<GuardianState> {
  GuardianController(this.owner, this.gateway, this.account)
    : super(const GuardianState());
  final String owner;
  final GuardianGateway? gateway;
  final AccountGateway account;
  Timer? _expiry;
  String? _previewToken;
  int _epoch = 0;
  void _check() {
    if (!mounted ||
        gateway == null ||
        account.currentIdentity?.userId != owner) {
      throw const GuardianException(
        'Account unavailable. Reload Guardian after signing in.',
      );
    }
  }

  void clearSecrets() {
    _epoch++;
    _expiry?.cancel();
    _previewToken = null;
    if (mounted) {
      state = const GuardianState(
        notice:
            'Invite codes were cleared. Reload to check the latest server state.',
      );
    }
  }

  void _expireAt(DateTime when) {
    _expiry?.cancel();
    final delay = when.difference(DateTime.now());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay, clearSecrets);
  }

  Future<void> _run(Future<GuardianState> Function() action) async {
    if (state.busy) return;
    final epoch = _epoch;
    try {
      _check();
      state = GuardianState(
        snapshot: state.snapshot,
        loaded: state.loaded,
        busy: true,
      );
      final result = await action();
      _check();
      if (epoch == _epoch) state = result;
    } catch (e) {
      if (mounted && epoch == _epoch) {
        _expiry?.cancel();
        _previewToken = null;
        state = GuardianState(
          notice: e is GuardianException
              ? e.message
              : 'Connection or response unavailable. An action may have completed. Reload before trying again.',
        );
      }
    }
  }

  Future<GuardianState> _loaded({String? notice}) async {
    _check();
    final snapshot = await gateway!.load(owner);
    return GuardianState(snapshot: snapshot, loaded: true, notice: notice);
  }

  Future<void> reload() {
    _expiry?.cancel();
    _previewToken = null;
    return _run(() => _loaded());
  }

  Future<void> create(GuardianPermissions permissions) {
    final reviewed = state.snapshot;
    return _run(() async {
      if (!state.loaded || reviewed?.username == null) {
        throw const GuardianException('Save a profile, then reload Guardian.');
      }
      final epoch = _epoch;
      final issued = await gateway!.create(
        owner,
        reviewed!.username!,
        reviewed.displayName!,
        permissions,
      );
      _check();
      if (epoch == _epoch) _expireAt(issued.expiresAt);
      return GuardianState(
        snapshot: reviewed,
        issued: issued,
        loaded: true,
        notice: 'Code created. Share it privately with one trusted person.',
      );
    });
  }

  Future<void> cancel(GuardianInvite invite) => _run(() async {
    await gateway!.cancel(owner, invite.id);
    _expiry?.cancel();
    _previewToken = null;
    return _loaded(
      notice:
          'Invite cancelled. Any already accepted request must be disconnected separately.',
    );
  });
  Future<void> preview(String code) => _run(() async {
    final epoch = _epoch;
    final preview = await gateway!.preview(owner, code.trim());
    _check();
    if (epoch == _epoch && preview != null) {
      _previewToken = code.trim();
      _expireAt(preview.invite.expiresAt);
    }
    return GuardianState(
      snapshot: state.snapshot,
      loaded: state.loaded,
      preview: preview,
      notice: preview == null
          ? 'Invite unavailable, expired, used or blocked.'
          : null,
    );
  });
  Future<void> accept(GuardianPreview reviewed) {
    final code = _previewToken;
    final current = state.preview;
    return _run(() async {
      if (code == null ||
          !identical(current, reviewed) ||
          !reviewed.invite.expiresAt.isAfter(DateTime.now())) {
        throw const GuardianException(
          'Invite expired or changed. Review again.',
        );
      }
      await gateway!.accept(owner, reviewed, code);
      _previewToken = null;
      _expiry?.cancel();
      return _loaded(
        notice: 'Accepted. Waiting for the driver to confirm your identity.',
      );
    });
  }

  Future<void> change(
    GuardianConnection row,
    GuardianAction action, {
    GuardianPermissions? permissions,
  }) => _run(() async {
    if (!state.loaded ||
        !row.actions.contains(action) ||
        !(state.snapshot?.connections.any(
              (current) =>
                  current.id == row.id && current.revision == row.revision,
            ) ??
            false)) {
      throw const GuardianException('Reload before acting again.');
    }
    await gateway!.change(owner, row, action, permissions: permissions);
    return _loaded(
      notice: 'Connection updated. Alert delivery is not available yet.',
    );
  });
  @override
  void dispose() {
    _expiry?.cancel();
    _previewToken = null;
    _epoch++;
    super.dispose();
  }
}

final guardianGatewayProvider = Provider<GuardianGateway?>((ref) {
  final account = ref.watch(accountGatewayProvider);
  return account is SupabaseAccountGateway
      ? SupabaseGuardianGateway(account.client)
      : null;
});
final guardianControllerProvider = StateNotifierProvider.autoDispose
    .family<GuardianController, GuardianState, String>(
      (ref, owner) => GuardianController(
        owner,
        ref.watch(guardianGatewayProvider),
        ref.watch(accountGatewayProvider),
      ),
    );
