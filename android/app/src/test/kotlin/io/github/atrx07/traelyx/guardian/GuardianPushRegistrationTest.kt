package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianPushRegistrationTest {
    private val consent = GuardianNotificationConsent("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222")

    @Test fun `construction and configured status do not register or initialize provider`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        assertTrue(provider.configured)
        assertEquals(0, backend.acquires)
        assertEquals(0, backend.deletions)
    }

    @Test fun `missing config permission and services do not acquire token`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        for (reason in listOf("notification_permission_required", "play_services_unavailable")) {
            backend.reason = reason
            provider.register(consent) { assertEquals(reason, (it as GuardianRegistrationResult.Unavailable).code) }
        }
        backend.configured = false
        provider.register(consent) { assertEquals("provider_not_configured", (it as GuardianRegistrationResult.Unavailable).code) }
        assertEquals(0, backend.acquires)
    }

    @Test fun `sign out waits for in flight registration then deletes before confirming cleanup`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        var registration: GuardianRegistrationResult? = null
        var deleted: Boolean? = null
        provider.register(consent) { registration = it }
        provider.unregister { deleted = it }
        assertEquals(0, backend.deletions)
        backend.acquired("synthetic-routing-token")
        assertEquals("consent_changed", (registration as GuardianRegistrationResult.Unavailable).code)
        assertEquals(1, backend.deletions)
        assertNull(deleted)
        provider.register(consent) { assertEquals("cleanup_required", (it as GuardianRegistrationResult.Unavailable).code) }
        backend.deleted(true)
        assertEquals(true, deleted)
    }

    @Test fun `failed cleanup prevents registration until successful retry`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        provider.unregister { assertFalse(it) }
        backend.deleted(false)
        provider.register(consent) { assertEquals("cleanup_required", (it as GuardianRegistrationResult.Unavailable).code) }
        assertEquals(0, backend.acquires)
        provider.unregister { assertTrue(it) }
        backend.deleted(true)
        provider.register(consent) { }
        assertEquals(1, backend.acquires)
    }

    @Test fun `success retains exact consent but diagnostics redact routing token`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        provider.register(consent) {
            assertEquals(consent, (it as GuardianRegistrationResult.Registered).consent)
            assertFalse(it.toString().contains("synthetic-routing-token"))
        }
        backend.acquired("synthetic-routing-token")
    }

    @Test fun `duplicate callback does not register or delete twice`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        var delivered = 0
        provider.register(consent) { delivered++ }
        provider.unregister { }
        backend.acquired("synthetic-routing-token")
        backend.acquired("synthetic-routing-token")
        assertEquals(1, delivered)
        assertEquals(1, backend.deletions)
    }

    @Test fun `different account or consent during registration invalidates old result`() {
        val backend = FakeBackend()
        val provider = ConsentBoundGuardianRegistration(backend)
        var oldResult: GuardianRegistrationResult? = null
        var newResult: GuardianRegistrationResult? = null
        provider.register(consent) { oldResult = it }
        provider.register(consent.copy(ownerId = "33333333-3333-4333-8333-333333333333")) { newResult = it }
        backend.acquired("synthetic-routing-token")
        assertEquals("consent_changed", (oldResult as GuardianRegistrationResult.Unavailable).code)
        assertEquals("cleanup_required", (newResult as GuardianRegistrationResult.Unavailable).code)
        assertEquals(1, backend.deletions)
    }

    private class FakeBackend : GuardianRegistrationBackend {
        override var configured = true
        var reason: String? = null
        var acquires = 0
        var deletions = 0
        lateinit var acquired: (String?) -> Unit
        lateinit var deleted: (Boolean) -> Unit
        override fun unavailableReason() = reason
        override fun acquire(complete: (String?) -> Unit) { acquires++; acquired = complete }
        override fun delete(complete: (Boolean) -> Unit) { deletions++; deleted = complete }
    }
}
