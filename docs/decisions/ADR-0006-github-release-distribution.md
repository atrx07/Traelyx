# ADR-0006 — GitHub Releases, No Store Dependency

**Status:** Accepted for current project phase

## Context

The maintainer does not intend to pay Play Store/App Store fees during the current student/open-source phase.

## Decision

Distribute signed Android APKs through GitHub Releases. A dedicated landing page may be a separate future project. App-store-specific features/policies are not MVP constraints unless Android platform rules independently require them.

## Consequences

Positive:
- ₹0 distribution;
- direct geek/open-source audience;
- full release control.

Negative:
- sideload friction;
- updates are not store-managed;
- users must trust signing/checksums/repository.
