package io.github.atrx07.traelyx.guardian

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

internal data class GuardianReceiptResponse(val status: Int, val body: String)

internal fun interface GuardianReceiptTransport {
    fun post(endpoint: String, body: ByteArray): GuardianReceiptResponse?
}

/** Bounded, no-redirect HTTPS transport. No response body or credential is logged. */
internal class BoundedGuardianHttpsTransport : GuardianReceiptTransport {
    override fun post(endpoint: String, body: ByteArray): GuardianReceiptResponse? {
        val connection = URL(endpoint).openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 3_000
            connection.readTimeout = 3_000
            connection.useCaches = false
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Cache-Control", "no-store")
            connection.setFixedLengthStreamingMode(body.size)
            connection.outputStream.use { it.write(body) }
            if (connection.responseCode != 200) return GuardianReceiptResponse(connection.responseCode, "")
            val output = ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer = ByteArray(64)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > 128) return null
                    output.write(buffer, 0, count)
                }
            }
            GuardianReceiptResponse(200, output.toString(Charsets.UTF_8.name()))
        } finally {
            connection.disconnect()
        }
    }
}

/** A server receipt is accepted only for the exact fixed response contract. */
internal class GuardianCapabilityReceiptGateway(
    private val endpoint: String,
    private val transport: GuardianReceiptTransport,
    private val trace: GuardianReceiveTrace = GuardianReceiveTrace(),
) {
    fun receive(request: GuardianPushReceiptRequest): Boolean {
        if (!ENDPOINT.matches(endpoint) || !UUID.matches(request.deliveryId) ||
            !UUID.matches(request.deviceId) || !CREDENTIAL.matches(request.credential)) {
            trace.record(GuardianReceiveStage.RECEIPT_REQUEST_REJECTED)
            return false
        }
        val body = ("{\"type\":\"receipt\",\"device\":\"${request.deviceId}\"," +
            "\"credential\":\"${request.credential}\",\"delivery\":\"${request.deliveryId}\"}")
            .toByteArray(Charsets.UTF_8)
        val response = try {
            runCatching { transport.post(endpoint, body) }.getOrNull()
        } finally {
            body.fill(0)
        }
        if (response == null) {
            trace.record(GuardianReceiveStage.RECEIPT_TRANSPORT_UNCONFIRMED)
            return false
        }
        val confirmed = response.status == 200 && RECEIVED_TRUE.matches(response.body)
        trace.record(if (confirmed) GuardianReceiveStage.RECEIPT_CONFIRMED else GuardianReceiveStage.RECEIPT_RESPONSE_REJECTED)
        return confirmed
    }

    private companion object {
        val ENDPOINT = Regex("^https://[a-z0-9]{20}\\.supabase\\.co/functions/v1/guardian-capability$")
        val UUID = Regex("^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$")
        val CREDENTIAL = Regex("^[a-f0-9]{64}$")
        val RECEIVED_TRUE = Regex("^\\{\\s*\"received\"\\s*:\\s*true\\s*\\}$")
    }
}

internal fun interface GuardianGenericNotice {
    fun post(deliveryId: String)
}

internal fun interface GuardianNoticeClaim {
    fun claim(request: GuardianPushReceiptRequest, generation: String): Boolean
}

/** Remote confirmation and a second local check precede any generic notice. */
internal class GuardianIncomingMessageHandler(
    private val preflight: GuardianPushPreflight,
    private val receipt: GuardianCapabilityReceiptGateway,
    private val claim: GuardianNoticeClaim,
    private val notice: GuardianGenericNotice,
    private val trace: GuardianReceiveTrace = GuardianReceiveTrace(),
) {
    fun handle(data: Map<String, String>, hasNotificationPayload: Boolean) {
        val first = preflight.check(data, hasNotificationPayload)
        if (first == null) {
            trace.record(GuardianReceiveStage.PREFLIGHT_REJECTED)
            return
        }
        if (!receipt.receive(first)) return
        val current = preflight.check(data, hasNotificationPayload)
        if (current == null || current.deviceId != first.deviceId || current.credential != first.credential ||
            current.deliveryId != first.deliveryId) {
            trace.record(GuardianReceiveStage.AUTHORITY_CHANGED)
            return
        }
        if (!runCatching { claim.claim(current, data.getValue("device_generation")) }.getOrDefault(false)) {
            trace.record(GuardianReceiveStage.CLAIM_UNAVAILABLE)
            return
        }
        trace.record(GuardianReceiveStage.NOTICE_CLAIMED)
        val final = preflight.check(data, hasNotificationPayload)
        if (final == null || final.deviceId != current.deviceId || final.credential != current.credential) {
            trace.record(GuardianReceiveStage.FINAL_AUTHORITY_REJECTED)
            return
        }
        // A successful notify call does not prove Android display or user attention.
        runCatching { notice.post(first.deliveryId) }
            .onSuccess { trace.record(GuardianReceiveStage.NOTICE_POST_ATTEMPTED) }
            .onFailure { trace.record(GuardianReceiveStage.NOTICE_POST_FAILED) }
    }
}
