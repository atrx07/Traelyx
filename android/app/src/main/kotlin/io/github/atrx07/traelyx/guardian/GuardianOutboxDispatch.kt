package io.github.atrx07.traelyx.guardian

import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** One-use handoff gate. Cancelling cannot retract IO that has already begun. */
internal class GuardianDispatchPermit(private val fresh: () -> Boolean = { true }) {
    private val state = AtomicInteger(0)
    fun tryBegin(): Boolean {
        if (!runCatching(fresh).getOrDefault(false)) { cancel(); return false }
        return state.compareAndSet(0, 1)
    }
    fun cancel() { state.set(2) }
    override fun toString() = "GuardianDispatchPermit(redacted)"
}

internal interface GuardianIngestRunner : AutoCloseable {
    /** Never blocks the control worker. False means no task was accepted. */
    fun submit(attempt: GuardianDispatchAttempt, permit: GuardianDispatchPermit,
        complete: (GuardianIngestResult) -> Unit): Boolean
}

/** No timers, Auth, vault access or recorder work on this bounded network executor. */
internal class GuardianIngestWorker(private val gateway: GuardianIngestPort) : GuardianIngestRunner {
    // One queued slot allows a completion to post the next task while its old
    // executor frame unwinds. The coordinator allows only one unsettled operation.
    private val executor = ThreadPoolExecutor(1, 1, 0, TimeUnit.MILLISECONDS, ArrayBlockingQueue(1),
        { task -> Thread(task, "traelyx-guardian-ingest").apply { isDaemon = true } },
        ThreadPoolExecutor.AbortPolicy())

    override fun submit(attempt: GuardianDispatchAttempt, permit: GuardianDispatchPermit,
        complete: (GuardianIngestResult) -> Unit): Boolean = try {
        executor.execute {
            val result = if (permit.tryBegin()) runCatching { gateway.ingest(attempt) }
                .getOrDefault(GuardianIngestResult.UNCONFIRMED) else GuardianIngestResult.UNCONFIRMED
            runCatching { complete(result) } // A lost control callback never authorizes another IO.
        }
        true
    } catch (_: java.util.concurrent.RejectedExecutionException) { false }

    override fun close() { executor.shutdownNow() }
}

/**
 * Dormant control-worker state machine. Its host must serialize every call,
 * invalidate before owner/activation/Stop changes, pump after enqueue/completion,
 * and schedule only the returned monotonic wake time. No Android caller exists yet.
 */
