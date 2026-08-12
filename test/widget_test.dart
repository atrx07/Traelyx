import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/app/traelyx_app.dart';
import 'package:traelyx/core/platform/recorder_bridge.dart';
import 'package:traelyx/core/platform/recorder_finalization.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';

import 'core/platform/recorder_bridge_test.dart'
    show permissionStatusMap, statusMap;

void main() {
  testWidgets('bootstrap shell states recorder limitations clearly', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapReadinessProvider.overrideWith(
            (ref) async => const BootstrapReadiness(
              databaseReady: true,
              bridgeVersion: 1,
              recorderState: 'skeleton',
              recordingAvailable: false,
            ),
          ),
          recorderPermissionStatusProvider.overrideWith(
            (ref) async =>
                RecorderPermissionStatus.fromMap(permissionStatusMap),
          ),
          recorderStatusProvider.overrideWith(
            (ref) async => RecorderStatus.fromMap(statusMap),
          ),
          recorderFinalizationSyncProvider.overrideWith(
            (ref) async => const RecorderFinalizationSyncResult(
              reconciledTripIds: [],
              invalidNativeRecordCount: 0,
            ),
          ),
          latestTripDebugExportTripIdProvider.overrideWith((ref) async => null),
        ],
        child: const TraelyxApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRAELYX'), findsOneWidget);
    expect(find.text('Your drives.\nYour evidence.'), findsOneWidget);
    expect(find.text('Local foundation ready'), findsOneWidget);
    expect(find.text('Drive recording is active'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('No telemetry uploaded'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No telemetry uploaded'), findsOneWidget);
  });
}
