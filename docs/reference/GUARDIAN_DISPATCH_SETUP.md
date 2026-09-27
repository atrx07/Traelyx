# Guardian dispatch worker — deployment boundary

## Current state

The SQL retry contract is deployed. `supabase/functions/guardian-dispatch/`
implements the server worker and replaceable FCM HTTP v1 adapter, tested with
synthetic responses and an ephemeral signing key. The Edge Function is **not
deployed**, has no sender credentials, and is disabled unless explicitly enabled.
No scheduler or real delivery is configured. M6.8 remains in progress.

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

## Required deployment review (not performed)

1. Create a dedicated sender service account in Firebase project
   `traelyx-e28ff`: `traelyx-guardian-sender`, with a custom project role containing
   only `cloudmessaging.messages.create`. Do not use a broadly privileged default
   Firebase Admin account. Approve the exact IAM role/key creation first.
2. Store its JSON only as `GUARDIAN_FCM_SERVICE_ACCOUNT` in Supabase Edge secrets,
   and set `GUARDIAN_FCM_PROJECT_ID=traelyx-e28ff`. Never put a server key in the
   Android config, repository, chat or client build. Remove any temporary local
   secret file after verified installation; retain a key identifier for revocation.
3. Generate a separate 64-character lowercase hexadecimal worker secret and
   store it as `GUARDIAN_WORKER_SECRET`. Keep dispatch disabled during deployment.
   The existing service-role key is supplied only by the Edge environment.
4. Deploy `guardian-dispatch` with the platform JWT gate disabled **only for this
   function**, because its independent worker-secret gate authenticates it.
   This is a reviewed security-sensitive deployment, not a mobile public API.
   No `verify_jwt=false` change has been made in the current config.
5. Verify unauthorized and disabled calls with secrets redacted. Only then
   approve enabling `GUARDIAN_DISPATCH_ENABLED=true` and empty-queue checks. A separate
   reviewed scheduler may invoke it once per minute with a secret stored in
   server-side Vault. Keep that job paused until receiver/consent integration and
   synthetic delivery testing are ready. Never embed credentials in SQL history.
6. Validate synthetic end-to-end receipt, revocation, duplicate suppression,
   expiry, offline/recovery and locked-phone handling before M6.8 completion.
   No real-contact test alerts or dangerous-road tests.

The worker does not implement the capability-based ingestion or receipt Edge
endpoints, mobile account/consent integration, or recorder attachment. Those are
still required. Six deliveries per invocation and free-tier limits bound capacity;
this is best-effort notification, not emergency protection or a delivery guarantee.

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
- https://developers.google.com/identity/protocols/oauth2/service-account
