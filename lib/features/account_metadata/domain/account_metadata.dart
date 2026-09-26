import 'dart:math';

enum MetadataKind { profile, vehicle }

enum MetadataFailure {
  connection,
  accessDenied,
  conflict,
  invalidData,
  accountChanged,
  unavailable,
}

class MetadataException implements Exception {
  const MetadataException(this.reason);
  final MetadataFailure reason;
}

class AccountMetadata {
  AccountMetadata({
    required this.userId,
    required this.kind,
    required this.id,
    required Map<String, Object?> fields,
    this.revision = 0,
  }) : fields = Map.unmodifiable(fields) {
    if (!isUuid(userId) ||
        !isUuid(id) ||
        revision < 0 ||
        (kind == MetadataKind.profile && id != userId)) {
      throw const FormatException('Invalid metadata identity.');
    }
    final expected = kind == MetadataKind.profile
        ? {'username', 'display_name', 'visibility'}
        : {'display_name', 'vehicle_class'};
    if (fields.length != expected.length ||
        !fields.keys.every(expected.contains) ||
        !_label(fields['display_name'], 80)) {
      throw const FormatException('Invalid metadata fields.');
    }
    if (kind == MetadataKind.profile) {
      if (fields['username'] is! String ||
          !RegExp(
            r'^[a-z][a-z0-9_]{2,29}$',
          ).hasMatch(fields['username']! as String) ||
          !['private', 'public'].contains(fields['visibility'])) {
        throw const FormatException('Invalid profile.');
      }
    } else if (!vehicleClasses.contains(fields['vehicle_class'])) {
      throw const FormatException('Invalid vehicle class.');
    }
  }

  static const vehicleClasses = ['unspecified', 'car', 'motorcycle', 'other'];
  final String userId;
  final MetadataKind kind;
  final String id;
  final Map<String, Object?> fields;
  final int revision;
  String get displayName => fields['display_name']! as String;
  bool get isPublic => fields['visibility'] == 'public';

  static bool _label(Object? value, int max) =>
      value is String &&
      value.trim() == value &&
      value.isNotEmpty &&
      value.runes.length <= max &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
  static bool isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(value);

  AccountMetadata withRevision(int value) => AccountMetadata(
    userId: userId,
    kind: kind,
    id: id,
    fields: fields,
    revision: value,
  );

  bool sameFields(AccountMetadata other) =>
      userId == other.userId &&
      kind == other.kind &&
      id == other.id &&
      fields.entries.every((e) => other.fields[e.key] == e.value);

  Map<String, Object?> toJson() => {
    'version': 1,
    'user_id': userId,
    'kind': kind.name,
    'id': id,
    'revision': revision,
    'fields': fields,
  };

  factory AccountMetadata.fromJson(Map<String, Object?> json) {
    const keys = {'version', 'user_id', 'kind', 'id', 'revision', 'fields'};
    if (json.length != keys.length ||
        !json.keys.every(keys.contains) ||
        json['version'] != 1) {
      throw const FormatException('Unsupported metadata.');
    }
    return AccountMetadata(
      userId: json['user_id']! as String,
      kind: MetadataKind.values.byName(json['kind']! as String),
      id: json['id']! as String,
      revision: json['revision']! as int,
      fields: (json['fields']! as Map).cast<String, Object?>(),
    );
  }
}

class MetadataMutation {
  MetadataMutation(this.data, this.mutationId) {
    if (!AccountMetadata.isUuid(mutationId)) {
      throw const FormatException('Invalid mutation.');
    }
  }
  final AccountMetadata data;
  final String mutationId;
  Map<String, Object?> toJson() => {
    'version': 1,
    'mutation_id': mutationId,
    'data': data.toJson(),
  };
  factory MetadataMutation.fromJson(Map<String, Object?> json) {
    if (json.length != 3 ||
        json['version'] != 1 ||
        !json.keys.every({'version', 'mutation_id', 'data'}.contains)) {
      throw const FormatException('Unsupported mutation.');
    }
    return MetadataMutation(
      AccountMetadata.fromJson((json['data']! as Map).cast<String, Object?>()),
      json['mutation_id']! as String,
    );
  }
}

abstract interface class MetadataGateway {
  Future<List<AccountMetadata>> fetch(String userId);
  Future<AccountMetadata> save(MetadataMutation mutation);
}

String newMetadataUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}
