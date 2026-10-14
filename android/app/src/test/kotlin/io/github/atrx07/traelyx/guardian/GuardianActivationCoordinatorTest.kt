package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianActivationCoordinatorTest {
    private val a = "11111111-1111-4111-8111-111111111111"
    private val b = "22222222-2222-4222-8222-222222222222"
    private val generation = "33333333-3333-4333-8333-333333333333"
    private class MemoryVault : GuardianVault {
        var value = GuardianVaultSnapshot()
        var failErase = false
        var failRead = false
        var failWrite = false
        override fun read(): GuardianVaultSnapshot { check(!failRead); return value }
        override fun write(snapshot: GuardianVaultSnapshot) { check(!failWrite); value = snapshot }
        override fun erase() { check(!failErase); value = GuardianVaultSnapshot() }
    }
    private inner class Fixture {
        var now = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
        val vault = MemoryVault()
        val journal = TestDriverRevokeJournal()
        val coordinator = GuardianActivationCoordinator(GuardianOutbox(vault), { now }, journal, { generation }, { "a".repeat(64) })
        fun begin(): GuardianActivationProposal { coordinator.bindOwner(a); return coordinator.begin(a, "+y", true) }
        fun commit() = coordinator.commit(a, generation, now.epochMillis + 28_800_000)
        fun advance(ms: Long) { now = now.copy(epochMillis = now.epochMillis + ms, elapsedMillis = now.elapsedMillis + ms) }
    }
    private fun rejected(action: () -> Unit) {
        try { action(); fail("Expected rejection") } catch (_: IllegalArgumentException) { } catch (_: IllegalStateException) { }
    }
    @Test fun `proposal remains inert until successful commit and is redacted`() {
        val f = Fixture()
        val p = f.begin()
        assertNull(f.vault.value.lease)
        assertFalse(p.toString().contains(p.credential))
        f.advance(1_000)
        val lease = f.commit()
        assertEquals(28_800_000, lease.expiresEpochMillis - lease.startedEpochMillis)
        assertEquals(lease, f.coordinator.snapshot(a).lease)
        rejected { f.commit() }
    }
    @Test fun `owner and mount consent are required`() {
        val f = Fixture()
        rejected { f.coordinator.begin(a, "+y", true) }
        f.coordinator.bindOwner(a)
        rejected { f.coordinator.begin(b, "+y", true) }
        rejected { f.coordinator.begin(a, "+y", false) }
        rejected { f.coordinator.begin(a, "unknown", true) }
        assertNull(f.vault.value.lease)
    }
    @Test fun `account change signout and disable invalidate delayed activation`() {
        for (change in listOf<(Fixture) -> Unit>(
            { it.coordinator.bindOwner(b) }, { it.coordinator.bindOwner(null) }, { it.coordinator.disable(a) },
        )) {
            val f = Fixture(); f.begin(); change(f)
            rejected { f.commit() }
            assertNull(f.vault.value.lease)
        }
    }
    @Test fun `expiry reboot rollback and server expiry fail closed`() {
        for (change in listOf<(Fixture) -> Unit>(
            { it.advance(120_000) },
            { it.now = it.now.copy(bootId = "boot-2") },
            { it.now = it.now.copy(epochMillis = it.now.epochMillis - 1) },
            { it.now = it.now.copy(elapsedMillis = it.now.elapsedMillis - 1) },
        )) {
            val f = Fixture(); f.begin(); change(f)
            rejected { f.commit() }
            assertNull(f.vault.value.lease)
        }
        val f = Fixture(); f.begin()
        rejected { f.coordinator.commit(a, generation, f.now.epochMillis) }
    }
    @Test fun `abort identity cannot cancel another proposal and failures cannot activate`() {
        val f = Fixture(); f.begin()
        f.coordinator.abort(b, generation)
        f.coordinator.abort(a, b)
        f.vault.failWrite = true
        rejected { f.commit() }
        f.vault.failWrite = false
        rejected { f.commit() }
        assertNull(f.vault.value.lease)
    }
    @Test fun `failed account teardown leaves coordinator unbound`() {
        val f = Fixture(); f.begin(); f.commit()
        f.vault.failErase = true
        rejected { f.coordinator.bindOwner(null) }
        rejected { f.coordinator.snapshot(a) }
        rejected { f.coordinator.begin(a, "+y", true) }
        f.vault.failErase = false
        f.coordinator.bindOwner(null)
        assertNull(f.vault.value.lease)
    }
    @Test fun `same owner recovery preserves committed lease without extending it`() {
        val f = Fixture(); f.begin(); val lease = f.commit()
        f.advance(5_000)
        f.coordinator.bindOwner(a)
        assertEquals(lease, f.coordinator.snapshot(a).lease)
        f.coordinator.bindOwner(b)
        assertNull(f.vault.value.lease)
    }
    @Test fun `failed disable or replacement cannot keep local authority usable`() {
        for (replace in listOf(false, true)) {
            val f = Fixture(); f.begin(); f.commit()
            f.vault.failErase = true
            rejected { if (replace) f.coordinator.begin(a, "+y", true) else f.coordinator.disable(a) }
            rejected { f.coordinator.snapshot(a) }
        }
    }
    @Test fun `pending reviews block duplicates but expire without extending authority`() {
        val f = Fixture(); f.begin()
        rejected { f.coordinator.begin(a, "+y", true) }
        f.advance(120_000)
        val replacement = f.coordinator.begin(a, "-x", true)
        assertEquals("-x", replacement.forwardAxis)
        assertNull(f.vault.value.lease)
    }

    @Test fun `stop erases local lease even when status read fails`() {
        val f = Fixture(); f.begin(); f.commit()
        f.vault.failRead = true
        rejected { f.coordinator.stop(a) }
        assertNull(f.vault.value.lease)
        f.vault.failRead = false
        assertNull(f.coordinator.stop(a))
    }

    @Test fun `pending stop survives restart and blocks activation until exact confirmation`() {
        val f = Fixture(); f.begin(); f.commit()
        assertEquals(generation, f.coordinator.stop(a))
        assertNull(f.vault.value.lease)
        val restarted = GuardianActivationCoordinator(GuardianOutbox(f.vault), { f.now }, f.journal)
        restarted.bindOwner(b)
        assertTrue(restarted.pendingRevokes(b).isEmpty())
        rejected { restarted.pendingRevokes(a) }
        restarted.bindOwner(a)
        assertEquals(listOf(GuardianDriverRevokeTicket(a, generation)), restarted.pendingRevokes(a))
        rejected { restarted.begin(a, "+y", true) }
        restarted.confirmRevoke(a, b)
        rejected { restarted.begin(a, "+y", true) }
        restarted.confirmRevoke(a, generation)
        restarted.begin(a, "+y", true)
    }

    @Test fun `journal write failure cannot leave local monitoring active`() {
        val f = Fixture(); f.begin(); f.commit()
        f.journal.failRecord = true
        rejected { f.coordinator.stop(a) }
        assertNull(f.vault.value.lease)
        assertNull(f.coordinator.recordingSnapshot())
    }

    @Test fun `stop retains the exact cleanup identity after local lease expiry`() {
        val f = Fixture(); f.begin(); f.commit()
        f.advance(28_800_000)
        assertEquals(generation, f.coordinator.stop(a))
        assertEquals(listOf(GuardianDriverRevokeTicket(a, generation)), f.journal.tickets)
        assertNull(f.vault.value.lease)
    }

    @Test fun `full journal refuses a new activation without discarding another owner ticket`() {
        val f = Fixture()
        repeat(GuardianDriverRevokeJournalCodec.MAX_TICKETS) {
            f.journal.record(GuardianDriverRevokeTicket(b,
                "${it.toString().padStart(8, '0')}-3333-4333-8333-333333333333"))
        }
        f.coordinator.bindOwner(a)
        rejected { f.coordinator.begin(a, "+y", true) }
        assertEquals(GuardianDriverRevokeJournalCodec.MAX_TICKETS, f.journal.tickets.size)
    }

    @Test fun `owner loss journals committed lease before erasing and hides it from the new owner`() {
        for (nextOwner in listOf(b, null)) {
            val f = Fixture(); f.begin(); f.commit()
            f.coordinator.bindOwner(nextOwner)
            assertNull(f.vault.value.lease)
            assertNull(f.coordinator.recordingSnapshot())
            assertEquals(listOf(GuardianDriverRevokeTicket(a, generation)), f.journal.tickets)
            if (nextOwner != null) assertTrue(f.coordinator.pendingRevokes(nextOwner).isEmpty())
            rejected { f.coordinator.pendingRevokes(a) }
            f.coordinator.bindOwner(a)
            assertEquals(f.journal.tickets, f.coordinator.pendingRevokes(a))
            rejected { f.coordinator.begin(a, "+y", true) }
        }
    }

    @Test fun `invalid retained leases journal expiry reboot and rollback cleanup`() {
        for (readFromRecorder in listOf(false, true)) {
            for (change in listOf<(Fixture) -> Unit>(
                { it.advance(28_800_000) },
                { it.now = it.now.copy(bootId = "boot-2") },
                { it.now = it.now.copy(epochMillis = it.now.epochMillis - 1) },
                { it.now = it.now.copy(elapsedMillis = it.now.elapsedMillis - 1) },
            )) {
                val f = Fixture(); f.begin(); f.commit(); change(f)
                if (readFromRecorder) assertNull(f.coordinator.recordingSnapshot())
                else assertNull(f.coordinator.snapshot(a).lease)
                assertNull(f.vault.value.lease)
                assertEquals(listOf(GuardianDriverRevokeTicket(a, generation)), f.journal.tickets)
            }
        }
    }

    @Test fun `owner cleanup journal failure still erases and refuses the new binding`() {
        val f = Fixture(); f.begin(); f.commit()
        f.journal.failRecord = true
        rejected { f.coordinator.bindOwner(b) }
        assertNull(f.vault.value.lease)
        assertNull(f.coordinator.recordingSnapshot())
        rejected { f.coordinator.snapshot(a) }
        rejected { f.coordinator.snapshot(b) }
    }

    @Test fun `fresh same owner binding preserves monitoring and writes no revoke`() {
        val f = Fixture(); f.begin(); val lease = f.commit()
        f.advance(1_000); f.coordinator.bindOwner(a)
        assertEquals(lease, f.coordinator.recordingSnapshot()?.lease)
        assertTrue(f.journal.tickets.isEmpty())
    }

    @Test fun `invalid lease journal failure still removes recording authority`() {
        val f = Fixture(); f.begin(); f.commit(); f.advance(28_800_000)
        f.journal.failRecord = true
        rejected { f.coordinator.recordingSnapshot() }
        assertNull(f.vault.value.lease)
        assertNull(f.coordinator.recordingSnapshot())
    }

    @Test fun `outbox reservation also journals an expired lease without a foreground status check`() {
        val f = Fixture(); f.begin(); f.commit(); f.advance(28_800_000)
        val outbox = GuardianOutbox(f.vault, f.journal::record)
        assertNull(outbox.reserveNext(a, f.now))
        assertNull(f.vault.value.lease)
        assertEquals(listOf(GuardianDriverRevokeTicket(a, generation)), f.journal.tickets)
    }

    @Test fun `unreadable lease account recovery attempts erasure and refuses binding`() {
        val f = Fixture(); f.begin(); f.commit(); f.vault.failRead = true
        rejected { f.coordinator.bindOwner(b) }
        assertNull(f.vault.value.lease)
        assertNull(f.coordinator.recordingSnapshot())
        rejected { f.coordinator.snapshot(b) }
    }
}
