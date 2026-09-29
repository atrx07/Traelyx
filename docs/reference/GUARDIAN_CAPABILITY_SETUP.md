# Guardian capability Edge boundary — M6.8 draft

## Current state

`supabase/functions/guardian-capability/` is implemented and locally tested, but
**not deployed or enabled**. It adds no device registration, activation, scheduler,
FCM credential or alert send. The existing `guardian-dispatch` remains disabled.
No physical phone is needed for the isolated Edge tests.

The function is intended to use `verify_jwt=false` because native background
delivery cannot own Flutter's rotating Supabase Auth token. Its own authority is
the random 256-bit, eight-hour driver capability or receipt-only device
capability established by the signed-in, guarded SQL APIs. The service-role key
stays in the Edge environment and is never returned to the app.

## Exact HTTP contract

POST JSON to `/functions/v1/guardian-capability`, with exactly one of these
shapes. Both use `Content-Type: application/json` and a 1,536-byte body limit.

```json
{"type":"ingest","owner_id":"00000000-0000-4000-8000-000000000001","credential":"<64 lowercase hex characters>","envelope":{"event_id":"00000000-0000-4000-8000-000000000002","kind":"severe_drive","occurred_at_epoch_ms":1790000000000,"rule_version":1,"schema_version":1,"uncertainty":"experimental_not_confirmed"}}
```

```json
{"type":"receipt","device":"00000000-0000-4000-8000-000000000003","credential":"<64 lowercase hex characters>","delivery":"00000000-0000-4000-8000-000000000004"}
```

The example identifiers and time are synthetic and are not usable credentials.
The server accepts no coordinates, speed, route, trip identifier, name, raw
telemetry, arbitrary message, or caller-selected RPC. It invokes only
`ingest_guardian_alert_v1` or `receive_guardian_alert_v1`, which are deployed
service-role-only functions. SQL performs credential, activation, device,
connection-revision, generation, permission, expiry, quota and duplicate checks.
The Edge layer validates syntax before contacting SQL and redacts SQL details.
Backend acceptance, device receipt and recipient view remain distinct states.

`GUARDIAN_CAPABILITY_ENABLED` must be exactly `true` to process a request; any
other value returns `503 capability_disabled` before parsing or SQL access.
There is no default enabled state. The planned hosted disabled-state check must
use a synthetic body and create no alert or registration.

## Before production deployment or enabling

1. Review the two source files and `verify_jwt=false` for this function only;
   obtain exact production-access approval. Deploy with
   `GUARDIAN_CAPABILITY_ENABLED=false` and verify a synthetic POST returns the
   function's `503 capability_disabled`. No live capability should be used.
2. Complete the signed-in driver activation and recipient opt-in UI, account
   change/teardown, encrypted capability storage, native outbox and guarded
   recorder integration. Keep local recording independent of cloud failures.
3. Validate adversarial hosted synthetic ingestion/receipt, unauthorized,
   duplicate, stale generation, expiry, revocation, offline recovery and locked
   phone behavior without real contacts or personal telemetry. Only then review
   enabling ingestion. The FCM sender credential and dispatch activation are
   separate gates; Google organization policy currently blocks key creation.

## Local verification

The pinned Deno 2.9.6 CI job runs formatting, lint, entry-point type checks and
`supabase/functions/tests/guardian_capability.test.mjs`. The eleven local tests
cover exact schemas, bounds/deadlines, fixed RPC routing, SQL error redaction,
duplicate ingestion, stale receipt and disabled behavior. These tests do not
prove production delivery or physical crash-detection accuracy.
