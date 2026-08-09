import 'package:flutter/material.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class FoundationDestinationScreen extends StatelessWidget {
  const FoundationDestinationScreen({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.traelyxColors;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(TraelyxSpacing.xl),
            children: [
              const SizedBox(height: TraelyxSpacing.section),
              Icon(icon, color: colors.accent, size: 36),
              const SizedBox(height: TraelyxSpacing.xl),
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.accent,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: TraelyxSpacing.sm),
              Text(
                title,
                key: ValueKey('destination-$title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: TraelyxSpacing.md),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: TraelyxSpacing.xxl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(TraelyxSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.construction_outlined,
                        color: colors.caution,
                        semanticLabel: 'Foundation only',
                      ),
                      const SizedBox(width: TraelyxSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Foundation only',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: TraelyxSpacing.xxs),
                            Text(
                              'This destination is routable, but its product '
                              'features are not implemented yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
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
