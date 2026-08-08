import 'package:go_router/go_router.dart';
import 'package:traelyx/features/bootstrap/presentation/bootstrap_screen.dart';

final traelyxRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const BootstrapScreen()),
  ],
);
