# ADR-0009 — Release Signing Key Remains Under Maintainer Local Custody

**Status:** Accepted for early releases

## Context

Direct APK distribution relies on stable Android signing identity. CI-based signing is convenient but expands secret exposure.

## Decision

CI handles tests/build validation. Final production signing initially happens on the maintainer's trusted machine using a securely backed-up keystore not stored in the repository.

## Consequences

Positive:
- smaller signing-key exposure;
- simple threat model.

Negative:
- final release is not fully automated;
- maintainer machine/backup discipline required.
