package io.github.atrx07.traelyx.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GuardianIncomingReceiptTest {
    private val now = 1_800_000_000_000L
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val deviceId = "22222222-2222-4222-8222-222222222222"
    private val generation = "33333333-3333-4333-8333-333333333333"
    private val delivery = "44444444-4444-4444-8444-444444444444"
    private val credential = "a".repeat(64)
    private val endpoint = "https://abcdefghijklmnopqrst.supabase.co/functions/v1/guardian-capability"
    private val data = mapOf(
        "schema_version" to "1", "delivery_id" to delivery, "device_generation" to generation,
    )

    private class Vault(var stored: GuardianRecipientDevice?) : GuardianRecipientVault {
        override fun readStored() = stored
        override fun write(device: GuardianRecipientDevice) { stored = device }
        override fun erase() { stored = null }
    }

    private class Marker(var marked: Boolean = true) : GuardianProviderMarker {
        override fun present() = marked
        override fun mark() { marked = true }
        override fun clear() { marked = false }
    }

    private class Transport : GuardianReceiptTransport {
        var calls = 0
        var body: String? = null
        var response = GuardianReceiptResponse(200, "{\"received\":true}")
        var beforeResponse: (() -> Unit)? = null
        override fun post(endpoint: String, body: ByteArray): GuardianReceiptResponse {
            calls++
            this.body = body.toString(Charsets.UTF_8)
            beforeResponse?.invoke()
            return response
        }
    }

    private fun device() = GuardianRecipientDevice(
        owner, deviceId, generation, credential, now - 1_000, now + 60_000,
    )

    private fun handler(vault: Vault, marker: Marker, transport: Transport, notices: MutableList<String>) =
        GuardianIncomingMessageHandler(
            GuardianPushPreflight(vault, marker) { now },
            GuardianCapabilityReceiptGateway(endpoint, transport),
            GuardianGenericNotice { notices.add(it) },
        )

    @Test fun `exact server receipt and stable local registration allow one generic notice`() {
        val transport = Transport()
        val notices = mutableListOf<String>()
        handler(Vault(device()), Marker(), transport, notices).handle(data, false)
        assertEquals(1, transport.calls)
        assertEquals(
            "{\"type\":\"receipt\",\"device\":\"$deviceId\",\"credential\":\"$credential\",\"delivery\":\"$delivery\"}",
            transport.body,
        )
        assertEquals(listOf(delivery), notices)
    }

    @Test fun `server denial or an unexpected response never posts a notice`() {
        val transport = Transport()
        val notices = mutableListOf<String>()
        val handler = handler(Vault(device()), Marker(), transport, notices)
        for (response in listOf(
            GuardianReceiptResponse(503, ""),
            GuardianReceiptResponse(200, "{\"received\":false}"),
            GuardianReceiptResponse(200, "{\"received\":true,\"name\":\"private\"}"),
        )) {
            transport.response = response
            handler.handle(data, false)
        }
        assertEquals(3, transport.calls)
        assertTrue(notices.isEmpty())
    }

    @Test fun `withdrawal while server responds prevents a stale notice`() {
        val vault = Vault(device())
        val marker = Marker()
        val transport = Transport().also {
            it.beforeResponse = { vault.erase(); marker.clear() }
        }
        val notices = mutableListOf<String>()
        handler(vault, marker, transport, notices).handle(data, false)
        assertEquals(1, transport.calls)
        assertTrue(notices.isEmpty())
    }

    @Test fun `malformed payload and missing local authority never contact server`() {
        val transport = Transport()
        val notices = mutableListOf<String>()
        val marker = Marker()
        val handler = handler(Vault(device()), marker, transport, notices)
        handler.handle(data + ("driver_name" to "private"), false)
        handler.handle(data, true)
        marker.clear()
        handler.handle(data, false)
        assertEquals(0, transport.calls)
        assertTrue(notices.isEmpty())
    }

    @Test fun `only the fixed HTTPS capability endpoint can receive credentials`() {
        val request = GuardianPushReceiptRequest(delivery, deviceId, credential)
        val transport = Transport()
        assertFalse(GuardianCapabilityReceiptGateway(
            "http://abcdefghijklmnopqrst.supabase.co/functions/v1/guardian-capability", transport,
        ).receive(request))
        assertFalse(GuardianCapabilityReceiptGateway(
            "$endpoint/other", transport,
        ).receive(request))
        assertEquals(0, transport.calls)
        assertTrue(GuardianCapabilityReceiptGateway(endpoint, transport).receive(request))
    }
}
