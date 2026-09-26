import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/app/traelyx_app.dart';
import 'package:traelyx/features/account/application/account_providers.dart';
import 'package:traelyx/features/account/application/initialize_account.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accountGateway = await initializeAccount();
  runApp(
    ProviderScope(
      overrides: [accountGatewayProvider.overrideWithValue(accountGateway)],
      child: const TraelyxApp(),
    ),
  );
}
