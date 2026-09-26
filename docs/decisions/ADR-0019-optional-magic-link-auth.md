# ADR-0019 — Optional email-link authentication with encrypted sessions

**Status:** Accepted for M6.2

## Context

M6.2 needs an account path without changing accountless recording or silently
syncing local trips. Supabase is already the accepted optional cloud provider.
The default `supabase_flutter` persistence uses ordinary preferences, which
do not meet Traelyx's session-storage requirement. Password sign-in would also
require a reset and verification experience before release.

## Decision

Use `supabase_flutter` 2.17.2 for email magic links and session lifecycle,
behind `AccountGateway`. Store both session JSON and PKCE code verifiers with
`flutter_secure_storage` 10.0.0, using Android Keystore-backed encryption.
Disable the plugin's reset-on-error behavior so storage faults fail visibly,
and exclude its encrypted preferences and configuration from Android backup.
The SDK accepts only Traelyx's dedicated auth callback URI.

Initialize the provider only when an HTTPS project URL and publishable client
key are supplied as build definitions. Keep the key out of Git and never put
a service-role key in the app. Opening the app, continuing locally, and using
local trip features create no cloud identity. Pressing the email-link action
may create an auth identity; it does not upload local trips. Session refresh
uses the SDK, and local sign-out clears this device's session.

## Dependency evaluation

| Dependency | Reason and license | Platform and data impact |
|---|---|---|
| `supabase_flutter` 2.17.2 | Official maintained Supabase Auth client; MIT. Replaces custom auth HTTP and session code. | Adds Auth HTTP, link handling, and several Dart/transitive packages. Network use is confined to user-requested auth and an existing session's refresh. No telemetry is sent. |
| `flutter_secure_storage` 10.0.0 | Established encrypted storage plugin; BSD-3-Clause. Needed because SDK default session/PKCE persistence uses ordinary preferences. | Adds an Android native plugin, requires API 23+, and increases APK size. Existing Flutter Android minimum is compatible. Encrypted auth files are excluded from backup. |

Both are optional to core driving and have no required paid plan. The
`AccountGateway` and `LocalStorage` boundaries keep replacement practical.
Supabase free-tier auth limits may constrain testing or later scale. APK size
and physical restore/deep-link behavior must be checked in M6.2 validation.

## Consequences

- Users can use the app without account configuration, email, or network.
- Magic-link delivery and callback depend on the hosted Auth service and
  correct redirect allowlisting; physical Android validation is required.
- No password is handled by Traelyx, so password reset is not in this method.
- Account deletion, summary migration/sync, and social access remain separate
  authorized work; this decision does not implement them.

## Revisit if

Email delivery limits, account recovery needs, or accessibility evidence
justify another method, or the secure-storage/SDK packages no longer meet
platform and privacy requirements.
