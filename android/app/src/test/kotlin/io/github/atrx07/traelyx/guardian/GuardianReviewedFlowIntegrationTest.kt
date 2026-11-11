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
    private val otherOwner = "44444444-4444-4444-8444-444444444444"
    private val otherActivation = "55555555-5555-4555-8555-555555555555"
    private val otherEvent = "66666666-6666-4666-8666-666666666666"

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
        var nextActivation = activation
        var nextEvent = event
        fun newCoordinator() = GuardianActivationCoordinator(outbox, { now }, journal,
            { nextActivation }, { "a".repeat(64) })
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
                outbox.enqueue(lease.ownerId, lease.activationId, detection, cooldowns, clock, nextEvent)
                schedule.refresh()
            }, { schedule.invalidate(); coordinator.disable(it); schedule.refresh() },
            { posted.addLast(it) }, createWorker = { _, _, detected, _ ->
                DetectionWorker(detected).also { workers.add(it) }
            })
        val bridge = GuardianActivationBridge(coordinator,
            pendingAlerts = controls::views, cancelAlert = controls::cancel, sendingPilotAvailable = true)

        fun activate(sending: Boolean = true, expectedOwner: String = owner) {
            coordinator.bindOwner(expectedOwner)
            val args = mapOf("ownerId" to expectedOwner, "forwardAxis" to "+y", "rigidMountConfirmed" to true)
            bridge.dispatch(if (sending) GuardianActivationBridge.BEGIN_SENDING else GuardianActivationBridge.BEGIN,
                if (sending) args + mapOf("sendingAcknowledged" to true, "sendingReviewVersion" to 1) else args)
            bridge.dispatch(GuardianActivationBridge.COMMIT, mapOf("ownerId" to expectedOwner,
                "activationId" to nextActivation, "serverExpiresEpochMillis" to now.epochMillis + 28_800_000))
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
        fun bindOwner(nextOwner: String?) {
            // Production host order: invalidate permits/offers, bind, then refresh both consumers.
            schedule.invalidate()
            bridge.dispatch(GuardianActivationBridge.BIND_OWNER, mapOf("ownerId" to nextOwner))
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

    @Test fun `Auth loss stops evaluation at cancellation queued and in-flight phases without stopping raw recording`() {
        for (phase in 0..2) {
            val f = Fixture()
            f.activate(); val handle = f.start(); f.detect(); f.drain()
            f.runFor(if (phase == 0) 10_000 else 30_000)
            val staleWake = f.wakes.last()
            val task = f.runner.tasks.singleOrNull()
            if (phase == 2) assertTrue(task!!.permit.tryBegin())
            val worker = f.workers.single()
            f.advance(1); f.detect(worker) // Detection queued before the identity callback.
            f.bindOwner(null)
            assertTrue(worker.closed)
            assertFalse(f.session.isEvaluating)
            assertFalse(handle.isClosed) // Guardian teardown must not stop the raw trip.
            assertFalse(f.coordinator.sendingReviewed())
            if (task != null) {
                assertFalse(task.permit.tryBegin())
                task.complete(GuardianIngestResult.BACKEND_ACCEPTED)
            }
            f.drain(); staleWake.action()
            f.bindOwner(owner) // Returning identity alone cannot activate or restore consent.
            f.detect(worker); f.drain(); f.runFor(60_000)
            assertNull(f.coordinator.snapshot(owner).lease)
            assertTrue(f.vault.value.alerts.isEmpty())
            assertEquals(listOf(GuardianDriverRevokeTicket(owner, activation)), f.coordinator.pendingRevokes(owner))
            assertEquals(1, f.workers.size)
            assertEquals(if (phase == 0) 0 else 1, f.runner.tasks.size)
            assertTrue(f.notices.visible.isEmpty())
            assertFalse(f.wakes.any { !it.cancelled })
        }
    }

    @Test fun `account replacement isolates old evidence cleanup and completion while new reviewed work waits`() {
        for (alreadyStarted in listOf(false, true)) {
            val f = Fixture()
            f.activate(); val handle = f.start(); f.detect(); f.drain(); f.runFor(30_000)
            val oldTask = f.runner.tasks.single()
            if (alreadyStarted) assertTrue(oldTask.permit.tryBegin())
            val oldWorker = f.workers.single()
            f.advance(1); f.detect(oldWorker)
            f.bindOwner(otherOwner); f.drain()
            assertTrue(oldWorker.closed)
            assertFalse(f.session.isEvaluating)
            assertFalse(handle.isClosed)
            assertFalse(oldTask.permit.tryBegin())
            assertFalse(f.coordinator.sendingReviewed())
            assertTrue(f.coordinator.pendingRevokes(otherOwner).isEmpty())
            assertNull(f.vault.value.lease)
            assertTrue(f.vault.value.alerts.isEmpty())

            f.nextActivation = otherActivation; f.nextEvent = otherEvent
            f.activate(expectedOwner = otherOwner); f.detect(); f.drain(); f.runFor(30_000)
            assertTrue(f.session.isEvaluating)
            assertEquals(1, f.runner.tasks.size) // The old unsettled IO retains its slot.
            assertEquals(1, f.transportConstructed)
            oldTask.complete(GuardianIngestResult.BACKEND_ACCEPTED); f.drain()
            val newTask = f.runner.tasks.last()
            assertEquals(2, f.runner.tasks.size)
            assertEquals(otherOwner, newTask.attempt.lease.ownerId)
            assertEquals(otherActivation, newTask.attempt.lease.activationId)
            assertEquals(otherEvent, newTask.attempt.alert.eventId)
            val replacement = f.vault.value
            f.detect(oldWorker); oldTask.complete(GuardianIngestResult.AUTHORIZATION_DENIED); f.drain()
            assertEquals(replacement, f.vault.value)
            assertEquals(listOf(GuardianDriverRevokeTicket(otherOwner, otherActivation)),
                f.coordinator.pendingRevokes(otherOwner))
            assertTrue(GuardianDriverRevokeTicket(owner, activation) in f.journal.pending())
            assertTrue(newTask.permit.tryBegin())
            newTask.complete(GuardianIngestResult.BACKEND_ACCEPTED); f.drain()
            assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
            assertTrue(f.notices.visible.isEmpty())
            assertFalse(f.wakes.any { !it.cancelled })
        }
    }

    @Test fun `cancelled evidence stays cancelled while another event retries after trip stop`() {
        val f = Fixture()
        f.activate(); val handle = f.start(); f.detect(); f.drain()
        val staleWake = f.wakes.last()
        assertEquals(true, f.bridge.dispatch(GuardianActivationBridge.CANCEL_ALERT,
            mapOf("ownerId" to owner, "activationId" to activation, "eventId" to event)))
        f.advance(1); f.nextEvent = otherEvent; f.detect(); f.drain()
        f.schedule.refresh()
        val worker = f.workers.single()
        f.advance(1); f.detect(worker) // Stopping the trip discards even an already queued detection.
        f.session.stop(handle); f.drain(); staleWake.action()
        assertTrue(worker.closed)
        assertFalse(f.session.isEvaluating)
        f.runFor(29_999)
        val first = f.runner.tasks.single()
        assertEquals(otherEvent, first.attempt.alert.eventId)
        assertTrue(first.permit.tryBegin())
        first.complete(GuardianIngestResult.UNCONFIRMED); f.drain()
        f.runFor(4_999)
        assertEquals(1, f.runner.tasks.size)
        f.runFor(1)
        val retry = f.runner.tasks.last()
        assertEquals(2, f.runner.tasks.size)
        assertEquals(first.attempt.lease, retry.attempt.lease)
        assertEquals(otherEvent, retry.attempt.alert.eventId)
        assertEquals(2, retry.attempt.alert.attempts)
        assertTrue(retry.permit.tryBegin())
        retry.complete(GuardianIngestResult.BACKEND_ACCEPTED); f.drain(); f.runFor(60_000)
        val cancelled = f.vault.value.alerts.single { it.eventId == event }
        assertEquals(GuardianSendState.CANCELLED, cancelled.state)
        assertEquals(0, cancelled.attempts)
        assertEquals(GuardianSendState.BACKEND_ACCEPTED,
            f.vault.value.alerts.single { it.eventId == otherEvent }.state)
        assertEquals(2, f.vault.value.alerts.size)
        assertTrue(f.runner.tasks.all { it.attempt.alert.eventId == otherEvent })
        assertEquals(1, f.workers.size)
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
