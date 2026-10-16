import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/data/supabase_client_source.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';
import 'package:traelyx/features/guardian/guardian_driver_consent.dart';

/// A separate debug gate: recipient registration never authorizes driver activation.
final guardianDriverPilotProvider = Provider<bool>(
  (ref) =>
      kDebugMode && const bool.fromEnvironment('TRAELYX_GUARDIAN_DRIVER_PILOT'),
);

abstract interface class GuardianDriverControls {
  Future<DateTime> activate(
    GuardianDriverConsent review,
    GuardianDriverReviewCancellation cancellation,
  );
  Future<void> stop(String owner);
}

final class ReviewedGuardianDriverControls implements GuardianDriverControls {
  const ReviewedGuardianDriverControls(this.service);
  final GuardianDriverActivationService service;
  @override
  Future<DateTime> activate(
    GuardianDriverConsent review,
    GuardianDriverReviewCancellation cancellation,
  ) => service.prepareAfterExplicitConsent(review, cancellation: cancellation);
  @override
  Future<void> stop(String owner) => service.stop(owner);
}

final guardianDriverControlsProvider = Provider<GuardianDriverControls?>((ref) {
  if (!ref.watch(guardianDriverPilotProvider)) return null;
  final account = ref.watch(accountGatewayProvider);
  final client = accountClientOf(account);
  if (account is! GuardianBoundAccountGateway || client == null) return null;
  return ReviewedGuardianDriverControls(
    GuardianDriverActivationService(
      account,
      const MethodChannelGuardianActivationPort(),
      SupabaseGuardianDriverSessionGateway(client),
    ),
  );
});

final guardianDriverIdleCheckProvider = Provider<Future<bool> Function()>((
  ref,
) {
  final bridge = ref.watch(recorderBridgeProvider);
  return () async => !(await bridge.getStatus().timeout(
    const Duration(seconds: 5),
  )).lifecycle.active;
});

final class GuardianDriverControlState {
  const GuardianDriverControlState({
    this.activating = false,
    this.stopping = false,
    this.expiresAt,
    this.notice,
  });
  final bool activating, stopping;
  final DateTime? expiresAt;
  final String? notice;
}

/// Ephemeral UI state, never an observation of monitoring or delivery.
class GuardianDriverControlsController
    extends StateNotifier<GuardianDriverControlState> {
  GuardianDriverControlsController(
    this.owner,
    this.account,
    this.controls,
    this.isIdle,
  ) : super(const GuardianDriverControlState()) {
    _identity = account.identityChanges.listen((identity) {
      if (identity?.userId != owner) interrupt();
    }, onError: (Object _) => interrupt());
  }
  final String owner;
  final AccountGateway account;
  final GuardianDriverControls? controls;
  final Future<bool> Function() isIdle;
  late final StreamSubscription<Object?> _identity;
  GuardianDriverReviewCancellation? _activation;
  bool _stopping = false;
  int _epoch = 0;
  bool get available => controls != null;
  bool get _sameOwner => account.currentIdentity?.userId == owner;

  /// Invalidates work without publishing during widget/provider teardown.
  void abandon() {
    _epoch++;
    final activation = _activation;
    if (activation != null) unawaited(activation.cancel());
  }

  void interrupt() {
    abandon();
    if (mounted) {
      state = GuardianDriverControlState(
        activating: _activation != null,
        stopping: _stopping,
        notice: _activation == null
            ? null
            : 'Driver review interrupted. Check driver state and use Stop if needed.',
      );
    }
  }

  Future<bool> canReview() async {
    if (!mounted ||
        !available ||
        !_sameOwner ||
        _activation != null ||
        _stopping) {
      return false;
    }
    final epoch = _epoch;
    try {
      final idle = await isIdle();
      if (!mounted || epoch != _epoch || !_sameOwner || _stopping) return false;
      if (!idle) {
        state = const GuardianDriverControlState(
          notice: 'End the recorded trip before reviewing driver alerts.',
        );
      }
      return idle;
    } catch (_) {
      if (mounted && epoch == _epoch) {
        state = const GuardianDriverControlState(
          notice: 'Could not check recording state. Try the review again.',
        );
      }
      return false;
    }
  }

  Future<void> activate(GuardianDriverConsent review) async {
    if (!mounted ||
        !available ||
        !_sameOwner ||
        _activation != null ||
        _stopping ||
        review.ownerId != owner ||
        !review.isFreshAt(DateTime.now().toUtc())) {
      return;
    }
    final cancellation = GuardianDriverReviewCancellation();
    _activation = cancellation;
    final epoch = _epoch;
    state = const GuardianDriverControlState(activating: true);
    try {
      if (!await isIdle() ||
          !mounted ||
          epoch != _epoch ||
          !_sameOwner ||
          cancellation.isCancelled ||
          !review.isFreshAt(DateTime.now().toUtc())) {
        throw const GuardianActivationException(
          'Driver review interrupted or recording is active. Review again while idle.',
        );
      }
      final expiry = await controls!.activate(review, cancellation);
      if (!mounted ||
          epoch != _epoch ||
          !_sameOwner ||
          cancellation.isCancelled) {
        return;
      }
      cancellation.acceptCompletion();
      state = GuardianDriverControlState(
        expiresAt: expiry,
        notice:
            'Driver consent saved. Check driver state; alert sending is unavailable in this build.',
      );
    } catch (error) {
      if (mounted && epoch == _epoch && _sameOwner) {
        state = GuardianDriverControlState(
          notice: error is GuardianActivationException
              ? error.message
              : 'Driver activation could not be confirmed. Check driver state and use Stop if needed.',
        );
      }
    } finally {
      _activation = null;
      if (mounted) {
        state = GuardianDriverControlState(
          stopping: _stopping,
          expiresAt: epoch == _epoch ? state.expiresAt : null,
          notice: state.notice,
        );
      }
    }
  }

  /// Remains usable during activation; raw trip recording is untouched.
  Future<void> stop() async {
    if (!mounted || !available || !_sameOwner || _stopping) return;
    interrupt();
    _stopping = true;
    final epoch = _epoch;
    state = GuardianDriverControlState(
      activating: _activation != null,
      stopping: true,
    );
    try {
      await controls!.stop(owner);
      if (!mounted || epoch != _epoch || !_sameOwner) return;
      state = GuardianDriverControlState(
        activating: _activation != null,
        notice:
            'Driver Stop completed. Already handed-off notices cannot be retracted.',
      );
    } catch (_) {
      if (mounted && epoch == _epoch && _sameOwner) {
        state = GuardianDriverControlState(
          activating: _activation != null,
          notice:
              'Driver Stop could not be fully confirmed. Check driver state and retry Stop.',
        );
      }
    } finally {
      _stopping = false;
      if (mounted) {
        state = GuardianDriverControlState(
          activating: _activation != null,
          notice: state.notice,
        );
      }
    }
  }

  @override
  void dispose() {
    abandon();
    unawaited(_identity.cancel());
    super.dispose();
  }
}

final guardianDriverControlsControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      GuardianDriverControlsController,
      GuardianDriverControlState,
      String
    >(
      (ref, owner) => GuardianDriverControlsController(
        owner,
        ref.watch(accountGatewayProvider),
        ref.watch(guardianDriverControlsProvider),
        ref.watch(guardianDriverIdleCheckProvider),
      ),
    );
