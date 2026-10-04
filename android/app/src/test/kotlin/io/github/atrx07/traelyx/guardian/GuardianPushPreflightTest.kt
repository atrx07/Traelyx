package io.github.atrx07.traelyx.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class GuardianPushPreflightTest {
    private val now = 1_800_000_000_000L
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val deviceId = "22222222-2222-4222-8222-222222222222"
    private val generation = "33333333-3333-4333-8333-333333333333"
    private val delivery = "44444444-4444-4444-8444-444444444444"
    private val credential = "a".repeat(64)
    private val data = mapOf(
        "schema_version" to "1", "delivery_id" to delivery, "device_generation" to generation,
    )

    private class Vault(var stored: GuardianRecipientDevice? = null) : GuardianRecipientVault {
        var failRead = false
        override fun readStored(): GuardianRecipientDevice? {
            if (failRead) error("unavailable")
            return stored
        }
        override fun write(device: GuardianRecipientDevice) { stored = device }
        override fun erase() { stored = null }
    }

    private class Marker(var marked: Boolean = true) : GuardianProviderMarker {
        var failRead = false
        override fun present(): Boolean {
            if (failRead) error("unavailable")
            return marked
        }
        override fun mark() { marked = true }
        override fun clear() { marked = false }
    }

    private fun device() = GuardianRecipientDevice(
        owner, deviceId, generation, credential, now - 1_000, now + 60_000,
    )

    @Test fun `valid local generation yields only a transient redacted receipt request`() {
        val request = GuardianPushPreflight(Vault(device()), Marker()) { now }.check(data, false)
        assertNotNull(request)
        assertEquals(delivery, request!!.deliveryId)
        assertEquals(deviceId, request.deviceId)
        assertEquals(credential, request.credential)
        assertFalse(request.toString().contains(credential))
        assertFalse(request.toString().contains(delivery))
    }

    @Test fun `malformed message cannot read local authority`() {
        val vault = Vault(device()).also { it.failRead = true }
        val marker = Marker().also { it.failRead = true }
        val preflight = GuardianPushPreflight(vault, marker) { now }
        assertNull(preflight.check(data + ("driver_name" to "private"), false))
        assertNull(preflight.check(data, true))
    }

    @Test fun `missing revoked expired or mismatched local authority denies receipt`() {
        val vault = Vault(device())
        val marker = Marker()
        val preflight = GuardianPushPreflight(vault, marker) { now }
        marker.marked = false
        assertNull(preflight.check(data, false))
        marker.marked = true
        vault.stored = null
        assertNull(preflight.check(data, false))
        vault.stored = device()
        assertNull(preflight.check(data + ("device_generation" to owner), false))
        assertNull(GuardianPushPreflight(vault, marker) { now + 60_000 }.check(data, false))
    }

    @Test fun `corrupt or uncertain local state fails closed`() {
        val vault = Vault(device()).also { it.failRead = true }
        val marker = Marker()
        assertNull(GuardianPushPreflight(vault, marker) { now }.check(data, false))
        vault.failRead = false
        marker.failRead = true
        assertNull(GuardianPushPreflight(vault, marker) { now }.check(data, false))
    }
}
