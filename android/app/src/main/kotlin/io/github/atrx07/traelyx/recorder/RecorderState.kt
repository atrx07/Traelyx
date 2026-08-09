package io.github.atrx07.traelyx.recorder

import java.util.UUID

const val RECORDER_STATE_CONTRACT_VERSION = 1
const val RECORDER_RECOVERY_METADATA_VERSION = 1

enum class RecorderLifecycleState(val wireName: String) {
    IDLE("idle"),
    STARTING("starting"),
    RECORDING("recording"),
    STOPPING("stopping"),
    RECOVERED("recovered"),
    ERROR("error"),
    ;

    val isActive: Boolean
        get() = this == STARTING || this == RECORDING || this == STOPPING || this == RECOVERED

    companion object {
        fun fromWireName(value: String): RecorderLifecycleState? =
            entries.firstOrNull { it.wireName == value }
    }
}

data class ActiveTripRecoveryRecord(
    val metadataVersion: Int = RECORDER_RECOVERY_METADATA_VERSION,
    val tripId: String,
    val startedAtUtcEpochMillis: Long,
    val startedAtElapsedRealtimeNanos: Long,
    val lifecycleState: RecorderLifecycleState,
    val recoveryCount: Int = 0,
    val errorCode: String? = null,
) {
    init {
        require(metadataVersion == RECORDER_RECOVERY_METADATA_VERSION)
        require(runCatching { UUID.fromString(tripId) }.isSuccess)
        require(startedAtUtcEpochMillis > 0)
        require(startedAtElapsedRealtimeNanos >= 0)
        require(lifecycleState != RecorderLifecycleState.IDLE)
        require(recoveryCount >= 0)
        require(errorCode == null || ERROR_CODE_PATTERN.matches(errorCode))
        require(lifecycleState == RecorderLifecycleState.ERROR || errorCode == null)
    }

    fun toSnapshot(): RecorderStateSnapshot =
        RecorderStateSnapshot(
            lifecycleState = lifecycleState,
            tripId = tripId,
            startedAtUtcEpochMillis = startedAtUtcEpochMillis,
            startedAtElapsedRealtimeNanos = startedAtElapsedRealtimeNanos,
            recoveryCount = recoveryCount,
            errorCode = errorCode,
        )

    companion object {
        private val ERROR_CODE_PATTERN = Regex("[a-z0-9_]{1,64}")
    }
}

data class RecorderStateSnapshot(
    val contractVersion: Int = RECORDER_STATE_CONTRACT_VERSION,
    val lifecycleState: RecorderLifecycleState,
    val tripId: String? = null,
    val startedAtUtcEpochMillis: Long? = null,
    val startedAtElapsedRealtimeNanos: Long? = null,
    val recoveryCount: Int = 0,
    val errorCode: String? = null,
) {
    val isActive: Boolean
        get() = lifecycleState.isActive

    fun toMap(): Map<String, Any?> =
        mapOf(
            "contractVersion" to contractVersion,
            "state" to lifecycleState.wireName,
            "active" to isActive,
            "tripId" to tripId,
            "startedAtUtcEpochMillis" to startedAtUtcEpochMillis,
            "startedAtElapsedRealtimeNanos" to startedAtElapsedRealtimeNanos,
            "recoveryCount" to recoveryCount,
            "errorCode" to errorCode,
        )

    companion object {
        fun idle(): RecorderStateSnapshot =
            RecorderStateSnapshot(lifecycleState = RecorderLifecycleState.IDLE)

        fun error(errorCode: String): RecorderStateSnapshot =
            RecorderStateSnapshot(
                lifecycleState = RecorderLifecycleState.ERROR,
                errorCode = errorCode,
            )
    }
}

sealed interface RecorderRecoveryRead {
    data object Empty : RecorderRecoveryRead

    data class Available(val record: ActiveTripRecoveryRecord) : RecorderRecoveryRead

    data class Invalid(val errorCode: String = "invalid_recovery_metadata") : RecorderRecoveryRead
}

enum class RecorderLifecycleOutcomeKind {
    APPLIED,
    NO_OP,
    REJECTED,
}

data class RecorderLifecycleOutcome(
    val kind: RecorderLifecycleOutcomeKind,
    val snapshot: RecorderStateSnapshot,
)
