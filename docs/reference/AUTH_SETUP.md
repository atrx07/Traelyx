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

## M6.4 profile/vehicle validation

Apply `20260926010000_profile_vehicle_sync.sql`, then
`20260926020000_metadata_account_guard.sql`, after previous migrations.
The maintainer must approve the exact public lookup grants before hosted
deployment. The narrow lookup returns only published username/display name;
owner-only mutation RPCs use expected revisions and idempotent mutation UUIDs.
Local SQL tests are `supabase/tests/profile_vehicle_sync.sql`; when adapting
them for a hosted SQL transaction, insert isolated test auth identities inside
that transaction and roll back all fixtures. Never reuse existing identities.

On a configured phone, open Account → Profile & vehicles, verify publication
is unchecked, and confirm Reload cloud works. The maintainer chooses any real
private profile/vehicle fields and confirms saves. Verify zero queued edits,
cold-start cache restoration, retained local trips/raw-file counts, and no
automatic summary upload. Public/private transitions and stale writes can be
tested with rollback-only synthetic SQL; do not publish a real test profile
without its owner's explicit choice. Schema 3 must not be downgraded.

For anonymous REST checks, PostgreSQL `42501` can map to HTTP 401; the same
privilege failure for an authenticated caller maps to 403. Check the error
code as well as HTTP status; see [PostgREST errors](https://docs.postgrest.org/en/v13/references/errors.html).

## M6.5 social validation

Apply `20260926030000_friendships.sql` after prior migrations. Validate
`supabase/tests/friendships.sql` in a transaction with isolated synthetic auth
identities; roll back every fixture. The bootstrap file is local/CI only.
Hosted deployment adds authenticated participant-only RPCs and no anonymous
social or direct-table privileges. On-device QA opens Social, confirms the
inert initial state, explicitly reloads, verifies empty/no-match states, and
preserves existing private metadata/trips. Real requests to other people need
explicit authorization; automated SQL/SDK/widget tests cover those transitions.
