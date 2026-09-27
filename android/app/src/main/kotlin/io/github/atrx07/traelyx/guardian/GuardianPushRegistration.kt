package io.github.atrx07.traelyx.guardian

/** Only the consent/account coordinator may request registration; app startup must not. */
interface GuardianPushRegistration {
    val configured: Boolean
    fun register(consent: GuardianNotificationConsent, complete: (GuardianRegistrationResult) -> Unit)
    fun unregister(complete: (Boolean) -> Unit)
}

data class GuardianNotificationConsent(val ownerId: String, val generation: String) {
    init {
        require(java.util.UUID.fromString(ownerId).toString() == ownerId)
        require(java.util.UUID.fromString(generation).toString() == generation)
    }
}

sealed interface GuardianRegistrationResult {
    /** Never log the token or use it as authorization for reading an alert. */
    class Registered(val token: String, val consent: GuardianNotificationConsent) : GuardianRegistrationResult {
        override fun toString() = "GuardianRegistrationResult.Registered(redacted)"
    }
    data class Unavailable(val code: String) : GuardianRegistrationResult
}
