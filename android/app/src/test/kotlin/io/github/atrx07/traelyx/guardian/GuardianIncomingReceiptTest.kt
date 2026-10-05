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

    private fun handler(
        vault: Vault, marker: Marker, transport: Transport, notices: MutableList<String>,
        clock: () -> Long = { now },
        claim: GuardianNoticeClaim = GuardianNoticeClaim { request, _ ->
            val stored = vault.stored!!
            if (request.deliveryId in stored.noticeDeliveryIds) false else {
                vault.stored = stored.copy(noticeDeliveryIds = stored.noticeDeliveryIds + request.deliveryId)
                true
            }
        },
        notice: GuardianGenericNotice = GuardianGenericNotice { notices.add(it) },
    ) =
        GuardianIncomingMessageHandler(
            GuardianPushPreflight(vault, marker, clock),
            GuardianCapabilityReceiptGateway(endpoint, transport),
            claim,
            notice,
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

    @Test fun `duplicate after dismissal and handler recreation never redisplays`() {
        val vault = Vault(device())
        val marker = Marker()
        val transport = Transport()
        val notices = mutableListOf<String>()
        handler(vault, marker, transport, notices).handle(data, false)
        notices.clear() // Dismissal does not erase the durable claim.
        handler(vault, marker, transport, notices).handle(data, false)
        assertTrue(notices.isEmpty())
        assertEquals(listOf(delivery), vault.stored!!.noticeDeliveryIds)
    }

    @Test fun `a distinct authorized delivery still posts after an earlier claim`() {
        val vault = Vault(device())
        val notices = mutableListOf<String>()
        val handler = handler(vault, Marker(), Transport(), notices)
        val second = "55555555-5555-4555-8555-555555555555"
        handler.handle(data, false)
        handler.handle(data + ("delivery_id" to second), false)
        handler.handle(data, false)
        assertEquals(listOf(delivery, second), notices)
    }

    @Test fun `lost receipt response can retry before any notice is claimed`() {
        val vault = Vault(device())
        val marker = Marker()
        val transport = Transport().also { it.beforeResponse = { error("network timeout") } }
        val notices = mutableListOf<String>()
        val handler = handler(vault, marker, transport, notices)
        handler.handle(data, false)
        assertTrue(vault.stored!!.noticeDeliveryIds.isEmpty())
        transport.beforeResponse = null
        handler.handle(data, false)
        assertEquals(listOf(delivery), notices)
    }

    @Test fun `display failure retains claim and never attempts that notice again`() {
        val vault = Vault(device())
        val marker = Marker()
        val transport = Transport()
        val notices = mutableListOf<String>()
        var attempts = 0
        val failedNotice = GuardianGenericNotice { attempts++; error("display unavailable") }
        handler(vault, marker, transport, notices, notice = failedNotice).handle(data, false)
        handler(vault, marker, transport, notices, notice = failedNotice).handle(data, false)
        assertEquals(1, attempts)
        assertEquals(listOf(delivery), vault.stored!!.noticeDeliveryIds)
        assertTrue(notices.isEmpty())
    }

    @Test fun `expiry or replacement while receipt responds prevents claim and display`() {
        for (replace in listOf(false, true)) {
            var clock = now
            val vault = Vault(device())
            val transport = Transport().also { it.beforeResponse = {
                if (replace) vault.stored = device().copy(credential = "b".repeat(64))
                else clock = device().expiresAtEpochMillis
            } }
            val notices = mutableListOf<String>()
            handler(vault, Marker(), transport, notices, { clock }).handle(data, false)
            assertTrue(notices.isEmpty())
            assertTrue(vault.stored!!.noticeDeliveryIds.isEmpty())
        }
    }

    @Test fun `failed claim and local withdrawal during claim suppress notice`() {
        for (withdraw in listOf(false, true)) {
            val vault = Vault(device())
            val marker = Marker()
            val notices = mutableListOf<String>()
            val claim = GuardianNoticeClaim { _, _ ->
                if (withdraw) { vault.erase(); marker.clear(); true } else error("disk uncertain")
            }
            handler(vault, marker, Transport(), notices, claim = claim).handle(data, false)
            assertTrue(notices.isEmpty())
        }
    }
}
