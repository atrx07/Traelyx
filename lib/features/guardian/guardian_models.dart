const guardianPermissionNames = [
  'crash_alert',
  'severe_drive_alert',
  'current_safety_state',
  'live_location',
  'current_speed',
  'trip_history',
];

class GuardianPermissions {
  const GuardianPermissions({
    this.crash = true,
    this.severe = false,
    this.state = false,
  });
  final bool crash, severe, state;
  Map<String, bool> toJson() => {
    'crash_alert': crash,
    'severe_drive_alert': severe,
    'current_safety_state': state,
    'live_location': false,
    'current_speed': false,
    'trip_history': false,
  };
  factory GuardianPermissions.fromJson(Object? raw) {
    final j = guardianObject(raw, guardianPermissionNames);
    if (j.values.any((v) => v is! bool) ||
        j['live_location'] != false ||
        j['current_speed'] != false ||
        j['trip_history'] != false) {
      throw const FormatException('Unsupported Guardian permissions');
    }
    return GuardianPermissions(
      crash: j['crash_alert'] as bool,
      severe: j['severe_drive_alert'] as bool,
      state: j['current_safety_state'] as bool,
    );
  }
  String get summary =>
      'Possible-crash alerts: ${crash ? "on" : "off"}; '
      'severe-drive alerts: ${severe ? "on" : "off"}; '
      'coarse safety state: ${state ? "on" : "off"}. '
      'Location, speed and trip history: off. Delivery is not available yet.';
}

Map<String, dynamic> guardianObject(Object? raw, List<String> keys) {
  if (raw is! Map ||
      raw.length != keys.length ||
      !raw.keys.every(keys.contains)) {
    throw const FormatException('Unexpected Guardian response');
  }
  return raw.cast<String, dynamic>();
}

String guardianId(Object? v) {
  if (v is! String ||
      !RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$').hasMatch(v)) {
    throw const FormatException('Invalid Guardian identifier');
  }
  return v;
}

String guardianUsername(Object? v) {
  if (v is! String || !RegExp(r'^[a-z][a-z0-9_]{2,29}$').hasMatch(v)) {
    throw const FormatException('Invalid Guardian username');
  }
  return v;
}

String guardianLabel(Object? v) {
  if (v is! String || v.trim() != v || v.isEmpty || v.length > 80) {
    throw const FormatException('Invalid Guardian label');
  }
  return v;
}

DateTime guardianTime(Object? v) {
  if (v is! String) throw const FormatException('Invalid Guardian date');
  return DateTime.parse(v);
}

class GuardianInvite {
  const GuardianInvite(this.id, this.expiresAt, this.permissions, {this.token});
  final String id;
  final DateTime expiresAt;
  final GuardianPermissions permissions;
  // Only the one-time create response includes a code. Never persisted.
  final String? token;
  factory GuardianInvite.fromJson(Object? raw, {bool issued = false}) {
    final j = guardianObject(raw, [
      'id',
      'expires_at',
      'permissions',
      if (issued) 'token',
    ]);
    final token = j['token'];
    if (issued && (token is! String || !validGuardianToken(token))) {
      throw const FormatException('Invalid Guardian code');
    }
    return GuardianInvite(
      guardianId(j['id']),
      guardianTime(j['expires_at']),
      GuardianPermissions.fromJson(j['permissions']),
      token: token as String?,
    );
  }
}

bool validGuardianToken(String value) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

class GuardianPreview {
  const GuardianPreview(
    this.invite,
    this.username,
    this.displayName,
    this.ownUsername,
    this.ownDisplayName,
  );
  final GuardianInvite invite;
  final String username, displayName, ownUsername, ownDisplayName;
  factory GuardianPreview.fromJson(Object? raw) {
    final j = guardianObject(raw, [
      'id',
      'username',
      'display_name',
      'expires_at',
      'permissions',
      'own_username',
      'own_display_name',
    ]);
    return GuardianPreview(
      GuardianInvite.fromJson({
        for (final k in ['id', 'expires_at', 'permissions']) k: j[k],
      }),
      guardianUsername(j['username']),
      guardianLabel(j['display_name']),
      guardianUsername(j['own_username']),
      guardianLabel(j['own_display_name']),
    );
  }
}

enum GuardianAction { confirm, disconnect, block, unblock, permissions }

