import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  static const _railBreakpoint = 720.0;

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveIsActive =
        navigationShell.currentIndex == 0 &&
        (ref.watch(recorderStatusProvider).valueOrNull?.lifecycle.active ??
            false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;

        return Scaffold(
          body: useRail && !driveIsActive
              ? Row(
                  children: [
                    SafeArea(
                      right: false,
                      child: NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: _selectDestination,
                        labelType: NavigationRailLabelType.all,
                        groupAlignment: -0.7,
                        leading: Padding(
                          padding: const EdgeInsets.only(
                            top: TraelyxSpacing.md,
                            bottom: TraelyxSpacing.xl,
                          ),
                          child: _BrandMark(
                            color: context.traelyxColors.accent,
                          ),
                        ),
                        destinations: _destinations
                            .map(
                              (destination) => NavigationRailDestination(
                                icon: Icon(destination.icon),
                                selectedIcon: Icon(destination.selectedIcon),
                                label: Text(destination.label),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: context.traelyxColors.outline,
                    ),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: useRail || driveIsActive
              ? null
              : SafeArea(
                  top: false,
                  child: NavigationBar(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: _selectDestination,
                    destinations: _destinations
                        .map(
                          (destination) => NavigationDestination(
                            key: ValueKey(destination.key),
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: destination.label,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Traelyx',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(
          Icons.route_rounded,
          color: context.traelyxColors.onAccent,
          size: 19,
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination(
    key: 'navigation-drive',
    label: 'Drive',
    icon: Icons.play_circle_outline_rounded,
    selectedIcon: Icons.play_circle_fill_rounded,
  ),
  _Destination(
    key: 'navigation-trips',
    label: 'Trips',
    icon: Icons.route_outlined,
    selectedIcon: Icons.route_rounded,
  ),
  _Destination(
    key: 'navigation-dna',
    label: 'DNA',
    icon: Icons.hub_outlined,
    selectedIcon: Icons.hub_rounded,
  ),
  _Destination(
    key: 'navigation-social',
    label: 'Social',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
  ),
  _Destination(
    key: 'navigation-you',
    label: 'You',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];
