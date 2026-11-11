# Execution Plan — M7 ML & Advanced Commentary

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M7
**Current gate:** M7.1 complete; M7.2 pending explicit authorization
**Started:** 2026-11-11
**Last updated:** 2026-11-11

## Context budget / references

Read `ml/AGENTS.md`, roadmap M7.1, dataset governance, ML split/provenance
requirements, the dataset registry schema, and affected tooling/tests only.

## Goal / user-visible result

M7.1 delivers a reproducible, local-only dataset registry and import command
for reviewed public data and a generated project fixture corpus. No model is
trained or promoted by this substep.

## Authorization / sequencing exception

On 2026-11-11 the maintainer explicitly authorized proceeding with M7.1 while
M6.8 acceptance remains incomplete. This changes development order, not its
acceptance criteria. M6.1–M6.7 remain complete. M6.8 physical active-driver
ingestion/cancellation, process/network recovery, performance and mounted/
vehicle/OEM gates remain open, with vehicle work maintainer-deferred. Its plan
stays active as an outstanding acceptance record; no new live operation is
authorized here. M7 is the current development milestone. Stop after M7.1 and
wait for explicit authorization before M7.2.

## In scope

- Versioned registry entries: license/attribution, source hashes, provenance,
  channels/units/rates, population, label confidence, privacy and limitations.
- Explicit local source import, bounded parsing, integrity verification,
  deterministic output manifests and refusal to overwrite existing results.
- A public licensed source and synthetic, location-free project fixtures.
- Preserve grouping before future windowing; block training eligibility when
  identity, timing, units or label evidence is insufficient.

## Out of scope

Training/windowing, model dependencies, app/recorder/scoring changes, private
trip imports, user contributions, cloud uploads and Guardian operations.

## Preconditions / affected components

Python standard library tooling, `ml/`, registry reference schema, tooling
tests, CI, and roadmap/status documents. Public license/source must be reviewed
before registering or importing data. No new dependency is planned.

## Data/privacy/security and compatibility

Downloaded data and derived imports stay in ignored `ml/data/private/`.
Only metadata and generated non-personal fixtures enter Git. No routes or
private recordings are read. Existing schemas/results and mobile behavior are
unchanged. Dataset/import versions and source/output hashes preserve replay.

## Implementation steps

- [x] Review public source and existing project corpus; record limitations.
- [x] Implement registry validation and deterministic fail-closed import.
- [x] Add governed synthetic fixture and hostile-input/reproducibility tests.
- [x] Run local gates and an actual checksum-verified public import.
- [x] Synchronize documents, inspect diff, commit/push, verify CI and Git sync.

## Tests / validation

- Registry/schema contract checks, Python compilation and unit/integration tests.
- Reimport byte equality; hash, malformed row, non-finite value, privacy-column,
  group leakage, output collision and input/output boundary rejection.
- Offline committed-fixture validation in CI; network-free normal test suite.
- Actual local public import against publisher SHA-256, with raw data ignored.
- Repository contracts/secrets and whitespace checks; full existing CI.
- No device/build-runtime or battery claims; mobile gates run through CI.

## Acceptance criteria

Both public data and generated project fixtures import reproducibly with license,
source and output hashes, source-label provenance and explicit quality limits.
No driver-held-out eligibility is fabricated from anonymous concatenated rows.
Unsafe/malformed input cannot publish a successful import. CI covers the new
tooling without network data dependencies. M6.8 is not marked complete.

## Risks / decisions

The reviewed public source has three drivers but no row-level driver/trip/time
fields. Acceleration magnitudes also warrant unit verification despite the
publisher's declared SI units. Preserve source values and block training use;
do not infer driver boundaries, timestamps, converted units or crash labels.

## Progress log

- 2026-11-11: M7.1 authorized with M6.8 acceptance explicitly carried forward.
  Reviewed Mendeley DOI `10.17632/jj3tw8kj6h.2` and publisher CC BY 4.0 notice;
  downloaded both small source files into ignored local storage and verified
  their publisher SHA-256 values. No personal telemetry accessed.
- Local checks: 22 dataset tests and 3 existing inspector tests pass with no
  failures/errors/skips and resource warnings treated as errors. Python
  compilation and registry validation pass. Actual imports produce 558 synthetic
  samples and 1,114 public rows (class counts 252/288/350/224); an independent
  public reimport is byte-identical. Raw source/summary and outputs are ignored.
  Repository contracts/secrets and whitespace checks pass.
- ADR-0034 records local import/quarantine decisions. The M3 native corpus stays
  authoritative and unchanged; the ML smoke corpus is separate synthetic data.
- Final boundary review added oversized-integer metadata cases: range rejection
  must not convert an arbitrary integer to float or expose a traceback. All
  25 Python checks and registry validation still pass. No valid import changes.

- Final source `460539f9a9872972e63a0d7531045a24fbbad956` passes full
  [CI 42970700095](https://github.com/atrx07/Traelyx/actions/runs/42970700095),
  all three jobs: Flutter/native tests, offline dataset checks, debug/release-
  validation APKs, cloud SQL/RLS, Edge and artifact gates. No gate was waived.
  Implementation and numeric-boundary follow-up are pushed on `origin/main`;
  final closure synchronizes this plan, STATUS, NEXTSTEPS and README.

## Completion summary

**M7.1 complete (2026-11-11).** Two governed registry entries and an operational
local importer preserve licensed source evidence and deterministic audit outputs.
Twenty-five Python tests, actual public import/reimport, repository checks and
full exact-source CI pass. No dependency/provider, app/schema migration, sampling,
scoring, private-data upload or device operation. Registry schema v1 replaces an
unused draft; no existing registry instances or historical results are migrated.
Public data remains training-blocked; synthetic data is plumbing evidence only.
M6.8 physical/vehicle acceptance remains open/deferred. M7 stays active as a
milestone plan, with M7.2 pending explicit maintainer authorization; no M7.2 work
was started. Real-device/battery behavior is unchanged and not newly validated.
