package io.github.atrx07.traelyx.guardian

import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import io.github.atrx07.traelyx.telemetry.FrameVector3
import java.util.concurrent.atomic.AtomicBoolean

/** Offer-only boundary: no vault, account identity or network authority on acquisition threads. */
interface GuardianRecordingWorker : AutoCloseable {
    val cooldowns: GuardianSafetyCooldowns
    val availability: GuardianEvaluationAvailability
    fun offer(sample: RawGnssSample)
    fun offer(sample: RawImuSample)
}

class GuardianRecorderHandle : AutoCloseable {
    private data class Binding(val worker: GuardianRecordingWorker, val failed: () -> Unit)
    private val closed = AtomicBoolean(false)
    @Volatile private var binding: Binding? = null
    @Volatile private var fallback = GuardianEvaluationAvailability.DISABLED
    internal val isClosed get() = closed.get()
    val availability get() = if (isClosed) GuardianEvaluationAvailability.DISABLED else binding?.worker?.availability ?: fallback

    fun offer(sample: RawGnssSample) = offer { it.offer(sample) }
    fun offer(sample: RawImuSample) = offer { it.offer(sample) }
    private inline fun offer(action: (GuardianRecordingWorker) -> Unit) {
        if (isClosed) return
        val current = binding ?: return
        try { action(current.worker) } catch (_: Exception) {
            suspend(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE)
            try { current.failed() } catch (_: Exception) { /* Never fail raw recording. */ }
        }
    }
    internal fun attach(worker: GuardianRecordingWorker, failed: () -> Unit) {
        if (!isClosed) binding = Binding(worker, failed)
    }
    internal fun suspend(state: GuardianEvaluationAvailability = GuardianEvaluationAvailability.DISABLED) {
        binding = null
        fallback = state
    }
    override fun close() { closed.set(true); suspend() }
}

/** All control/authority/disk calls run on one owner worker; only handle.offer runs on acquisition. */
class GuardianRecordingSession(
    private val authority: () -> GuardianVaultSnapshot?,
    private val clock: () -> GuardianClock,
    private val enqueue: (GuardianDriverLease, GuardianDetection, GuardianSafetyCooldowns, GuardianClock) -> Unit,
    private val revoke: (String) -> Unit,
    private val post: (() -> Unit) -> Unit,
    private val createWorker: (FrameVector3, GuardianSafetyCooldowns, (GuardianDetection) -> Unit, () -> Unit) -> GuardianRecordingWorker =
        { forward, cooldowns, detected, failed ->
            GuardianSafetyWorker(forward, cooldowns, onFailure = failed, onDetection = detected) },
) {
    private class Run(val lease: GuardianDriverLease, val handle: GuardianRecorderHandle) {
        lateinit var worker: GuardianRecordingWorker
    }
    private var handle: GuardianRecorderHandle? = null
    private var run: Run? = null
    private var blockedActivation: Pair<String, String>? = null
    val isEvaluating get() = run != null
    fun observation() = GuardianRecordingObservation(
        recording = handle?.isClosed == false,
        availability = handle?.availability ?: GuardianEvaluationAvailability.DISABLED,
    )

    /** No vault IO during valid monitoring; expiry/clock failure still stops a quiet session. */
    fun tick() {
        val current = run ?: return
        try {
            if (current.handle.isClosed) stop(current.handle)
            else if (!current.lease.valid(clock(), current.lease.ownerId)) refresh()
        } catch (_: Exception) { failed(current) }
    }

    fun start(next: GuardianRecorderHandle) {
        if (next.isClosed) return
        handle?.close()
        stopWorker()
        handle = next
        refresh()
    }

    fun stop(expected: GuardianRecorderHandle) {
        expected.close() // May already have been closed by the service before this task ran.
        if (handle !== expected) return
        stopWorker()
        handle = null
    }

    /** Binding/activation changes never restart a failed activation or reuse old calibration. */
    fun refresh() {
        val current = handle ?: return
        if (current.isClosed) { stop(current); return }
        try {
            val snapshot = authority()
            val lease = snapshot?.lease
            if (lease == null || !lease.valid(clock(), lease.ownerId)) {
                stopWorker()
                return
            }
            if (blockedActivation == (lease.ownerId to lease.activationId)) {
                stopWorker(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE)
                return
            }
            if (run?.lease == lease && run?.handle === current) return
            stopWorker()
            val next = Run(lease, current)
            run = next
            next.worker = createWorker(forward(lease.forwardAxis), snapshot.cooldowns,
                { detection -> post { detected(next, detection) } },
                { post { failed(next) } })
            current.attach(next.worker) { post { failed(next) } }
        } catch (_: Exception) {
            run?.let(::failed) ?: stopWorker(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE)
        }
    }

    private fun detected(expected: Run, detection: GuardianDetection) {
        if (run !== expected || expected.handle.isClosed) return
        if (expected.worker.availability == GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE) {
            failed(expected)
            return
        }
        try {
            val live = authority()?.lease
            val now = clock()
            if (live != expected.lease || !live.valid(now, live.ownerId)) { refresh(); return }
            if (expected.handle.isClosed) return
            enqueue(live, detection, expected.worker.cooldowns, now)
        } catch (_: Exception) { failed(expected) }
    }

    private fun failed(expected: Run) {
        if (run !== expected) return // Late failure cannot revoke replacement authority.
        blockedActivation = expected.lease.ownerId to expected.lease.activationId
        stopWorker(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE)
        try {
            if (authority()?.lease == expected.lease) revoke(expected.lease.ownerId)
        } catch (_: Exception) { /* Already stopped; cleanup failure cannot restore this run. */ }
    }

    private fun stopWorker(state: GuardianEvaluationAvailability = GuardianEvaluationAvailability.DISABLED) {
        val old = run
        run = null // Ignore callbacks even if worker shutdown fails.
        handle?.suspend(state)
        try { old?.worker?.close() } catch (_: Exception) { /* Independent raw recorder stays alive. */ }
    }

    private fun forward(axis: String): FrameVector3 = when (axis) {
        "+x" -> FrameVector3(1.0, 0.0, 0.0)
        "-x" -> FrameVector3(-1.0, 0.0, 0.0)
        "+y" -> FrameVector3(0.0, 1.0, 0.0)
        "-y" -> FrameVector3(0.0, -1.0, 0.0)
        "+z" -> FrameVector3(0.0, 0.0, 1.0)
        "-z" -> FrameVector3(0.0, 0.0, -1.0)
        else -> error("Invalid confirmed forward axis")
    }
}
