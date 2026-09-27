package io.github.atrx07.traelyx.guardian

internal interface GuardianRegistrationBackend {
    val configured: Boolean
    fun unavailableReason(): String?
    fun acquire(complete: (String?) -> Unit)
    fun delete(complete: (Boolean) -> Unit)
}

/** Serializes SDK operations so late registration cannot recreate a token after sign-out cleanup. */
internal class ConsentBoundGuardianRegistration(
    private val backend: GuardianRegistrationBackend,
) : GuardianPushRegistration {
    override val configured get() = backend.configured
    private var phase = Phase.IDLE
    private var operation = 0L
    private var needsDeletion = false
    private var inFlightConsent: GuardianNotificationConsent? = null
    private val deletionCallbacks = mutableListOf<(Boolean) -> Unit>()

    @Synchronized
    override fun register(consent: GuardianNotificationConsent, complete: (GuardianRegistrationResult) -> Unit) {
        if (phase == Phase.REGISTERING && inFlightConsent != consent) needsDeletion = true
        val unavailable = when {
            needsDeletion -> "cleanup_required"
            phase != Phase.IDLE -> "registration_busy"
            !configured -> "provider_not_configured"
            else -> backend.unavailableReason()
        }
        if (unavailable != null) {
            complete(GuardianRegistrationResult.Unavailable(unavailable))
            return
        }
        phase = Phase.REGISTERING
        inFlightConsent = consent
        val current = ++operation
        fun finish(token: String?) = synchronized(this) {
            if (current != operation || phase != Phase.REGISTERING) return@synchronized
            phase = Phase.IDLE
            inFlightConsent = null
            if (needsDeletion) {
                try { complete(GuardianRegistrationResult.Unavailable("consent_changed")) }
                finally { startDeletion() }
            } else {
                complete(if (token.isNullOrBlank()) GuardianRegistrationResult.Unavailable("registration_failed")
                else GuardianRegistrationResult.Registered(token, consent))
            }
        }
        try { backend.acquire(::finish) } catch (_: Exception) { finish(null) }
    }

    @Synchronized
    override fun unregister(complete: (Boolean) -> Unit) {
        needsDeletion = true
        deletionCallbacks += complete
        if (phase == Phase.IDLE) startDeletion()
    }

    private fun startDeletion() {
        if (phase != Phase.IDLE) return
        phase = Phase.DELETING
        val current = ++operation
        fun finish(success: Boolean) = synchronized(this) {
            if (current != operation || phase != Phase.DELETING) return@synchronized
            phase = Phase.IDLE
            needsDeletion = !success
            val callbacks = deletionCallbacks.toList()
            deletionCallbacks.clear()
            callbacks.forEach { it(success) }
        }
        try { backend.delete(::finish) } catch (_: Exception) { finish(false) }
    }

    private enum class Phase { IDLE, REGISTERING, DELETING }
}
