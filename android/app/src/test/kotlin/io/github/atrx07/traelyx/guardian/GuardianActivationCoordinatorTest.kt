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
        var failWrite = false
        override fun read() = value
        override fun write(snapshot: GuardianVaultSnapshot) { check(!failWrite); value = snapshot }
        override fun erase() { check(!failErase); value = GuardianVaultSnapshot() }
    }
    private inner class Fixture {
        var now = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
        val vault = MemoryVault()
        val coordinator = GuardianActivationCoordinator(GuardianOutbox(vault), { now }, { generation }, { "a".repeat(64) })
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
}
