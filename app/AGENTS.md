# app/AGENTS.md — Traelyx Flutter/Application Scope

Applies to files under `app/`.

## Read selectively

For UI-only work, read the relevant section of `docs/product/UX_SPEC.md` and feature spec. Do not automatically read ML, signing, Android tracking, or unrelated backend specifications.

## Ownership

Flutter/application code owns presentation, navigation, application state, replay UI, profiles/social UI, settings, cloud orchestration, and portable domain logic that is not platform acquisition.

## Rules

- Keep business/scoring logic out of widgets.
- Important state must be testable without rendering a full UI.
- Prefer immutable/domain models and explicit state transitions.
- Keep animation declarative and interruptible where practical.
- Respect reduced-motion/accessibility settings.
- Drive-mode controls must remain large, minimal, and non-distracting.
- Do not require account/login for local trip functionality.
- Do not bypass native recorder responsibilities by adding fragile background hacks in Flutter.
- Never expose API keys in logs/state dumps.
- Provider settings must use secure credential storage.
- Any important score/indicator should have an explanation affordance.
- Avoid visual imitation of competitor apps.

## Minimum checks

- format/analyze;
- relevant unit/widget tests;
- golden/screenshot tests where visual regression matters;
- navigation/deep-link tests when routes change;
- reduced-motion behavior for major animation features.
