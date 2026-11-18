# Architecture Decision Records

Read only ADRs relevant to the decision being modified/revisited.

- `ADR-0001-local-first.md`
- `ADR-0002-flutter-kotlin-boundary.md`
- `ADR-0003-supabase-connected-layer.md`
- `ADR-0004-ml-evidence-explicit-scoring.md`
- `ADR-0005-provider-agnostic-commentary.md`
- `ADR-0006-github-release-distribution.md`
- `ADR-0007-raw-telemetry-local-summary-cloud.md`
- `ADR-0008-safe-competition.md`
- `ADR-0009-release-key-local-custody.md`
- `ADR-0010-progressive-agent-context.md`
- `ADR-0011-native-drift-finalization-handoff.md`
- `ADR-0012-tripdebug-native-private-export.md`
- `ADR-0013-telemetry-coordinate-frames.md`
- `ADR-0014-categorical-telemetry-confidence.md`
- `ADR-0015-windowed-replay-reduction.md`
- `ADR-0016-bounded-native-route-display-boundary.md`
- `ADR-0017-single-manual-replay-clock.md`
- `ADR-0018-user-directed-storage-and-redacted-export.md`
- `ADR-0019-optional-magic-link-auth.md`
- `ADR-0025-guardian-live-evaluation-boundary.md`
- `ADR-0026-guardian-alert-capabilities.md`
- `ADR-0027-guardian-notice-claims.md`
- `ADR-0028-guardian-processing-windows.md`
- `ADR-0031-guardian-dispatch-worker-isolation.md`
- `ADR-0032-guardian-cancellation-offers.md`
- `ADR-0033-guardian-versioned-sending-review.md`
- `ADR-0034-offline-dataset-import-quarantine.md`
- `ADR-0035-source-space-eventnet-experiment.md`
- `ADR-0036-isolated-mobile-ml-runtime.md`
- `ADR-0037-gated-event-model-evidence.md`
- `ADR-0038-generated-integrity-comparison.md`

- [ADR-0043: Local narrator admission and artifact boundary](ADR-0043-local-narrator-admission-and-artifact-boundary.md) — functional local architecture; optional runtime/model activation gated.
- [ADR-0044: Recorder-owned CPU lease](ADR-0044-recorder-owned-cpu-lease.md) — bounded renewable CPU ownership during explicit acquisition; battery/physical acceptance required.
- [ADR-0045: Explicit local-data backup policy](ADR-0045-explicit-local-data-backup-policy.md) — exclude implicit Android backup/device transfer; user-directed exports remain separate.
- [ADR-0046: Atomic local database upgrades](ADR-0046-atomic-local-database-upgrades.md) — schema DDL and user_version commit together; old results/consent remain unchanged.
- [ADR-0047: Local post-build APK signing](ADR-0047-local-post-build-apk-signing.md) — unsigned opt-in plus short-lived local signer; passwords never enter Gradle.
