# Stage 8 Playbook — Hardening & GitHub Release

## Goal

Make v0.1 trustworthy enough that a stranger can sideload it, upgrade it, record a real trip, and understand its limitations.

## Minimum references

`RELEASE_SIGNING.md`, `SECURITY.md`, `release-checklist.yaml`, privacy/testing/performance governance.

## Work units

1. Freeze release scope; no late feature frenzy.
2. Run Android background/lifecycle torture tests.
3. Benchmark battery, CPU, memory, storage/hour, replay frames, model latency, APK size.
4. Fix severe recorder/data-loss regressions before visual bugs.
5. Audit Android permissions and cloud endpoints.
6. Audit RLS and Guardian access.
7. Audit provider payload/credential logging.
8. Run DB migration from previous signed/pre-release representative build.
9. Maintain/verify release keystore backup outside repo.
10. Build release APK(s) with chosen ABI strategy.
11. Verify signature and SHA-256.
12. Clean-install smoke test.
13. Upgrade-install test with populated history/settings.
14. Record final physical-device normal trip.
15. Produce release notes/known limitations/model+scoring versions.
16. Publish canonical GitHub Release.

## Acceptance

- signed update installs over previous signed build;
- local history survives migration;
- core functions work without login/network;
- no secret in repository/artifact;
- release notes state limitations honestly;
- checksum published;
- installer artifact comes from canonical release location.
