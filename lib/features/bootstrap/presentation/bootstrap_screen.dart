import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';
import 'package:traelyx/features/bootstrap/application/drive_control_model.dart';

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen>
    with WidgetsBindingObserver {
  bool _actionInProgress = false;
  bool _exportInProgress = false;
  String? _actionError;
  String? _actionSuccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(recorderPermissionControllerProvider).refresh();
      ref.invalidate(recorderFinalizationSyncProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ref.watch(bootstrapReadinessProvider);
    final permissions = ref.watch(recorderPermissionStatusProvider);
    final recorder = ref.watch(recorderStatusProvider);
    ref.watch(recorderStatusPollingProvider);
    final finalization = ref.watch(recorderFinalizationSyncProvider);
    final latestExportTripId = ref.watch(latestTripDebugExportTripIdProvider);
    final colors = context.traelyxColors;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TraelyxSpacing.xl,
              TraelyxSpacing.xxl,
              TraelyxSpacing.xl,
              TraelyxSpacing.section,
            ),
            children: [
              const _Wordmark(),
              const SizedBox(height: TraelyxSpacing.hero),
              Text(
                'Your drives.\nYour evidence.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Text(
                'Record directly on this phone. Traelyx asks for access only '
                'when it is needed and keeps raw telemetry local.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: TraelyxSpacing.xxl),
              _FoundationCard(readiness: readiness),
              const SizedBox(height: TraelyxSpacing.md),
              _DriveCard(permissions: permissions, recorder: recorder),
              _FinalizationCard(finalization: finalization),
              _TripDebugExportCard(
                latestTripId: latestExportTripId,
                recorder: recorder,
                exportInProgress: _exportInProgress,
                onExport: _runTripDebugExport,
              ),
              const SizedBox(height: TraelyxSpacing.md),
              _NotificationCard(
                permissions: permissions,
                actionInProgress: _actionInProgress,
                onRequest: () => _runPermissionAction(
                  ref
                      .read(recorderPermissionControllerProvider)
                      .requestNotification,
                ),
                onOpenSettings: () => _runPermissionAction(
                  ref
                      .read(recorderPermissionControllerProvider)
                      .openAppSettings,
                ),
              ),
              if (_actionError != null) ...[
                const SizedBox(height: TraelyxSpacing.md),
                Text(
                  _actionError!,
                  key: const ValueKey('drive-action-error'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.critical),
                ),
              ],
              if (_actionSuccess != null) ...[
                const SizedBox(height: TraelyxSpacing.md),
                Text(
                  _actionSuccess!,
                  key: const ValueKey('drive-action-success'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.positive),
                ),
              ],
              const SizedBox(height: TraelyxSpacing.xxl),
              _PrimaryDriveButton(
                permissions: permissions,
                recorder: recorder,
                actionInProgress: _actionInProgress,
                onAction: _runPrimaryAction,
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                'No account required · No telemetry uploaded · '
                'No background location requested',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                'Stopped drives are finalized into local history before native handoff cleanup.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runTripDebugExport(String tripId) async {
    if (_exportInProgress || _actionInProgress) return;
    setState(() {
      _exportInProgress = true;
      _actionError = null;
      _actionSuccess = null;
    });
    try {
      final result = await ref
          .read(recorderTripDebugExporterProvider)
          .exportTrip(tripId);
      if (!mounted) return;
      setState(() {
        if (result.exported) {
          _actionSuccess =
              'Private fixture exported and verified (${result.chunkCount} chunks).';
        } else if (result.errorCode == 'export_cancelled') {
          _actionSuccess = 'Export cancelled. No file was written.';
        } else {
          _actionError = 'The private fixture could not be exported safely.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'The private fixture could not be exported safely.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportInProgress = false;
        });
      }
    }
  }

  Future<void> _runPrimaryAction(DrivePrimaryAction action) async {
    final permissions = ref.read(recorderPermissionControllerProvider);
    final commands = ref.read(recorderCommandControllerProvider);
    switch (action) {
      case DrivePrimaryAction.requestPreciseLocation:
        await _runPermissionAction(permissions.requestLocation);
      case DrivePrimaryAction.openAppSettings:
        await _runPermissionAction(permissions.openAppSettings);
      case DrivePrimaryAction.openLocationSettings:
        await _runPermissionAction(permissions.openLocationSettings);
      case DrivePrimaryAction.startTrip:
        await _runStatusAction(commands.startTrip);
      case DrivePrimaryAction.stopTrip:
        await _runStatusAction(
          commands.stopTrip,
          successMessage: 'Drive finalized and indexed in local history.',
        );
      case DrivePrimaryAction.none:
        return;
    }
  }

  Future<void> _runPermissionAction(
    Future<RecorderPermissionStatus> Function() action,
  ) => _runAction(action);

  Future<void> _runStatusAction(
    Future<RecorderStatus> Function() action, {
    String? successMessage,
  }) => _runAction(action, successMessage: successMessage);

  Future<void> _runAction<T>(
    Future<T> Function() action, {
    String? successMessage,
  }) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
      _actionError = null;
      _actionSuccess = null;
    });
    try {
      await action();
      if (mounted && successMessage != null) {
        setState(() {
          _actionSuccess = successMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'That action did not complete. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: TraelyxSpacing.sm),
        Expanded(
          child: Text(
            'TRAELYX',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(letterSpacing: 2.8),
          ),
        ),
        const SizedBox(width: TraelyxSpacing.sm),
        Text(
          'M2 · RECORDING',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard({required this.readiness});

  final AsyncValue<BootstrapReadiness> readiness;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: readiness.when(
          loading: () => _StatusRow(
            icon: Icons.sync,
            color: context.traelyxColors.information,
            title: 'Checking local foundation',
            detail: 'Opening local storage and the native recorder bridge…',
          ),
          error: (error, stackTrace) => _StatusRow(
            icon: Icons.error_outline,
            color: context.traelyxColors.critical,
            title: 'Foundation check failed',
            detail: 'Recording remains unavailable until this check succeeds.',
          ),
          data: (status) => _StatusRow(
            icon: Icons.check_circle_outline,
            color: context.traelyxColors.positive,
            title: 'Local foundation ready',
            detail:
                'Database v1 · Native bridge v${status.bridgeVersion} · '
                'Recorder ${status.recorderState}',
          ),
        ),
      ),
    );
  }
}

class _DriveCard extends StatelessWidget {
  const _DriveCard({required this.permissions, required this.recorder});

  final AsyncValue<RecorderPermissionStatus> permissions;
  final AsyncValue<RecorderStatus> recorder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: permissions.when(
          loading: () => _StatusRow(
            icon: Icons.location_searching,
            color: context.traelyxColors.information,
            title: 'Checking recording access',
            detail: 'No permission prompt is shown during this check.',
          ),
          error: (error, stackTrace) => _StatusRow(
            icon: Icons.error_outline,
            color: context.traelyxColors.critical,
            title: 'Could not check recording access',
            detail: 'Recording remains unavailable. Reopen Drive to retry.',
          ),
          data: (permissionStatus) => recorder.when(
            loading: () => _StatusRow(
              icon: Icons.sync,
              color: context.traelyxColors.information,
              title: 'Checking recorder state',
              detail: 'Reading the local recorder status…',
            ),
            error: (error, stackTrace) => _StatusRow(
              icon: Icons.error_outline,
              color: context.traelyxColors.critical,
              title: 'Could not check recorder state',
              detail: 'Recording remains unavailable. Reopen Drive to retry.',
            ),
            data: (recorderStatus) {
              final model = DriveControlModel.from(
                permissions: permissionStatus,
                recorder: recorderStatus,
              );
              return _StatusRow(
                icon: _driveIcon(model.action),
                color: _driveColor(context, model.action),
                title: model.title,
                detail: model.detail,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.permissions,
    required this.actionInProgress,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final AsyncValue<RecorderPermissionStatus> permissions;
  final bool actionInProgress;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final status = permissions.valueOrNull;
    if (status == null ||
        status.notificationState == RecorderPermissionState.granted ||
        status.notificationState == RecorderPermissionState.notRequired) {
      return const SizedBox.shrink();
    }
    final canRequest = status.canRequestNotification;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TraelyxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              icon: Icons.notifications_outlined,
              color: context.traelyxColors.caution,
              title: 'Keep the recording notice visible',
              detail:
                  'Notification access keeps the foreground-service notice in '
                  'the notification drawer. Recording can still start without it.',
            ),
            const SizedBox(height: TraelyxSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('notification-permission-action'),
                onPressed: actionInProgress
                    ? null
                    : canRequest
                    ? onRequest
                    : onOpenSettings,
                child: Text(
                  canRequest ? 'Allow notifications' : 'Open app settings',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalizationCard extends StatelessWidget {
  const _FinalizationCard({required this.finalization});

  final AsyncValue<RecorderFinalizationSyncResult> finalization;

  @override
  Widget build(BuildContext context) {
    return finalization.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.only(top: TraelyxSpacing.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(TraelyxSpacing.lg),
            child: _StatusRow(
              icon: Icons.warning_amber_outlined,
              color: context.traelyxColors.critical,
              title: 'A stopped drive needs attention',
              detail:
                  'Its native evidence remains preserved, but local history indexing did not complete.',
            ),
          ),
        ),
      ),
      data: (result) {
        if (result.reconciledTripIds.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: TraelyxSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(TraelyxSpacing.lg),
              child: _StatusRow(
                icon: Icons.inventory_2_outlined,
                color: context.traelyxColors.positive,
                title: 'Recovered drive saved locally',
                detail:
                    'Verified native chunks were indexed without uploading telemetry.',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TripDebugExportCard extends StatelessWidget {
  const _TripDebugExportCard({
    required this.latestTripId,
    required this.recorder,
    required this.exportInProgress,
    required this.onExport,
  });

  final AsyncValue<String?> latestTripId;
  final AsyncValue<RecorderStatus> recorder;
  final bool exportInProgress;
  final ValueChanged<String> onExport;

  @override
  Widget build(BuildContext context) {
    final tripId = latestTripId.valueOrNull;
    final recorderStatus = recorder.valueOrNull;
    if (tripId == null ||
        recorderStatus == null ||
        recorderStatus.lifecycle.active) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: TraelyxSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(TraelyxSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(
                icon: Icons.lock_outline,
                color: context.traelyxColors.caution,
                title: 'Export private drive fixture',
                detail:
                    'The .tripdebug file contains the exact route and raw motion. '
                    'Save it only somewhere private.',
              ),
              const SizedBox(height: TraelyxSpacing.md),
              OutlinedButton.icon(
                key: const ValueKey('tripdebug-export-action'),
                onPressed: exportInProgress ? null : () => onExport(tripId),
                icon: exportInProgress
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  exportInProgress ? 'Verifying…' : 'Export private .tripdebug',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryDriveButton extends StatelessWidget {
  const _PrimaryDriveButton({
    required this.permissions,
    required this.recorder,
    required this.actionInProgress,
    required this.onAction,
  });

  final AsyncValue<RecorderPermissionStatus> permissions;
  final AsyncValue<RecorderStatus> recorder;
  final bool actionInProgress;
  final ValueChanged<DrivePrimaryAction> onAction;

  @override
  Widget build(BuildContext context) {
    final permissionStatus = permissions.valueOrNull;
    final recorderStatus = recorder.valueOrNull;
    final model = permissionStatus == null || recorderStatus == null
        ? null
        : DriveControlModel.from(
            permissions: permissionStatus,
            recorder: recorderStatus,
          );
    final enabled =
        model != null &&
        model.action != DrivePrimaryAction.none &&
        !actionInProgress;
    return FilledButton.icon(
      key: const ValueKey('drive-primary-action'),
      onPressed: enabled ? () => onAction(model.action) : null,
      icon: actionInProgress
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_driveIcon(model?.action ?? DrivePrimaryAction.none)),
      label: Text(
        actionInProgress ? 'Working…' : model?.actionLabel ?? 'Checking…',
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, semanticLabel: title),
        const SizedBox(width: TraelyxSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: TraelyxSpacing.xxs),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _driveIcon(DrivePrimaryAction action) => switch (action) {
  DrivePrimaryAction.requestPreciseLocation => Icons.my_location,
  DrivePrimaryAction.openAppSettings => Icons.settings_outlined,
  DrivePrimaryAction.openLocationSettings => Icons.location_off_outlined,
  DrivePrimaryAction.startTrip => Icons.route_outlined,
  DrivePrimaryAction.stopTrip => Icons.stop_circle_outlined,
  DrivePrimaryAction.none => Icons.shield_outlined,
};

Color _driveColor(BuildContext context, DrivePrimaryAction action) =>
    switch (action) {
      DrivePrimaryAction.startTrip => context.traelyxColors.positive,
      DrivePrimaryAction.stopTrip => context.traelyxColors.information,
      DrivePrimaryAction.none => context.traelyxColors.critical,
      _ => context.traelyxColors.caution,
    };
