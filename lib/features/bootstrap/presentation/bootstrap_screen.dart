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
    final permissionStatus = permissions.valueOrNull;
    final recorderStatus = recorder.valueOrNull;
    final model = permissionStatus == null || recorderStatus == null
        ? null
        : DriveControlModel.from(
            permissions: permissionStatus,
            recorder: recorderStatus,
          );

    return AnimatedSwitcher(
      duration: TraelyxMotion.effectiveDuration(
        context,
        TraelyxMotion.emphasized,
      ),
      switchInCurve: TraelyxMotion.standardCurve,
      switchOutCurve: TraelyxMotion.standardCurve,
      child: model?.isLive == true
          ? _LiveDriveView(
              key: const ValueKey('live-drive-view'),
              model: model!,
              actionInProgress: _actionInProgress,
              actionError: _actionError,
              actionSuccess: _actionSuccess,
              onEndDrive: _confirmEndDrive,
            )
          : _ReadyDriveView(
              key: const ValueKey('ready-drive-view'),
              readiness: readiness,
              permissions: permissions,
              recorder: recorder,
              model: model,
              finalization: finalization,
              latestExportTripId: latestExportTripId,
              actionInProgress: _actionInProgress,
              exportInProgress: _exportInProgress,
              actionError: _actionError,
              actionSuccess: _actionSuccess,
              onPrimaryAction: _runPrimaryAction,
              onNotificationRequest: () => _runPermissionAction(
                ref
                    .read(recorderPermissionControllerProvider)
                    .requestNotification,
              ),
              onOpenAppSettings: () => _runPermissionAction(
                ref.read(recorderPermissionControllerProvider).openAppSettings,
              ),
              onExport: _runTripDebugExport,
            ),
    );
  }

  Future<void> _confirmEndDrive() async {
    if (_actionInProgress) return;
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('end-drive-confirm-dialog'),
        icon: Icon(
          Icons.stop_circle_outlined,
          color: context.traelyxColors.caution,
        ),
        title: const Text('End this drive?'),
        content: const Text(
          'Recording continues until you confirm. Traelyx will verify and '
          'save the completed evidence to local history.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('continue-recording-action'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue recording'),
          ),
          FilledButton(
            key: const ValueKey('confirm-end-drive-action'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End and save'),
          ),
        ],
      ),
    );
    if (shouldEnd == true && mounted) {
      await _runStatusAction(
        ref.read(recorderCommandControllerProvider).stopTrip,
        successMessage: 'Drive finalized and indexed in local history.',
      );
    }
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

class _ReadyDriveView extends StatelessWidget {
  const _ReadyDriveView({
    required this.readiness,
    required this.permissions,
    required this.recorder,
    required this.model,
    required this.finalization,
    required this.latestExportTripId,
    required this.actionInProgress,
    required this.exportInProgress,
    required this.actionError,
    required this.actionSuccess,
    required this.onPrimaryAction,
    required this.onNotificationRequest,
    required this.onOpenAppSettings,
    required this.onExport,
    super.key,
  });

