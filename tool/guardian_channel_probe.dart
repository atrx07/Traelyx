// Physical M6.8 bridge probe. Build as an alternate Flutter entrypoint only
// after confirming no production Guardian vault/lease exists on the device.
// The Dart probe makes no Supabase RPC or FCM registration/send call.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traelyx/features/guardian/guardian_account_binding.dart';
import 'package:traelyx/features/guardian/guardian_driver_activation.dart';

const _channel = MethodChannel('io.github.atrx07.traelyx/guardian_activation');

String _syntheticOwner() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final owner = _syntheticOwner();
  const binding = MethodChannelGuardianOwnerPort();
  const native = MethodChannelGuardianActivationPort();
  GuardianActivationDraft? draft;
  var passed = false;
  try {
    await binding.bindOwner(owner);
    draft = await native.begin(owner, '+y');
    final status = await _channel.invokeMethod<Object?>('snapshot', {
      'ownerId': owner,
    });
    if (status is! Map ||
        status.length != 2 ||
        status['localLeasePresent'] != false ||
        status['expiresEpochMillis'] != null) {
      throw const FormatException('Guardian status not inactive');
    }
    await native.abort(owner, draft.activationId);
    draft = null;

    // A synthetic confirmation tests the production commit wire without a
    // server session. No recorder or dispatch path consumes this short lease.
    draft = await native.begin(owner, '+y');
    final syntheticExpiry = DateTime.now().toUtc().add(
      const Duration(minutes: 5),
    );
    final localExpiry = await native.commit(
      owner,
      draft.activationId,
      syntheticExpiry,
    );
    draft = null;
    final active = await _channel.invokeMethod<Object?>('snapshot', {
      'ownerId': owner,
    });
    if (active is! Map ||
        active.length != 2 ||
        active['localLeasePresent'] != true ||
        active['expiresEpochMillis'] != localExpiry.millisecondsSinceEpoch) {
      throw const FormatException('Guardian synthetic lease not present');
    }
    await native.disable(owner);
    final disabled = await _channel.invokeMethod<Object?>('snapshot', {
      'ownerId': owner,
    });
    if (disabled is! Map ||
        disabled.length != 2 ||
        disabled['localLeasePresent'] != false ||
        disabled['expiresEpochMillis'] != null) {
      throw const FormatException('Guardian synthetic lease not removed');
    }
    passed = true;
  } catch (_) {
    // A generic result only: never print the proposal or platform arguments.
  } finally {
    if (draft != null) {
      try {
        await native.abort(owner, draft.activationId);
      } catch (_) {
        passed = false;
      }
    }
    try {
      await native.disable(owner);
    } catch (_) {
      passed = false;
    }
    try {
      await binding.bindOwner(null);
    } catch (_) {
      passed = false;
    }
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            passed
                ? 'GUARDIAN CHANNEL PROBE PASSED'
                : 'GUARDIAN CHANNEL PROBE FAILED',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    ),
  );
}
