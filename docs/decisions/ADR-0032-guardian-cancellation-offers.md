# ADR-0032: Require an observed cancellation offer before Guardian handoff

- Date: 2026-10-17
- Status: offer checks pass; serialized scheduling attached with Android sending fixed off

## Decision

An event's age alone cannot satisfy the cancellation affordance. Keep one
in-process offer per exact lease/event, bounded by the existing 16-event outbox.
Observe the app's exact cancellation notification in Android's active list,
then require at least 30 seconds on both monotonic and wall clocks before the
future dispatcher may use that offer. Clock uncertainty, changed authority,
expiry, missing proof or blocked notification access denies handoff. This proves
an available control, not that a person saw or understood it.

Dismissal or permission loss during an unfinished window invalidates the offer
without reposting it. Reservation cannot retroactively mature an unfinished
offer. A completed offer remains usable for exact retries after its notice is removed.

Proof is not persisted. ADR-0029 requires fresh driver review after full process
death; a restored lease cannot resume evaluation. A new process has no eligible
offers, including for already-reserved events. Retry retains its original exact
offer in the same process and cannot borrow another event's metadata or lease.
The dispatcher calls this gate on the control worker, schedules offer maturity
independently of event age, and retains ADR-0031 permit/Stop checks. Android's
sending gate remains fixed false pending renewed consent and live review.

The notification is generic and private, with no account, event kind, capability
or trip details. It uses a separate channel and exact tag, an immutable explicit
PendingIntent, and a non-exported receiver. The action carries only validated
owner/activation/event UUIDs and serializes cancellation through the existing
native worker. Fresh bound authority must still match; a process-start action
cannot reconstruct authority. Cancellation persists before success and is denied
after the first attempt reservation. Removal failure cannot undo cancellation.
Recipient notices are never removed by this controller.

Submission is not observation. A submitted but unobserved/dismissed notice is not
reposted in a loop. Blocked permission/channel access cannot create proof; no
permission prompt or Firebase initialization is introduced. Android 26+ receives
a timeout bounded by event and lease expiry. On Android 24–25, process death can
leave a stale generic notice until user/app dismissal; its action still cannot
restore authority, create proof or send. Even on newer versions, OS removal is
not a real-time guarantee. Current tests do not claim user visibility or delivery.

## Integration boundaries

Offer handling runs after enqueue and through one cancellable in-process wake
on the serialized worker, independently of recorder lifetime. Asynchronous
submission gets bounded one-second observation checks for three seconds;
an observed unfinished offer is checked at most once per second through its
30-second dual-clock window. Retry/deadline and expiry share that wake; idle
work schedules none. The dispatcher can also trigger an initial event-age
check. Timers may be deferred by Android; late wakes revalidate authority and
clocks. This adds no acquisition work, sampling change, wake lock, OS alarm or
network operation while the fixed Android sending gate is false. Stop/owner/replacement paths invalidate
offers first. The default-off debug pilot adds explicit local check/cancel UI;
checks are not automatic or delivery confirmations, and observations clear on
background/account change. Normal/release and installed validation builds keep
the pilot off. Review discloses the local notification; sending remains unavailable.

No dependency, persisted schema, backend access or network field changes.
Renewed sending consent, hosted activation/Stop,
accepted action under a real live driver lease and active physical recording/
two-account reliability remain later gates.

## Validation

Native synthetic tests cover dual-clock maturity after observation, delayed or
blocked notification, durable cancellation/write failure, exact identity,
restart, replacement, rollback, expiry, retries, bounded proof state and strict
foreground bridge access. Flutter tests cover strict metadata parsing, explicit
operations, stale account/lifecycle results, no retraction claim and large text.
An isolated Android proof checks the real generic notice/private immutable
action, unbound receiver denial, full elapsed window and scoped durable cancel.
Results and exact-source CI belong in the active M6 execution plan.

Source `8d346aa` passes full CI
[39039569866](https://github.com/atrx07/Traelyx/actions/runs/39039569866), including
both APKs, native/Flutter checks, server policies and artifacts. Local validation
passes all 459 native app and 384 Flutter tests, analysis, app lint and configured
builds. The scoped Tecno proof passes with real data preserved; live accepted
action/recording and two-account physical reliability remain unverified.

Android API behavior reference: [NotificationManager](https://developer.android.com/reference/android/app/NotificationManager).
