# Guardian active-driver recovery: desk-safe coverage review

## Scope and status

Authorized on 2026-11-11: review active-driver authority loss, cancellation,
trip stop, retry and process recovery using generated evidence and fake services.
No phone/emulator operation, live Auth mutation, hosted activation, backend change,
real notification, sensor acquisition or trip upload is part of this review.
M6.8 remains incomplete; mounted/vehicle validation stays deferred.
This bounded review passed and is closed on 2026-11-11. No runtime fix was needed.

## Existing coverage and identified gaps

All test files below are in
`android/app/src/test/kotlin/io/github/atrx07/traelyx/guardian/`.

| Required behavior | Existing evidence retained | Missing integration coverage added |
|---|---|---|
| Auth loss stops evaluation and rejects stale work | `GuardianRecordingSessionTest` rejects queued detections after sign-out/replacement; `GuardianActivationCoordinatorTest` journals owner loss; `GuardianOutboxDispatchTest` ignores in-flight acceptance after authority loss | Bind the owner to null through the production bridge while recording, at cancellation, queued-handoff and already-started phases; join evaluator shutdown, dispatch invalidation, late detection/completion, retained cleanup and same-owner rebind |
| Replacement cannot upload the old account's evidence | Coordinator owner/journal isolation and dispatcher replacement/busy-slot tests | Change bridge owner while old work is queued or started, then freshly activate the new synthetic owner; old callbacks cannot change its outbox or consume its consent, and new work waits for the old IO slot |
| Cancellation survives trip stop and connectivity retry | `GuardianCancellationTest` covers durable pre-reservation cancellation; `GuardianDispatchScheduleTest` covers stale wakes/backoff; existing reviewed-flow tests cover cancellation and dispatch after recording ends | Keep a cancelled event beside a separate eligible event, stop the recording with a detection callback queued, return an unconfirmed network result and retry only the eligible event under its unchanged identity |
| Restart requires fresh activation and cannot reuse sending consent | Existing reviewed-flow test `restored lease and pending event cannot resume recording or sending`; `GuardianRecordingSessionTest` fresh-process case; `GuardianSendingReviewTest` ephemeral consent case | No duplicate test added: the existing coverage already reconstructs the coordinator, refuses evaluation/transport/timers and retains cleanup evidence |

The three new tests extend `GuardianReviewedFlowIntegrationTest`; its five
existing tests remain. They exercise production activation bridge/coordinator,
recording session, outbox, cancellation controls, dispatch schedule and dispatch
coordinator together. The host's invalidate-before-bind and refresh ordering is
modeled explicitly; Android host execution and Flutter-to-native Auth delivery
are not executed by this JVM harness.

The vault/journal are in memory, detections are generated, notice observation and
clocks are virtual, and the ingest runner only records permits and invokes fake
completion callbacks. The tests contain only fixed synthetic identities and
credentials. No HTTP or provider SDK is used.

## Assertions and contract limits

- Losing Auth closes the evaluator and clears its local capability/outbox while
  keeping the raw-recorder handle open. Late detections and timer callbacks do
  not enqueue evidence. Rebinding the same owner alone does not activate it;
  its exact cleanup ticket remains available for an authenticated retry.
- A replacement owner cannot enumerate the prior owner's cleanup ticket.
  Fresh synthetic activation is explicit. One unsettled old transport blocks a
  second handoff; its completion releases that slot without changing the new
  event. Replayed completion/denial and old evaluator callbacks are inert.
- Cancellation persists before the first reservation, and that event remains
  cancelled with zero attempts while another event retries after trip stop.
  The eligible event keeps its owner, activation and event identity; backoff is
  honored, no additional evaluator is created and no timer remains after
  acceptance.
- Trip stop is not alert cancellation: it stops new detections, while previously
  eligible evidence may complete its reviewed cancellation window and retry.
  A request already handed to a transport cannot be retracted. Ignoring its late
  callback is not proof that the backend never received it. Fake backend
  acceptance is not a receipt, notification or delivery guarantee.
- Restart coverage verifies that a recovered lease is cleanup evidence rather
  than fresh activation/sending consent. It does not establish physical Android
  process recovery, Keystore behavior, network timing or OEM reliability.

## Validation

- Targeted reviewed-flow suite: **8 tests, zero failures/errors/skips**.
- Complete `testDebugUnitTest`: **492 app tests in 59 suites, zero failures,
  errors or skips**, plus successful dependency-module suites (Java 21).
- Repository validation and whitespace checks: pass.
- Source [`b2a3270`](https://github.com/atrx07/Traelyx/commit/b2a32702b2ac746a2efd2f5e7c5372c029004d71)
  passes full [CI 42967259142](https://github.com/atrx07/Traelyx/actions/runs/42967259142):
  all three jobs, Flutter/native tests, debug/release-validation APKs, cloud
  SQL/RLS, Edge suites and repository/size gates. No failed gate was waived.

No product-runtime behavior, wire format, schema, dependency, sample rate,
permission or backend configuration changes. Physical active-driver ingestion,
mounted review, calibration, cancellation UX, process/network recovery and
recording/performance remain separate acceptance gates in
[`GUARDIAN_ALERTS_V1.md`](../technical/GUARDIAN_ALERTS_V1.md).
