import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/features/bootstrap/presentation/bootstrap_screen.dart';
import 'package:traelyx/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:traelyx/features/navigation/presentation/app_navigation_shell.dart';
import 'package:traelyx/features/navigation/presentation/foundation_destination_screen.dart';
import 'package:traelyx/features/navigation/presentation/you_screen.dart';

GoRouter createTraelyxRouter({String initialLocation = TraelyxRoutes.root}) {
  return GoRouter(
    initialLocation: initialLocation,
    errorBuilder: (context, state) => FoundationDestinationScreen(
      icon: Icons.wrong_location_outlined,
      eyebrow: 'ROUTE UNAVAILABLE',
      title: 'Page not found',
      description:
          'Traelyx could not open ${state.uri.path}. Return to Drive to '
          'continue locally.',
    ),
    routes: [
      GoRoute(
        path: TraelyxRoutes.root,
        redirect: (context, state) => TraelyxRoutes.drive,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.drive,
                builder: (context, state) =>
                    const BootstrapScreen(key: ValueKey('bootstrap-drive')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.trips,
                builder: (context, state) => const FoundationDestinationScreen(
                  icon: Icons.route_outlined,
                  eyebrow: 'LOCAL HISTORY',
                  title: 'Trips',
                  description:
                      'Recorded drives and their details will live here. '
                      'Local history will not require a cloud account.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.dna,
                builder: (context, state) => const FoundationDestinationScreen(
                  icon: Icons.hub_outlined,
                  eyebrow: 'LONG-TERM PATTERNS',
                  title: 'DNA',
                  description:
                      'Auditable driving patterns and trends will appear here '
                      'after the telemetry and scoring foundations exist.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.social,
                builder: (context, state) => const FoundationDestinationScreen(
                  icon: Icons.people_alt_outlined,
                  eyebrow: 'OPTIONAL CONNECTIONS',
                  title: 'Social',
                  description:
                      'Friends, safe rankings, and Guardian features will stay '
                      'optional. Core driving features remain local-first.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.you,
                builder: (context, state) => const YouScreen(),
                routes: [
                  GoRoute(
                    path: 'diagnostics',
                    builder: (context, state) => const DiagnosticsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final traelyxRouter = createTraelyxRouter();
