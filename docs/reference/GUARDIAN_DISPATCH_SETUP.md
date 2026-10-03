# Guardian dispatch worker — deployment boundary

## Current state

The SQL retry contract and `guardian-dispatch` Edge Function are deployed.
`supabase/functions/guardian-dispatch/` implements the server worker and
replaceable FCM HTTP v1 adapter, tested with synthetic responses and an
ephemeral signing key. Production has `GUARDIAN_DISPATCH_ENABLED=false`, a
separate 256-bit worker secret and the FCM project ID. The function's legacy
JWT gate is off only for this function; its worker-secret gate is active.
Hosted calls returned the worker's own `401 unauthorized` without that secret
and `503 dispatch_disabled` with it. No scheduler or real delivery is configured.
M6.8 remains in progress.

Google Cloud project `traelyx-e28ff` has the dedicated
`traelyx-guardian-sender` service account, granted only the custom
`Traelyx Guardian Message Sender` role with
`cloudmessaging.messages.create`. On 2026-10-03, one dedicated sender key was
installed as Supabase Edge secret `GUARDIAN_FCM_SERVICE_ACCOUNT`. The hosted
secret digest matched the exact local JSON uploaded. The ignored local key file
was deleted after verification; the key remains active in Google IAM and in
Supabase Edge secrets. No OAuth or FCM send has been attempted with it.

Creation required a separately approved, temporary project exception to the
inherited `iam.disableServiceAccountKeyCreation` policy and a temporary
organization policy administrator role. The inherited policy was restored and
verified enforced, and the temporary role was removed and verified absent. The
one-time Supabase token was limited to this project and Edge Function Secrets
Read-write, then independently verified revoked after upload. An older legacy
`traelyx-m6` token was left untouched. The first browser-downloaded key was
revoked; the final Google key inventory showed only the replacement sender key.
The hosted digest for `GUARDIAN_DISPATCH_ENABLED` matches the literal `false`.
Dispatch remains disabled pending the remaining M6.8 gates.

Earlier read-only console recheck on 2026-10-01: the legacy
`iam.disableServiceAccountKeyCreation` policy is still active and inherited;
the newer managed key-creation constraint is inactive. The dedicated sender
had no keys at that time, and no Workload Identity Pool was configured. Supabase Auth's
current signing key is asymmetric ECC P-256, but its documented OAuth server
supports authorization-code and refresh grants, not a machine
`client_credentials` grant. A dedicated, restricted worker identity would be
needed before considering Google Workload Identity Federation. No IAM,
signing-key, Edge secret or dispatch setting was changed in this recheck.

The entry point uses Supabase's existing Deno 2 runtime. The portable core uses
only built-in fetch, Web Crypto and streams; it adds no runtime package or mobile
SDK. Deno 2.9.6 is a pinned development/CI CLI fetched from its official npm
package. This does not change the hosted runtime version or app dependencies.

## Worker contract

- Only POST with an empty JSON object is accepted. A separate random 256-bit
  `x-guardian-worker-secret` is checked before parsing; neither a mobile JWT nor
  a device capability invokes dispatch. Payloads are bounded to 32 bytes and a
  one-second body deadline. No body fields select an account, target or RPC.
