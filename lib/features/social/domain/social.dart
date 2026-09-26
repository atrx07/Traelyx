enum SocialStatus { incoming, outgoing, friend, blocked }

enum SocialAction { accept, decline, cancel, remove, block, unblock }

class SocialException implements Exception {
  const SocialException(this.message);
  final String message;
}

class SocialPerson {
  SocialPerson(this.username, this.displayName) {
    if (!RegExp(r'^[a-z][a-z0-9_]{2,29}$').hasMatch(username) ||
        displayName.trim().isEmpty ||
        displayName.runes.length > 80) {
      throw const FormatException('Invalid social profile');
    }
  }
  final String username;
  final String displayName;
  factory SocialPerson.fromJson(Map<String, dynamic> json) {
    if (json.length != 2) {
      throw const FormatException('Unexpected public fields');
    }
    return SocialPerson(
      json['username'] as String,
      json['display_name'] as String,
    );
  }
}

class SocialEntry {
  SocialEntry(this.id, this.revision, this.person, this.status) {
    if (!RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(id) ||
        revision < 1) {
      throw const FormatException('Invalid relationship');
    }
  }
  final String id;
  final int revision;
  final SocialPerson person;
  final SocialStatus status;
  List<SocialAction> get actions => switch (status) {
    SocialStatus.incoming => [
      SocialAction.accept,
      SocialAction.decline,
      SocialAction.block,
    ],
    SocialStatus.outgoing => [SocialAction.cancel, SocialAction.block],
    SocialStatus.friend => [SocialAction.remove, SocialAction.block],
    SocialStatus.blocked => [SocialAction.unblock],
  };
  factory SocialEntry.fromJson(Map<String, dynamic> json) {
    if (json.length != 5) {
      throw const FormatException('Unexpected relationship fields');
    }
    return SocialEntry(
      json['id'] as String,
      json['revision'] as int,
      SocialPerson(json['username'] as String, json['display_name'] as String),
      SocialStatus.values.byName(json['state'] as String),
    );
  }
}

abstract interface class SocialGateway {
  Future<List<SocialEntry>> load(String owner);
  Future<SocialPerson?> lookup(String owner, String username);
  Future<void> request(String owner, SocialPerson person, String mutationId);
  Future<void> change(String owner, SocialEntry entry, SocialAction action);
}
