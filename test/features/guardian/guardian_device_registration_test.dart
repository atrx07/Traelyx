import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const otherOwner = '22222222-2222-4222-8222-222222222222';
const device = '33333333-3333-4333-8333-333333333333';
const generation = '44444444-4444-4444-8444-444444444444';
const token = 'synthetic-routing-token-123456';
const credential =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

GuardianDeviceRegistration draft({
  String ownerId = owner,
  String deviceId = device,
  String deviceGeneration = generation,
  String routingToken = token,
  String deviceCredential = credential,
}) => GuardianDeviceRegistration(
  ownerId: ownerId,
  deviceId: deviceId,
  generation: deviceGeneration,
  routingToken: routingToken,
  credential: deviceCredential,
);

final class FakeTransport implements GuardianDeviceRpcTransport {
  String? ownerId = owner;
  final calls = <(String, Map<String, Object?>)>[];
  Future<Object?> Function()? reply;

  @override
  String? get currentOwnerId => ownerId;

  @override
  Future<Object?> call(String name, Map<String, Object?> parameters) async {
    calls.add((name, parameters));
    return await reply?.call();
  }
}

void main() {
  test('registration sends only the guarded server contract', () async {
    final transport = FakeTransport();
    final registration = draft();
    await GuardianDeviceServerGateway(transport).register(registration);
    expect(transport.calls, hasLength(1));
    expect(transport.calls.single.$1, 'set_guardian_push_device_v1');
    expect(transport.calls.single.$2, <String, Object?>{
      'expected_user_id': owner,
      'device': device,
      'generation': generation,
      'routing_token': token,
      'credential': credential,
    });
    expect(registration.toString(), isNot(contains(token)));
    expect(registration.toString(), isNot(contains(credential)));
  });

  test('malformed data and wrong owner never reach the server', () async {
    final transport = FakeTransport();
    final gateway = GuardianDeviceServerGateway(transport);
    for (final invalid in [
      draft(ownerId: 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA'),
      draft(deviceId: 'not-a-device'),
      draft(deviceGeneration: 'not-a-generation'),
      draft(routingToken: 'short'),
      draft(routingToken: '$token\n'),
      draft(routingToken: 'a' * 4097),
      draft(deviceCredential: 'A' * 64),
    ]) {
      await expectLater(gateway.register(invalid), throwsFormatException);
    }
    transport.ownerId = otherOwner;
    await expectLater(
      gateway.register(draft()),
      throwsA(isA<GuardianDeviceRegistrationException>()),
    );
    expect(transport.calls, isEmpty);
  });

  test(
    'account change during server response cannot confirm registration',
    () async {
      final transport = FakeTransport();
      final reply = Completer<Object?>();
      transport.reply = () => reply.future;
      final pending = GuardianDeviceServerGateway(transport).register(draft());
      await Future<void>.delayed(Duration.zero);
      transport.ownerId = otherOwner;
      reply.complete(null);
      await expectLater(
        pending,
        throwsA(isA<GuardianDeviceRegistrationException>()),
      );
    },
  );

  test('revoke targets only the device and sends no routing secret', () async {
    final transport = FakeTransport();
    final gateway = GuardianDeviceServerGateway(transport);
    await gateway.revoke(owner, device, generation);
    expect(transport.calls, hasLength(1));
    expect(transport.calls.single.$1, 'set_guardian_push_device_v1');
    expect(transport.calls.single.$2, <String, Object?>{
      'expected_user_id': owner,
      'device': device,
      'generation': generation,
      'routing_token': null,
      'credential': null,
    });
    transport.ownerId = otherOwner;
    await expectLater(
      gateway.revoke(owner, device, generation),
      throwsA(isA<GuardianDeviceRegistrationException>()),
    );
    expect(transport.calls.length, 1);
  });

  test('unexpected server body cannot be mistaken for confirmation', () async {
    final transport = FakeTransport()..reply = () async => {'accepted': true};
    await expectLater(
      GuardianDeviceServerGateway(transport).register(draft()),
      throwsA(isA<GuardianDeviceRegistrationException>()),
    );
  });

  test('transport errors do not expose routing secrets', () async {
    final transport = FakeTransport()
      ..reply = () async => throw StateError('private $token $credential');
    try {
      await GuardianDeviceServerGateway(transport).register(draft());
      fail('Expected registration failure');
    } on GuardianDeviceRegistrationException catch (error) {
      expect(error.toString(), isNot(contains(token)));
      expect(error.toString(), isNot(contains(credential)));
    }
  });
}
