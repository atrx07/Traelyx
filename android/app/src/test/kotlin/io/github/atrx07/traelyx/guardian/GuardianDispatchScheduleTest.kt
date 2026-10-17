package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianDispatchScheduleTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"
    private val other = "44444444-4444-4444-8444-444444444444"
    private val start = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
    private class Vault : GuardianVault {
        var value = GuardianVaultSnapshot()
        override fun read() = value
        override fun write(snapshot: GuardianVaultSnapshot) { value = snapshot }
        override fun erase() { value = GuardianVaultSnapshot() }
    }
    private class Notices : GuardianCancellationNotice {
        var enabled = true
        var observed = true
        var shown = false
        var fail = false
        var shows = 0
        override fun available(): Boolean { check(!fail); return enabled }
        override fun show(reference: GuardianEventReference, expiresAfterMillis: Long): Boolean {
            shows++; shown = true; return observed
        }
        override fun present(reference: GuardianEventReference) = shown && observed
        override fun remove(reference: GuardianEventReference) { shown = false }
    }
    private class Runner : GuardianIngestRunner {
        data class Task(val attempt: GuardianDispatchAttempt, val permit: GuardianDispatchPermit,
            val complete: (GuardianIngestResult) -> Unit)
        val tasks = mutableListOf<Task>()
        var closed = false
        override fun submit(attempt: GuardianDispatchAttempt, permit: GuardianDispatchPermit,
            complete: (GuardianIngestResult) -> Unit): Boolean {
            tasks.add(Task(attempt, permit, complete)); return true
        }
        override fun close() { closed = true }
    }
    private inner class Fixture(defaultGate: Boolean = false) {
        var now = start
        var enabled = true
        var bound = true
        var failClock = false
        var failSchedule = false
        var constructed = 0
        val vault = Vault()
        val box = GuardianOutbox(vault)
        val notices = Notices()
        val runner = Runner()
        val callbacks = ArrayDeque<() -> Unit>()
        inner class Wake(val at: Long, val action: () -> Unit) : GuardianScheduledWake {
            var cancelled = false
            override fun cancel() { cancelled = true }
        }
        val wakes = mutableListOf<Wake>()
        val lease = GuardianDriverLease(owner, activation, "a".repeat(64), start.epochMillis,
            start.elapsedMillis, start.epochMillis + 28_800_000, start.bootId, "+y")
        fun snapshot() = if (bound) box.recover(owner, now) else null
        fun clock(): GuardianClock { check(!failClock); return now }
        val controls = GuardianCancellationControls(box, ::snapshot, ::clock, notices)
        private val factory: (post: (() -> Unit) -> Unit) -> GuardianOutboxDispatchCoordinator = { post ->
            constructed++
            GuardianOutboxDispatchCoordinator(box, ::snapshot, ::clock, { enabled }, controls::allows, runner, post)
        }
        private val schedule: (Long, () -> Unit) -> GuardianScheduledWake = { delay, action ->
            check(!failSchedule); check(delay > 0)
            Wake(now.elapsedMillis + delay, action).also { wakes.add(it) }
        }
        val host = if (defaultGate) GuardianDispatchSchedule(controls, ::clock,
            createDispatch = factory, postControl = { callbacks.addLast(it) }, schedule = schedule)
        else GuardianDispatchSchedule(controls, ::clock, { enabled }, factory, { callbacks.addLast(it) }, schedule)
        init { box.activate(lease, now); enqueue() }
        fun enqueue(id: String = event) {
            box.enqueue(owner, activation, GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, 0, 10_000_000_000),
                GuardianSafetyCooldowns(10_000_000_000, null), now, id)
        }
        fun move(ms: Long) { now = now.copy(epochMillis = now.epochMillis + ms, elapsedMillis = now.elapsedMillis + ms) }
        fun runFor(ms: Long) {
            val end = now.elapsedMillis + ms
            var calls = 0
            while (true) {
                val next = wakes.filter { !it.cancelled && it.at <= end }.minByOrNull { it.at } ?: break
                check(++calls <= 1_000) { "Unbounded timer loop" }
                move(maxOf(0, next.at - now.elapsedMillis)); next.cancelled = true; next.action()
            }
            move(end - now.elapsedMillis)
        }
        fun drain() { while (callbacks.isNotEmpty()) callbacks.removeFirst()() }
        fun reply(result: GuardianIngestResult = GuardianIngestResult.BACKEND_ACCEPTED) {
            runner.tasks.last().complete(result); drain()
        }
        fun alert() = vault.value.alerts.first { it.eventId == event }
        fun activeWakes() = wakes.count { !it.cancelled }
    }

    @Test fun `default unavailable gate never constructs network worker or reserves`() {
        val f = Fixture(defaultGate = true); f.host.refresh(); f.runFor(599_999)
        assertEquals(0, f.constructed); assertTrue(f.runner.tasks.isEmpty())
        assertEquals(0, f.alert().attempts); f.runFor(1)
        assertTrue(f.vault.value.alerts.isEmpty()); assertEquals(0, f.activeWakes())
        assertFalse(f.notices.shown)
    }
    @Test fun `empty authority stays idle without timer or IO`() {
        val f = Fixture(); f.bound = false; f.host.refresh()
        assertTrue(f.wakes.isEmpty()); assertTrue(f.runner.tasks.isEmpty())
    }
    @Test fun `independent one-shot wakes complete observed window after recorder ends`() {
        val f = Fixture(); f.host.refresh(); f.runFor(29_999)
        assertTrue(f.runner.tasks.isEmpty()); assertEquals(0, f.alert().attempts)
        assertEquals(1, f.activeWakes()); f.runFor(1)
        assertEquals(1, f.runner.tasks.size); assertEquals(1, f.alert().attempts)
        assertTrue(f.runner.tasks.single().permit.tryBegin())
        f.reply(); assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.alert().state)
        assertEquals(0, f.activeWakes()); assertFalse(f.notices.shown)
    }
    @Test fun `asynchronous notice observation starts a new full window`() {
        val f = Fixture(); f.notices.observed = false; f.host.refresh()
        f.runFor(1_000); f.notices.observed = true; f.runFor(1_000)
        f.runFor(29_999); assertTrue(f.runner.tasks.isEmpty())
        f.runFor(1); assertEquals(1, f.runner.tasks.size)
    }
    @Test fun `unobserved confirmation polling is bounded then only expiry wakes`() {
        val f = Fixture(); f.notices.observed = false; f.host.refresh(); f.runFor(100_000)
        // Four initial checks, plus the dispatcher's one initial event-age wake.
        assertEquals(5, f.notices.shows); assertEquals(1, f.activeWakes())
        assertEquals(start.elapsedMillis + 600_000, f.wakes.last().at)
        assertTrue(f.runner.tasks.isEmpty()); f.runFor(500_000)
        assertEquals(0, f.activeWakes()); assertFalse(f.notices.shown)
    }
    @Test fun `blocked notifications do not create periodic polls or reservations`() {
        val f = Fixture(); f.notices.enabled = false; f.host.refresh(); f.runFor(599_999)
        assertEquals(0, f.notices.shows); assertEquals(2, f.wakes.size)
        assertTrue(f.runner.tasks.isEmpty()); f.runFor(1); assertEquals(0, f.activeWakes())
    }
    @Test fun `dismissal during window removes proof and cannot send or repost`() {
        val f = Fixture(); f.host.refresh(); f.runFor(10_000)
        f.notices.observed = false; f.runFor(50_000)
        assertEquals(1, f.notices.shows); assertTrue(f.runner.tasks.isEmpty())
        assertEquals(start.elapsedMillis + 600_000, f.wakes.last().at)
    }
    @Test fun `durable cancel cancels timer and cannot be undone by dequeued wake`() {
        val f = Fixture(); f.host.refresh(); val old = f.wakes.single()
        assertTrue(f.controls.cancel(GuardianEventReference(owner, activation, event))); f.host.refresh()
        old.action(); f.runFor(60_000)
        assertEquals(GuardianSendState.CANCELLED, f.alert().state)
        assertTrue(f.runner.tasks.isEmpty()); assertEquals(0, f.activeWakes())
    }
    @Test fun `repeated refresh replaces rather than accumulates active wakes`() {
        val f = Fixture(); repeat(20) { f.host.refresh(); assertEquals(1, f.activeWakes()) }
        f.runFor(30_000); assertEquals(1, f.runner.tasks.size); assertEquals(1, f.activeWakes())
    }
    @Test fun `completion marshals to control and schedules exact persisted retry`() {
        val f = Fixture(); f.host.refresh(); f.runFor(30_000)
        f.runner.tasks.single().complete(GuardianIngestResult.UNCONFIRMED)
        assertTrue(f.notices.shown); assertEquals(1, f.callbacks.size)
        f.drain(); assertFalse(f.notices.shown)
        f.runFor(4_999); assertEquals(1, f.runner.tasks.size)
        f.runFor(1); assertEquals(2, f.runner.tasks.size); assertEquals(2, f.alert().attempts)
    }
    @Test fun `deadline never releases stuck IO slot or creates repeated polling`() {
        val f = Fixture(); f.host.refresh(); f.runFor(40_000)
        assertFalse(f.runner.tasks.single().permit.tryBegin())
        f.runFor(100_000); assertEquals(1, f.runner.tasks.size)
        assertEquals(start.elapsedMillis + 600_000, f.wakes.last().at)
        f.reply(); assertEquals(2, f.runner.tasks.size) // Retry only once the old transport drains.
    }
    @Test fun `stop invalidates queued handoff before clearing authority`() {
        val f = Fixture(); f.host.refresh(); f.runFor(30_000)
        f.host.invalidate(); f.bound = false; f.host.refresh()
        assertFalse(f.runner.tasks.single().permit.tryBegin()); f.reply()
        assertEquals(1, f.runner.tasks.size); assertEquals(0, f.activeWakes())
    }
    @Test fun `replacement cannot create a second runner or bypass old unsettled operation`() {
        val f = Fixture(); f.host.refresh(); f.runFor(30_000)
        f.host.invalidate(); f.box.revoke()
        f.box.activate(f.lease.copy(activationId = other), f.now)
        val detected = f.now.elapsedMillis * 1_000_000
        f.box.enqueue(owner, other, GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, 0, detected),
            GuardianSafetyCooldowns(detected, null), f.now, event)
        f.host.refresh(); f.runFor(30_000)
        assertEquals(1, f.runner.tasks.size); assertEquals(1, f.constructed)
        f.reply(); assertEquals(2, f.runner.tasks.size); assertEquals(1, f.constructed)
        assertEquals(other, f.runner.tasks.last().attempt.lease.activationId)
    }
    @Test fun `disabling gate invalidates queued permit without constructing replacement`() {
        val f = Fixture(); f.host.refresh(); f.runFor(30_000)
        f.host.invalidate(); f.enabled = false; f.host.refresh()
        assertFalse(f.runner.tasks.single().permit.tryBegin()); f.reply(); f.runFor(60_000)
        assertEquals(1, f.runner.tasks.size); assertEquals(1, f.constructed)
    }
    @Test fun `clock rollback or reboot cannot authorize scheduled handoff`() {
        for (reboot in listOf(false, true)) {
            val f = Fixture(); f.host.refresh(); f.runFor(29_000)
            f.now = if (reboot) f.now.copy(bootId = "boot-2") else f.now.copy(epochMillis = start.epochMillis - 60_000)
            f.runFor(1_000); assertTrue(f.runner.tasks.isEmpty()); assertEquals(0, f.activeWakes())
        }
    }
    @Test fun `clock and timer failures fail closed and cannot restart on refresh`() {
        for (timer in listOf(false, true)) {
            val f = Fixture(); f.failClock = !timer; f.failSchedule = timer; f.host.refresh()
            f.failClock = false; f.failSchedule = false; f.host.refresh(); f.runFor(60_000)
            assertTrue(f.runner.tasks.isEmpty()); assertEquals(0, f.activeWakes())
        }
    }
    @Test fun `notification failure removes proof and does not authorize dispatch`() {
        val f = Fixture(); f.notices.fail = true; f.host.refresh(); f.runFor(60_000)
        assertTrue(f.runner.tasks.isEmpty()); assertEquals(0, f.activeWakes())
    }
    @Test fun `close invalidates timer and queued permit and late callbacks stay inert`() {
        val f = Fixture(); f.host.refresh(); f.runFor(30_000); val wake = f.wakes.last()
        f.host.close(); f.host.close(); wake.action(); f.reply(); f.host.refresh()
        assertFalse(f.runner.tasks.single().permit.tryBegin()); assertTrue(f.runner.closed)
        assertEquals(1, f.runner.tasks.size); assertEquals(0, f.activeWakes())
    }
}
