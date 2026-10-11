package io.github.atrx07.traelyx.guardian

/** No identity, activation ID, event evidence or credential crosses this boundary. */
data class GuardianRecordingObservation(
    val recording: Boolean = false,
    val availability: GuardianEvaluationAvailability = GuardianEvaluationAvailability.DISABLED,
)

fun guardianDriverStatus(
    lease: GuardianDriverLease?,
    freshActivation: Boolean,
    observation: GuardianRecordingObservation,
): Map<String, Any?> {
    val state = when {
        observation.availability == GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE -> "evidence_unavailable"
        lease == null -> "disabled"
        !freshActivation -> "reactivation_required"
        !observation.recording -> "waiting_for_trip"
        observation.availability == GuardianEvaluationAvailability.CALIBRATING -> "calibrating"
        observation.availability == GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL -> "monitoring_experimental"
        else -> "evidence_unavailable" // Consent alone never implies evaluation.
    }
    return mapOf("state" to state, "expiresEpochMillis" to lease?.expiresEpochMillis)
}
