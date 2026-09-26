import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/account/domain/account_gateway.dart';
import 'package:traelyx/features/account/domain/account_identity.dart';

final accountGatewayProvider = Provider<AccountGateway>(
  (ref) => const UnavailableAccountGateway(),
);

final accountIdentityProvider = StreamProvider<AccountIdentity?>((ref) async* {
  final gateway = ref.watch(accountGatewayProvider);
  yield gateway.currentIdentity;
  yield* gateway.identityChanges;
});
