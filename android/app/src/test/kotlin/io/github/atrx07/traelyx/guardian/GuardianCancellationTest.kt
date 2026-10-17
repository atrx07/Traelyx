package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianCancellationTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"
    private val other = "44444444-4444-4444-8444-444444444444"
    private val start = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
    private val ref = GuardianEventReference(owner, activation, event)
    private class Vault : GuardianVault {
        var value = GuardianVaultSnapshot()
        var failWrite = false
        override fun read() = value
        override fun write(snapshot: GuardianVaultSnapshot) { check(!failWrite); value = snapshot }
        override fun erase() { value = GuardianVaultSnapshot() }
    }
    private class Notices : GuardianCancellationNotice {
        var enabled = true
        var observed = true
        var failShow = false
        var failRemove = false
        var shows = 0
        var lifetime = 0L
        var afterShow: () -> Unit = {}
        val removed = mutableListOf<GuardianEventReference>()
        override fun available() = enabled
        override fun present(reference: GuardianEventReference) = observed
        override fun show(reference: GuardianEventReference, expiresAfterMillis: Long): Boolean {
            shows++; lifetime = expiresAfterMillis; afterShow(); check(!failShow); return observed
        }
        override fun remove(reference: GuardianEventReference) { removed.add(reference); check(!failRemove) }
    }
    private inner class Fixture {
        var now = start
        var bound = true
        var clockFails = false
        val vault = Vault()
        val box = GuardianOutbox(vault)
        val notices = Notices()
        val lease = GuardianDriverLease(owner, activation, "a".repeat(64), start.epochMillis,
            start.elapsedMillis, start.epochMillis + 28_800_000, start.bootId, "+y")
        init {
            box.activate(lease, now)
            box.enqueue(owner, activation, GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, 0, 10_000_000_000),
                GuardianSafetyCooldowns(10_000_000_000, null), now, event)
        }
        fun snapshot(): GuardianVaultSnapshot? = if (bound) box.recover(vault.read().lease?.ownerId ?: owner, now) else null
        fun controls() = GuardianCancellationControls(box, ::snapshot, { check(!clockFails); now }, notices)
        val controls = controls()
        fun advance(ms: Long) { now = now.copy(epochMillis = now.epochMillis + ms, elapsedMillis = now.elapsedMillis + ms) }
        fun alert() = snapshot()!!.alerts.single()
    }

    @Test fun `old event age cannot replace a full observed cancellation window`() {
        val f = Fixture(); f.advance(90_000)
        assertFalse(f.controls.allows(f.alert()))
        f.controls.refresh()
        assertEquals(30_000L, f.controls.views(owner).single()["cancellationReadyInMillis"])
        f.advance(29_999); assertFalse(f.controls.allows(f.alert()))
        f.advance(1); assertTrue(f.controls.allows(f.alert()))
        assertEquals(0, f.alert().attempts)
        assertEquals(510_000L, f.notices.lifetime)
    }
    @Test fun `both clocks must complete the cancellation window`() {
        val f = Fixture(); f.controls.refresh()
        f.now = f.now.copy(elapsedMillis = f.now.elapsedMillis + 60_000)
        assertFalse(f.controls.allows(f.alert()))
        f.now = f.now.copy(epochMillis = f.now.epochMillis + 29_999)
        assertFalse(f.controls.allows(f.alert()))
        f.now = f.now.copy(epochMillis = f.now.epochMillis + 1)
        assertTrue(f.controls.allows(f.alert()))
    }
    @Test fun `blocked or unobserved notice cannot authorize sending`() {
        for (blocked in listOf(true, false)) {
            val f = Fixture(); f.notices.enabled = !blocked; f.notices.observed = false
            f.controls.refresh(); f.advance(60_000); f.controls.refresh()
            assertFalse(f.controls.allows(f.alert()))
            assertNull(f.controls.views(owner).single()["cancellationReadyInMillis"])
            assertEquals(if (blocked) 0 else 2, f.notices.shows)
            assertTrue(f.controls.cancel(ref)) // Cancellation itself does not require notification permission.
        }
    }
    @Test fun `proof starts after confirmation rather than before a slow notice call`() {
        val f = Fixture(); f.notices.afterShow = { f.advance(20_000) }
        f.controls.refresh(); f.advance(29_999)
        assertFalse(f.controls.allows(f.alert()))
        f.advance(1); assertTrue(f.controls.allows(f.alert()))
    }
    @Test fun `notice exception fails closed and removes only its attempted notice`() {
        val f = Fixture(); f.notices.failShow = true
        f.controls.refresh(); f.advance(60_000)
        assertFalse(f.controls.allows(f.alert()))
        assertFalse(f.controls.cancel(ref))
        assertEquals(listOf(ref), f.notices.removed)
        assertThrows(IllegalStateException::class.java) { f.controls.views(owner) }
    }
    @Test fun `cancellation persists first and is unavailable after reservation`() {
        val f = Fixture(); f.controls.refresh(); f.advance(30_000)
        assertTrue(f.controls.cancel(ref))
        assertEquals(GuardianSendState.CANCELLED, f.alert().state)
        assertNull(f.box.reserveNext(owner, f.now))
        assertEquals(listOf(ref), f.notices.removed)
        val g = Fixture(); g.controls.refresh(); g.advance(30_000)
        g.box.reserveNext(owner, g.now)
        assertFalse(g.controls.cancel(ref))
        assertEquals(1, g.alert().attempts)
    }
    @Test fun `failed cancellation write never reports success or grants handoff`() {
        val f = Fixture(); f.controls.refresh(); f.vault.failWrite = true
        assertFalse(f.controls.cancel(ref))
        f.vault.failWrite = false; f.advance(30_000)
        assertEquals(GuardianSendState.QUEUED, f.alert().state)
        assertFalse(f.controls.allows(f.alert()))
    }
    @Test fun `notification removal failure cannot undo durable cancellation`() {
        val f = Fixture(); f.controls.refresh(); f.notices.failRemove = true
        assertTrue(f.controls.cancel(ref))
        assertEquals(GuardianSendState.CANCELLED, f.alert().state)
        assertFalse(f.controls.allows(f.alert()))
    }
    @Test fun `wrong owner generation or event never cancels the current alert`() {
        val f = Fixture(); f.controls.refresh()
        for (wrong in listOf(ref.copy(ownerId = other), ref.copy(activationId = other), ref.copy(eventId = other))) {
            assertFalse(f.controls.cancel(wrong))
        }
        assertEquals(GuardianSendState.CANCELLABLE, f.alert().state)
        assertEquals(0, f.notices.removed.size)
    }
    @Test fun `restart or authority loss cannot reuse an in-memory offer`() {
        val f = Fixture(); f.controls.refresh(); f.advance(30_000)
        assertTrue(f.controls.allows(f.alert()))
        assertFalse(f.controls().allows(f.alert()))
        f.bound = false; f.controls.refresh()
        assertTrue(f.controls.views(owner).isEmpty())
        assertFalse(f.controls.cancel(ref))
        f.bound = true
        assertFalse(f.controls.allows(f.alert()))
        assertEquals(listOf(ref), f.notices.removed)
    }
    @Test fun `replacement and invalidation discard exact offers without touching new events`() {
        val f = Fixture(); f.controls.refresh()
        f.box.activate(f.lease.copy(ownerId = other, activationId = event), f.now)
        f.controls.refresh()
        assertEquals(listOf(ref), f.notices.removed)
        assertTrue(f.controls.views(other).isEmpty())
        assertFalse(f.controls.cancel(ref))
        val g = Fixture(); g.controls.refresh(); g.controls.invalidate(); g.advance(30_000)
        assertFalse(g.controls.allows(g.alert()))
        g.controls.refresh(); assertFalse(g.controls.allows(g.alert()))
    }
    @Test fun `expiry and reboot deny old offers and remove pending notices`() {
        for (reboot in listOf(true, false)) {
            val f = Fixture(); f.controls.refresh()
            if (reboot) f.now = f.now.copy(bootId = "boot-2") else f.advance(600_000)
            f.controls.refresh()
            assertTrue(f.controls.views(owner).isEmpty())
            assertFalse(f.controls.cancel(ref))
            assertEquals(listOf(ref), f.notices.removed)
        }
    }
    @Test fun `clock loss or rollback fails closed without dispatch or plaintext status`() {
        for (failure in listOf("clock", "wall", "elapsed")) {
            val f = Fixture(); f.advance(5_000); f.controls.refresh()
            when (failure) {
                "clock" -> f.clockFails = true
                "wall" -> f.now = f.now.copy(epochMillis = f.now.epochMillis - 1)
                "elapsed" -> f.now = f.now.copy(elapsedMillis = f.now.elapsedMillis - 1)
            }
            assertFalse(f.controls.allows(f.vault.read().alerts.single()))
            assertThrows(IllegalStateException::class.java) { f.controls.views(owner) }
            assertFalse(ref.toString().contains(owner))
        }
    }
    @Test fun `retry keeps its original offer but permission withdrawal denies handoff`() {
        val f = Fixture(); f.controls.refresh(); f.advance(30_000)
        assertTrue(f.controls.allows(f.alert()))
        val attempt = f.box.reserveNext(owner, f.now)!!
        f.controls.refresh()
        assertEquals(listOf(ref), f.notices.removed)
        assertTrue(f.controls.allows(attempt.alert))
        f.box.complete(attempt, false, false, f.now)
        f.advance(5_000); assertTrue(f.controls.allows(f.alert()))
        f.notices.enabled = false; assertFalse(f.controls.allows(f.alert()))
        assertEquals(1, f.notices.shows)
    }
    @Test fun `dismissal during the cancellation window denies sending without reposting`() {
        val f = Fixture(); f.controls.refresh(); f.advance(1_000); f.notices.observed = false
        f.controls.refresh(); f.advance(30_000); f.notices.observed = true
        f.controls.refresh()
        assertFalse(f.controls.allows(f.alert()))
        assertEquals(1, f.notices.shows)
        assertNull(f.controls.views(owner).single()["cancellationReadyInMillis"])
        assertTrue(f.controls.cancel(ref))
    }
    @Test fun `direct reservation cannot manufacture proof that the full window was offered`() {
        val f = Fixture(); f.controls.refresh(); f.advance(30_000)
        val attempt = f.box.reserveNext(owner, f.now)!!
        assertFalse(f.controls.allows(attempt.alert))
        f.controls.refresh()
        assertFalse(f.controls.allows(attempt.alert))
    }
    @Test fun `status uses only bounded allowlisted metadata and no credentials`() {
        val f = Fixture(); f.controls.refresh()
        val view = f.controls.views(owner).single()
        assertEquals(setOf("activationId", "eventId", "kind", "state", "canCancel", "cancellationReadyInMillis"), view.keys)
        assertEquals(true, view["canCancel"])
        assertFalse(view.toString().contains(f.lease.credential))
        assertThrows(IllegalArgumentException::class.java) { f.controls.views(other) }
    }
    @Test fun `forged event content cannot borrow another events cancellation offer`() {
        val f = Fixture(); f.controls.refresh(); f.advance(30_000)
        val alert = f.alert()
        assertFalse(f.controls.allows(alert.copy(eventId = other)))
        assertFalse(f.controls.allows(alert.copy(occurredAtEpochMillis = alert.occurredAtEpochMillis + 1)))
        assertFalse(f.controls.allows(alert.copy(kind = GuardianAlertKind.POSSIBLE_CRASH)))
        assertTrue(f.controls.allows(alert))
    }
    @Test fun `the full bounded outbox is offered once without growing proof state`() {
        val f = Fixture()
        repeat(GuardianVaultSnapshot.MAX_ALERTS - 1) { i ->
            f.advance(1)
            f.box.enqueue(owner, activation, GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, 0,
                f.now.elapsedMillis * 1_000_000), GuardianSafetyCooldowns(f.now.elapsedMillis * 1_000_000, null),
                f.now, "${i.toString().padStart(8, '0')}-5555-4555-8555-555555555555")
        }
        f.controls.refresh(); f.controls.refresh()
        assertEquals(16, f.notices.shows)
        assertEquals(16, f.controls.views(owner).size)
        f.controls.invalidate()
        assertEquals(16, f.notices.removed.distinct().size)
    }
}
