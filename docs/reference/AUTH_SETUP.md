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
device. This auth path does not create a `profiles` row. M6.3 adds a separate
explicit review/consent flow for private compact summaries; sign-in itself
does not invoke that flow or opt in later trips.

Physical QA must verify a fresh link, warm and cold app callback, session
restore after restart, refresh after token expiry/network interruption, and
local sign-out. Do not mark M6.2 complete from widget tests alone.

The built-in Supabase email provider has a small project-wide hourly limit
(currently two emails per hour; see the [provider rate limits](https://supabase.com/docs/guides/auth/rate-limits)).
Plan physical link tests accordingly. If Account reports temporarily limited
email requests, wait for the provider limit to recover rather than repeatedly
retrying or toggling Wi-Fi. A rate-limit response demonstrates a reachable
auth service; it is not an offline-device error.

## M6.3 hosted summary validation

Apply the versioned migrations before enabling summary QA. With an existing
signed-in debug installation, build the isolated harness using:

```powershell
flutter build apk --debug --no-pub --dart-define-from-file=auth-config.local.json --target=tool/summary_sync_hosted_qa.dart
```

Update-install with `adb install -r` and launch Traelyx. The harness uses the
encrypted on-device session and one random synthetic summary; it never opens
the local trip database. It verifies owner insert/readback, duplicate handling,
snapshot-conflict rejection, denied forged-owner writes, denied anonymous reads,
and deletion of only its own synthetic row. Require every displayed check,
including cleanup, to pass. Never log or export the session.

Restore the ordinary app afterward by rebuilding without `--target` and
update-installing with `-r`; do not uninstall or clear app data. Validate the
real review/Keep local UI separately. Uploading personal summaries requires
explicit consent in that UI. Drift schema 2 is a forward upgrade; do not
reinstall an older schema-1 build over the upgraded database.
