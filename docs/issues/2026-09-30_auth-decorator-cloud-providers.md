# Auth decorator hid optional cloud providers

**Status:** Repaired in [103d3d7](https://github.com/atrx07/Traelyx/commit/103d3d77f2fd9a59cb685145e6595e2afb28658f). [Source CI run 36743035626](https://github.com/atrx07/Traelyx/actions/runs/36743035626) passed.

**Affected path:** Account-bound profile/vehicle metadata, summary sync, Social,
rankings, Guardian pairing and Guardian alert inbox. Local recording and history
do not use these provider gates.

## Symptoms and evidence

The M6.8 Auth binding decorator introduced in `90cf5c5` wrapped the Supabase
account gateway. Six feature providers still required
`account is SupabaseAccountGateway`; the wrapper therefore selected their
unavailable/null gateway branches. This was confirmed by source inspection.
The earlier physical startup check showed signed-in status and local trip
history, but did not invoke a hosted feature. No cloud mutation or data loss was
observed during investigation.

## Cause and repair

Provider selection depended on the concrete Auth gateway type instead of its
optional Supabase transport. The repair adds `SupabaseClientSource`, delegates
it through the Auth decorator, and updates the six providers to use that
interface. The accountless decorator yields no client. Feature-level Auth and
consent checks still govern operations; no schema, permission or upload rule
changed. No data reset or recovery was needed.

## Validation and limits

- A provider-graph regression checks all six wrapped cloud gateways plus the
  accountless null path. All 286 Flutter tests and analysis pass; a configured
  debug APK builds.
- A data-preserving phone update preserved sign-in and local trip history. A
  read-only Guardian reload reached the hosted account and displayed its
  server-backed controls. No activation, device registration, alert or trip
  upload occurred.
- Physical account switching remains open. The other five cloud features were
  covered by provider construction tests, not individual hosted mutations.
  Guardian alert delivery remains disabled under the
  [M6 execution plan](../exec-plans/active/M6_CONNECTED_LAYER.md).
