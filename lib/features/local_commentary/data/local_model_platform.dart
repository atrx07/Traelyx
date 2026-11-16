import 'package:flutter/services.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

class LocalModelPlatform {
  const LocalModelPlatform();
  static const channel = MethodChannel(
    'io.github.atrx07.traelyx/local_commentary/v1',
  );
  Future<LocalDevice> device() async {
    try {
      final value = await channel.invokeMapMethod<String, Object?>('device');
      if (value == null ||
          value.length != 5 ||
          value['version'] is! int ||
          value['version'] != 1 ||
          value['root'] is! String ||
          (value['root'] as String).isEmpty ||
          value['api'] is! int ||
          (value['api'] as int) < 26 ||
          value['abis'] is! List ||
          (value['abis'] as List).isEmpty ||
          (value['abis'] as List).any((v) => v is! String) ||
          value['freeBytes'] is! int ||
          (value['freeBytes'] as int) < 0) {
        throw const FormatException();
      }
      return LocalDevice(
        root: value['root']! as String,
        androidApi: value['api']! as int,
        abis: (value['abis']! as List).cast<String>(),
        freeBytes: value['freeBytes']! as int,
      );
    } catch (_) {
      throw const LocalCommentaryException(LocalFailure.storage);
    }
  }
}
