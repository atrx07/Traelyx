# ADR-0022 — Mutual friendships with participant-only disclosure

**Status:** Accepted 2026-09-26

## Context

M6.5 requires basic relationships with abuse/privacy controls. Friendship must
not unlock private trip summaries, vehicles, routes, scores, or Guardian access.
Private profile owners need an explicit way to disclose their identity to one
recipient without making their profile public. Account changes and concurrent
requests must not reinterpret an earlier action.

## Decision

Use one canonical UUID-ordered pair row per relationship, with a private state,
requester, revision, name snapshots, timestamps, mutation UUID, and independent
block flags. Snapshot only username/display name when the request is created;
subsequent private profile edits are not exposed through old relationships.
Exact public username discovery uses the existing two-field lookup. Sending
and acceptance require explicit app confirmation. Sender profiles may remain
private; accepting shares no additional data categories.

No client has direct table access. Three fixed-search-path SECURITY DEFINER
RPCs validate expected account against auth.uid before accessing rows. Lists
return only relationship ID, revision, peer username/display name, and the
caller's state. Changes require participant membership and expected revision.
Only recipients accept/decline; requesters cancel; either friend can remove.
Block closes the relationship and hides it from the other party. Unblock never
restores it. Block history is visible only to its owner. Anonymous RPC access
and public relationship enumeration are denied.

Requests expire after seven days. Closed pairs require seven days before a new
request, and each account may send at most 30 successful new requests per
24-hour quota window anchored at its first request. Pair and ordered user advisory
locks serialize duplicate requests and quotas; changes lock the pair row. A
maximum of 1,000 retained pairs per account bounds reads/storage. Closed pairs
retain minimal snapshots for cooldown and abuse controls; no automatic purge
or erasure UI is introduced here. Auth/profile deletion cascades these rows.

The app uses a replaceable gateway and account-scoped in-memory controller.
Opening Social is inert. Reads, lookups, and actions are explicit foreground
operations. Ambiguous failures clear actionable state and ask for reload;
there is no background retry/outbox or persistent social cache. Successful
writes refresh the current list. Request mutation IDs deduplicate a repeated
request; state changes use revisions and require reload after lost responses.

## Consequences / validation

No dependency, permission, local schema upgrade, contact upload, messaging,
notification, ranking, or Guardian change is required. Core offline features
remain independent. Blocking cannot hide an independently public profile from
its existing anonymous lookup. It denies relationship requests and access.

SQL fixtures cover anonymous/direct-table denial, wrong accounts, request
replay, private sender disclosure, participant transitions, revision conflicts,
block isolation, snapshot privacy, expiry, cooldown, and quotas. SDK tests
assert exact fields and safe failures; controller/widget tests cover inert
opening, confirmation/cancel, account changes, uncertain responses, and layout.
Real-device testing does not send requests to real people without authorization.
