package io.github.atrx07.traelyx.guardian

import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.Assert.*
import org.junit.Test

/** Real encryption and independent storage domains; all identities and evidence are synthetic. */
class GuardianCleanupRetentionTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"
    private val otherOwner = "44444444-4444-4444-8444-444444444444"
    private val start = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
    private val ticket = GuardianDriverRevokeTicket(owner, activation)
    private fun now(delta: Long) = start.copy(epochMillis = start.epochMillis + delta,
        elapsedMillis = start.elapsedMillis + delta)

    private class Disk : GuardianSealedStorage {
        var bytes: ByteArray? = null
        var failReplace = false
        var failReadback = false
        var writes = 0
        private var alteredRead = false
        override fun read(): ByteArray? {
            val value = bytes?.copyOf() ?: return null
            if (alteredRead) { alteredRead = false; value[0] = (value[0].toInt() xor 1).toByte() }
            return value
        }
        override fun replace(bytes: ByteArray) {
            check(!failReplace)
            writes++
            this.bytes = bytes.copyOf()
            alteredRead = failReadback
        }
        override fun delete() { bytes = null }
    }
    private class Keys {
        var key: SecretKey? = null
        fun cipher(domain: String) = GuardianVaultCipher(domain = domain, key = { create ->
            key ?: if (create) KeyGenerator.getInstance("AES").apply { init(256) }.generateKey().also { key = it }
            else error("Missing synthetic key")
        })
    }
    private inner class Fixture {
        var clock = start
        val disk = Disk()
        val keys = Keys()
        val journalDisk = Disk()
        val journalKeys = Keys()
        fun reopenVault() = EncryptedGuardianVault(disk, keys.cipher("cleanup-test-vault")) { keys.key = null }
        fun reopenJournal() = EncryptedGuardianDriverRevokeJournal(journalDisk,
            journalKeys.cipher("cleanup-test-journal"))
        val vault = reopenVault()
        val journal = reopenJournal()
        val outbox = GuardianOutbox(vault, journal::record)
        val coordinator = coordinator(outbox)
        fun coordinator(box: GuardianOutbox) = GuardianActivationCoordinator(box, { clock }, reopenJournal(),
            { activation }, { "a".repeat(64) })
        fun activate() {
            coordinator.bindOwner(owner)
            coordinator.begin(owner, "+y", true)
            coordinator.commit(owner, activation, start.epochMillis + 28_800_000)
        }
        fun enqueue() = outbox.enqueue(owner, activation,
            GuardianDetection(GuardianAlertKind.POSSIBLE_CRASH, 9_000_000_000, 10_000_000_000),
            GuardianSafetyCooldowns(10_000_000_000, 10_000_000_000), start, event)
        fun legacyLease() {
            GuardianOutbox(vault).activate(GuardianDriverLease(owner, activation, "a".repeat(64),
                start.epochMillis, start.elapsedMillis, start.epochMillis + 28_800_000, start.bootId, "+y"), start)
            assertTrue(journal.pending().isEmpty())
        }
    }

    @Test fun `destructive enqueue failure retains exact cleanup after process recreation`() {
        val f = Fixture(); f.activate()
        f.disk.failReplace = true
        assertThrows(GuardianVaultUnavailable::class.java) { f.enqueue() }
        assertNull(f.keys.key)
        assertNull(f.disk.bytes)
        assertNull(f.reopenVault().read().lease)
        assertEquals(listOf(ticket), f.reopenJournal().pending())
    }

    @Test fun `reservation cancellation recovery and completion failures preserve cleanup`() {
        for (readback in listOf(false, true)) {
            for (operation in listOf("reserve", "cancel", "recover", "complete")) {
                val f = Fixture(); f.activate(); f.enqueue()
                val attempt = if (operation == "complete") f.outbox.reserveNext(owner, now(30_000))!! else null
                if (operation == "reserve") f.outbox.recover(owner, now(30_000))
                f.disk.failReplace = !readback
                f.disk.failReadback = readback
                assertThrows(GuardianVaultUnavailable::class.java) {
                    when (operation) {
                        "reserve" -> f.outbox.reserveNext(owner, now(30_000))
                        "cancel" -> f.outbox.cancel(owner, event, now(20_000))
                        "recover" -> f.outbox.recover(owner, now(600_000))
                        "complete" -> f.outbox.complete(attempt!!, true, false, now(31_000))
                    }
                }
                assertNull(f.keys.key)
                assertNull(f.reopenVault().read().lease)
                assertEquals(listOf(ticket), f.reopenJournal().pending())
            }
        }
    }

    @Test fun `retained committed reservation is idempotent and cannot be confirmed while active`() {
        val f = Fixture(); f.activate()
        val writes = f.journalDisk.writes
        assertEquals(listOf(ticket), f.coordinator.pendingRevokes(owner))
        assertThrows(IllegalStateException::class.java) { f.coordinator.confirmRevoke(owner, activation) }
        f.enqueue()
        f.outbox.cancel(owner, event, now(20_000))
        f.coordinator.bindOwner(owner)
        assertNotNull(f.coordinator.recordingSnapshot())
        assertEquals(writes, f.journalDisk.writes)
        assertEquals(activation, f.coordinator.stop(owner))
        f.coordinator.confirmRevoke(owner, activation) // Simulated exact successful server reply.
        assertTrue(f.reopenJournal().pending().isEmpty())
    }

    @Test fun `readable legacy lease is adopted on binding without starting restored evaluation`() {
        val f = Fixture(); f.legacyLease()
        f.coordinator.bindOwner(owner)
        assertEquals(listOf(ticket), f.reopenJournal().pending())
        assertNotNull(f.coordinator.snapshot(owner).lease)
        assertNull(f.coordinator.recordingSnapshot())
        // Corruption after adoption cannot remove the independent cleanup identity.
        f.disk.bytes = f.disk.bytes!!.copyOf().also { it[0] = (it[0].toInt() xor 1).toByte() }
        assertThrows(GuardianVaultUnavailable::class.java) { f.coordinator.snapshot(owner) }
        assertEquals(listOf(ticket), f.reopenJournal().pending())
    }

    @Test fun `legacy recovery journals before destructive pruning write`() {
        val f = Fixture(); f.legacyLease()
        // Simulate an older build's cancellable event without a reservation journal entry.
        val old = f.vault.read()
        f.vault.write(old.copy(alerts = listOf(GuardianPendingAlert(event, owner, activation,
            GuardianAlertKind.POSSIBLE_CRASH, start.epochMillis, start.elapsedMillis, start.bootId,
            GuardianDetection(GuardianAlertKind.POSSIBLE_CRASH, 0, 0).ruleVersion))))
        f.clock = now(600_000)
        f.disk.failReadback = true
        assertThrows(GuardianVaultUnavailable::class.java) { f.coordinator.bindOwner(owner) }
        assertNull(f.reopenVault().read().lease)
        assertEquals(listOf(ticket), f.reopenJournal().pending())
        assertThrows(IllegalArgumentException::class.java) { f.coordinator.snapshot(owner) }
    }

    @Test fun `unavailable cleanup journal denies mutation before the vault is touched`() {
        for (operation in listOf("enqueue", "replace", "bind")) {
            val f = Fixture(); f.legacyLease()
            val sealed = f.disk.bytes!!.copyOf()
            val writes = f.disk.writes
            f.journalDisk.failReplace = true
            assertThrows(GuardianVaultUnavailable::class.java) {
                when (operation) {
                    "enqueue" -> f.enqueue()
                    "replace" -> f.outbox.activate(f.vault.read().lease!!.copy(ownerId = otherOwner,
                        activationId = event), start)
                    "bind" -> f.coordinator.bindOwner(owner)
                }
            }
            assertEquals(writes, f.disk.writes)
            assertArrayEquals(sealed, f.disk.bytes)
            assertNotNull(f.keys.key)
        }
    }

    @Test fun `replacement write failure retains both identities and exact cleanup preserves the other owner`() {
        val f = Fixture(); f.activate()
        val next = f.vault.read().lease!!.copy(ownerId = otherOwner, activationId = event)
        f.disk.failReplace = true
        assertThrows(GuardianVaultUnavailable::class.java) { f.outbox.activate(next, start) }
        val nextTicket = GuardianDriverRevokeTicket(otherOwner, event)
        assertEquals(listOf(ticket, nextTicket), f.reopenJournal().pending())
        f.disk.failReplace = false
        val restored = f.coordinator(GuardianOutbox(f.reopenVault(), f.reopenJournal()::record))
        restored.bindOwner(owner)
        assertNull(restored.stop(owner))
        restored.confirmRevoke(owner, activation)
        assertEquals(listOf(nextTicket), f.reopenJournal().pending())
    }

    @Test fun `failed server-cleanup confirmation keeps ticket and blocks replacement after restart`() {
        val f = Fixture(); f.activate(); f.coordinator.stop(owner)
        f.journalDisk.failReplace = true
        assertThrows(GuardianVaultUnavailable::class.java) { f.coordinator.confirmRevoke(owner, activation) }
        assertEquals(listOf(ticket), f.reopenJournal().pending())
        f.journalDisk.failReplace = false
        val restored = f.coordinator(GuardianOutbox(f.reopenVault(), f.reopenJournal()::record))
        restored.bindOwner(owner)
        assertThrows(IllegalStateException::class.java) { restored.begin(owner, "+y", true) }
        restored.confirmRevoke(owner, activation)
        restored.begin(owner, "+y", true)
    }

    @Test fun `full cleanup journal refuses replacement without erasing prior lease or tickets`() {
        val f = Fixture(); f.activate()
        repeat(GuardianDriverRevokeJournalCodec.MAX_TICKETS - 1) {
            f.journal.record(GuardianDriverRevokeTicket(otherOwner,
                "${it.toString().padStart(8, '0')}-3333-4333-8333-333333333333"))
        }
        val original = f.vault.read()
        val tickets = f.reopenJournal().pending()
        assertThrows(IllegalArgumentException::class.java) {
            f.outbox.activate(original.lease!!.copy(ownerId = otherOwner, activationId = event), start)
        }
        assertEquals(original, f.vault.read())
        assertEquals(tickets, f.reopenJournal().pending())
    }
}
