import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/app/traelyx_app.dart';
import 'package:traelyx/features/bootstrap/application/bootstrap_readiness.dart';

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
        ],
        child: const TraelyxApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRAELYX'), findsOneWidget);
    expect(find.text('Your drives.\nYour evidence.'), findsOneWidget);
    expect(find.text('Local foundation ready'), findsOneWidget);
    expect(find.text('Recorder intentionally unavailable'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('No telemetry uploaded'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No telemetry uploaded'), findsOneWidget);
  });
}
