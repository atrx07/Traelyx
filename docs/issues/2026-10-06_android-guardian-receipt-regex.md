# Android Guardian receipt parser initialization failure

**Status:** Parser repair passes physical Android and local gates; hosted retry
pending. Fix is the commit introducing this record; the receipt-check checkpoint
will link its hash and CI result.

**Affected path:** M6.8 native capability receipt gateway and incoming Guardian
message handler. Recording, trip history and sign-in do not use this parser.

## Symptoms and confirmed cause

The approved first-phone synthetic receipt probe failed during gateway class
initialization with `PatternSyntaxException` on Android 14. Its fixed positive
response pattern escaped the opening brace but left the closing brace literal.
Android's ICU regex engine rejects this pattern; desktop JVM unit tests accepted
it. The gateway failed before calling the transport. The hosted synthetic
delivery did not reach `device_received`. No FCM message or notification was sent.

## Recovery and repair

Capability processing was enabled from 14:20:07 to 14:20:41 UTC on 2026-10-06,
then restored to explicit false. Its digest and synthetic `503 capability_disabled`
responses were verified. Dispatch stayed disabled throughout. Marker-checked
cleanup removed the synthetic principal, connection and delivery; final counts
were 0 sessions, 1 device, 1 unexpired device, 0 events and 0 deliveries. The
real recipient registration and encrypted phone authority remain present.

The repair explicitly escapes both literal braces. The fixed response contract
is unchanged. A JVM regression rejects missing braces and trailing content;
instrumentation mode `guardian-receipt-contract` checks exact positive,
malformed, extra-field and denied responses on Android using only synthetic
transport. It uses no network or stored credential. Instrumentation failures
now identify the selected mode instead of always naming recorder recovery.

## Validation and limits

- All 352 native unit tests, Android lint, configured review-pilot APK and
  repository validation pass. The data-preserving update and network-free
  `guardian-receipt-contract` proof pass on the first Android 14 phone, with
  Firebase inactive and no stored authority change.
- Source CI and hosted retry remain pending at this checkpoint. See the [receipt procedure](../reference/GUARDIAN_RECEIPT_CHECK.md)
  and [M6 plan](../exec-plans/active/M6_CONNECTED_LAYER.md).
- This is a durable parser repair, not an environment workaround. It does not
  establish actual FCM arrival, notice display, cold-process delivery or
  emergency reliability. No schema, dependency, credential, data format,
  sampling or privacy contract changed.