class GuardianHistory {
  const GuardianHistory(this.action, this.actor, this.permissions, this.at);
  final String action, actor;
  final GuardianPermissions permissions;
  final DateTime at;
  factory GuardianHistory.fromJson(Object? raw) {
    final j = guardianObject(raw, ['action', 'actor', 'permissions', 'at']);
    if (![
          'accept_pending',
          ...GuardianAction.values.map((a) => a.name),
        ].contains(j['action']) ||
        !['driver', 'guardian'].contains(j['actor'])) {
      throw const FormatException('Invalid history');
    }
    return GuardianHistory(
      j['action'] as String,
      j['actor'] as String,
      GuardianPermissions.fromJson(j['permissions']),
      guardianTime(j['at']),
    );
  }
}

class GuardianConnection {
  const GuardianConnection(
    this.id,
    this.revision,
    this.role,
    this.username,
    this.displayName,
    this.status,
    this.permissions,
    this.updatedAt,
    this.history,
  );
  final String id, role, username, displayName, status;
  final int revision;
  final GuardianPermissions permissions;
  final DateTime updatedAt;
  final List<GuardianHistory> history;
  List<GuardianAction> get actions => [
    if (status == 'confirm' && role == 'driver') GuardianAction.confirm,
    if (status == 'active' && role == 'driver') GuardianAction.permissions,
    if (status == 'active' || status == 'confirm' || status == 'waiting')
      GuardianAction.disconnect,
    if (status == 'blocked') GuardianAction.unblock else GuardianAction.block,
  ];
  factory GuardianConnection.fromJson(Object? raw) {
    final j = guardianObject(raw, [
      'id',
      'revision',
      'role',
      'username',
      'display_name',
      'state',
      'permissions',
      'updated_at',
      'history',
    ]);
    if (j['revision'] is! int ||
        (j['revision'] as int) < 1 ||
        !['driver', 'guardian'].contains(j['role']) ||
        ![
          'active',
          'confirm',
          'waiting',
          'closed',
          'blocked',
        ].contains(j['state']) ||
        (j['state'] == 'confirm' && j['role'] != 'driver') ||
        (j['state'] == 'waiting' && j['role'] != 'guardian') ||
        j['history'] is! List ||
        (j['history'] as List).length > 20) {
      throw const FormatException('Invalid Guardian connection');
    }
    return GuardianConnection(
      guardianId(j['id']),
      j['revision'] as int,
      j['role'] as String,
      guardianUsername(j['username']),
      guardianLabel(j['display_name']),
      j['state'] as String,
      GuardianPermissions.fromJson(j['permissions']),
      guardianTime(j['updated_at']),
      List.unmodifiable((j['history'] as List).map(GuardianHistory.fromJson)),
    );
  }
}

class GuardianSnapshot {
  const GuardianSnapshot({
    this.username,
    this.displayName,
    this.invite,
    this.connections = const [],
  });
  final String? username, displayName;
  final GuardianInvite? invite;
  final List<GuardianConnection> connections;
  factory GuardianSnapshot.fromJson(Object? raw) {
    final j = guardianObject(raw, ['profile', 'invite', 'connections']);
    final profile = j['profile'] == null
        ? null
        : guardianObject(j['profile'], ['username', 'display_name']);
    final rows = (j['connections'] as List)
        .map(GuardianConnection.fromJson)
        .toList();
    if (rows.length > 100 ||
        rows.map((r) => r.id).toSet().length != rows.length) {
      throw const FormatException('Invalid connections');
    }
    return GuardianSnapshot(
      username: profile == null ? null : guardianUsername(profile['username']),
      displayName: profile == null
          ? null
          : guardianLabel(profile['display_name']),
      invite: j['invite'] == null ? null : GuardianInvite.fromJson(j['invite']),
      connections: List.unmodifiable(rows),
    );
  }
}

abstract interface class GuardianGateway {
  Future<GuardianSnapshot> load(String owner);
  Future<GuardianInvite> create(
    String owner,
    String username,
    String displayName,
    GuardianPermissions permissions,
  );
  Future<void> cancel(String owner, String inviteId);
  Future<GuardianPreview?> preview(String owner, String token);
  Future<void> accept(String owner, GuardianPreview preview, String token);
  Future<void> change(
    String owner,
    GuardianConnection connection,
    GuardianAction action, {
    GuardianPermissions? permissions,
  });
}

class GuardianException implements Exception {
  const GuardianException(this.message);
  final String message;
}
