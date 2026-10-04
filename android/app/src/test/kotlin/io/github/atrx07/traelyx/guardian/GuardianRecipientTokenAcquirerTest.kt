package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianRecipientTokenAcquirerTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val other = "22222222-2222-4222-8222-222222222222"
    private val device = "33333333-3333-4333-8333-333333333333"
    private val generation = "44444444-4444-4444-8444-444444444444"
    private val args get() = mapOf("ownerId" to owner, "deviceId" to device, "generation" to generation)

    private class Vault : GuardianRecipientVault {
        var stored: GuardianRecipientDevice? = null
        override fun readStored() = stored
        override fun write(device: GuardianRecipientDevice) { stored = device }
        override fun erase() { stored = null }
    }

    private class Push : GuardianPushRegistration {
        override val configured = true
        var calls = 0
        var consent: GuardianNotificationConsent? = null
        var callback: ((GuardianRegistrationResult) -> Unit)? = null
        override fun register(consent: GuardianNotificationConsent, complete: (GuardianRegistrationResult) -> Unit) {
            calls++
            this.consent = consent
            callback = complete
        }
        override fun unregister(complete: (Boolean) -> Unit) { complete(true) }
    }

    @Test fun `token request requires the exact bound pending ticket`() {
        val coordinator = GuardianRecipientCoordinator(Vault(), MemoryGuardianRecipientRevokeJournal()) { 1_800_000_000_000L }
        val push = Push()
        val acquirer = GuardianRecipientTokenAcquirer(GuardianRecipientBridge(coordinator), push)
        var response: Result<String>? = null
        coordinator.bindOwner(owner)
        acquirer.acquire(args) { response = it }
        assertTrue(response!!.isFailure)
        assertEquals(0, push.calls)
        coordinator.recordRegistrationAttempt(GuardianRecipientRevokeTicket(owner, device, generation))
        acquirer.acquire(args + ("extra" to true)) { response = it }
        assertTrue(response!!.isFailure)
        acquirer.acquire(args) { response = it }
        assertEquals(1, push.calls)
        val token = "synthetic-routing-token-123456789"
        push.callback!!(GuardianRegistrationResult.Registered(token, push.consent!!))
        assertEquals(token, response!!.getOrThrow())
    }

    @Test fun `late provider token is denied after owner changes`() {
        val journal = MemoryGuardianRecipientRevokeJournal()
        val coordinator = GuardianRecipientCoordinator(Vault(), journal) { 1_800_000_000_000L }
        val push = Push()
        val acquirer = GuardianRecipientTokenAcquirer(GuardianRecipientBridge(coordinator), push)
        coordinator.bindOwner(owner)
        coordinator.recordRegistrationAttempt(GuardianRecipientRevokeTicket(owner, device, generation))
        var response: Result<String>? = null
        acquirer.acquire(args) { response = it }
        coordinator.bindOwner(other)
        push.callback!!(GuardianRegistrationResult.Registered("synthetic-routing-token-123456789", push.consent!!))
        assertTrue(response!!.isFailure)
        assertFalse(response!!.exceptionOrNull().toString().contains("synthetic-routing-token"))
        assertEquals(listOf(GuardianRecipientRevokeTicket(owner, device, generation)), journal.pending())
    }

    @Test fun `provider failure or mismatched consent cannot expose token`() {
        val coordinator = GuardianRecipientCoordinator(Vault(), MemoryGuardianRecipientRevokeJournal()) { 1_800_000_000_000L }
        val push = Push()
        val acquirer = GuardianRecipientTokenAcquirer(GuardianRecipientBridge(coordinator), push)
        coordinator.bindOwner(owner)
        coordinator.recordRegistrationAttempt(GuardianRecipientRevokeTicket(owner, device, generation))
        var response: Result<String>? = null
        acquirer.acquire(args) { response = it }
        push.callback!!(GuardianRegistrationResult.Unavailable("network"))
        assertTrue(response!!.isFailure)
        acquirer.acquire(args) { response = it }
        push.callback!!(GuardianRegistrationResult.Registered(
            "synthetic-routing-token-123456789", GuardianNotificationConsent(other, generation)))
        assertTrue(response!!.isFailure)
    }

    @Test fun `provider can complete token request only once`() {
        val coordinator = GuardianRecipientCoordinator(Vault(), MemoryGuardianRecipientRevokeJournal()) { 1_800_000_000_000L }
        val push = Push()
        val acquirer = GuardianRecipientTokenAcquirer(GuardianRecipientBridge(coordinator), push)
        coordinator.bindOwner(owner)
        coordinator.recordRegistrationAttempt(GuardianRecipientRevokeTicket(owner, device, generation))
        val responses = mutableListOf<Result<String>>()
        acquirer.acquire(args) { responses.add(it) }
        push.callback!!(GuardianRegistrationResult.Registered("synthetic-routing-token-123456789", push.consent!!))
        push.callback!!(GuardianRegistrationResult.Unavailable("late failure"))
        assertEquals(1, responses.size)
        assertTrue(responses.single().isSuccess)
    }
}
