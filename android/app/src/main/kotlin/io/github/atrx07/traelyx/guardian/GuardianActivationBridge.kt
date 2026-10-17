package io.github.atrx07.traelyx.guardian

/** Foreground-only bridge. Its proposal contains a credential: never log bridge arguments or results. */
class GuardianActivationBridge(
    private val coordinator: GuardianActivationCoordinator,
    private val recordingObservation: () -> GuardianRecordingObservation = { GuardianRecordingObservation() },
    private val pendingAlerts: (String) -> List<Map<String, Any?>> = { emptyList() },
    private val cancelAlert: (GuardianEventReference) -> Boolean = { false },
) {
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
            STOP -> {
                exact("ownerId")
                mapOf("activationId" to coordinator.stop(owner()))
            }
            PENDING_REVOKES -> {
                exact("ownerId")
                coordinator.pendingRevokes(owner()).map { mapOf("activationId" to it.activationId) }
            }
            CONFIRM_REVOKE -> {
                exact("ownerId", "activationId")
                coordinator.confirmRevoke(owner(), requireNotNull(arguments["activationId"] as? String))
                null
            }
            SNAPSHOT -> {
                exact("ownerId")
                val lease = coordinator.snapshot(owner()).lease
                mapOf("localLeasePresent" to (lease != null), "expiresEpochMillis" to lease?.expiresEpochMillis)
            }
            DRIVER_STATUS -> {
                exact("ownerId")
                // Validate the bound owner before observing a live recording handle.
                val lease = coordinator.snapshot(owner()).lease
                val fresh = coordinator.recordingSnapshot()?.lease != null
                guardianDriverStatus(lease, fresh, recordingObservation())
            }
            PENDING_ALERTS -> {
                exact("ownerId")
                coordinator.snapshot(owner()) // Reject an unbound/other owner before reading controls.
                pendingAlerts(owner())
            }
            CANCEL_ALERT -> {
                exact("ownerId", "activationId", "eventId")
                val ref = GuardianEventReference(owner(), requireNotNull(arguments["activationId"] as? String),
                    requireNotNull(arguments["eventId"] as? String))
                coordinator.snapshot(owner())
                cancelAlert(ref)
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
        const val STOP = "stop"
        const val PENDING_REVOKES = "pendingRevokes"
        const val CONFIRM_REVOKE = "confirmRevoke"
        const val SNAPSHOT = "snapshot"
        const val DRIVER_STATUS = "driverStatus"
        const val PENDING_ALERTS = "pendingAlerts"
        const val CANCEL_ALERT = "cancelAlert"
        val METHODS = setOf(BIND_OWNER, BEGIN, COMMIT, ABORT, DISABLE, STOP, PENDING_REVOKES,
            CONFIRM_REVOKE, SNAPSHOT, DRIVER_STATUS, PENDING_ALERTS, CANCEL_ALERT)
    }
}
