package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class MarkedGuardianPushRegistrationTest {
    private val consent = GuardianNotificationConsent(
        "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222",
    )

    private class Marker : GuardianProviderMarker {
        var marked = false
        var failMark = false
        var failClear = false
        override fun present() = marked
        override fun mark() {
            if (failMark) error("disk failure")
            marked = true
        }
        override fun clear() {
            if (failClear) error("disk failure")
            marked = false
        }
    }

    private class Provider(private val marker: Marker) : GuardianPushRegistration {
        override var configured = true
        var registers = 0
        var deletions = 0
        var deleteSuccess = true
        var registrationCallback: ((GuardianRegistrationResult) -> Unit)? = null
        override fun register(consent: GuardianNotificationConsent, complete: (GuardianRegistrationResult) -> Unit) {
            check(marker.marked) { "Firebase requested a token before cleanup intent was durable" }
            registers++
            registrationCallback = complete
        }
        override fun unregister(complete: (Boolean) -> Unit) {
            deletions++
            complete(deleteSuccess)
        }
    }

    @Test fun `construction and unavailable configuration remain inert`() {
        val marker = Marker()
        val provider = Provider(marker).also { it.configured = false }
        val marked = MarkedGuardianPushRegistration(marker, provider)
        assertFalse(marked.configured)
        assertFalse(marker.marked)
        marked.register(consent) {
            assertEquals("provider_not_configured", (it as GuardianRegistrationResult.Unavailable).code)
        }
        assertFalse(marker.marked)
        assertEquals(0, provider.registers)
    }

    @Test fun `durable marker precedes token request and survives process restart`() {
        val marker = Marker()
        val provider = Provider(marker)
        val marked = MarkedGuardianPushRegistration(marker, provider)
        marked.register(consent) { assertTrue(it is GuardianRegistrationResult.Registered) }
        assertTrue(marker.marked)
        assertEquals(1, provider.registers)
        provider.registrationCallback!!(GuardianRegistrationResult.Registered("synthetic-routing-token", consent))
        val restarted = MarkedGuardianPushRegistration(marker, provider)
        restarted.register(consent) {
            assertEquals("cleanup_required", (it as GuardianRegistrationResult.Unavailable).code)
        }
        assertEquals(1, provider.registers)
        restarted.unregister { assertTrue(it) }
        assertFalse(marker.marked)
        assertEquals(1, provider.deletions)
    }

    @Test fun `failed marker write forbids provider registration`() {
        val marker = Marker().also { it.failMark = true }
        val provider = Provider(marker)
        MarkedGuardianPushRegistration(marker, provider).register(consent) {
            assertEquals("storage_unavailable", (it as GuardianRegistrationResult.Unavailable).code)
        }
        assertEquals(0, provider.registers)
    }

    @Test fun `failed token deletion retains cleanup marker for retry`() {
        val marker = Marker().also { it.marked = true }
        val provider = Provider(marker).also { it.deleteSuccess = false }
        val marked = MarkedGuardianPushRegistration(marker, provider)
        marked.unregister { assertFalse(it) }
        assertTrue(marker.marked)
        provider.deleteSuccess = true
        marked.unregister { assertTrue(it) }
        assertFalse(marker.marked)
        assertEquals(2, provider.deletions)
    }

    @Test fun `failed marker removal remains cleanup required`() {
        val marker = Marker().also { it.marked = true; it.failClear = true }
        val provider = Provider(marker)
        val marked = MarkedGuardianPushRegistration(marker, provider)
        marked.unregister { assertFalse(it) }
        assertTrue(marker.marked)
        marked.register(consent) {
            assertEquals("cleanup_required", (it as GuardianRegistrationResult.Unavailable).code)
        }
        marker.failClear = false
        marked.unregister { assertTrue(it) }
        assertFalse(marker.marked)
    }

    @Test fun `in flight registration cannot clear marker before deletion`() {
        val marker = Marker()
        val backend = object : GuardianRegistrationBackend {
            override val configured = true
            var deletions = 0
            lateinit var acquired: (String?) -> Unit
            lateinit var deleted: (Boolean) -> Unit
            override fun unavailableReason(): String? = null
            override fun acquire(complete: (String?) -> Unit) { acquired = complete }
            override fun delete(complete: (Boolean) -> Unit) { deletions++; deleted = complete }
        }
        val marked = MarkedGuardianPushRegistration(marker, ConsentBoundGuardianRegistration(backend))
        var registration: GuardianRegistrationResult? = null
        var cleanup: Boolean? = null
        marked.register(consent) { registration = it }
        marked.unregister { cleanup = it }
        assertTrue(marker.marked)
        assertEquals(0, backend.deletions)
        assertNull(cleanup)
        backend.acquired("synthetic-routing-token")
        assertEquals("consent_changed", (registration as GuardianRegistrationResult.Unavailable).code)
        assertEquals(1, backend.deletions)
        assertTrue(marker.marked)
        assertNull(cleanup)
        backend.deleted(true)
        assertEquals(true, cleanup)
        assertFalse(marker.marked)
    }
}
