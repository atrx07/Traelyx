package io.github.atrx07.traelyx.guardian

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class GuardianOutboxDispatchTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"
    private val other = "44444444-4444-4444-8444-444444444444"
    private val start = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
    private fun lease() = GuardianDriverLease(owner, activation, "a".repeat(64), start.epochMillis,
        start.elapsedMillis, start.epochMillis + 28_800_000, start.bootId, "+y")
    private class Vault : GuardianVault {
        var value = GuardianVaultSnapshot()
        var failWrite = false
        override fun read() = value
        override fun write(snapshot: GuardianVaultSnapshot) {
            check(!failWrite) { "synthetic storage failure" }
            value = snapshot
        }
        override fun erase() { value = GuardianVaultSnapshot() }
    }
    private class Runner : GuardianIngestRunner {
        data class Task(val attempt: GuardianDispatchAttempt, val permit: GuardianDispatchPermit,
            val complete: (GuardianIngestResult) -> Unit)
        val tasks = mutableListOf<Task>()
        var reject = false
        var throwSubmit = false
        var inline: GuardianIngestResult? = null
        var closed = false
        override fun submit(attempt: GuardianDispatchAttempt, permit: GuardianDispatchPermit,
            complete: (GuardianIngestResult) -> Unit): Boolean {
            check(!throwSubmit) { "synthetic submit failure" }
            if (reject) return false
            val task = Task(attempt, permit, complete)
            tasks.add(task)
            inline?.let { if (permit.tryBegin()) complete(it) }
            return true
        }
        fun reply(index: Int = tasks.lastIndex, result: GuardianIngestResult = GuardianIngestResult.BACKEND_ACCEPTED) {
            tasks[index].complete(result)
        }
        override fun close() { closed = true }
    }
    private inner class Fixture {
        val vault = Vault()
        val outbox = GuardianOutbox(vault)
        val runner = Runner()
        val callbacks = ArrayDeque<() -> Unit>()
        var time = start
        var enabled = false
        var allowed = true
        var bound = true
        var failAuthority = false
        var failClock = false
        var inlineControl = false
        var ownerId = owner
        val coordinator = GuardianOutboxDispatchCoordinator(outbox, {
            check(!failAuthority) { "synthetic private details" }
            if (bound) outbox.recover(ownerId, time) else null
        }, { check(!failClock); time }, { enabled }, { allowed }, runner, { action ->
            if (inlineControl) action() else callbacks.addLast(action)
        })
        init {
            outbox.activate(lease(), start)
            outbox.enqueue(owner, activation,
                GuardianDetection(GuardianAlertKind.POSSIBLE_CRASH, 9_000_000_000, 10_000_000_000),
                GuardianSafetyCooldowns(10_000_000_000, 10_000_000_000), start, event)
        }
        fun advance(delta: Long) { time = start.copy(epochMillis = start.epochMillis + delta,
            elapsedMillis = start.elapsedMillis + delta) }
        fun ready() { enabled = true; advance(30_000) }
        fun drain() { while (callbacks.isNotEmpty()) callbacks.removeFirst().invoke() }
        fun alert() = vault.value.alerts.single()
    }

    @Test fun `disabled missing authority and unavailable cancellation affordance reserve nothing`() {
        val f = Fixture()
        f.advance(30_000)
        assertNull(f.coordinator.pump())
        f.enabled = true; f.bound = false
        assertNull(f.coordinator.pump())
        f.bound = true; f.allowed = false
        assertNull(f.coordinator.pump())
        assertEquals(0, f.alert().attempts)
        assertTrue(f.runner.tasks.isEmpty())
    }

    @Test fun `only one due wake is returned during cancellation and reservation precedes submission`() {
        val f = Fixture()
        f.enabled = true
        assertEquals(start.elapsedMillis + 30_000, f.coordinator.pump())
        f.advance(29_999)
        assertEquals(start.elapsedMillis + 30_000, f.coordinator.pump())
        assertTrue(f.runner.tasks.isEmpty())
        f.advance(30_000)
        assertEquals(start.elapsedMillis + 40_000, f.coordinator.pump())
        assertEquals(1, f.alert().attempts)
        assertEquals(f.alert(), f.runner.tasks.single().attempt.alert)
        repeat(5) { assertEquals(start.elapsedMillis + 40_000, f.coordinator.pump()) }
        assertEquals(1, f.runner.tasks.size)
    }

    @Test fun `completion is marshalled and backend acceptance never becomes receipt or display`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        assertTrue(f.runner.tasks.single().permit.tryBegin())
        f.runner.reply()
        assertEquals(GuardianSendState.QUEUED, f.alert().state)
        f.drain()
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
        assertNull(f.coordinator.pump())
        f.runner.reply(); f.drain() // Duplicate callback cannot perform another transition.
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
    }

    @Test fun `exact cancellation survives reopen but cannot retract a reserved attempt`() {
        val f = Fixture()
        assertFalse(f.coordinator.cancel(other, activation, event))
        assertFalse(f.coordinator.cancel(owner, other, event))
        assertFalse(f.coordinator.cancel(owner, activation, "invalid"))
        assertEquals(lease(), f.vault.value.lease)
        assertTrue(f.coordinator.cancel(owner, activation, event))
        f.ready()
        assertNull(f.coordinator.pump())
        assertNull(GuardianOutbox(f.vault).reserveNext(owner, f.time))
        val reserved = Fixture(); reserved.ready(); reserved.coordinator.pump()
        assertFalse(reserved.coordinator.cancel(owner, activation, event))
        assertEquals(1, reserved.alert().attempts)
    }

    @Test fun `queued invalidation prevents handoff and late callbacks cannot restore a replacement`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        f.coordinator.invalidate()
        assertFalse(f.runner.tasks.single().permit.tryBegin())
        f.outbox.activate(lease().copy(activationId = other), f.time)
        f.runner.reply(); f.drain()
        assertEquals(other, f.vault.value.lease?.activationId)
        assertTrue(f.vault.value.alerts.isEmpty())
        assertNull(f.coordinator.pump())
    }

    @Test fun `owner loss disable or gate withdrawal ignores an in-flight accepted callback`() {
        for (change in 0..2) {
            val f = Fixture(); f.ready(); f.coordinator.pump()
            assertTrue(f.runner.tasks.single().permit.tryBegin())
            when (change) {
                0 -> f.bound = false
                1 -> f.enabled = false
                2 -> f.allowed = false
            }
            assertNull(f.coordinator.pump())
            f.runner.reply(); f.drain()
            assertEquals(GuardianSendState.QUEUED, f.alert().state)
        }
    }

    @Test fun `local timeout retains busy slot until actual completion and never overlaps retries`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        assertTrue(f.runner.tasks.single().permit.tryBegin())
        f.advance(40_000)
        assertNull(f.coordinator.pump())
        f.advance(50_000)
        repeat(20) { assertNull(f.coordinator.pump()) }
        assertEquals(1, f.runner.tasks.size)
        assertEquals(1, f.alert().attempts)
        f.runner.reply(); f.drain()
        assertEquals(GuardianSendState.QUEUED, f.alert().state)
        f.coordinator.pump()
        assertEquals(2, f.runner.tasks.size)
        assertEquals(event, f.runner.tasks.last().attempt.alert.eventId)
    }

    @Test fun `handoff deadline is checked even if the control timer has not run`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        f.advance(40_000)
        assertFalse(f.runner.tasks.single().permit.tryBegin())
        f.advance(30_000)
        assertFalse(f.runner.tasks.single().permit.tryBegin()) // A failed permit is single-use.
    }

    @Test fun `queued permits reject clock loss reboot and rollback before the network begins`() {
        for (change in 0..3) {
            val f = Fixture(); f.ready(); f.coordinator.pump()
            when (change) {
                0 -> f.failClock = true
                1 -> f.time = f.time.copy(bootId = "new-boot")
                2 -> f.time = f.time.copy(epochMillis = f.time.epochMillis - 1)
                3 -> f.time = f.time.copy(elapsedMillis = f.time.elapsedMillis - 1)
            }
            assertFalse(f.runner.tasks.single().permit.tryBegin())
            assertNull(f.coordinator.pump())
        }
    }

    @Test fun `late response without a timer tick still cannot claim acceptance`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        assertTrue(f.runner.tasks.single().permit.tryBegin())
        f.advance(40_000)
        f.runner.reply(); f.drain()
        assertEquals(GuardianSendState.QUEUED, f.alert().state)
    }

    @Test fun `uncertain retries preserve ID and backoff and an old callback cannot affect the retry`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        f.runner.reply(result = GuardianIngestResult.UNCONFIRMED); f.drain()
        assertEquals(start.elapsedMillis + 35_000, f.coordinator.pump())
        f.advance(35_000); f.coordinator.pump()
        assertEquals(event, f.runner.tasks.last().attempt.alert.eventId)
        assertEquals(2, f.alert().attempts)
        f.runner.reply(0); f.drain()
        assertEquals(GuardianSendState.QUEUED, f.alert().state)
        f.runner.reply(1); f.drain()
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
    }

    @Test fun `denial and all six unconfirmed attempts terminate without another reservation`() {
        val denied = Fixture(); denied.ready(); denied.coordinator.pump()
        denied.runner.reply(result = GuardianIngestResult.AUTHORIZATION_DENIED); denied.drain()
        assertEquals(GuardianSendState.CONSENT_REVOKED, denied.alert().state)
        assertNull(denied.coordinator.pump())
        val f = Fixture(); f.ready()
        repeat(6) {
            f.coordinator.pump()
            f.runner.reply(result = GuardianIngestResult.UNCONFIRMED); f.drain()
            if (it < 5) f.advance(f.alert().nextAttemptAtElapsedMillis - start.elapsedMillis)
        }
        assertEquals(6, f.runner.tasks.size)
        assertEquals(GuardianSendState.RETRIES_EXHAUSTED, f.alert().state)
        assertNull(f.coordinator.pump())
    }

    @Test fun `submission rejection remains a durable retry without a busy loop`() {
        val f = Fixture(); f.ready(); f.runner.reject = true
        assertEquals(start.elapsedMillis + 35_000, f.coordinator.pump())
        assertEquals(1, f.alert().attempts)
        assertEquals(start.elapsedMillis + 35_000, f.coordinator.pump())
        assertTrue(f.runner.tasks.isEmpty())
        assertFalse(f.coordinator.unavailable)
    }

    @Test fun `control persistence authority or submit failure fails closed without another handoff`() {
        for (failure in 0..2) {
            val f = Fixture(); f.ready()
            when (failure) {
                0 -> f.vault.failWrite = true
                1 -> f.failAuthority = true
                2 -> f.runner.throwSubmit = true
            }
            assertNull(f.coordinator.pump())
            assertTrue(f.coordinator.unavailable)
            assertNull(f.coordinator.pump())
            assertTrue(f.runner.tasks.isEmpty())
        }
    }

    @Test fun `completion persistence failure disables dispatch and never loops`() {
        val f = Fixture(); f.ready(); f.coordinator.pump()
        f.vault.failWrite = true
        f.runner.reply(); f.drain()
        assertTrue(f.coordinator.unavailable)
        assertNull(f.coordinator.pump())
        assertEquals(1, f.alert().attempts)
    }

    @Test fun `inline completion cannot race job assignment and close invalidates queued work`() {
        val f = Fixture(); f.ready(); f.inlineControl = true
        f.runner.inline = GuardianIngestResult.BACKEND_ACCEPTED
        assertNull(f.coordinator.pump())
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
        val pending = Fixture(); pending.ready(); pending.coordinator.pump()
        pending.coordinator.close(); pending.coordinator.close()
        assertTrue(pending.runner.closed)
        assertFalse(pending.runner.tasks.single().permit.tryBegin())
        pending.runner.reply(); pending.drain()
        assertEquals(GuardianSendState.QUEUED, pending.alert().state)
        assertNull(pending.coordinator.pump())
    }

    @Test fun `expired rebooted or backwards-clock authority never enters a network runner`() {
        for (time in listOf(start.copy(bootId = "new-boot"), start.copy(epochMillis = start.epochMillis - 1),
            start.copy(elapsedMillis = start.elapsedMillis - 1), start.copy(epochMillis = start.epochMillis + 600_000,
                elapsedMillis = start.elapsedMillis + 600_000))) {
            val f = Fixture(); f.enabled = true; f.time = time
            assertNull(f.coordinator.pump())
            assertTrue(f.runner.tasks.isEmpty())
        }
    }

    @Test fun `network worker uses a separate thread and respects cancelled or consumed permits`() {
        val f = Fixture(); f.ready()
        val attempt = f.outbox.reserveNext(owner, f.time)!!
        val calls = AtomicInteger()
        val callback = CountDownLatch(1)
        val caller = Thread.currentThread()
        val worker = GuardianIngestWorker {
            assertNotSame(caller, Thread.currentThread())
            calls.incrementAndGet()
            GuardianIngestResult.BACKEND_ACCEPTED
        }
        try {
            val cancelled = GuardianDispatchPermit().also { it.cancel() }
            assertTrue(worker.submit(attempt, cancelled) { callback.countDown() })
            assertTrue(callback.await(3, TimeUnit.SECONDS))
            assertEquals(0, calls.get())
            val complete = CountDownLatch(1)
            val permit = GuardianDispatchPermit()
            assertTrue(worker.submit(attempt, permit) { assertEquals(GuardianIngestResult.BACKEND_ACCEPTED, it); complete.countDown() })
            assertTrue(complete.await(3, TimeUnit.SECONDS))
            assertEquals(1, calls.get())
            assertFalse(permit.tryBegin())
        } finally { worker.close() }
        assertFalse(worker.submit(attempt, GuardianDispatchPermit()) { fail("Closed worker callback") })
    }

    @Test fun `network exceptions return a redacted unconfirmed result without killing the worker`() {
        val f = Fixture(); f.ready()
        val attempt = f.outbox.reserveNext(owner, f.time)!!
        val calls = AtomicInteger()
        val worker = GuardianIngestWorker {
            if (calls.incrementAndGet() == 1) error("synthetic private details")
            GuardianIngestResult.BACKEND_ACCEPTED
        }
        try {
            for (expected in listOf(GuardianIngestResult.UNCONFIRMED, GuardianIngestResult.BACKEND_ACCEPTED)) {
                val complete = CountDownLatch(1)
                assertTrue(worker.submit(attempt, GuardianDispatchPermit()) {
                    assertEquals(expected, it); complete.countDown()
                })
                assertTrue(complete.await(3, TimeUnit.SECONDS))
            }
            assertEquals(2, calls.get())
        } finally { worker.close() }
    }

    @Test fun `stalled network executor has bounded capacity and does not block its submitter`() {
        val f = Fixture(); f.ready()
        val attempt = f.outbox.reserveNext(owner, f.time)!!
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val drained = CountDownLatch(2)
        val calls = AtomicInteger()
        val worker = GuardianIngestWorker {
            calls.incrementAndGet(); entered.countDown()
            release.await(10, TimeUnit.SECONDS)
            GuardianIngestResult.UNCONFIRMED
        }
        try {
            assertTrue(worker.submit(attempt, GuardianDispatchPermit()) { drained.countDown() })
            assertTrue(entered.await(3, TimeUnit.SECONDS))
            val queued = GuardianDispatchPermit()
            assertTrue(worker.submit(attempt, queued) { drained.countDown() })
            assertFalse(worker.submit(attempt, GuardianDispatchPermit()) { fail("Rejected task callback") })
            queued.cancel()
            release.countDown()
            assertTrue(drained.await(3, TimeUnit.SECONDS))
            assertEquals(1, calls.get())
        } finally { release.countDown(); worker.close() }
    }
}
