import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/features/account/domain/account_callback.dart';
import 'package:traelyx/features/account/presentation/account_screen.dart';
import 'package:traelyx/features/account_metadata/presentation/metadata_screen.dart';
import 'package:traelyx/features/bootstrap/presentation/bootstrap_screen.dart';
import 'package:traelyx/features/data_management/presentation/data_export_screen.dart';
import 'package:traelyx/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:traelyx/features/drive_dna/presentation/drive_dna_screen.dart';
import 'package:traelyx/features/navigation/presentation/app_navigation_shell.dart';
import 'package:traelyx/features/navigation/presentation/foundation_destination_screen.dart';
import 'package:traelyx/features/navigation/presentation/you_screen.dart';
import 'package:traelyx/features/rankings/ranking_screen.dart';
import 'package:traelyx/features/social/presentation/social_screen.dart';
import 'package:traelyx/features/summary_sync/presentation/summary_sync_screen.dart';
import 'package:traelyx/features/trips/presentation/trip_result_screen.dart';
import 'package:traelyx/features/trips/presentation/trips_screen.dart';

String initialLocationForAccountLink(
  Uri? uri, {
  required bool accountEnabled,
}) => accountEnabled && uri != null && isAccountCallback(uri)
    ? TraelyxRoutes.youAccount
    : TraelyxRoutes.root;

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
                builder: (context, state) => const TripsScreen(),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    builder: (context, state) => TripResultScreen(
                      tripId: state.pathParameters['tripId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.dna,
                builder: (context, state) => const DriveDnaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TraelyxRoutes.social,
                builder: (context, state) => const SocialScreen(),
                routes: [
                  GoRoute(
                    path: 'rankings',
                    builder: (context, state) => const RankingScreen(),
                  ),
                ],
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
                    path: 'account',
                    builder: (context, state) => const AccountScreen(),
                    routes: [
                      GoRoute(
                        path: 'profile',
                        builder: (context, state) => const MetadataScreen(),
                      ),
                      GoRoute(
                        path: 'summaries',
                        builder: (context, state) => const SummarySyncScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'data-export',
                    builder: (context, state) => const DataExportScreen(),
                  ),
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
