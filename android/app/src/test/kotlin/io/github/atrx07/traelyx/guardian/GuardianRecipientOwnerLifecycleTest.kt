package io.github.atrx07.traelyx.guardian

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.*
import org.junit.Test

class GuardianRecipientOwnerLifecycleTest {
    private val ownerA = "11111111-1111-4111-8111-111111111111"
    private val ownerB = "22222222-2222-4222-8222-222222222222"
    private val now = 1_800_000_000_000L
    private fun device(owner: String = ownerA) = GuardianRecipientDevice(
        owner, "33333333-3333-4333-8333-333333333333",
        "44444444-4444-4444-8444-444444444444", "a".repeat(64), now, now + 60_000,
    )

    private class Vault : GuardianRecipientVault {
        @Volatile
        var stored: GuardianRecipientDevice? = null
        var erasures = 0
        override fun readStored() = stored
        override fun write(device: GuardianRecipientDevice) { stored = device }
        override fun erase() { stored = null; erasures++ }
    }

    private class Marker(@Volatile var marked: Boolean = false) : GuardianProviderMarker {
        var failRead = false
        override fun present(): Boolean { if (failRead) error("storage unavailable"); return marked }
        override fun mark() { marked = true }
        override fun clear() { marked = false }
    }

    private class Push(private val marker: Marker) : GuardianPushRegistration {
        override val configured = true
        @Volatile
        var deletions = 0
        @Volatile
        var deletion: ((Boolean) -> Unit)? = null
        var autoComplete: Boolean? = null
        override fun register(consent: GuardianNotificationConsent, complete: (GuardianRegistrationResult) -> Unit) =
            error("owner binding must not request a token")
        override fun unregister(complete: (Boolean) -> Unit) {
            check(marker.marked)
            deletions++
            deletion = { success -> if (success) marker.clear(); complete(success) }
            autoComplete?.let { deletion!!(it) }
        }
    }

    private fun lifecycle(vault: Vault, marker: Marker, push: Push, timeout: Long = 1_000) =
        GuardianRecipientOwnerLifecycle(
            GuardianRecipientCoordinator(vault) { now }, vault, marker, push, { now }, timeout,
        )

    @Test fun `same owner restart preserves active authority without deleting provider`() {
        val vault = Vault().also { it.stored = device() }
        val marker = Marker(true)
        val push = Push(marker)
        val coordinator = GuardianRecipientCoordinator(vault) { now }
        GuardianRecipientOwnerLifecycle(coordinator, vault, marker, push, { now }).bindOwner(ownerA)
        assertEquals(device().deviceId, coordinator.snapshot(ownerA)?.deviceId)
        assertEquals(0, vault.erasures)
        assertEquals(0, push.deletions)
        assertTrue(marker.marked)
    }

    @Test fun `account switch erases authority and waits for provider deletion`() {
        val vault = Vault().also { it.stored = device() }
        val marker = Marker(true)
        val push = Push(marker)
        val coordinator = GuardianRecipientCoordinator(vault) { now }
        coordinator.bindOwner(ownerA)
        val lifecycle = GuardianRecipientOwnerLifecycle(coordinator, vault, marker, push, { now })
        val finished = CountDownLatch(1)
        val failure = AtomicReference<Throwable?>()
        val thread = Thread {
            try { lifecycle.bindOwner(ownerB) } catch (error: Throwable) { failure.set(error) }
            finally { finished.countDown() }
        }
        thread.start()
        try {
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(1)
            while (push.deletions == 0 && System.nanoTime() < deadline) Thread.yield()
            assertEquals(1, push.deletions)
            assertNull(vault.stored)
            assertFalse(finished.await(10, TimeUnit.MILLISECONDS))
            push.deletion!!(true)
            assertTrue(finished.await(1, TimeUnit.SECONDS))
            assertNull(failure.get())
            assertNull(coordinator.snapshot(ownerB))
            assertFalse(marker.marked)
        } finally { thread.join(1_000) }
    }

    @Test fun `failed deletion blocks new owner and marker survives for retry`() {
        val vault = Vault().also { it.stored = device() }
        val marker = Marker(true)
        val push = Push(marker).also { it.autoComplete = false }
        val coordinator = GuardianRecipientCoordinator(vault) { now }
        coordinator.bindOwner(ownerA)
        val lifecycle = GuardianRecipientOwnerLifecycle(coordinator, vault, marker, push, { now })
        assertThrows(IllegalStateException::class.java) { lifecycle.bindOwner(ownerB) }
        assertTrue(marker.marked)
        assertNull(vault.stored)
        assertThrows(IllegalArgumentException::class.java) { coordinator.snapshot(ownerA) }
    }

    @Test fun `orphan marker after restart requires deletion before binding`() {
        val vault = Vault()
        val marker = Marker(true)
        val push = Push(marker).also { it.autoComplete = true }
        val lifecycle = lifecycle(vault, marker, push)
        lifecycle.bindOwner(ownerA)
        assertEquals(1, push.deletions)
        assertFalse(marker.marked)
    }

    @Test fun `unmarked receipt is discarded and no Firebase cleanup is invoked`() {
        val vault = Vault().also { it.stored = device() }
        val marker = Marker()
        val push = Push(marker)
        val coordinator = GuardianRecipientCoordinator(vault) { now }
        GuardianRecipientOwnerLifecycle(coordinator, vault, marker, push, { now }).bindOwner(ownerA)
        assertNull(coordinator.snapshot(ownerA))
        assertEquals(0, push.deletions)
    }

    @Test fun `missing marker and no receipt keep sign out inert`() {
        val vault = Vault()
        val marker = Marker()
        val push = Push(marker)
        lifecycle(vault, marker, push).bindOwner(null)
        assertEquals(0, push.deletions)
    }

    @Test fun `marker read failure erases authority and denies rebind`() {
        val vault = Vault().also { it.stored = device() }
        val marker = Marker(true).also { it.failRead = true }
        val push = Push(marker)
        val coordinator = GuardianRecipientCoordinator(vault) { now }
        coordinator.bindOwner(ownerA)
        assertThrows(IllegalStateException::class.java) {
            GuardianRecipientOwnerLifecycle(coordinator, vault, marker, push, { now }).bindOwner(ownerB)
        }
        assertNull(vault.stored)
        assertEquals(0, push.deletions)
        assertThrows(IllegalArgumentException::class.java) { coordinator.snapshot(ownerA) }
    }

    @Test fun `provider timeout denies rebind and retains cleanup intent`() {
        val vault = Vault().also { it.stored = device() }
        val marker = Marker(true)
        val push = Push(marker)
        val coordinator = GuardianRecipientCoordinator(vault) { now }
        coordinator.bindOwner(ownerA)
        assertThrows(IllegalStateException::class.java) {
            GuardianRecipientOwnerLifecycle(coordinator, vault, marker, push, { now }, 10).bindOwner(ownerB)
        }
        assertNull(vault.stored)
        assertTrue(marker.marked)
        assertEquals(1, push.deletions)
    }
}
