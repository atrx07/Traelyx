package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianSendingReviewTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val other = "33333333-3333-4333-8333-333333333333"
    private class Vault : GuardianVault {
        var value = GuardianVaultSnapshot()
        var failWrite = false
        var failRead = false
        override fun read(): GuardianVaultSnapshot { check(!failRead); return value }
        override fun write(snapshot: GuardianVaultSnapshot) { check(!failWrite); value = snapshot }
        override fun erase() { value = GuardianVaultSnapshot() }
    }
    private inner class Fixture(available: Boolean = true) {
        var now = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
        val vault = Vault()
        val journal = TestDriverRevokeJournal()
        val box = GuardianOutbox(vault)
        fun coordinator() = GuardianActivationCoordinator(box, { now }, journal, { activation }, { "a".repeat(64) })
        val control = coordinator()
        val bridge = GuardianActivationBridge(control, sendingPilotAvailable = available)
        val args = mapOf("ownerId" to owner, "forwardAxis" to "+y", "rigidMountConfirmed" to true,
            "sendingAcknowledged" to true, "sendingReviewVersion" to 1)
        init { control.bindOwner(owner) }
        fun begin() { bridge.dispatch(GuardianActivationBridge.BEGIN_SENDING, args) }
        fun commit() { control.commit(owner, activation, now.epochMillis + 60_000) }
    }
    private fun rejected(action: () -> Any?) {
        try { action(); fail("Expected rejection") }
        catch (_: IllegalArgumentException) { } catch (_: IllegalStateException) { }
    }
    @Test fun `old reviews remain evaluation only and fresh sending review is exact and ephemeral`() {
        val old = Fixture(); old.control.begin(owner, "+y", true); old.commit()
        assertFalse(old.control.sendingReviewed())
        val f = Fixture(); f.begin(); assertFalse(f.control.sendingReviewed()); f.commit()
        assertTrue(f.control.sendingReviewed())
        f.control.bindOwner(owner); assertTrue(f.control.sendingReviewed())
        f.control.abort(owner, other); assertTrue(f.control.sendingReviewed())
        val restarted = f.coordinator(); restarted.bindOwner(owner)
        assertFalse(restarted.sendingReviewed()); assertNull(restarted.recordingSnapshot())
        f.control.stop(owner); assertFalse(f.control.sendingReviewed())
    }
    @Test fun `unavailable bridge cannot create a sending proposal even with all acknowledgements`() {
        val f = Fixture(false); rejected { f.begin() }
        assertTrue(f.journal.tickets.isEmpty()); assertNull(f.vault.value.lease)
        assertFalse(f.control.sendingReviewed())
    }
    @Test fun `sending bridge rejects missing false wrong version type extras and foreign owner`() {
        val f = Fixture()
        val invalid = listOf(f.args - "sendingAcknowledged", f.args - "sendingReviewVersion",
            f.args + ("sendingAcknowledged" to false), f.args + ("sendingAcknowledged" to "true"),
            f.args + ("sendingReviewVersion" to 0), f.args + ("sendingReviewVersion" to 2),
            f.args + ("sendingReviewVersion" to 1L), f.args + ("extra" to true),
            f.args + ("ownerId" to other))
        invalid.forEach { args -> rejected { f.bridge.dispatch(GuardianActivationBridge.BEGIN_SENDING, args) } }
        rejected { f.bridge.dispatch(GuardianActivationBridge.BEGIN, f.args) }
        assertTrue(f.journal.tickets.isEmpty()); f.begin(); f.commit(); assertTrue(f.control.sendingReviewed())
    }
    @Test fun `expiry reboot owner loss and missing vault deny sending without restoring consent`() {
        for (change in listOf<(Fixture) -> Unit>(
            { it.now = it.now.copy(epochMillis = it.now.epochMillis + 60_000, elapsedMillis = it.now.elapsedMillis + 60_000) },
            { it.now = it.now.copy(bootId = "boot-2") }, { it.control.bindOwner(other) },
            { it.vault.erase() }, { it.control.disable(owner) },
        )) {
            val f = Fixture(); f.begin(); f.commit(); change(f)
            assertFalse(f.control.sendingReviewed())
        }
    }
    @Test fun `failed persistence stale review and abort cannot grant sending`() {
        val failed = Fixture(); failed.begin(); failed.vault.failWrite = true
        rejected { failed.commit() }; assertFalse(failed.control.sendingReviewed())
        val stale = Fixture(); stale.begin()
        stale.now = stale.now.copy(epochMillis = stale.now.epochMillis + 120_000, elapsedMillis = stale.now.elapsedMillis + 120_000)
        rejected { stale.commit() }; assertFalse(stale.control.sendingReviewed())
        val aborted = Fixture(); aborted.begin(); aborted.control.abort(owner, activation)
        rejected { aborted.commit() }; assertFalse(aborted.control.sendingReviewed())
    }
}