internal class GuardianOutboxDispatchCoordinator(
    private val outbox: GuardianOutbox,
    private val authority: () -> GuardianVaultSnapshot?,
    private val clock: () -> GuardianClock,
    private val enabled: () -> Boolean,
    private val handoffAllowed: (GuardianPendingAlert) -> Boolean,
    private val runner: GuardianIngestRunner,
    private val postControl: (() -> Unit) -> Unit,
) : AutoCloseable {
    private class Job(val attempt: GuardianDispatchAttempt, val started: GuardianClock, fresh: () -> Boolean) {
        val permit = GuardianDispatchPermit(fresh)
        var abandoned = false
        var deadlineReported = false
    }
    private var busy: Job? = null
    private var closed = false
    var unavailable = false
        private set

    /** Revoke queued handoff immediately; an existing IO keeps its busy slot until it returns. */
    fun invalidate() {
        busy?.let { it.abandoned = true; it.permit.cancel() }
    }

    /** Null means there is no clock wake to schedule; no busy-loop polling is needed. */
    fun pump(): Long? {
        if (closed || unavailable) return null
        return try {
            if (!enabled()) { invalidate(); return null }
            val now = clock()
            val snapshot = authority()
            val current = busy
            if (current != null) {
                if (current.abandoned || current.deadlineReported) return null
                if (!matches(snapshot, current.attempt) || !handoffAllowed(current.attempt.alert)) {
                    invalidate()
                    return null
                }
                if (deadlinePassed(current.started, now)) {
                    current.deadlineReported = true
                    current.permit.cancel()
                    outbox.complete(current.attempt, false, false, now)
                    // A stuck transport must not create overlapping attempts or grow a queue.
                    return null
                }
                return deadline(current.started.elapsedMillis)
            }
            val lease = snapshot?.lease ?: return null
            if (!lease.valid(now, lease.ownerId)) return null
            val pending = snapshot.alerts.map { it.advance(now.elapsedMillis, now.epochMillis,
                now.bootId, lease.ownerId, lease.activationId) }.filter { it.state in ACTIVE_STATES }
            val candidate = pending.firstOrNull { it.readyToAttempt(now.elapsedMillis) }
            if (candidate == null) return pending.minOfOrNull { it.nextAttemptAtElapsedMillis }
                ?.coerceAtLeast(now.elapsedMillis)
            if (!handoffAllowed(candidate)) return null
            val reserved = outbox.reserveNext(lease.ownerId, now) ?: return null
            // reserveNext preserves outbox ordering, including ties. The gate must
            // approve the actual reserved event rather than just a sampled candidate.
            if (reserved.lease != lease || !handoffAllowed(reserved.alert) ||
                !matches(authority(), reserved) || !enabled()) return null
            val job = Job(reserved, now) { !deadlinePassed(now, clock()) }
            busy = job // Before submit: even a synchronous fake callback cannot race assignment.
            val submitted = runner.submit(reserved, job.permit) { result ->
                postControl { finished(job, result) }
            }
            if (!submitted) finished(job, GuardianIngestResult.UNCONFIRMED)
            if (busy === job) deadline(now.elapsedMillis) else nextWake()
        } catch (_: Exception) {
            failClosed()
            null
        }
    }

    /** Exact account/activation check precedes outbox recovery; never erase another owner's lease. */
    fun cancel(owner: String, activation: String, event: String): Boolean {
        if (closed || unavailable) return false
        if (runCatching { guardianUuid(owner); guardianUuid(activation); guardianUuid(event) }.isFailure) return false
        return try {
            val snapshot = authority() ?: return false
            val lease = snapshot.lease ?: return false
            val now = clock()
            if (lease.ownerId != owner || lease.activationId != activation || !lease.valid(now, owner)) return false
            outbox.cancel(owner, event, now)
        } catch (_: Exception) { failClosed(); false }
    }

    private fun finished(job: Job, result: GuardianIngestResult) {
        if (busy !== job) return
        busy = null
        job.permit.cancel()
        if (closed || unavailable || job.abandoned || job.deadlineReported) return
        try {
            val now = clock()
            if (!enabled() || !matches(authority(), job.attempt)) return
            val timely = !deadlinePassed(job.started, now)
            outbox.complete(job.attempt, timely && result == GuardianIngestResult.BACKEND_ACCEPTED,
                timely && result == GuardianIngestResult.AUTHORIZATION_DENIED, now)
        } catch (_: Exception) { failClosed() }
    }

    private fun nextWake(): Long? {
        val snapshot = authority() ?: return null
        return snapshot.alerts.filter { it.state in ACTIVE_STATES }.minOfOrNull { it.nextAttemptAtElapsedMillis }
    }

    private fun matches(snapshot: GuardianVaultSnapshot?, attempt: GuardianDispatchAttempt) =
        snapshot?.lease == attempt.lease && snapshot.alerts.any { it == attempt.alert }

    private fun deadlinePassed(start: GuardianClock, now: GuardianClock) = now.bootId != start.bootId ||
        now.epochMillis < start.epochMillis || now.elapsedMillis < start.elapsedMillis ||
        now.epochMillis - start.epochMillis >= NETWORK_DEADLINE_MILLIS ||
        now.elapsedMillis - start.elapsedMillis >= NETWORK_DEADLINE_MILLIS

    private fun deadline(start: Long) = if (start > Long.MAX_VALUE - NETWORK_DEADLINE_MILLIS) Long.MAX_VALUE
        else start + NETWORK_DEADLINE_MILLIS

    private fun failClosed() { unavailable = true; invalidate() }

    override fun close() {
        if (closed) return
        closed = true
        invalidate()
        runCatching { runner.close() }
    }

    private companion object {
        const val NETWORK_DEADLINE_MILLIS = 10_000L
        val ACTIVE_STATES = setOf(GuardianSendState.CANCELLABLE, GuardianSendState.QUEUED)
    }
}
