package io.github.atrx07.traelyx.guardian

/** Foreground-only bridge. Its proposal contains a credential: never log bridge arguments or results. */
class GuardianActivationBridge(private val coordinator: GuardianActivationCoordinator) {
    fun dispatch(method: String, rawArguments: Any?): Any? {
        val arguments = rawArguments as? Map<*, *> ?: throw IllegalArgumentException("Invalid Guardian request")
        fun exact(vararg names: String) { require(arguments.keys == names.toSet()) }
        fun owner(): String = requireNotNull(arguments["ownerId"] as? String)
        return when (method) {
            BIND_OWNER -> {
                exact("ownerId")
                require(arguments["ownerId"] == null || arguments["ownerId"] is String)
                coordinator.bindOwner(arguments["ownerId"] as String?)
                null
            }
            BEGIN -> {
                exact("ownerId", "forwardAxis", "rigidMountConfirmed")
                val axis = requireNotNull(arguments["forwardAxis"] as? String)
                val confirmed = requireNotNull(arguments["rigidMountConfirmed"] as? Boolean)
                val proposal = coordinator.begin(owner(), axis, confirmed)
                mapOf("ownerId" to proposal.ownerId, "activationId" to proposal.activationId,
                    "credential" to proposal.credential, "forwardAxis" to proposal.forwardAxis)
            }
            COMMIT -> {
                exact("ownerId", "activationId", "serverExpiresEpochMillis")
                val activation = requireNotNull(arguments["activationId"] as? String)
                val expiry = requireNotNull(arguments["serverExpiresEpochMillis"] as? Long)
                val lease = coordinator.commit(owner(), activation, expiry)
                mapOf("localLeasePresent" to true, "expiresEpochMillis" to lease.expiresEpochMillis)
            }
            ABORT -> {
                exact("ownerId", "activationId")
                coordinator.abort(owner(), requireNotNull(arguments["activationId"] as? String))
                null
            }
            DISABLE -> {
                exact("ownerId")
                coordinator.disable(owner())
                null
            }
            SNAPSHOT -> {
                exact("ownerId")
                val lease = coordinator.snapshot(owner()).lease
                mapOf("localLeasePresent" to (lease != null), "expiresEpochMillis" to lease?.expiresEpochMillis)
            }
            else -> throw IllegalArgumentException("Unknown Guardian request")
        }
    }

    companion object {
        const val CHANNEL = "io.github.atrx07.traelyx/guardian_activation"
        const val BIND_OWNER = "bindOwner"
        const val BEGIN = "begin"
        const val COMMIT = "commit"
        const val ABORT = "abort"
        const val DISABLE = "disable"
        const val SNAPSHOT = "snapshot"
        val METHODS = setOf(BIND_OWNER, BEGIN, COMMIT, ABORT, DISABLE, SNAPSHOT)
    }
}
