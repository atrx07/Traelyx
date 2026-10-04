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

    private fun register(coordinator: GuardianRecipientCoordinator, owner: String, candidate: GuardianRecipientDevice): GuardianRecipientStatus {
        val ticket = GuardianRecipientRevokeTicket(owner, candidate.deviceId, candidate.generation)
        coordinator.recordRegistrationAttempt(ticket)
        val status = coordinator.commit(owner, candidate)
        coordinator.confirmPendingRevoke(ticket)
        return status
    }

    @Test fun `same owner binding preserves a valid registration without exposing its secret`() {
        val vault = MemoryVault()
        val first = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        first.bindOwner(ownerA)
        val status = register(first, ownerA, device())
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
        register(coordinator, ownerA, device())
        coordinator.bindOwner(ownerB)
        assertNull(vault.stored)
        assertNull(coordinator.snapshot(ownerB))
        denied { register(coordinator, ownerA, device()) }
        register(coordinator, ownerB, device(ownerB))
        coordinator.bindOwner(null)
        assertNull(vault.stored)
        denied { coordinator.snapshot(ownerB) }
    }

    @Test fun `owner switch records exact server revoke intent before erasing receipt`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        register(coordinator, ownerA, device())
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
        register(coordinator, ownerA, device())
        journal.failRecord = true
        denied { coordinator.bindOwner(ownerB) }
        assertEquals(device(), vault.stored)
        denied { coordinator.snapshot(ownerA) }
        denied { register(coordinator, ownerB, device(ownerB)) }
        journal.failRecord = false
        coordinator.bindOwner(ownerB)
        assertNull(vault.stored)
        assertEquals(1, journal.pending().size)
    }

    @Test fun `replacement cannot overwrite a registered receipt`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        register(coordinator, ownerA, device())
        val replacement = device().copy(deviceId = "55555555-5555-4555-8555-555555555555")
        denied { coordinator.recordRegistrationAttempt(GuardianRecipientRevokeTicket(ownerA, replacement.deviceId, replacement.generation)) }
        denied { coordinator.commit(ownerA, replacement) }
        assertEquals(device(), vault.stored)
        assertTrue(journal.pending().isEmpty())
        coordinator.disable(ownerA)
        register(coordinator, ownerA, replacement)
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
        register(coordinator, ownerA, device().copy(deviceId = "55555555-5555-4555-8555-555555555555"))
        coordinator.disable(ownerA)
        assertEquals(2, journal.pending().size)
        assertNull(vault.stored)
    }

    @Test fun `pending retry exposes only bound owner and exact confirmation removes ticket`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        val own = GuardianRecipientRevokeTicket(ownerA, deviceId, generation)
        val other = own.copy(ownerId = ownerB)
        journal.record(own)
        journal.record(other)
        coordinator.bindOwner(ownerA)
        assertEquals(listOf(own), coordinator.pendingRevokes(ownerA))
        denied { coordinator.pendingRevokes(ownerB) }
        denied { coordinator.confirmPendingRevoke(other) }
        coordinator.confirmPendingRevoke(own)
        coordinator.confirmPendingRevoke(own)
        assertEquals(listOf(other), journal.pending())
    }

    @Test fun `registration attempt reserves exact revoke intent before receipt exists`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        val ticket = GuardianRecipientRevokeTicket(ownerA, deviceId, generation)
        denied { coordinator.recordRegistrationAttempt(ticket) }
        coordinator.bindOwner(ownerA)
        denied { coordinator.recordRegistrationAttempt(ticket.copy(ownerId = ownerB)) }
        coordinator.recordRegistrationAttempt(ticket)
        coordinator.recordRegistrationAttempt(ticket)
        assertEquals(listOf(ticket), journal.pending())
        assertNull(vault.stored)
        denied { coordinator.commit(ownerA, device().copy(deviceId = "55555555-5555-4555-8555-555555555555")) }
        assertNull(vault.stored)
        coordinator.commit(ownerA, device())
        denied { coordinator.recordRegistrationAttempt(ticket) }
        assertEquals(listOf(ticket), journal.pending())
        coordinator.disableConfirmed(ownerA, deviceId, generation)
        assertNull(vault.stored)
        assertTrue(journal.pending().isEmpty())
    }

    @Test fun `failed local receipt erasure retains registration attempt ticket`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        val ticket = GuardianRecipientRevokeTicket(ownerA, deviceId, generation)
        coordinator.bindOwner(ownerA)
        coordinator.recordRegistrationAttempt(ticket)
        coordinator.commit(ownerA, device())
        vault.failErase = true
        denied { coordinator.disableConfirmed(ownerA, deviceId, generation) }
        assertEquals(device(), vault.stored)
        assertEquals(listOf(ticket), journal.pending())
        vault.failErase = false
        coordinator.disableConfirmed(ownerA, deviceId, generation)
        assertNull(vault.stored)
        assertTrue(journal.pending().isEmpty())
    }

    @Test fun `confirmed server revoke erases exact local row without creating a ticket`() {
        val vault = MemoryVault()
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(vault, journal) { now }
        coordinator.bindOwner(ownerA)
        register(coordinator, ownerA, device())
        denied { coordinator.disableConfirmed(ownerA, deviceId, "55555555-5555-4555-8555-555555555555") }
        assertEquals(device(), vault.stored)
        coordinator.disableConfirmed(ownerA, deviceId, generation)
        coordinator.bindOwner(null)
        assertTrue(journal.pending().isEmpty())
        assertNull(vault.stored)
    }

    @Test fun `failed erasure blocks rebind and stale commit`() {
        val vault = MemoryVault()
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        register(coordinator, ownerA, device())
        vault.failErase = true
        denied { coordinator.bindOwner(ownerB) }
        denied { register(coordinator, ownerA, device()) }
        denied { register(coordinator, ownerB, device(ownerB)) }
        vault.failErase = false
        coordinator.bindOwner(ownerB)
        assertNull(vault.stored)
    }

    @Test fun `malformed replacement owner clears local authority and refuses operations`() {
        val vault = MemoryVault()
        val coordinator = GuardianRecipientCoordinator(vault, MemoryGuardianRecipientRevokeJournal()) { now }
        coordinator.bindOwner(ownerA)
        register(coordinator, ownerA, device())
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
        coordinator.recordRegistrationAttempt(GuardianRecipientRevokeTicket(ownerA, deviceId, generation))
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
        denied { bridge.dispatch("commit", args) }
        bridge.dispatch("recordAttempt", mapOf("ownerId" to ownerA, "deviceId" to deviceId, "generation" to generation))
        val committed = bridge.dispatch("commit", args) as Map<*, *>
        assertEquals(setOf("deviceId", "generation", "expiresAtEpochMillis"), committed.keys)
        assertFalse(committed.toString().contains("a".repeat(64)))
        assertEquals(committed, bridge.dispatch("snapshot", mapOf("ownerId" to ownerA)))
        bridge.dispatch("disable", mapOf("ownerId" to ownerA))
        assertNull(bridge.dispatch("snapshot", mapOf("ownerId" to ownerA)))
        assertEquals(listOf(mapOf("deviceId" to deviceId, "generation" to generation)),
            bridge.dispatch("pendingRevokes", mapOf("ownerId" to ownerA)))
        denied { bridge.dispatch("confirmRevoke", mapOf("ownerId" to ownerB, "deviceId" to deviceId, "generation" to generation)) }
        bridge.dispatch("confirmRevoke", mapOf("ownerId" to ownerA, "deviceId" to deviceId, "generation" to generation))
        assertEquals(emptyList<Any>(), bridge.dispatch("pendingRevokes", mapOf("ownerId" to ownerA)))
        denied { bridge.dispatch("recordAttempt", mapOf("ownerId" to ownerA, "deviceId" to deviceId, "generation" to generation, "extra" to true)) }
        bridge.dispatch("recordAttempt", mapOf("ownerId" to ownerA, "deviceId" to deviceId, "generation" to generation))
        assertEquals(listOf(mapOf("deviceId" to deviceId, "generation" to generation)),
            bridge.dispatch("pendingRevokes", mapOf("ownerId" to ownerA)))
    }
}
