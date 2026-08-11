package io.github.atrx07.traelyx.recorder

import android.content.Context

const val RECORDER_STATUS_CONTRACT_VERSION = 1

data class RecorderBridgeCapabilities(
    val bridgeVersion: Int = RecorderContract.BRIDGE_VERSION,
    val statusContractVersion: Int = RECORDER_STATUS_CONTRACT_VERSION,
    val implementationState: String = "bridge_ready",
    val recordingAvailable: Boolean = false,
    val serviceRegistered: Boolean = true,
    val commandsAvailable: Boolean = true,
    val healthAvailable: Boolean = true,
    val permissionOnboardingAvailable: Boolean = true,
) {
    fun toMap(): Map<String, Any> =
        linkedMapOf(
            "bridgeVersion" to bridgeVersion,
            "statusContractVersion" to statusContractVersion,
            "implementationState" to implementationState,
            "recordingAvailable" to recordingAvailable,
            "serviceRegistered" to serviceRegistered,
            "commandsAvailable" to commandsAvailable,
            "healthAvailable" to healthAvailable,
            "permissionOnboardingAvailable" to permissionOnboardingAvailable,
        )
}

data class RecorderStatusSnapshot(
    val contractVersion: Int = RECORDER_STATUS_CONTRACT_VERSION,
    val bridgeVersion: Int = RecorderContract.BRIDGE_VERSION,
    val lifecycle: RecorderStateSnapshot,
    val gnss: GnssHealthSnapshot,
    val imu: ImuHealthSnapshot,
    val buffer: TelemetryBufferHealthSnapshot,
) {
    fun toMap(): Map<String, Any> =
        linkedMapOf(
            "contractVersion" to contractVersion,
            "bridgeVersion" to bridgeVersion,
            "lifecycle" to lifecycle.toBridgeMap(),
            "gnss" to gnss.toBridgeMap(),
            "imu" to imu.toBridgeMap(),
            "buffer" to buffer.toBridgeMap(),
        )
}

internal fun RecorderStateSnapshot.toBridgeMap(): Map<String, Any?> =
    linkedMapOf(
        "contractVersion" to contractVersion,
        "state" to lifecycleState.wireName,
        "active" to isActive,
        "tripId" to tripId,
        "recoveryCount" to recoveryCount,
        "errorCode" to errorCode,
    )

internal fun GnssHealthSnapshot.toBridgeMap(): Map<String, Any?> =
    linkedMapOf(
        "contractVersion" to contractVersion,
        "state" to state.wireName,
        "provider" to provider,
        "requestedIntervalMillis" to requestedIntervalMillis,
        "acceptedSampleCount" to acceptedSampleCount,
        "rejectedSampleCount" to rejectedSampleCount,
        "lowAccuracySampleCount" to lowAccuracySampleCount,
        "clockDiscontinuityCount" to clockDiscontinuityCount,
        "mockSignalCount" to mockSignalCount,
        "providerDisabledCount" to providerDisabledCount,
        "registrationFailureCount" to registrationFailureCount,
        "lastFixHadSpeed" to lastFixHadSpeed,
        "lastFixHadBearing" to lastFixHadBearing,
        "errorCode" to errorCode,
    )

internal fun ImuHealthSnapshot.toBridgeMap(): Map<String, Any?> =
    linkedMapOf(
        "contractVersion" to contractVersion,
        "state" to state.wireName,
        "accelerometerAvailable" to (accelerometerConfiguration != null),
        "gyroscopeAvailable" to (gyroscopeConfiguration != null),
        "accelerometerBatchingAvailable" to
            (accelerometerConfiguration?.batchingAvailable ?: false),
        "gyroscopeBatchingAvailable" to (gyroscopeConfiguration?.batchingAvailable ?: false),
        "accelerometerAcceptedSampleCount" to accelerometerAcceptedSampleCount,
        "gyroscopeAcceptedSampleCount" to gyroscopeAcceptedSampleCount,
        "rejectedSampleCount" to rejectedSampleCount,
        "unreliableAccuracySampleCount" to unreliableAccuracySampleCount,
        "clockDiscontinuityCount" to clockDiscontinuityCount,
        "dropoutCount" to dropoutCount,
        "accuracyChangeCount" to accuracyChangeCount,
        "registrationFailureCount" to registrationFailureCount,
        "errorCode" to errorCode,
    )

