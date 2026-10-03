package io.github.atrx07.traelyx.guardian

/** Foreground-only bridge; commit arguments contain a secret and must never be logged. */
class GuardianRecipientBridge(
    private val coordinator: GuardianRecipientCoordinator,
    private val bindOwner: (String?) -> Unit = coordinator::bindOwner,
) {
    fun dispatch(method: String, rawArguments: Any?): Any? {
        val arguments = rawArguments as? Map<*, *> ?: throw IllegalArgumentException("Invalid Guardian recipient request")
        fun exact(vararg names: String) { require(arguments.keys == names.toSet()) }
        fun owner(): String = requireNotNull(arguments["ownerId"] as? String)
        return when (method) {
            BIND_OWNER -> {
                exact("ownerId")
                require(arguments["ownerId"] == null || arguments["ownerId"] is String)
                bindOwner(arguments["ownerId"] as String?)
                null
            }
            COMMIT -> {
                exact("ownerId", "deviceId", "generation", "credential", "registeredAtEpochMillis", "expiresAtEpochMillis")
                val device = GuardianRecipientDevice(
                    owner(), requireNotNull(arguments["deviceId"] as? String),
                    requireNotNull(arguments["generation"] as? String),
                    requireNotNull(arguments["credential"] as? String),
                    requireNotNull(arguments["registeredAtEpochMillis"] as? Long),
                    requireNotNull(arguments["expiresAtEpochMillis"] as? Long),
                )
                coordinator.commit(device.ownerId, device).asMap()
            }
            SNAPSHOT -> {
                exact("ownerId")
                coordinator.snapshot(owner())?.asMap()
            }
            DISABLE -> {
                exact("ownerId")
                coordinator.disable(owner())
                null
            }
            else -> throw IllegalArgumentException("Unknown Guardian recipient request")
        }
    }

    private fun GuardianRecipientStatus.asMap(): Map<String, Any> = mapOf(
        "deviceId" to deviceId,
        "generation" to generation,
        "expiresAtEpochMillis" to expiresAtEpochMillis,
    )

    companion object {
        const val CHANNEL = "io.github.atrx07.traelyx/guardian_recipient"
        const val BIND_OWNER = "bindOwner"
        const val COMMIT = "commit"
        const val SNAPSHOT = "snapshot"
        const val DISABLE = "disable"
        val METHODS = setOf(BIND_OWNER, COMMIT, SNAPSHOT, DISABLE)
    }
}
