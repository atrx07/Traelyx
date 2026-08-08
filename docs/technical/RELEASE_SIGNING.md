# Traelyx — Android Builds, Signing & GitHub Releases

## When to read

Read for release builds, APK signing, keystore handling, GitHub publishing, versioning, checksums, or upgrade-install tests.

Do not read for ordinary UI/backend work or normal debug builds.

## 1. Debug builds

Development builds can use Android's debug signing identity. Agents may run debug builds and install via ADB on emulator/attached device.

Typical conceptual loop:

```text
flutter analyze
flutter test
flutter build apk --debug
adb install -r <debug-apk>
```

Exact commands are updated once repository paths/tool versions are established.

## 2. Release signing identity

The maintainer creates and controls the production release keystore/private key.

The same signing identity is required for Android to accept future APKs as updates to an installed app.

Losing the key can force users to uninstall/reinstall rather than seamlessly upgrade. Therefore maintain secure backups.

## 3. Secret files

Example local-only files:

```text
<secure location>/traelyx-release.jks
android/key.properties
```

Repository ignore/secret scanning must reject:

```text
*.jks
*.keystore
key.properties
```

Do not commit secrets even while the repository is private.

## 4. Agent authority

An agent may:

- configure Gradle to read signing configuration from local secret paths/environment;
- build release APK when credentials are already available in the trusted local environment;
- verify signature;
- run install/upgrade tests.

An agent must **not**:

- upload signing key to repository;
- rotate/replace the release key;
- print passwords;
- move the key into project directory for convenience;
- publish a release under a different key without explicit maintainer instruction.

## 5. Initial signing strategy

Preferred during early open-source phase:

```text
GitHub CI
  ├─ analyze/tests
  ├─ build validation
  └─ optional unsigned/debug artifacts

Trusted maintainer machine
  ├─ clean checkout/tag
  ├─ full tests
  ├─ signed release build
  ├─ signature verification
  ├─ clean install test
  ├─ upgrade install test
  └─ upload signed APK + checksum to GitHub Release
```

CI signing may be reconsidered later with a documented secret-management threat model.

## 6. ABI packaging

Because distribution is GitHub-based, consider ABI-specific release APKs to avoid a large universal APK, especially arm64-v8a as primary modern-device target. Support matrix must be decided through actual target audience/device compatibility.

## 7. Verification

Use Android tooling such as `apksigner verify --verbose` as part of release checklist.

Generate SHA-256 checksums for release artifacts.

## 8. Upgrade test

Before publishing:

1. install previous public release;
2. create representative local trips/settings;
3. install new signed APK over it;
4. verify Android accepts update;
5. verify DB migration;
6. verify trips/settings/accounts remain valid;
7. verify recorder still works.

## 9. Release contents

Recommended:

- versioned signed APK(s), for example:
  - `traelyx-v0.1.0-arm64-v8a.apk`;
  - `traelyx-v0.1.0-armeabi-v7a.apk`;
  - `traelyx-v0.1.0-x86_64.apk`;
- `SHA256SUMS.txt`;
- release notes;
- migration/known issues;
- model/scoring version changes;
- privacy-impact notes if relevant.
