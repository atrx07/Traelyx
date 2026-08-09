typedef SettingEncoder<T> = String Function(T value);
typedef SettingDecoder<T> = T Function(String encoded);

/// A typed definition for a deliberately non-sensitive application setting.
///
/// Feature code must define settings through this type before using the
/// non-secret settings repository. Credentials, tokens, passwords, and other
/// secret material belong behind `SecureValueStore` instead.
final class NonSecretSetting<T> {
  factory NonSecretSetting({
    required String key,
    required T defaultValue,
    required SettingEncoder<T> encode,
    required SettingDecoder<T> decode,
  }) {
    _validateNonSecretKey(key);
    return NonSecretSetting._(
      key: key,
      defaultValue: defaultValue,
      encode: encode,
      decode: decode,
    );
  }

  const NonSecretSetting._({
    required this.key,
    required this.defaultValue,
    required this.encode,
    required this.decode,
  });

  final String key;
  final T defaultValue;
  final SettingEncoder<T> encode;
  final SettingDecoder<T> decode;
}

abstract final class SettingCodecs {
  static String encodeBool(bool value) => value ? 'true' : 'false';

  static bool decodeBool(String encoded) {
    return switch (encoded) {
      'true' => true,
      'false' => false,
      _ => throw FormatException('Invalid encoded boolean setting value.'),
    };
  }

  static String encodeString(String value) => value;

  static String decodeString(String encoded) => encoded;
}

final _settingKeyPattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

const _sensitiveKeySegments = {
  'api_key',
  'apikey',
  'credential',
  'credentials',
  'password',
  'private_key',
  'secret',
  'secrets',
  'token',
  'tokens',
};

void _validateNonSecretKey(String key) {
  if (!_settingKeyPattern.hasMatch(key)) {
    throw ArgumentError.value(
      key,
      'key',
      'Use a lowercase namespaced key such as appearance.reduced_motion.',
    );
  }

  final segments = key.split('.');
  if (segments.any(_containsSensitiveMarker)) {
    throw ArgumentError.value(
      key,
      'key',
      'Sensitive values cannot use NonSecretSetting.',
    );
  }
}

bool _containsSensitiveMarker(String segment) {
  return _sensitiveKeySegments.any(
    (marker) =>
        segment == marker ||
        segment.startsWith('${marker}_') ||
        segment.endsWith('_$marker') ||
        segment.contains('_${marker}_'),
  );
}
