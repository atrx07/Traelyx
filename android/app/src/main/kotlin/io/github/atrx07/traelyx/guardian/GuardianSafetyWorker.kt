package io.github.atrx07.traelyx.guardian

import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.telemetry.FrameVector3
import java.util.PriorityQueue
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Optional, bounded sidecar. Acquisition only offers; recorder persistence owns its own queue.
 * Missing/late/overflow evidence disables this worker until a new explicit activation.
 * No sensor subscriptions, sampling changes, wake lock, or exception propagation to recording.
 */
class GuardianSafetyWorker(
    forward: FrameVector3,
    restoredCooldowns: GuardianSafetyCooldowns = GuardianSafetyCooldowns(),
    private val onDetection: (GuardianDetection) -> Unit,
) : AutoCloseable {
    private val queue = ArrayBlockingQueue<Input>(1024)
    private val stopped = AtomicBoolean(false)
    private val evaluator = GuardianSafetyEvaluator(forward, restoredCooldowns)
    @Volatile var cooldowns = restoredCooldowns
        private set
    @Volatile var failed = false
        private set
    @Volatile var availability = GuardianEvaluationAvailability.CALIBRATING
        private set
    private val worker = Thread(::run, "guardian-safety-v1").apply { isDaemon = true; start() }

    fun offer(sample: RawGnssSample) = offer(Input(sample.sourceTimestampNanos, 0, sample, null))
    fun offer(sample: RawImuSample) = offer(Input(sample.sourceTimestampNanos,
        if (sample.sensorType == ImuSensorType.GYROSCOPE) 1 else 2, null, sample))

    private fun offer(input: Input) {
        if (stopped.get()) return
        if (!queue.offer(input)) fail()
    }

    private fun fail() {
        failed = true
        availability = GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE
        stopped.set(true)
        queue.clear()
        worker.interrupt()
    }

    private fun run() {
        val reorder = PriorityQueue<Input>(compareBy<Input> { it.time }.thenBy { it.order })
        var newest = 0L
        var released = -1L
        var lastArrival: Long? = null
        try {
            while (!stopped.get()) {
                val input = queue.poll(250, TimeUnit.MILLISECONDS)
                if (input == null) {
                    if (lastArrival?.let { System.nanoTime() - it > 1_500_000_000L } == true) fail()
                    continue
                }
                lastArrival = System.nanoTime()
                if (input.time < released || reorder.size >= 1024) {
                    fail()
                    break
                }
                newest = maxOf(newest, input.time)
                reorder.add(input)
                while (reorder.isNotEmpty() && reorder.peek().time <= newest - 2_000_000_000L && !stopped.get()) {
                    val next = reorder.remove()
                    released = next.time
                    next.motion?.let(evaluator::accept)
                    next.fix?.let { fix ->
                        val detections = evaluator.accept(fix)
                        cooldowns = evaluator.cooldownSnapshot()
                        detections.forEach { if (!stopped.get()) onDetection(it) }
                    }
                    availability = evaluator.availability
                }
            }
        } catch (_: InterruptedException) {
            if (!stopped.get()) fail()
        } catch (_: Exception) {
            fail()
        } finally {
            evaluator.invalidate()
            reorder.clear()
            queue.clear()
        }
    }

    override fun close() {
        stopped.set(true)
        worker.interrupt()
        if (Thread.currentThread() !== worker) worker.join(1000)
        availability = GuardianEvaluationAvailability.DISABLED
    }

    private data class Input(val time: Long, val order: Int, val fix: RawGnssSample?, val motion: RawImuSample?)
}
