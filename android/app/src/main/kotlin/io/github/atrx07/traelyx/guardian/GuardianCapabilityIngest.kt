package io.github.atrx07.traelyx.guardian

internal enum class GuardianIngestResult { BACKEND_ACCEPTED, AUTHORIZATION_DENIED, UNCONFIRMED }

internal fun interface GuardianIngestPort {
    fun ingest(attempt: GuardianDispatchAttempt): GuardianIngestResult
}

/** Dormant adapter: only a durably reserved outbox attempt may be handed to this port.
 * The future runtime must recheck authority immediately before IO on its separate network worker.
 * No Auth refresh token, trip identity or raw evidence is accepted by this interface.
 */
internal class GuardianCapabilityIngestGateway(
    private val endpoint: String,
    private val transport: GuardianReceiptTransport,
    private val clock: () -> GuardianClock,
) : GuardianIngestPort {
    override fun ingest(attempt: GuardianDispatchAttempt): GuardianIngestResult {
        val lease = attempt.lease
        val alert = attempt.alert
        if (!ENDPOINT.matches(endpoint) || alert.ownerId != lease.ownerId ||
            alert.consentGeneration != lease.activationId || alert.bootId != lease.bootId ||
            alert.state != GuardianSendState.QUEUED || alert.attempts !in 1..GuardianPendingAlert.MAX_ATTEMPTS ||
            alert.occurredAtEpochMillis > 9_007_199_254_740_991L ||
            alert.occurredAtEpochMillis < lease.startedEpochMillis ||
            alert.createdAtElapsedMillis < lease.startedElapsedMillis) {
            return GuardianIngestResult.UNCONFIRMED
        }
        val now = runCatching(clock).getOrNull() ?: return GuardianIngestResult.UNCONFIRMED
        if (!lease.valid(now, lease.ownerId) ||
            now.elapsedMillis - alert.createdAtElapsedMillis < GuardianPendingAlert.CANCEL_WINDOW_MILLIS ||
            alert.advance(now.elapsedMillis, now.epochMillis,
                now.bootId, lease.ownerId, lease.activationId) != alert) return GuardianIngestResult.UNCONFIRMED
        // Each interpolated value is constrained by the native lease/alert constructors.
        // Keep this separate from generic telemetry serialization.
        val body = ("{\"type\":\"ingest\",\"owner_id\":\"${lease.ownerId}\"," +
            "\"credential\":\"${lease.credential}\",\"envelope\":{" +
            "\"schema_version\":1,\"event_id\":\"${alert.eventId}\",\"kind\":\"${alert.kind.wireName}\"," +
            "\"rule_version\":${alert.ruleVersion},\"occurred_at_epoch_ms\":${alert.occurredAtEpochMillis}," +
            "\"uncertainty\":\"experimental_not_confirmed\"}}")
            .toByteArray(Charsets.UTF_8)
        val response = try {
            runCatching { transport.post(endpoint, body) }.getOrNull()
        } finally { body.fill(0) }
        return when {
            response == null -> GuardianIngestResult.UNCONFIRMED
            response.status in setOf(401, 403) -> GuardianIngestResult.AUTHORIZATION_DENIED
            response.status == 200 && accepted(response.body, alert.eventId) -> GuardianIngestResult.BACKEND_ACCEPTED
            else -> GuardianIngestResult.UNCONFIRMED
        }
    }

    private fun accepted(body: String, eventId: String): Boolean {
        // Deliberately parse only the fixed, unescaped response vocabulary. Reject
        // duplicate keys, trailing content and any fields outside the server contract.
        if (body.length !in 2..MAX_RESPONSE_BYTES || body.first() != '{' || body.last() != '}') return false
        val members = body.substring(1, body.lastIndex).split(',')
        if (members.size !in 3..4) return false
        val fields = mutableMapOf<String, String>()
        for (member in members) {
            val match = MEMBER.matchEntire(member) ?: return false
            if (fields.put(match.groupValues[1], match.groupValues[2]) != null) return false
        }
        if (fields["event_id"] != "\"$eventId\"" || fields["state"] != "\"backend_accepted\"") return false
        val duplicate = fields["duplicate"]
        if (duplicate != "true" && duplicate != "false") return false
        val keys = setOf("event_id", "state", "duplicate")
        if (fields.keys == keys) return duplicate == "true"
        if (fields.keys != keys + "recipient_devices") return false
        val devices = fields.getValue("recipient_devices")
        return INTEGER.matches(devices) && devices.toIntOrNull() in 0..30
    }

    internal companion object {
        const val MAX_RESPONSE_BYTES = 128
        private val ENDPOINT = Regex("^https://[a-z0-9]{20}\\.supabase\\.co/functions/v1/guardian-capability$")
        private val INTEGER = Regex("(?:0|[1-9][0-9]?)")
        private val MEMBER = Regex("[ \\t\\r\\n]*\"([a-z_]+)\"[ \\t\\r\\n]*:[ \\t\\r\\n]*(\"[a-z0-9_-]+\"|true|false|[0-9]+)[ \\t\\r\\n]*")
    }
}
