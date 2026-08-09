import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

void main() {
  group('TraelyxTheme', () {
    test('exposes dark-first semantic colors through ThemeData', () {
      final theme = TraelyxTheme.dark;
      final colors = theme.extension<TraelyxSemanticColors>();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, TraelyxSemanticColors.dark.canvas);
      expect(colors, isNotNull);
      expect(theme.colorScheme.primary, colors!.accent);
      expect(theme.colorScheme.error, colors.critical);
      expect(theme.colorScheme.outline, colors.outlineStrong);
    });

    test('keeps essential foreground colors at accessible contrast', () {
      const colors = TraelyxSemanticColors.dark;

      expect(_contrast(colors.textPrimary, colors.canvas), greaterThan(7));
      expect(_contrast(colors.textSecondary, colors.canvas), greaterThan(4.5));
      expect(_contrast(colors.accent, colors.canvas), greaterThan(4.5));
      expect(_contrast(colors.positive, colors.canvas), greaterThan(4.5));
      expect(_contrast(colors.caution, colors.canvas), greaterThan(4.5));
      expect(_contrast(colors.critical, colors.canvas), greaterThan(4.5));
      expect(_contrast(colors.information, colors.canvas), greaterThan(4.5));
      expect(_contrast(colors.onAccent, colors.accent), greaterThan(4.5));
    });

    test('provides glanceable tabular numeric styles and padded controls', () {
      final theme = TraelyxTheme.dark;
      final displayStyle = theme.textTheme.displayLarge!;
      final minimumButtonSize = theme.filledButtonTheme.style!.minimumSize!
          .resolve(<WidgetState>{})!;

      expect(displayStyle.fontSize, 56);
      expect(displayStyle.fontFeatures, isNotEmpty);
      expect(minimumButtonSize.height, 56);
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    testWidgets('removes user-visible motion when animations are disabled', (
      tester,
    ) async {
      Duration? resolved;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolved = TraelyxMotion.effectiveDuration(
                context,
                TraelyxMotion.standard,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, Duration.zero);
    });
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final high = lighter > darker ? lighter : darker;
  final low = lighter > darker ? darker : lighter;
  return (high + 0.05) / (low + 0.05);
}
