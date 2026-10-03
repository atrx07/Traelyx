import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

final _guardianUuid = RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');
final _guardianCredential = RegExp(r'^[a-f0-9]{64}$');

/// Transient registration data. The routing token and credential must never be logged.
final class GuardianDeviceRegistration {
  const GuardianDeviceRegistration({
    required this.ownerId,
    required this.deviceId,
    required this.generation,
    required this.routingToken,
    required this.credential,
  });

  final String ownerId;
  final String deviceId;
  final String generation;
  final String routingToken;
  final String credential;

  void validate() {
    if (!_guardianUuid.hasMatch(ownerId) ||
        !_guardianUuid.hasMatch(deviceId) ||
        !_guardianUuid.hasMatch(generation) ||
        routingToken.length < 16 ||
        routingToken.length > 4096 ||
        routingToken.trim() != routingToken ||
        routingToken.runes.any((rune) => rune < 0x21 || rune > 0x7e) ||
        !_guardianCredential.hasMatch(credential)) {
      throw const FormatException('Invalid Guardian device registration');
    }
  }

  @override
  String toString() => 'GuardianDeviceRegistration(redacted)';
}

/// Separate from the mobile provider so account/race behavior can be tested.
abstract interface class GuardianDeviceRpcTransport {
  String? get currentOwnerId;
  Future<Object?> call(String name, Map<String, Object?> parameters);
}

final class SupabaseGuardianDeviceRpcTransport
    implements GuardianDeviceRpcTransport {
  const SupabaseGuardianDeviceRpcTransport(this.client);

  final SupabaseClient client;

  @override
  String? get currentOwnerId => client.auth.currentUser?.id;

  @override
  Future<Object?> call(String name, Map<String, Object?> parameters) =>
      client.rpc<Object?>(name, params: parameters);
}

/// Guarded server half of recipient opt-in. No caller is connected yet.
final class GuardianDeviceServerGateway {
  const GuardianDeviceServerGateway(this.transport);

  final GuardianDeviceRpcTransport transport;

  void _checkOwner(String owner) {
    if (!_guardianUuid.hasMatch(owner) || transport.currentOwnerId != owner) {
      throw const GuardianDeviceRegistrationException();
    }
  }

  Future<void> register(GuardianDeviceRegistration registration) async {
    registration.validate();
    _checkOwner(registration.ownerId);
    final Object? result;
    try {
      result = await transport
          .call('set_guardian_push_device_v1', {
            'expected_user_id': registration.ownerId,
            'device': registration.deviceId,
            'generation': registration.generation,
            'routing_token': registration.routingToken,
            'credential': registration.credential,
          })
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const GuardianDeviceRegistrationException();
    }
    _checkOwner(registration.ownerId);
    if (result != null) throw const GuardianDeviceRegistrationException();
  }

  /// Requires the same signed-in owner; local token deletion is a separate step.
  Future<void> revoke(String owner, String device, String generation) async {
    if (!_guardianUuid.hasMatch(device) ||
        !_guardianUuid.hasMatch(generation)) {
      throw const FormatException('Invalid Guardian device identity');
    }
    _checkOwner(owner);
    final Object? result;
    try {
      result = await transport
          .call('set_guardian_push_device_v1', {
            'expected_user_id': owner,
            'device': device,
            'generation': generation,
            'routing_token': null,
            'credential': null,
          })
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const GuardianDeviceRegistrationException();
    }
    _checkOwner(owner);
    if (result != null) throw const GuardianDeviceRegistrationException();
  }
}

final class GuardianDeviceRegistrationException implements Exception {
  const GuardianDeviceRegistrationException();

  @override
  String toString() => 'Guardian device registration could not be confirmed.';
}
