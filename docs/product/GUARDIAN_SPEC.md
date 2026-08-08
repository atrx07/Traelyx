# GUARDIAN_SPEC.md — Partner Connect / Guardian Mode

## When to read

Read when implementing trusted-contact pairing, safety-state evaluation, alerts, permissions, notifications, or relationship privacy.

## 1. Purpose

Guardian Mode is an opt-in safety connection between a driver and a trusted account/contact. It sends event-triggered safety information when explicitly permitted.

It is **not** default continuous partner surveillance.

## 2. Pairing

Recommended flow:

1. Driver generates a short-lived cryptographically random invite token/QR.
2. Trusted user accepts using an authenticated account.
3. Driver sees the identity/profile being connected and confirms if needed.
4. Connection is stored server-side with explicit permissions.
5. Either side can disconnect; driver can revoke access immediately.

Invite tokens:

- expire quickly;
- are single-use;
- are not stored as permanent shared secrets;
- are rate-limited;
- are never predictable sequential IDs.

## 3. Permission model

Permissions are granular. Initial candidates:

- `crash_alert` — receive possible-crash alert.
- `severe_drive_alert` — receive high-confidence severe-risk-state alerts.
- `current_safety_state` — view coarse current state while a trip is active.
- `live_location` — **off by default**, explicit opt-in if ever enabled.
- `current_speed` — **off by default**.
- `trip_history` — **off by default**.

The machine-readable default matrix lives in `docs/reference/permissions-matrix.yaml`.

Do not make a trusted relationship imply all permissions.

## 4. Safety states

Possible coarse states:

- Normal;
- Elevated;
- Severe;
- Possible Crash.

Exact transitions must be defined by auditable local/safety logic. LLM commentary does not participate.

A single GPS spike must not produce a severe notification without corroborating evidence/confidence.

## 5. Alert philosophy

Avoid notification spam. Alerts should be rare enough that recipients take them seriously.

Severe/crash-like alerts should include:

- what was detected in plain language;
- confidence/uncertainty appropriate to severity;
- time;
- action option such as contact driver;
- only location information if that permission is enabled and product/legal review permits it.

## 6. Tone

Safety-critical notifications default to clear, calm copy.

An optional humorous personality can exist for non-emergency or user-selected severe-driving notifications, for example playful "your partner is negotiating with physics" style text. However:

- Possible Crash alerts must never be obscured by jokes.
- Avoid definitive death/injury statements based only on telemetry.
- Do not use panic-inducing language when confidence is low.

The earlier humorous concept (e.g., "book a funeral") is appropriate only as inspiration for an explicitly opt-in novelty tone and must be rewritten to avoid presenting an unverified death as fact.

## 7. Anti-abuse/privacy

- No hidden Guardian mode.
- Driver must always be able to see active connections and permissions.
- Revocation must take effect server-side.
- Log permission changes and relationship state for audit.
- Do not expose precise routes as a side effect of alert delivery.
- Rate-limit pairing attempts and notification abuse.
- Block/ignore capability should exist for unwanted invitations.

## 8. Offline behavior

Local safety-state detection can continue offline, but remote notification obviously requires connectivity. Do not claim an alert was delivered until delivery is confirmed by the notification/backend mechanism where possible.

## 9. Data model

At minimum:

```text
guardian_connection
  driver_user_id
  guardian_user_id
  status
  permissions
  created_at
  updated_at
  revoked_at
```

Do not use a simple `partner_id` column on profile as the full permission model.

## 10. Testing

Include:

- token expiry/reuse;
- permission downgrade/revocation;
- RLS isolation;
- alert deduplication;
- false GPS spike;
- connectivity loss;
- severe event with/without permission;
- disconnect while trip active;
- blocked invitation.
