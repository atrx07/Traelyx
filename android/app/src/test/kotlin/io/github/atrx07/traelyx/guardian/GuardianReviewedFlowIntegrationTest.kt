package io.github.atrx07.traelyx.guardian

import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import org.junit.Assert.*
import org.junit.Test

/** Synthetic callbacks and virtual time only: no sensors, account, Android notice or HTTP. */
class GuardianReviewedFlowIntegrationTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"

    private class Vault : GuardianVault {
        var value = GuardianVaultSnapshot()
        override fun read() = value
        override fun write(snapshot: GuardianVaultSnapshot) { value = snapshot }
        override fun erase() { value = GuardianVaultSnapshot() }
    }

    private class Notices : GuardianCancellationNotice {
        val visible = mutableSetOf<GuardianEventReference>()
        override fun available() = true
        override fun show(reference: GuardianEventReference, expiresAfterMillis: Long): Boolean {
            visible.add(reference)
            return true
        }
        override fun present(reference: GuardianEventReference) = reference in visible
        override fun remove(reference: GuardianEventReference) { visible.remove(reference) }
    }

    private class DetectionWorker(val detected: (GuardianDetection) -> Unit) : GuardianRecordingWorker {
        override var cooldowns = GuardianSafetyCooldowns()
        override val availability = GuardianEvaluationAvailability.CALIBRATING
        var closed = false
        override fun offer(sample: RawGnssSample) = Unit
        override fun offer(sample: RawImuSample) = Unit
        override fun close() { closed = true }
    }

    private class Runner : GuardianIngestRunner {
        data class Task(val attempt: GuardianDispatchAttempt, val permit: GuardianDispatchPermit,
            val complete: (GuardianIngestResult) -> Unit)
        val tasks = mutableListOf<Task>()
        override fun submit(attempt: GuardianDispatchAttempt, permit: GuardianDispatchPermit,
            complete: (GuardianIngestResult) -> Unit): Boolean {
            tasks.add(Task(attempt, permit, complete))
            return true
        }
        override fun close() = Unit
    }

    private inner class Fixture {
        var now = GuardianClock(1_800_000_000_000, 10_000, "synthetic-boot")
        val vault = Vault()
        val journal = TestDriverRevokeJournal()
        val outbox = GuardianOutbox(vault, journal::record)
        fun newCoordinator() = GuardianActivationCoordinator(outbox, { now }, journal,
            { activation }, { "a".repeat(64) })
        var coordinator = newCoordinator()
        val notices = Notices()
        val runner = Runner()
        val posted = ArrayDeque<() -> Unit>()
        val workers = mutableListOf<DetectionWorker>()
        var transportConstructed = 0
        inner class Wake(val at: Long, val action: () -> Unit) : GuardianScheduledWake {
            var cancelled = false
            override fun cancel() { cancelled = true }
        }
        val wakes = mutableListOf<Wake>()
        val controls = GuardianCancellationControls(outbox, { coordinator.recordingSnapshot() }, { now }, notices)
        val schedule = GuardianDispatchSchedule(controls, { now }, { coordinator.sendingReviewed() },
            createDispatch = { post ->
                transportConstructed++
                GuardianOutboxDispatchCoordinator(outbox, { coordinator.recordingSnapshot() }, { now },
                    { coordinator.sendingReviewed() }, controls::allows, runner, post)
            }, postControl = { posted.addLast(it) }, schedule = { delay, action ->
                check(delay > 0)
                Wake(now.elapsedMillis + delay, action).also { wakes.add(it) }
            })
        val session = GuardianRecordingSession({ coordinator.recordingSnapshot() }, { now },
            { lease, detection, cooldowns, clock ->
                outbox.enqueue(lease.ownerId, lease.activationId, detection, cooldowns, clock, event)
                schedule.refresh()
            }, { schedule.invalidate(); coordinator.disable(it); schedule.refresh() },
            { posted.addLast(it) }, createWorker = { _, _, detected, _ ->
                DetectionWorker(detected).also { workers.add(it) }
            })
        val bridge = GuardianActivationBridge(coordinator,
            pendingAlerts = controls::views, cancelAlert = controls::cancel, sendingPilotAvailable = true)

        fun activate(sending: Boolean = true) {
            coordinator.bindOwner(owner)
            val args = mapOf("ownerId" to owner, "forwardAxis" to "+y", "rigidMountConfirmed" to true)
            bridge.dispatch(if (sending) GuardianActivationBridge.BEGIN_SENDING else GuardianActivationBridge.BEGIN,
                if (sending) args + mapOf("sendingAcknowledged" to true, "sendingReviewVersion" to 1) else args)
            bridge.dispatch(GuardianActivationBridge.COMMIT, mapOf("ownerId" to owner,
                "activationId" to activation, "serverExpiresEpochMillis" to now.epochMillis + 28_800_000))
            session.refresh()
            schedule.refresh()
        }
        fun start() = GuardianRecorderHandle().also(session::start)
        fun detect(worker: DetectionWorker = workers.last()) {
            val nanos = now.elapsedMillis * 1_000_000
            worker.cooldowns = GuardianSafetyCooldowns(nanos, null)
            worker.detected(GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, 0, nanos))
        }
        fun drain() { while (posted.isNotEmpty()) posted.removeFirst()() }
        fun advance(ms: Long) { now = now.copy(epochMillis = now.epochMillis + ms, elapsedMillis = now.elapsedMillis + ms) }
        fun runFor(ms: Long) {
            val end = now.elapsedMillis + ms
            var calls = 0
            while (true) {
                val wake = wakes.filter { !it.cancelled && it.at <= end }.minByOrNull { it.at } ?: break
                check(++calls <= 1_000) { "Unbounded synthetic timer loop" }
                advance(maxOf(0, wake.at - now.elapsedMillis))
                wake.cancelled = true
                wake.action()
                drain()
            }
            advance(end - now.elapsedMillis)
        }
        fun stop() {
            // Same ordering as the Android host: invalidate queued permits before mutating authority.
            schedule.invalidate()
            bridge.dispatch(GuardianActivationBridge.STOP, mapOf("ownerId" to owner))
            session.refresh()
            schedule.refresh()
        }
        fun alert() = vault.value.alerts.single()
    }

    @Test fun `old evaluation review can enqueue but cannot construct transport or reserve`() {
        val f = Fixture()
        f.activate(sending = false)
        f.start()
        f.detect(); f.drain(); f.runFor(60_000)
        assertEquals(GuardianSendState.QUEUED, f.alert().state)
        assertEquals(0, f.alert().attempts)
        assertEquals(0, f.transportConstructed)
        assertTrue(f.runner.tasks.isEmpty())
        assertFalse(f.coordinator.sendingReviewed())
    }

    @Test fun `fresh reviewed callback waits full observed window even after recording ends`() {
        val f = Fixture()
        f.activate()
        val handle = f.start()
        f.detect(); f.drain()
        assertEquals(1, f.notices.visible.size)
        f.session.stop(handle)
        assertTrue(f.workers.single().closed)
        f.runFor(29_999)
        assertTrue(f.runner.tasks.isEmpty())
        assertEquals(0, f.alert().attempts)
        f.runFor(1)
        val task = f.runner.tasks.single()
        assertEquals(1, f.alert().attempts)
        assertEquals(owner, task.attempt.lease.ownerId)
        assertEquals(activation, task.attempt.lease.activationId)
        assertEquals(event, task.attempt.alert.eventId)
        assertTrue(task.permit.tryBegin())
        task.complete(GuardianIngestResult.BACKEND_ACCEPTED); f.drain()
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
        assertTrue(f.notices.visible.isEmpty())
        assertFalse(f.wakes.any { !it.cancelled })
    }

    @Test fun `foreground bridge cancellation persists and prevents scheduler reservation`() {
        val f = Fixture()
        f.activate(); f.start(); f.detect(); f.drain(); f.runFor(10_000)
        assertEquals(true, f.bridge.dispatch(GuardianActivationBridge.CANCEL_ALERT,
            mapOf("ownerId" to owner, "activationId" to activation, "eventId" to event)))
        f.schedule.refresh(); f.runFor(60_000)
        assertEquals(GuardianSendState.CANCELLED, f.outbox.recover(owner, f.now).alerts.single().state)
        assertEquals(0, f.alert().attempts)
        assertTrue(f.runner.tasks.isEmpty())
        assertTrue(f.notices.visible.isEmpty())
        assertFalse(f.wakes.any { !it.cancelled })
    }

    @Test fun `Stop rejects queued handoff late detection and late accepted callback`() {
        val f = Fixture()
        f.activate(); f.start(); f.detect(); f.drain(); f.runFor(30_000)
        val task = f.runner.tasks.single()
        val worker = f.workers.single()
        f.detect(worker) // Control callback already queued when Stop begins.
        f.stop()
        assertFalse(task.permit.tryBegin())
        task.complete(GuardianIngestResult.BACKEND_ACCEPTED); f.drain(); f.runFor(60_000)
        assertNull(f.vault.value.lease)
        assertTrue(f.vault.value.alerts.isEmpty())
        assertTrue(worker.closed)
        assertEquals(1, f.runner.tasks.size)
        assertEquals(listOf(GuardianDriverRevokeTicket(owner, activation)), f.coordinator.pendingRevokes(owner))
        assertTrue(f.notices.visible.isEmpty())
        assertFalse(f.wakes.any { !it.cancelled })
    }

    @Test fun `restored lease and pending event cannot resume recording or sending`() {
        val f = Fixture()
        f.activate(); val handle = f.start(); f.detect(); f.drain(); f.runFor(10_000)
        f.session.stop(handle); f.schedule.close()
        val stored = f.vault.value
        f.coordinator = f.newCoordinator()
        f.coordinator.bindOwner(owner)
        assertNotNull(f.coordinator.snapshot(owner).lease)
        assertFalse(f.coordinator.sendingReviewed())
        val workerCount = f.workers.size
        f.start()
        assertEquals(workerCount, f.workers.size)
        val restartedNotices = Notices()
        val restartedControls = GuardianCancellationControls(f.outbox,
            { f.coordinator.recordingSnapshot() }, { f.now }, restartedNotices)
        var constructed = false
        var scheduled = 0
        var callbacks = 0
        val restartedSchedule = GuardianDispatchSchedule(restartedControls, { f.now },
            { f.coordinator.sendingReviewed() }, createDispatch = { constructed = true; error("Must stay disabled") },
            postControl = { callbacks++ }, schedule = { _, _ ->
                scheduled++
                GuardianScheduledWake { }
            })
        restartedSchedule.refresh(); f.runFor(60_000)
        assertEquals(stored, f.vault.value)
        assertFalse(constructed)
        assertEquals(0, scheduled)
        assertEquals(0, callbacks)
        assertTrue(restartedNotices.visible.isEmpty())
        assertTrue(f.runner.tasks.isEmpty())
        restartedSchedule.close()
    }
}
