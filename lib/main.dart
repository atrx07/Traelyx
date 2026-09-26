import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/app/traelyx_app.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLinks = AppLinks();
  Uri? initialLink;
  try {
    initialLink = await appLinks.getInitialLink();
  } catch (_) {
    // Missing link handling must not prevent accountless local startup.
  }
  final accountGateway = await initializeAccount();
  final router = createTraelyxRouter(
    initialLocation: initialLocationForAccountLink(
      initialLink,
      accountEnabled: accountGateway.isAvailable,
    ),
  );
  runApp(
    ProviderScope(
      overrides: [accountGatewayProvider.overrideWithValue(accountGateway)],
      child: TraelyxApp(
        router: router,
        accountLinks: accountGateway.isAvailable
            ? appLinks.uriLinkStream
            : null,
      ),
    ),
  );
}
