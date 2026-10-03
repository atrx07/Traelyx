package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianRecipientCoordinatorTest {
    private val ownerA = "11111111-1111-4111-8111-111111111111"
    private val ownerB = "22222222-2222-4222-8222-222222222222"
    private val deviceId = "33333333-3333-4333-8333-333333333333"
    private val generation = "44444444-4444-4444-8444-444444444444"
    private val now = 1_800_000_000_000L
    private fun device(owner: String = ownerA, started: Long = now, lifetime: Long = GuardianRecipientCoordinator.LOCAL_MAX_LIFETIME_MILLIS) =
        GuardianRecipientDevice(owner, deviceId, generation, "a".repeat(64), started, started + lifetime)

    private class MemoryVault : GuardianRecipientVault {
        var stored: GuardianRecipientDevice? = null
        var erased = 0
        var failRead = false
        var failErase = false
        override fun readStored(): GuardianRecipientDevice? {
            if (failRead) throw GuardianVaultUnavailable()
            return stored
        }
        override fun write(device: GuardianRecipientDevice) { stored = device }
        override fun erase() {
            if (failErase) throw GuardianVaultUnavailable()
            stored = null
            erased++
            failRead = false
        }
    }

    private inline fun denied(block: () -> Unit) {
        try { block(); fail("Expected rejection") } catch (_: IllegalArgumentException) { } catch (_: IllegalStateException) { }
    }

    @Test fun `same owner binding preserves a valid registration without exposing its secret`() {
        val vault = MemoryVault()
        val first = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        first.bindOwner(ownerA)
        val status = first.commit(ownerA, device())
        assertEquals(deviceId, status.deviceId)
        assertFalse(status.toString().contains(device().credential))
        val restarted = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now + 1 }
        restarted.bindOwner(ownerA)
        assertEquals(status, restarted.snapshot(ownerA))
        assertEquals(0, vault.erased)
    }

    @Test fun `account switch and sign out erase local receipt authority before binding`() {
        val vault = MemoryVault()
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        coordinator.commit(ownerA, device())
        coordinator.bindOwner(ownerB)
        assertNull(vault.stored)
        assertNull(coordinator.snapshot(ownerB))
        denied { coordinator.commit(ownerA, device()) }
        coordinator.commit(ownerB, device(ownerB))
        coordinator.bindOwner(null)
        assertNull(vault.stored)
        denied { coordinator.snapshot(ownerB) }
    }

    @Test fun `owner switch records exact server revoke intent before erasing receipt`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        coordinator.commit(ownerA, device())
        coordinator.bindOwner(ownerB)
        assertEquals(listOf(GuardianRecipientRevokeTicket(ownerA, deviceId, generation)), journal.pending())
        assertNull(vault.stored)
        coordinator.bindOwner(null)
        assertEquals(1, journal.pending().size)
    }

    @Test fun `journal write failure blocks new owner and preserves receipt for retry`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        coordinator.commit(ownerA, device())
        journal.failRecord = true
        denied { coordinator.bindOwner(ownerB) }
        assertEquals(device(), vault.stored)
        denied { coordinator.snapshot(ownerA) }
        denied { coordinator.commit(ownerB, device(ownerB)) }
        journal.failRecord = false
        coordinator.bindOwner(ownerB)
        assertNull(vault.stored)
        assertEquals(1, journal.pending().size)
    }

    @Test fun `replacement receipt journals prior device before overwrite`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        coordinator.commit(ownerA, device())
        val replacement = device().copy(deviceId = "55555555-5555-4555-8555-555555555555")
        journal.failRecord = true
        denied { coordinator.commit(ownerA, replacement) }
        assertEquals(device(), vault.stored)
        journal.failRecord = false
        coordinator.commit(ownerA, replacement)
        assertEquals(replacement, vault.stored)
        assertEquals(listOf(GuardianRecipientRevokeTicket(ownerA, deviceId, generation)), journal.pending())
    }

    @Test fun `expired snapshot and explicit disable retain revoke IDs`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        vault.stored = device(started = now - GuardianRecipientCoordinator.LOCAL_MAX_LIFETIME_MILLIS)
        assertNull(coordinator.snapshot(ownerA))
        assertEquals(1, journal.pending().size)
        coordinator.commit(ownerA, device())
        coordinator.disable(ownerA)
        assertEquals(1, journal.pending().size)
        assertNull(vault.stored)
    }

    @Test fun `failed erasure blocks rebind and stale commit`() {
        val vault = MemoryVault()
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        coordinator.commit(ownerA, device())
        vault.failErase = true
        denied { coordinator.bindOwner(ownerB) }
        denied { coordinator.commit(ownerA, device()) }
        denied { coordinator.commit(ownerB, device(ownerB)) }
        vault.failErase = false
        coordinator.bindOwner(ownerB)
        assertNull(vault.stored)
    }

    @Test fun `malformed replacement owner clears local authority and refuses operations`() {
        val vault = MemoryVault()
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        coordinator.commit(ownerA, device())
        denied { coordinator.bindOwner("invalid-owner") }
        assertNull(vault.stored)
        denied { coordinator.snapshot(ownerA) }
    }

    @Test fun `corruption is erased before a new owner is bound`() {
        val vault = MemoryVault()
        vault.failRead = true
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        assertEquals(1, vault.erased)
        assertNull(coordinator.snapshot(ownerA))
    }

    @Test fun `old future and expired confirmations cannot commit or survive restart`() {
        val vault = MemoryVault()
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        denied { coordinator.commit(ownerA, device(started = now - GuardianRecipientCoordinator.REVIEW_TTL_MILLIS)) }
        denied { coordinator.commit(ownerA, device(started = now + 1)) }
        denied { coordinator.commit(ownerA, device(lifetime = GuardianRecipientCoordinator.LOCAL_MAX_LIFETIME_MILLIS + 1)) }
        assertNull(vault.stored)
        vault.stored = device(started = now - GuardianRecipientCoordinator.LOCAL_MAX_LIFETIME_MILLIS)
        coordinator.bindOwner(ownerA)
        assertNull(vault.stored)
    }

    @Test fun `bridge validates exact fields and never returns a credential`() {
        val vault = MemoryVault()
        val bridge = GuardianRecipientBridge(GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now })
        bridge.dispatch("bindOwner", mapOf("ownerId" to ownerA))
        val args = mapOf(
            "ownerId" to ownerA, "deviceId" to deviceId, "generation" to generation,
            "credential" to "a".repeat(64), "registeredAtEpochMillis" to now,
            "expiresAtEpochMillis" to now + GuardianRecipientCoordinator.LOCAL_MAX_LIFETIME_MILLIS,
        )
        denied { bridge.dispatch("commit", args + ("extra" to true)) }
        denied { bridge.dispatch("commit", args + ("credential" to "bad")) }
        val committed = bridge.dispatch("commit", args) as Map<*, *>
        assertEquals(setOf("deviceId", "generation", "expiresAtEpochMillis"), committed.keys)
        assertFalse(committed.toString().contains("a".repeat(64)))
        assertEquals(committed, bridge.dispatch("snapshot", mapOf("ownerId" to ownerA)))
        bridge.dispatch("disable", mapOf("ownerId" to ownerA))
        assertNull(bridge.dispatch("snapshot", mapOf("ownerId" to ownerA)))
    }
}