internal fun TelemetryBufferHealthSnapshot.toBridgeMap(): Map<String, Any?> =
    linkedMapOf(
        "contractVersion" to contractVersion,
        "state" to state.wireName,
        "queueCapacity" to queueCapacity,
        "reorderBufferCapacity" to reorderBufferCapacity,
        "queueDepth" to queueDepth,
        "bufferedSampleCount" to bufferedSampleCount,
        "completedChunkCount" to completedChunkCount,
        "persistedGnssSampleCount" to persistedGnssSampleCount,
        "persistedAccelerometerSampleCount" to persistedAccelerometerSampleCount,
        "persistedGyroscopeSampleCount" to persistedGyroscopeSampleCount,
        "persistedByteCount" to persistedByteCount,
        "recoveredValidChunkCount" to recoveredValidChunkCount,
        "corruptChunkCount" to corruptChunkCount,
        "orphanedWriteCount" to orphanedWriteCount,
        "orderingViolationCount" to orderingViolationCount,
        "overflowCount" to overflowCount,
        "invalidTripTimeCount" to invalidTripTimeCount,
        "lateSampleCount" to lateSampleCount,
        "writeFailureCount" to writeFailureCount,
        "lastCompletedSequence" to lastCompletedSequence,
        "hasCommittedElapsedBoundary" to hasCommittedElapsedBoundary,
        "errorCode" to errorCode,
    )

interface RecorderBridgeGateway {
    fun capabilities(): Map<String, Any>

    fun status(): Map<String, Any>

    fun startTrip(): Map<String, Any>

    fun stopTrip(): Map<String, Any>

    fun recoverTrip(): Map<String, Any>
}

class AndroidRecorderBridgeGateway(
    context: Context,
    private val recordingReadiness: () -> Boolean = { isPlatformRecordingReady(context) },
) : RecorderBridgeGateway {
    private val applicationContext = context.applicationContext

    override fun capabilities(): Map<String, Any> =
        RecorderBridgeCapabilities(recordingAvailable = recordingReadiness()).toMap()

    override fun status(): Map<String, Any> = collectStatus().toMap()

    override fun startTrip(): Map<String, Any> {
        RecorderService.requestStart(applicationContext)
        return status()
    }

    override fun stopTrip(): Map<String, Any> {
        RecorderService.requestStop(applicationContext)
        return status()
    }

    override fun recoverTrip(): Map<String, Any> {
        RecorderService.requestRecovery(applicationContext)
        return status()
    }

    private fun collectStatus(): RecorderStatusSnapshot =
        RecorderStatusSnapshot(
            lifecycle = RecorderService.queryState(applicationContext),
            gnss = RecorderService.queryGnssHealth(),
            imu = RecorderService.queryImuHealth(),
            buffer = RecorderService.queryTelemetryHealth(),
        )
}

sealed interface RecorderBridgeDispatchResult {
    data class Handled(val payload: Map<String, Any?>) : RecorderBridgeDispatchResult

    data object NotImplemented : RecorderBridgeDispatchResult
}

class RecorderBridgeDispatcher(private val gateway: RecorderBridgeGateway) {
    fun dispatch(method: String): RecorderBridgeDispatchResult =
        when (method) {
            RecorderContract.GET_CAPABILITIES -> handled(gateway.capabilities())
            RecorderContract.GET_STATE -> {
                val lifecycle = gateway.status()["lifecycle"]
                @Suppress("UNCHECKED_CAST")
                RecorderBridgeDispatchResult.Handled(lifecycle as Map<String, Any?>)
            }
            RecorderContract.GET_STATUS -> handled(gateway.status())
            RecorderContract.START_TRIP -> handled(gateway.startTrip())
            RecorderContract.STOP_TRIP -> handled(gateway.stopTrip())
            RecorderContract.RECOVER_TRIP -> handled(gateway.recoverTrip())
            else -> RecorderBridgeDispatchResult.NotImplemented
        }

    private fun handled(payload: Map<String, Any>): RecorderBridgeDispatchResult.Handled =
        RecorderBridgeDispatchResult.Handled(payload)
}
