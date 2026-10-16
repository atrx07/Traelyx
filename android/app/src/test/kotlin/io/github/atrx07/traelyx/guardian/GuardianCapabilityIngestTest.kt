package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianCapabilityIngestTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"
    private val other = "44444444-4444-4444-8444-444444444444"
    private val start = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
    private val endpoint = "https://abcdefghijklmnopqrst.supabase.co/functions/v1/guardian-capability"
    private fun now(delta: Long = 30_000) = start.copy(
        epochMillis = start.epochMillis + delta, elapsedMillis = start.elapsedMillis + delta,
    )
    private fun lease() = GuardianDriverLease(owner, activation, "a".repeat(64), start.epochMillis,
        start.elapsedMillis, start.epochMillis + 28_800_000, start.bootId, "+y")
    private fun alert() = GuardianPendingAlert(event, owner, activation, GuardianAlertKind.POSSIBLE_CRASH,
        start.epochMillis, start.elapsedMillis, start.bootId)
    private fun attempt() = GuardianDispatchAttempt(lease(), alert().advance(now().elapsedMillis,
        now().epochMillis, start.bootId, owner, activation).reserveAttempt(now().elapsedMillis))
    private fun accepted(id: String = event, duplicate: Boolean = false) =
        "{\"event_id\":\"$id\",\"state\":\"backend_accepted\",\"duplicate\":$duplicate,\"recipient_devices\":1}"

    private class Transport : GuardianReceiptTransport {
        var calls = 0
        var request = ""
        var buffer: ByteArray? = null
        var response: GuardianReceiptResponse? = null
        var onPost: (() -> Unit)? = null
        override fun post(endpoint: String, body: ByteArray): GuardianReceiptResponse? {
            calls++
            request = body.toString(Charsets.UTF_8)
            buffer = body
            onPost?.invoke()
            return response
        }
    }

    private class Vault : GuardianVault {
        var snapshot = GuardianVaultSnapshot()
        var failWrites = false
        override fun read() = snapshot
        override fun write(snapshot: GuardianVaultSnapshot) {
            if (failWrites) error("synthetic disk failure")
            this.snapshot = snapshot
        }
        override fun erase() { snapshot = GuardianVaultSnapshot() }
    }
    private fun gateway(transport: Transport, url: String = endpoint, clock: () -> GuardianClock = { now() }) =
        GuardianCapabilityIngestGateway(url, transport, clock)
    private fun active(vault: Vault) = GuardianOutbox(vault).also {
        it.activate(lease(), start)
        it.enqueue(owner, activation,
            GuardianDetection(GuardianAlertKind.POSSIBLE_CRASH, 9_000_000_000, 10_000_000_000),
            GuardianSafetyCooldowns(10_000_000_000, 10_000_000_000), start, event)
    }

    @Test fun `request has only the capability authorization and six approved envelope fields`() {
        val transport = Transport().also { it.response = GuardianReceiptResponse(200, accepted()) }
        assertEquals(GuardianIngestResult.BACKEND_ACCEPTED, gateway(transport).ingest(attempt()))
        assertEquals("{\"type\":\"ingest\",\"owner_id\":\"$owner\",\"credential\":\"${lease().credential}\"," +
            "\"envelope\":{\"schema_version\":1,\"event_id\":\"$event\",\"kind\":\"possible_crash\"," +
            "\"rule_version\":1,\"occurred_at_epoch_ms\":${start.epochMillis}," +
            "\"uncertainty\":\"experimental_not_confirmed\"}}", transport.request)
        assertTrue(transport.buffer!!.all { it == 0.toByte() })
        assertFalse(attempt().toString().contains(owner))
        assertFalse(attempt().toString().contains(lease().credential))
        val severe = attempt().alert.copy(kind = GuardianAlertKind.SEVERE_DRIVE)
        gateway(transport).ingest(GuardianDispatchAttempt(lease(), severe))
        assertTrue(transport.request.contains("\"kind\":\"severe_drive\""))
    }

    @Test fun `only exact current event acceptance or an explicit duplicate is accepted`() {
        val transport = Transport()
        val gateway = gateway(transport)
        for (response in listOf(accepted(), accepted(duplicate = true),
            "{\"duplicate\":true,\"state\":\"backend_accepted\",\"event_id\":\"$event\"}",
            "{ \"recipient_devices\" : 30, \"duplicate\":false,\"state\":\"backend_accepted\",\"event_id\":\"$event\"}")) {
            assertTrue(response.length <= GuardianCapabilityIngestGateway.MAX_RESPONSE_BYTES)
            transport.response = GuardianReceiptResponse(200, response)
            assertEquals(GuardianIngestResult.BACKEND_ACCEPTED, gateway.ingest(attempt()))
        }
    }

    @Test fun `malformed ambiguous extended wrong event and impossible count responses stay unconfirmed`() {
        val transport = Transport()
        val gateway = gateway(transport)
        val good = accepted()
        for (body in listOf(accepted(other), good.dropLast(1), "$good\n", "[$good]",
            good.replace("backend_accepted", "received"),
            good.replace("\"duplicate\":false", "\"duplicate\":\"false\""),
            good.replace("\"duplicate\":false,", ""),
            good.replace(",\"recipient_devices\":1", ""),
            good.replace("\"recipient_devices\":1", "\"recipient_devices\":31"),
            good.replace("\"recipient_devices\":1", "\"recipient_devices\":-1"),
            good.replace("\"recipient_devices\":1", "\"recipient_devices\":01"),
            good.replace("\"recipient_devices\":1", "\"recipient_devices\":1.0"),
            good.replace("\"recipient_devices\":1", "\"recipient_devices\":true"),
            good.replace("\"recipient_devices\":1", "\"recipient_devices\":\"1\""),
            good.replace("\"recipient_devices\":1", "\"private_name\":\"extra\""),
            good.replace("\"recipient_devices\":1", "\"duplicate\":true"),
            good.replace("{", "{\"duplicate\":true,"),
            good.replace("{", "{" + " ".repeat(128)))) {
            transport.response = GuardianReceiptResponse(200, body)
            assertEquals(GuardianIngestResult.UNCONFIRMED, gateway.ingest(attempt()))
        }
    }

    @Test fun `authorization denial differs from rate limiting server failures redirects and transport loss`() {
        val transport = Transport()
        val gateway = gateway(transport)
        for (status in listOf(401, 403)) {
            transport.response = GuardianReceiptResponse(status, "")
            assertEquals(GuardianIngestResult.AUTHORIZATION_DENIED, gateway.ingest(attempt()))
        }
        for (status in listOf(201, 204, 301, 302, 307, 308, 400, 409, 429, 500, 503)) {
            transport.response = GuardianReceiptResponse(status, accepted())
            assertEquals(GuardianIngestResult.UNCONFIRMED, gateway.ingest(attempt()))
        }
        transport.response = null
        assertEquals(GuardianIngestResult.UNCONFIRMED, gateway.ingest(attempt()))
        assertTrue(transport.buffer!!.all { it == 0.toByte() })
        transport.onPost = { error("synthetic failure with credential-like details") }
        assertEquals(GuardianIngestResult.UNCONFIRMED, gateway.ingest(attempt()))
        assertTrue(transport.buffer!!.all { it == 0.toByte() })
    }

    @Test fun `endpoint confusion never exposes a credential to transport`() {
        val transport = Transport()
        for (url in listOf("", endpoint.replace("https:", "http:"), "$endpoint/", "$endpoint?x=1",
            "$endpoint#fragment", endpoint.replace("https://", "https://user@"),
            endpoint.replace(".supabase.co", ".supabase.co.evil.test"), endpoint.uppercase(),
            endpoint.replace(".co/", ".co:443/"))) {
            assertEquals(GuardianIngestResult.UNCONFIRMED, gateway(transport, url).ingest(attempt()))
        }
        assertEquals(0, transport.calls)
    }

    @Test fun `unreserved cancelled wrong owner generation or boot attempt never reaches transport`() {
        val transport = Transport()
        val reserved = attempt().alert
        for (alert in listOf(alert(), reserved.copy(attempts = 0), reserved.copy(state = GuardianSendState.CANCELLED),
            reserved.copy(ownerId = other), reserved.copy(consentGeneration = other), reserved.copy(bootId = "boot-2"),
            reserved.copy(occurredAtEpochMillis = start.epochMillis - 1),
            reserved.copy(createdAtElapsedMillis = start.elapsedMillis - 1),
            reserved.copy(occurredAtEpochMillis = 9_007_199_254_740_992L))) {
            assertEquals(GuardianIngestResult.UNCONFIRMED,
                gateway(transport).ingest(GuardianDispatchAttempt(lease(), alert)))
        }
        assertEquals(0, transport.calls)
    }

    @Test fun `expiry reboot clock rollback and unavailable clock deny before transport`() {
        val transport = Transport()
        for (clock in listOf(now(29_999), now(600_000), now(28_800_000), now().copy(bootId = "boot-2"),
            now().copy(epochMillis = start.epochMillis - 1), now().copy(elapsedMillis = start.elapsedMillis - 1))) {
            assertEquals(GuardianIngestResult.UNCONFIRMED, gateway(transport, clock = { clock }).ingest(attempt()))
        }
        assertEquals(GuardianIngestResult.UNCONFIRMED,
            gateway(transport, clock = { error("clock unavailable") }).ingest(attempt()))
        assertEquals(0, transport.calls)
    }

    @Test fun `durable cancellation blocks reservation and failed persistence cannot authorize IO`() {
        val vault = Vault()
        val outbox = active(vault)
        assertTrue(outbox.cancel(owner, event, start))
        assertNull(GuardianOutbox(vault).reserveNext(owner, now()))
        val failed = Vault()
        val pending = active(failed)
        failed.failWrites = true
        try { pending.reserveNext(owner, now()); fail("Must persist before returning authority") }
        catch (_: IllegalStateException) { }
        assertEquals(0, failed.snapshot.alerts.single().attempts)
    }

    @Test fun `unconfirmed retry retains event and reservation across outbox recreation`() {
        val vault = Vault()
        val outbox = active(vault)
        val first = outbox.reserveNext(owner, now())!!
        val transport = Transport()
        assertEquals(GuardianIngestResult.UNCONFIRMED, gateway(transport).ingest(first))
        outbox.complete(first, false, false, now())
        val reopened = GuardianOutbox(vault)
        assertNull(reopened.reserveNext(owner, now(34_999)))
        val second = reopened.reserveNext(owner, now(35_000))!!
        assertEquals(event, second.alert.eventId)
        assertEquals(2, second.alert.attempts)
        transport.response = GuardianReceiptResponse(200, accepted(duplicate = true))
        assertEquals(GuardianIngestResult.BACKEND_ACCEPTED, gateway(transport, clock = { now(35_000) }).ingest(second))
        reopened.complete(second, true, false, now(35_000))
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, vault.snapshot.alerts.single().state)
        assertNull(reopened.reserveNext(owner, now(40_000)))
    }

    @Test fun `late accepted response after local revocation or replacement restores nothing`() {
        for (replace in listOf(false, true)) {
            val vault = Vault()
            val outbox = active(vault)
            val reserved = outbox.reserveNext(owner, now())!!
            val transport = Transport().also {
                it.response = GuardianReceiptResponse(200, accepted())
                it.onPost = {
                    outbox.revoke()
                    if (replace) outbox.activate(lease().copy(activationId = other), now())
                }
            }
            assertEquals(GuardianIngestResult.BACKEND_ACCEPTED, gateway(transport).ingest(reserved))
            outbox.complete(reserved, true, false, now())
            assertTrue(vault.snapshot.alerts.isEmpty())
            assertEquals(if (replace) other else null, vault.snapshot.lease?.activationId)
        }
    }

    @Test fun `denied result ends this event without claiming recipient delivery`() {
        val vault = Vault()
        val outbox = active(vault)
        val reserved = outbox.reserveNext(owner, now())!!
        val transport = Transport().also { it.response = GuardianReceiptResponse(401, "") }
        val result = gateway(transport).ingest(reserved)
        outbox.complete(reserved, result == GuardianIngestResult.BACKEND_ACCEPTED,
            result == GuardianIngestResult.AUTHORIZATION_DENIED, now())
        assertEquals(GuardianSendState.CONSENT_REVOKED, vault.snapshot.alerts.single().state)
        assertNull(outbox.reserveNext(owner, now(40_000)))
    }
}
