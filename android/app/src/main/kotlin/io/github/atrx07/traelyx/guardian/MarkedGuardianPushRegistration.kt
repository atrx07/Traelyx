package io.github.atrx07.traelyx.guardian

/** Crash-safe provider boundary. A durable marker precedes every opt-in token request. */
internal class MarkedGuardianPushRegistration(
    private val marker: GuardianProviderMarker,
    private val provider: GuardianPushRegistration,
) : GuardianPushRegistration {
    override val configured get() = provider.configured

    @Synchronized override fun register(consent: GuardianNotificationConsent, complete: (GuardianRegistrationResult) -> Unit) {
        if (!configured) {
            complete(GuardianRegistrationResult.Unavailable("provider_not_configured"))
            return
        }
        try {
            if (marker.present()) {
                complete(GuardianRegistrationResult.Unavailable("cleanup_required"))
                return
            }
            marker.mark()
        } catch (_: Exception) {
            complete(GuardianRegistrationResult.Unavailable("storage_unavailable"))
            return
        }
        provider.register(consent, complete)
    }

    @Synchronized override fun unregister(complete: (Boolean) -> Unit) {
        val present = runCatching { marker.present() }.getOrElse {
            complete(false)
            return
        }
        if (!present) {
            complete(true)
            return
        }
        provider.unregister { deleted ->
            val cleared = deleted && runCatching { marker.clear() }.isSuccess
            complete(cleared)
        }
    }
}
