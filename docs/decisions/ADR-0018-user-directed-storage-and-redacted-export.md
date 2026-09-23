# ADR-0018 — User-directed storage and separate redacted export

**Status:** Accepted

## Context

M5.9 needs useful local storage controls without risking background loss of replay evidence or weakening the existing precise-private `.tripdebug` boundary. A single “anonymized export” switch would be misleading: a summary can omit obvious identifiers yet still be linkable from its combination of metrics. Raw telemetry also remains authoritative native app-private data while its relational index and trip results live in Drift.

## Decision

Keep retention user-directed. The saved Manual/7-day/30-day/Forever preference never schedules deletion; age-based cleanup first creates an exact finalized-trip preview and requires consequence-specific confirmation. Android remains authoritative for deleting one UUID-scoped raw trip directory and refuses an active recorder or pending finalization. Drift removes matching index rows or the selected trip only after native success.

Keep `.tripdebug` format version 1 unchanged as `precise_private`. Add a separate, strict `traelyx.redacted_trip_summary` JSON format version 1. It includes only bounded outcome/evidence aggregates and excludes route, raw samples, identifiers, vehicle/account/device identity, storage metadata, and wall-clock time. UI and documentation call it redacted, never anonymous. Both exports are explicit system-document operations and perform no upload.

Storage and cache presentation consume aggregate project-level contracts. The current offline canvas continues to report no tile cache; future providers must report and clear their own cache behind that boundary.

## Consequences

Positive:

- no retained raw evidence expires without a fresh user confirmation;
- native path/finalization safeguards stay adjacent to the authoritative files;
- precise and redacted exports have separate versioned privacy promises;
- M5.9 adds no schema, dependency, account, service, or network requirement.

Negative:

- the retention preference is advisory rather than automatic;
- filesystem deletion and relational cleanup cannot be one cross-runtime transaction, so partial failure must remain visible and fail closed;
- redacted summaries are still private derived data and cannot be claimed anonymous or automatically public-safe.

## Revisit if

Measured storage pressure justifies an opt-in scheduled retention service, a governed archive retains enough low-rate evidence for replay/recomputation, or a formally evaluated public-contribution format is added. Any revision requires a new version/privacy review and must not reinterpret `.tripdebug` version 1.
