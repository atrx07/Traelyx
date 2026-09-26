# Optional account build setup — M6.2

Traelyx starts and all local driving features work without account build
configuration. To enable the Account screen's email-link action in an Android
build, create an untracked `auth-config.local.json` at the repository root:

```json
{
  "TRAELYX_SUPABASE_URL": "https://<project-ref>.supabase.co",
  "TRAELYX_SUPABASE_PUBLISHABLE_KEY": "<publishable-client-key>"
}
```

Use the project's **publishable** client key, never a secret/service-role key.
This file is ignored by Git. Pass it to Flutter with
`--dart-define-from-file=auth-config.local.json` when building or running.
The compiled publishable key is public client configuration, not a server
secret; never use it to bypass RLS.

In Supabase Authentication → URL Configuration, allow this exact redirect URL:

```text
io.github.atrx07.traelyx://auth-callback/
```

Keep email provider and signup enabled for link-based account creation.
The SDK handles the callback with PKCE; the session and verifier are stored
in encrypted device storage. Local trip rows and raw telemetry stay on the
device. This auth path does not create a `profiles` row or expose the M6.1
Data API tables; those belong to later authorized substeps.

Physical QA must verify a fresh link, warm and cold app callback, session
restore after restart, refresh after token expiry/network interruption, and
local sign-out. Do not mark M6.2 complete from widget tests alone.

The built-in Supabase email provider has a small project-wide hourly limit
(currently two emails per hour; see the [provider rate limits](https://supabase.com/docs/guides/auth/rate-limits)).
Plan physical link tests accordingly. If Account reports temporarily limited
email requests, wait for the provider limit to recover rather than repeatedly
retrying or toggling Wi-Fi. A rate-limit response demonstrates a reachable
auth service; it is not an offline-device error.
