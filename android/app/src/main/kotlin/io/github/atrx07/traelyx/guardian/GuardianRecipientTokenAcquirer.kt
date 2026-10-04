package io.github.atrx07.traelyx.guardian

import java.util.concurrent.atomic.AtomicBoolean

/** Keeps provider token acquisition behind an exact pending cleanup ticket. */
class GuardianRecipientTokenAcquirer(
    private val bridge: GuardianRecipientBridge,
    private val push: GuardianPushRegistration,
) {
    fun acquire(rawArguments: Any?, complete: (Result<String>) -> Unit) {
        val completed = AtomicBoolean(false)
        fun finish(outcome: Result<String>) {
            if (completed.compareAndSet(false, true)) complete(outcome)
        }
        val request = runCatching {
            bridge.dispatch(GuardianRecipientBridge.AUTHORIZE_TOKEN, rawArguments)
            val args = rawArguments as Map<*, *>
            val owner = args["ownerId"] as String
            val generation = args["generation"] as String
            GuardianNotificationConsent(owner, generation)
        }
        val consent = request.getOrElse { finish(Result.failure(it)); return }
        try {
            push.register(consent) { outcome ->
                finish(runCatching {
                    bridge.dispatch(GuardianRecipientBridge.AUTHORIZE_TOKEN, rawArguments)
                    val registered = outcome as? GuardianRegistrationResult.Registered
                        ?: error("Guardian provider unavailable")
                    check(registered.consent == consent)
                    val token = registered.token
                    require(token.length in 16..4096 && token.isNotBlank() &&
                        token.trim() == token && token.all { it.code in 0x21..0x7e })
                    token
                })
            }
        } catch (error: Exception) {
            finish(Result.failure(error))
        }
    }
}
