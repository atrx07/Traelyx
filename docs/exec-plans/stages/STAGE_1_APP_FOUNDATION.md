# Stage 1 Playbook — Application Foundation

## Goal

Create stable UI/state/storage foundations that will not fight the recorder later.

## Minimum references

`app/AGENTS.md`, relevant UX sections, `DATA_MODEL.md`, `STORAGE_SPEC.md`.

## Work units

1. Build semantic theme token system; final colors can evolve.
2. Add navigation skeleton with Drive/Trips/DNA/Social/You destinations.
3. Add Riverpod state boundaries and dependency injection strategy.
4. Build local settings repository; secrets deliberately excluded.
5. Implement Drift schema v1 for vehicle/trip/chunk/event/score/baseline/sync metadata.
6. Add database migrations and fixture upgrade tests.
7. Add secure-storage abstraction for future provider keys/auth-sensitive local material.
8. Add diagnostics screen shell including build/database/storage info.
9. Add accountless owner namespace/device-local identity if needed for local data association.
10. Add skeleton "Start locally" onboarding and permission education without requesting everything immediately.

## Acceptance

- app starts with no account/network;
- database survives restart;
- migration test harness exists;
- navigation/state logic is testable;
- secure/non-secure settings are clearly separated;
- UI is original and accessible enough to build upon.
