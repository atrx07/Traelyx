# ADR-0047 — Local post-build APK signing

**Status:** Accepted for M8.7

## Context

ADR-0009 keeps production signing on the maintainer's machine. Putting a password
in key.properties or a Gradle property would expose it to persistent build state,
the Gradle daemon and a broader plugin/dependency process tree.

## Decision

An explicit Gradle property produces unsigned release APKs. Normal development/CI
release-validation builds remain debug-signed and cannot pass production-input
validation. A separate local operator checks a clean source commit and exact input
hashes, proves the pinned existing private key, and invokes Android apksigner in
short-lived JVMs. The password enters through a masked local prompt and child
environment only. It is never supplied to Gradle, file, command arguments or CI.
SDK verification, ABI/package/version/alignment checks and SHA-256 checksums are
required before recording successful production artifacts.

## Consequences

Production signing is an explicit second step; unsigned inputs and development
APKs cannot be confused with verified production artifacts. Temporary password
handling is not perfect process-memory erasure. The owner must enter the password
again for future signing. Installation/upgrade and publication remain separate
acceptance gates; successful cryptographic verification does not prove them.
