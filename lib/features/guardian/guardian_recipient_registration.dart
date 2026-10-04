import 'dart:math';

import 'package:flutter/services.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_device_registration.dart';
import 'package:traelyx/features/guardian/guardian_recipient_consent.dart';

final _uuid = RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');
final _credential = RegExp(r'^[a-f0-9]{64}$');

abstract interface class GuardianRecipientTokenPort {
  /// Called only after explicit consent and a durable revoke reservation.
  Future<String> acquire(String ownerId, String deviceId, String generation);
}

final class MethodChannelGuardianRecipientTokenPort
    implements GuardianRecipientTokenPort {
  const MethodChannelGuardianRecipientTokenPort();
  static const _channel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_recipient',
  );

  @override
  Future<String> acquire(
    String ownerId,
    String deviceId,
    String generation,
  ) async {
    if (!_uuid.hasMatch(ownerId) ||
        !_uuid.hasMatch(deviceId) ||
        !_uuid.hasMatch(generation)) {
      throw const FormatException('Invalid Guardian device identity');
    }
    final raw = await _channel.invokeMethod<Object?>('acquireToken', {
      'ownerId': ownerId,
      'deviceId': deviceId,
      'generation': generation,
    });
    if (raw is! String ||
        raw.length < 16 ||
        raw.length > 4096 ||
        raw.trim() != raw ||
        raw.runes.any((r) => r < 0x21 || r > 0x7e)) {
      throw const FormatException('Invalid Guardian routing token');
    }
    return raw;
  }
}

abstract interface class GuardianRecipientReceiptPort {
  Future<void> commit(
    GuardianDeviceRegistration registration,
    DateTime registeredAt,
    DateTime expiresAt,
  );
}

/// The credential crosses this channel once; native encrypts it in no-backup storage.
final class MethodChannelGuardianRecipientReceiptPort
    implements GuardianRecipientReceiptPort {
  const MethodChannelGuardianRecipientReceiptPort();
  static const _channel = MethodChannel(
    'io.github.atrx07.traelyx/guardian_recipient',
  );

  @override
  Future<void> commit(
    GuardianDeviceRegistration registration,
    DateTime registeredAt,
    DateTime expiresAt,
  ) async {
    final raw = await _channel.invokeMethod<Object?>('commit', {
      'ownerId': registration.ownerId,
      'deviceId': registration.deviceId,
      'generation': registration.generation,
      'credential': registration.credential,
      'registeredAtEpochMillis': registeredAt.millisecondsSinceEpoch,
      'expiresAtEpochMillis': expiresAt.millisecondsSinceEpoch,
    });
    if (raw is! Map ||
        raw.length != 3 ||
        raw['deviceId'] != registration.deviceId ||
        raw['generation'] != registration.generation ||
        raw['expiresAtEpochMillis'] != expiresAt.millisecondsSinceEpoch) {
      throw const FormatException('Invalid Guardian local receipt');
    }
  }
}

abstract interface class GuardianRecipientIdentitySource {
  String newUuid();
  String newCredential();
}

