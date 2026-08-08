# Traelyx — GitHub-Native Update Strategy

## When to read

Read when implementing update notifications, release metadata, GitHub API integration, or installation guidance.

## 1. Distribution

GitHub Releases is the canonical public binary channel during the current project phase.

## 2. In-app update checker — optional MVP/post-MVP

The app may periodically check a small GitHub release endpoint/metadata for a newer stable version.

Requirements:

- never auto-install without user action;
- show current/new version;
- show release notes link/details;
- download only from canonical project release source;
- verify expected checksum/signature metadata where feasible;
- respect user setting for update checks;
- fail quietly/offline without affecting recording.

## 3. Sideload UX

Documentation should explain Android may prompt users to allow installation from the browser/file manager they use. Do not request unnecessary install-package permissions unless implementing a deliberate updater that needs them.

## 4. Release channels

Possible later channels:

- stable;
- beta;
- nightly/dev.

Do not expose ordinary users to unsigned/untrusted artifacts.