  final AsyncValue<BootstrapReadiness> readiness;
  final AsyncValue<RecorderPermissionStatus> permissions;
  final AsyncValue<RecorderStatus> recorder;
  final DriveControlModel? model;
  final AsyncValue<RecorderFinalizationSyncResult> finalization;
  final AsyncValue<String?> latestExportTripId;
  final bool actionInProgress;
  final bool exportInProgress;
  final String? actionError;
  final String? actionSuccess;
  final ValueChanged<DrivePrimaryAction> onPrimaryAction;
  final VoidCallback onNotificationRequest;
  final VoidCallback onOpenAppSettings;
  final ValueChanged<String> onExport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            key: const ValueKey('ready-drive-scroll'),
            padding: const EdgeInsets.fromLTRB(
              TraelyxSpacing.xl,
              TraelyxSpacing.xl,
              TraelyxSpacing.xl,
              TraelyxSpacing.section,
            ),
            children: [
              const _Wordmark(stage: 'ON-DEVICE'),
              const SizedBox(height: TraelyxSpacing.xxl),
              _ReadyHero(
                readiness: readiness,
                permissions: permissions,
                recorder: recorder,
                model: model,
              ),
              if (model != null) ...[
                const SizedBox(height: TraelyxSpacing.xl),
                _HealthGrid(
                  compact: true,
                  items: model!.health
                      .where((item) => item.kind != DriveHealthKind.storage)
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: TraelyxSpacing.xl),
              _PrimaryDriveButton(
                readiness: readiness,
                model: model,
                actionInProgress: actionInProgress,
                onAction: onPrimaryAction,
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                'No account · No telemetry upload · No background location',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (actionError != null) ...[
                const SizedBox(height: TraelyxSpacing.md),
                _ActionMessage(
                  key: const ValueKey('drive-action-error'),
                  message: actionError!,
                  tone: DriveStatusTone.critical,
                ),
              ],
              if (actionSuccess != null) ...[
                const SizedBox(height: TraelyxSpacing.md),
                _ActionMessage(
                  key: const ValueKey('drive-action-success'),
                  message: actionSuccess!,
                  tone: DriveStatusTone.positive,
                ),
              ],
              const SizedBox(height: TraelyxSpacing.xl),
              _FoundationSummary(readiness: readiness),
              _FinalizationCard(finalization: finalization),
              _NotificationCard(
                permissions: permissions,
                actionInProgress: actionInProgress,
                onRequest: onNotificationRequest,
                onOpenSettings: onOpenAppSettings,
              ),
              _TripDebugExportCard(
                latestTripId: latestExportTripId,
                recorder: recorder,
                exportInProgress: exportInProgress,
                onExport: onExport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDriveView extends StatelessWidget {
  const _LiveDriveView({
    required this.model,
    required this.actionInProgress,
    required this.actionError,
    required this.actionSuccess,
    required this.onEndDrive,
    super.key,
  });

  final DriveControlModel model;
  final bool actionInProgress;
  final String? actionError;
  final String? actionSuccess;
  final VoidCallback onEndDrive;

  @override
  Widget build(BuildContext context) {
    final health = model.health
        .where(
          (item) =>
              item.kind == DriveHealthKind.gps ||
              item.kind == DriveHealthKind.motion ||
              item.kind == DriveHealthKind.storage,
        )
        .toList(growable: false);
    final stopping = model.mode == DrivePresentationMode.stopping;
    final colors = context.traelyxColors;

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              TraelyxSpacing.xl,
              TraelyxSpacing.xl,
              TraelyxSpacing.xl,
              0,
            ),
            child: _Wordmark(stage: 'RECORDING'),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('live-drive-scroll'),
              padding: const EdgeInsets.fromLTRB(
                TraelyxSpacing.xl,
                TraelyxSpacing.xxl,
                TraelyxSpacing.xl,
                TraelyxSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      _LiveIndicator(tone: model.tone, stopping: stopping),
                      const SizedBox(height: TraelyxSpacing.xl),
                      Text(
                        model.eyebrow,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _toneColor(context, model.tone),
                              letterSpacing: 1.8,
                            ),
                      ),
                      const SizedBox(height: TraelyxSpacing.xs),
                      Text(
                        model.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: TraelyxSpacing.sm),
                      Text(
                        model.detail,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: TraelyxSpacing.xxl),
                      _HealthGrid(items: health),
                      if (model.tone == DriveStatusTone.caution ||
                          model.tone == DriveStatusTone.critical) ...[
                        const SizedBox(height: TraelyxSpacing.lg),
                        _ActionMessage(
                          message:
                              'Keep driving attention on the road. Traelyx will continue preserving available evidence locally.',
                          tone: model.tone,
                        ),
                      ],
                      if (actionError != null) ...[
                        const SizedBox(height: TraelyxSpacing.lg),
                        _ActionMessage(
                          key: const ValueKey('drive-action-error'),
                          message: actionError!,
                          tone: DriveStatusTone.critical,
                        ),
                      ],
                      if (actionSuccess != null) ...[
                        const SizedBox(height: TraelyxSpacing.lg),
                        _ActionMessage(
                          key: const ValueKey('drive-action-success'),
                          message: actionSuccess!,
                          tone: DriveStatusTone.positive,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.canvas,
              border: Border(top: BorderSide(color: colors.outline)),
            ),
            padding: const EdgeInsets.fromLTRB(
              TraelyxSpacing.xl,
              TraelyxSpacing.md,
              TraelyxSpacing.xl,
              TraelyxSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    SizedBox(
                      height: 64,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('drive-end-action'),
                        onPressed: stopping || actionInProgress
                            ? null
                            : onEndDrive,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.critical,
                          disabledForegroundColor: colors.textSecondary,
                          side: BorderSide(
                            color: stopping || actionInProgress
                                ? colors.outlineStrong
                                : colors.critical,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              TraelyxRadii.control,
                            ),
                          ),
                        ),
                        icon: actionInProgress
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : stopping
                            ? const Icon(Icons.save_outlined)
                            : const Icon(Icons.stop_circle_outlined),
                        label: Text(
                          actionInProgress || stopping
                              ? 'Saving drive…'
                              : 'End drive',
                        ),
                      ),
                    ),
                    const SizedBox(height: TraelyxSpacing.xs),
                    Text(
                      'A confirmation protects against accidental taps.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    return Row(
      children: [
        Semantics(
          label: 'Traelyx',
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
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
          stage,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _ReadyHero extends StatelessWidget {
  const _ReadyHero({
    required this.readiness,
    required this.permissions,
    required this.recorder,
    required this.model,
  });

  final AsyncValue<BootstrapReadiness> readiness;
  final AsyncValue<RecorderPermissionStatus> permissions;
  final AsyncValue<RecorderStatus> recorder;
  final DriveControlModel? model;

  @override
  Widget build(BuildContext context) {
    final coreError = permissions.hasError || recorder.hasError;
    final coreLoading = permissions.isLoading || recorder.isLoading;
    final foundationError = readiness.hasError;
    final foundationLoading = readiness.isLoading;

    if (coreError) {
      return const _HeroCopy(
        eyebrow: 'DRIVE UNAVAILABLE',
        title: 'Could not check recorder state',
        detail: 'Recording remains unavailable. Reopen Drive to retry.',
        tone: DriveStatusTone.critical,
      );
    }
    if (coreLoading || model == null) {
      return const _HeroCopy(
        eyebrow: 'CHECKING DRIVE',
        title: 'Checking recording access',
        detail: 'Traelyx checks local readiness without showing a prompt.',
        tone: DriveStatusTone.information,
      );
    }
    if ((foundationError || foundationLoading) &&
        model!.action == DrivePrimaryAction.startTrip) {
      if (foundationError) {
        return const _HeroCopy(
          eyebrow: 'DRIVE UNAVAILABLE',
          title: 'Local foundation check failed',
          detail:
              'Recording stays unavailable until local storage and the native bridge are ready.',
          tone: DriveStatusTone.critical,
        );
      }
      return const _HeroCopy(
        eyebrow: 'CHECKING DRIVE',
        title: 'Checking local foundation',
        detail: 'Opening local storage and the native recorder bridge.',
        tone: DriveStatusTone.information,
      );
    }
    return _HeroCopy(
      eyebrow: model!.eyebrow,
      title: model!.title,
      detail: model!.detail,
      tone: model!.tone,
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final DriveStatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      header: true,
      label: '$eyebrow. $title. $detail',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _toneColor(context, tone),
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: TraelyxSpacing.xs),
            Text(title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: TraelyxSpacing.sm),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.traelyxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthGrid extends StatelessWidget {
  const _HealthGrid({required this.items, this.compact = false});

  final List<DriveHealthItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (textScale > 1.3) {
      return Column(
        key: const ValueKey('drive-health-grid'),
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _HealthTile(item: items[index], compact: compact),
            if (index != items.length - 1)
              const SizedBox(height: TraelyxSpacing.sm),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        key: const ValueKey('drive-health-grid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(
              child: _HealthTile(item: items[index], compact: compact),
            ),
            if (index != items.length - 1)
              const SizedBox(width: TraelyxSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.item, required this.compact});

  final DriveHealthItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;
    return Semantics(
      container: true,
      label: '${item.label}: ${item.value}. ${item.detail}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(TraelyxSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(TraelyxRadii.card),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _healthIcon(item.kind),
                color: _toneColor(context, item.tone),
                size: 21,
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                item.label.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(letterSpacing: 0.9),
              ),
              const SizedBox(height: TraelyxSpacing.xxs),
              Text(item.value, style: Theme.of(context).textTheme.titleMedium),
              if (!compact) ...[
                const SizedBox(height: TraelyxSpacing.xxs),
                Text(item.detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.tone, required this.stopping});

  final DriveStatusTone tone;
  final bool stopping;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Semantics(
      label: stopping ? 'Saving recorded drive' : 'Recording is active',
      liveRegion: true,
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(
          stopping ? Icons.save_outlined : Icons.fiber_manual_record_rounded,
          color: color,
          size: stopping ? 42 : 48,
        ),
      ),
    );
  }
}

class _PrimaryDriveButton extends StatelessWidget {
  const _PrimaryDriveButton({
    required this.readiness,
    required this.model,
    required this.actionInProgress,
    required this.onAction,
  });

  final AsyncValue<BootstrapReadiness> readiness;
  final DriveControlModel? model;
  final bool actionInProgress;
  final ValueChanged<DrivePrimaryAction> onAction;

  @override
  Widget build(BuildContext context) {
    final action = model?.action ?? DrivePrimaryAction.none;
    final foundationReady =
        readiness.valueOrNull?.databaseReady == true &&
        (readiness.valueOrNull?.bridgeVersion ?? 0) > 0;
    final startAllowed =
        action != DrivePrimaryAction.startTrip || foundationReady;
    final enabled =
        model != null &&
        action != DrivePrimaryAction.none &&
        startAllowed &&
        !actionInProgress;
    final label = actionInProgress
        ? 'Working…'
        : action == DrivePrimaryAction.startTrip && !foundationReady
        ? readiness.hasError
              ? 'Start unavailable'
              : 'Checking local storage…'
        : model?.actionLabel ?? 'Checking…';

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: action == DrivePrimaryAction.startTrip
          ? 'Starts local GPS and motion recording'
          : null,
      onTap: enabled ? () => onAction(action) : null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 64,
          child: FilledButton.icon(
            key: const ValueKey('drive-primary-action'),
            onPressed: enabled ? () => onAction(action) : null,
            icon: actionInProgress
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_driveIcon(action)),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class _FoundationSummary extends StatelessWidget {
  const _FoundationSummary({required this.readiness});

  final AsyncValue<BootstrapReadiness> readiness;

  @override
  Widget build(BuildContext context) {
    return readiness.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => _ActionMessage(
        message:
            'Local storage or the recorder bridge could not be verified. Start remains disabled.',
        tone: DriveStatusTone.critical,
      ),
      data: (status) => Semantics(
        label:
            'On-device foundation ready. Database version 1. Native bridge version ${status.bridgeVersion}.',
        child: ExcludeSemantics(
          child: Row(
            key: const ValueKey('drive-foundation-summary'),
            children: [
              Icon(
                Icons.shield_outlined,
                size: 19,
                color: context.traelyxColors.positive,
              ),
              const SizedBox(width: TraelyxSpacing.sm),
              Expanded(
                child: Text(
                  'On-device foundation · Database v1 · Bridge v${status.bridgeVersion}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
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
    return Padding(
      padding: const EdgeInsets.only(top: TraelyxSpacing.lg),
      child: _SecondaryPanel(
        icon: Icons.notifications_outlined,
        tone: DriveStatusTone.caution,
        title: 'Keep the recording notice visible',
        detail:
            'Notification access keeps the foreground-service notice visible. Recording can still start without it.',
        action: TextButton(
          key: const ValueKey('notification-permission-action'),
          onPressed: actionInProgress
              ? null
              : canRequest
              ? onRequest
              : onOpenSettings,
          child: Text(canRequest ? 'Allow notifications' : 'Open app settings'),
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
      error: (error, stackTrace) => const Padding(
        padding: EdgeInsets.only(top: TraelyxSpacing.lg),
        child: _SecondaryPanel(
          icon: Icons.warning_amber_outlined,
          tone: DriveStatusTone.critical,
          title: 'A stopped drive needs attention',
          detail:
              'Its native evidence remains preserved, but local history indexing did not complete.',
        ),
      ),
      data: (result) {
        if (result.reconciledTripIds.isEmpty) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.only(top: TraelyxSpacing.lg),
          child: _SecondaryPanel(
            icon: Icons.inventory_2_outlined,
            tone: DriveStatusTone.positive,
            title: 'Recovered drive saved locally',
            detail:
                'Verified native chunks were indexed without uploading telemetry.',
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
      padding: const EdgeInsets.only(top: TraelyxSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOCAL TOOLS',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: TraelyxSpacing.sm),
          _SecondaryPanel(
            icon: Icons.lock_outline,
            tone: DriveStatusTone.caution,
            title: 'Export private drive fixture',
            detail:
                'The .tripdebug file contains the exact route and raw motion. Save it only somewhere private.',
            action: OutlinedButton.icon(
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
          ),
        ],
      ),
    );
  }
}

class _SecondaryPanel extends StatelessWidget {
  const _SecondaryPanel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final DriveStatusTone tone;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TraelyxSpacing.lg),
      decoration: BoxDecoration(
        color: context.traelyxColors.surface,
        borderRadius: BorderRadius.circular(TraelyxRadii.card),
        border: Border.all(color: context.traelyxColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _toneColor(context, tone), semanticLabel: title),
          const SizedBox(width: TraelyxSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: TraelyxSpacing.xxs),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                if (action != null) ...[
                  const SizedBox(height: TraelyxSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMessage extends StatelessWidget {
  const _ActionMessage({required this.message, required this.tone, super.key});

  final String message;
  final DriveStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Semantics(
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(TraelyxSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(TraelyxRadii.control),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

IconData _driveIcon(DrivePrimaryAction action) => switch (action) {
  DrivePrimaryAction.requestPreciseLocation => Icons.my_location,
  DrivePrimaryAction.openAppSettings => Icons.settings_outlined,
  DrivePrimaryAction.openLocationSettings => Icons.location_off_outlined,
  DrivePrimaryAction.startTrip => Icons.play_arrow_rounded,
  DrivePrimaryAction.stopTrip => Icons.stop_circle_outlined,
  DrivePrimaryAction.none => Icons.shield_outlined,
};

IconData _healthIcon(DriveHealthKind kind) => switch (kind) {
  DriveHealthKind.location => Icons.my_location_rounded,
  DriveHealthKind.gps => Icons.satellite_alt_outlined,
  DriveHealthKind.motion => Icons.screen_rotation_alt_outlined,
  DriveHealthKind.storage => Icons.shield_outlined,
};

Color _toneColor(BuildContext context, DriveStatusTone tone) => switch (tone) {
  DriveStatusTone.positive => context.traelyxColors.positive,
  DriveStatusTone.caution => context.traelyxColors.caution,
  DriveStatusTone.critical => context.traelyxColors.critical,
  DriveStatusTone.information => context.traelyxColors.information,
  DriveStatusTone.neutral => context.traelyxColors.textSecondary,
};
