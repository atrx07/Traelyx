package io.github.atrx07.traelyx.guardian

import java.util.UUID

enum class GuardianSendState {
    CANCELLABLE,
    QUEUED,
    BACKEND_ACCEPTED,
    CANCELLED,
    EXPIRED,
    CONSENT_REVOKED,
    RETRIES_EXHAUSTED,
}

/** Persist atomically before dispatch; one event ID is retained across every retry. */
data class GuardianPendingAlert(
    val eventId: String,
    val ownerId: String,
    val consentGeneration: String,
    val kind: GuardianAlertKind,
    val occurredAtEpochMillis: Long,
    val createdAtElapsedMillis: Long,
    val bootId: String,
    val ruleVersion: Int = GuardianSafetyRulesV1.VERSION,
    val state: GuardianSendState = GuardianSendState.CANCELLABLE,
    val attempts: Int = 0,
    val nextAttemptAtElapsedMillis: Long = createdAtElapsedMillis + CANCEL_WINDOW_MILLIS,
) {
    init {
        require(UUID.fromString(eventId).toString() == eventId)
        require(UUID.fromString(ownerId).toString() == ownerId)
        require(UUID.fromString(consentGeneration).toString() == consentGeneration)
        require(bootId.isNotBlank() && bootId.length <= 128)
        require(occurredAtEpochMillis > 0 && createdAtElapsedMillis >= 0)
        require(createdAtElapsedMillis <= Long.MAX_VALUE - TTL_MILLIS)
        require(nextAttemptAtElapsedMillis >= createdAtElapsedMillis)
        require(ruleVersion == GuardianSafetyRulesV1.VERSION)
        require(attempts in 0..MAX_ATTEMPTS)
    }

    /** Only this allowlist crosses the network; owner/generation are authorization arguments. */
    fun envelope(): Map<String, Any> = mapOf(
        "schema_version" to 1,
        "event_id" to eventId,
        "kind" to kind.wireName,
        "rule_version" to ruleVersion,
        "occurred_at_epoch_ms" to occurredAtEpochMillis,
        "uncertainty" to "experimental_not_confirmed",
    )

    // Once an attempt is reserved, a request may already have reached the backend.
    // Do not claim that cancelling a local callback retracts that network request.
    fun cancel(): GuardianPendingAlert = if (state == GuardianSendState.CANCELLABLE ||
        (state == GuardianSendState.QUEUED && attempts == 0)) {
        copy(state = GuardianSendState.CANCELLED)
    } else this

    /** No reboot replay or clock-jump bypass of cancellation/expiry. Missing consent fails closed. */
    fun advance(
        elapsedMillis: Long,
        epochMillis: Long,
        currentBootId: String,
        currentOwnerId: String?,
        currentConsentGeneration: String?,
    ): GuardianPendingAlert {
        if (state !in ACTIVE_STATES) return this
        if (ownerId != currentOwnerId || consentGeneration != currentConsentGeneration) {
            return copy(state = GuardianSendState.CONSENT_REVOKED)
        }
        if (bootId != currentBootId || elapsedMillis < createdAtElapsedMillis || epochMillis < occurredAtEpochMillis ||
            elapsedMillis - createdAtElapsedMillis >= TTL_MILLIS || epochMillis - occurredAtEpochMillis >= TTL_MILLIS) {
            return copy(state = GuardianSendState.EXPIRED)
        }
        if (state == GuardianSendState.QUEUED && attempts >= MAX_ATTEMPTS && elapsedMillis >= nextAttemptAtElapsedMillis) {
            return copy(state = GuardianSendState.RETRIES_EXHAUSTED)
        }
        return if (state == GuardianSendState.CANCELLABLE && elapsedMillis - createdAtElapsedMillis >= CANCEL_WINDOW_MILLIS) {
            copy(state = GuardianSendState.QUEUED)
        } else this
    }

    fun readyToAttempt(elapsedMillis: Long): Boolean = state == GuardianSendState.QUEUED &&
        attempts < MAX_ATTEMPTS && elapsedMillis >= nextAttemptAtElapsedMillis &&
        elapsedMillis - createdAtElapsedMillis in CANCEL_WINDOW_MILLIS until TTL_MILLIS

    /** Persist the attempt reservation before IO, so process death also consumes a retry. */
    fun reserveAttempt(elapsedMillis: Long): GuardianPendingAlert {
        require(readyToAttempt(elapsedMillis))
        val backoffMillis = minOf(120_000L, 5_000L shl attempts)
        return copy(attempts = attempts + 1, nextAttemptAtElapsedMillis = elapsedMillis + backoffMillis)
    }

    fun result(backendAccepted: Boolean, authorizationDenied: Boolean = false): GuardianPendingAlert {
        if (state != GuardianSendState.QUEUED) return this
        require(attempts > 0)
        return when {
            authorizationDenied -> copy(state = GuardianSendState.CONSENT_REVOKED)
            backendAccepted -> copy(state = GuardianSendState.BACKEND_ACCEPTED)
            attempts >= MAX_ATTEMPTS -> copy(state = GuardianSendState.RETRIES_EXHAUSTED)
            else -> this
        }
    }

    companion object {
        const val CANCEL_WINDOW_MILLIS = 30_000L
        const val TTL_MILLIS = 600_000L
        const val MAX_ATTEMPTS = 6
        private val ACTIVE_STATES = setOf(GuardianSendState.CANCELLABLE, GuardianSendState.QUEUED)
    }
}