final class SecureGuardianRecipientIdentitySource
    implements GuardianRecipientIdentitySource {
  const SecureGuardianRecipientIdentitySource();

  @override
  String newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  String newCredential() {
    final random = Random.secure();
    return List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

final class GuardianRecipientRegistrationException implements Exception {
  const GuardianRecipientRegistrationException();
  @override
  String toString() =>
      'Guardian recipient registration could not be confirmed.';
}

/// Foreground-only registration and withdrawal; the caller owns explicit review.
final class GuardianRecipientRegistrationService {
  const GuardianRecipientRegistrationService({
    required this.account,
    required this.ownerPort,
    required this.tokenPort,
    required this.server,
    required this.receiptPort,
    this.identitySource = const SecureGuardianRecipientIdentitySource(),
    this.now = DateTime.now,
  });

  final GuardianBoundAccountGateway account;
  final GuardianOwnerPort ownerPort;
  final GuardianRecipientTokenPort tokenPort;
  final GuardianDeviceServerGateway server;
  final GuardianRecipientReceiptPort receiptPort;
  final GuardianRecipientIdentitySource identitySource;
  final DateTime Function() now;

  Future<bool> isRegistered(String owner) async {
    try {
      if (account.currentIdentity?.userId != owner ||
          !await account.ensureCurrentOwnerBound() ||
          account.currentIdentity?.userId != owner) {
        throw const GuardianRecipientRegistrationException();
      }
      return await ownerPort.recipientStatus(owner) != null;
    } catch (_) {
      throw const GuardianRecipientRegistrationException();
    }
  }

  Future<void> disable(String owner) async {
    try {
      if (account.currentIdentity?.userId != owner) {
        throw const GuardianRecipientRegistrationException();
      }
      await account.runRecipientRegistration(owner, () async {
        if (account.currentIdentity?.userId != owner) {
          throw const GuardianRecipientRegistrationException();
        }
        final status = await ownerPort.recipientStatus(owner);
        if (status == null) return;
        if (account.currentIdentity?.userId != owner) {
          throw const GuardianRecipientRegistrationException();
        }
        await server.revoke(owner, status.deviceId, status.generation);
        if (account.currentIdentity?.userId != owner) {
          throw const GuardianRecipientRegistrationException();
        }
        await ownerPort.disableConfirmedRecipient(owner, status);
        await ownerPort.bindOwner(owner);
      });
    } catch (_) {
      throw const GuardianRecipientRegistrationException();
    }
  }

  Future<void> registerAfterExplicitConsent(
    GuardianRecipientConsent consent,
  ) async {
    final owner = consent.ownerId;
    if (!consent.isFreshAt(now().toUtc()) ||
        account.currentIdentity?.userId != owner) {
      throw const GuardianRecipientRegistrationException();
    }
    try {
      await account.runRecipientRegistration(owner, () async {
        void checkOwner() {
          if (account.currentIdentity?.userId != owner) {
            throw const GuardianRecipientRegistrationException();
          }
        }

        checkOwner();
        if (await ownerPort.recipientStatus(owner) != null) {
          throw const GuardianRecipientRegistrationException();
        }
        checkOwner();
        if (!consent.isFreshAt(now().toUtc())) {
          throw const GuardianRecipientRegistrationException();
        }
        final status = GuardianRecipientLocalStatus(
          identitySource.newUuid(),
          identitySource.newUuid(),
        );
        final credential = identitySource.newCredential();
        // Validate generated identities before any persistent or network effect.
        if (!_uuid.hasMatch(status.deviceId) ||
            !_uuid.hasMatch(status.generation) ||
            status.deviceId == status.generation ||
            !_credential.hasMatch(credential)) {
          throw const GuardianRecipientRegistrationException();
        }
        await ownerPort.recordRegistrationAttempt(owner, status);
        checkOwner();
        try {
          final token = await tokenPort
              .acquire(owner, status.deviceId, status.generation)
              .timeout(const Duration(seconds: 25));
          checkOwner();
          final registration = GuardianDeviceRegistration(
            ownerId: owner,
            deviceId: status.deviceId,
            generation: status.generation,
            routingToken: token,
            credential: credential,
          );
          registration.validate();
          await server.register(registration);
          checkOwner();
          final registeredAt = now().toUtc();
          await receiptPort
              .commit(
                registration,
                registeredAt,
                registeredAt.add(const Duration(days: 29)),
              )
              .timeout(const Duration(seconds: 25));
          checkOwner();
          await ownerPort.confirmPendingRevoke(owner, status);
          checkOwner();
        } catch (_) {
          if (account.currentIdentity?.userId == owner) {
            try {
              await server.revoke(owner, status.deviceId, status.generation);
              final local = await ownerPort.recipientStatus(owner);
              if (local?.deviceId == status.deviceId &&
                  local?.generation == status.generation) {
                await ownerPort.disableConfirmedRecipient(owner, status);
              } else {
                await ownerPort.confirmPendingRevoke(owner, status);
              }
              await ownerPort.bindOwner(owner);
            } catch (_) {
              // The durable ticket or provider marker retains cleanup authority.
            }
          }
          rethrow;
        }
      });
    } catch (_) {
      throw const GuardianRecipientRegistrationException();
    }
  }
}