- The server uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` exclusively for
  the three fixed worker RPCs. Only official HTTPS Supabase project hosts are
  accepted by this adapter; other deployments need a deliberately reviewed
  adapter change. Direct table access remains denied by the deployed SQL grants.
- FCM OAuth is established before reserving attempts. Service-account project,
  issuer domain and fixed Google token endpoint must match. A narrowly scoped
  RS256 assertion is signed by Web Crypto; access tokens remain in worker memory.
- At most six claims, processed in two waves of three. No local send retry loop.
  RPC calls are bounded to five seconds; OAuth and send calls to eight seconds,
  including response bodies capped at 16 KiB. Redirects are rejected. Current
  authorization is rechecked immediately before each send. This fits within the
  SQL 120-second reservation under the specified IO limits; runtime interruption
  leaves work reclaimable by the next invocation.
- Data-only FCM payload: schema version, delivery UUID and device-generation
  UUID, plus the routing token and Android delivery options. No name, event kind,
  location, speed, trip ID or capability. High priority, remaining event TTL,
  restricted Android package and no direct-boot delivery. The receiving app must
  recheck account/generation and show only generic lock-screen copy; it is not
  implemented by this worker.
- Provider acceptance is not receipt or viewing. Invalid/unregistered targets
  are terminal; transient/configuration failures use SQL retries with bounded
  Retry-After (minimum 60 seconds). A lost provider response may cause a duplicate
  push; the receiver must deduplicate. Permission revocation cannot retract a
  request already in flight, but receipt/details remain guarded.
- Replies contain aggregate counters only. Errors are redacted; no application
  logging of keys, routing tokens, SQL bodies or alert data. Platform HTTP logs
  may still record normal request metadata.

## Deployment record and remaining gates

1. The dedicated sender account and one-permission custom role are present.
   Do not use the broadly privileged default Firebase Admin account.
2. `GUARDIAN_FCM_PROJECT_ID=traelyx-e28ff`, `GUARDIAN_WORKER_SECRET` and
   `GUARDIAN_DISPATCH_ENABLED=false` are stored as Supabase Edge secrets. The
   worker-secret digest matched the locally generated value before its ignored
   temporary file was removed. The existing service-role key is supplied only
   by the Edge environment. `GUARDIAN_FCM_SERVICE_ACCOUNT` is installed as an
   Edge secret; its hosted digest matched the uploaded JSON, and the temporary
   local JSON and scoped CLI token were removed. Never
   place a server key in the Android config, repository, chat or client build.
3. The deployed function uses `verify_jwt=false` in `supabase/config.toml` and
   in the hosted function settings **only for `guardian-dispatch`**. The
   independent worker-secret check runs before the disabled check. Hosted POST
   `{}` results: missing secret → 401 `unauthorized`; matching secret → 503
   `dispatch_disabled`. These calls made no claim, OAuth or provider request.
   Ignored screenshots: `.dart_tool/m6_8_sender_iam.png` and
   `.dart_tool/m6_8_dispatch_disabled_settings.png`.
4. The backend FCM credential gate is complete, but no live send has been
   tested. Keep the sender key in Supabase Edge secrets only. For rotation or
   revocation, identify the active key under the dedicated Google service
   account; never place a server key in the app, Git, chat or SQL history.
   Do not weaken the organization policy without separate explicit approval.
5. Only after credential, receiver/consent and synthetic delivery gates pass,
   review enabling `GUARDIAN_DISPATCH_ENABLED=true` and empty-queue checks. A
   separate reviewed scheduler may invoke it once per minute with a secret
   stored in server-side Vault; rotate the worker secret when that job is
   configured because the setup copy is removed locally. Keep the job paused
   until integration is ready. Never embed credentials in SQL history.
6. Validate synthetic end-to-end receipt, revocation, duplicate suppression,
   expiry, offline/recovery and locked-phone handling before M6.8 completion.
   No real-contact test alerts or dangerous-road tests.

The separate capability ingestion/receipt Edge function is deployed with
processing disabled. Mobile account/consent integration and recorder attachment
are still required. Six deliveries per invocation and free-tier limits bound
capacity; this is best-effort notification, not emergency protection or a
delivery guarantee.

## Local checks

```powershell
npx --yes --package=deno@2.9.6 deno fmt --check supabase/functions
npx --yes --package=deno@2.9.6 deno lint supabase/functions
npx --yes --package=deno@2.9.6 deno check supabase/functions/guardian-dispatch/index.ts
npx --yes --package=deno@2.9.6 deno test --no-prompt supabase/functions/tests/guardian_dispatch.test.mjs
```

Tests require no network, environment access or real credential. An alternate
Node 20+ runtime can run the same suite with `node --test`.

Primary protocol references:

- https://firebase.google.com/docs/cloud-messaging/send/v1-api
- https://firebase.google.com/docs/cloud-messaging/error-codes
- https://supabase.com/docs/guides/functions/auth
- https://docs.cloud.google.com/iam/docs/roles-permissions/firebasecloudmessaging
- https://docs.cloud.google.com/iam/docs/troubleshoot-org-policies
- https://developers.google.com/identity/protocols/oauth2/service-account
- https://docs.cloud.google.com/iam/docs/workload-identity-federation
- https://supabase.com/docs/guides/auth/oauth-server/oauth-flows
