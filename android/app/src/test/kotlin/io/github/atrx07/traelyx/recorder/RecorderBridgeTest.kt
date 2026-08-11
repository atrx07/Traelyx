package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecorderBridgeTest {
    @Test
    fun capabilitiesRemainVersionedAndConservativelyUnavailable() {
        val map = RecorderBridgeCapabilities().toMap()

        assertEquals(1, map["bridgeVersion"])
        assertEquals(1, map["statusContractVersion"])
        assertEquals("bridge_ready", map["implementationState"])
        assertEquals(false, map["recordingAvailable"])
        assertEquals(true, map["commandsAvailable"])
        assertEquals(true, map["healthAvailable"])
        assertEquals(false, map["permissionOnboardingAvailable"])
    }

    @Test
    fun statusMapExposesOnlyAllowlistedAggregateEvidence() {
        val status = sampleStatus().toMap()
        val lifecycle = status.mapValue("lifecycle")
        val gnss = status.mapValue("gnss")
        val imu = status.mapValue("imu")
        val buffer = status.mapValue("buffer")

        assertEquals(TRIP_ID, lifecycle["tripId"])
        assertFalse(lifecycle.containsKey("startedAtUtcEpochMillis"))
        assertFalse(lifecycle.containsKey("startedAtElapsedRealtimeNanos"))
        assertEquals(7L, gnss["acceptedSampleCount"])
        assertFalse(gnss.containsKey("lastSourceTimestampNanos"))
        assertFalse(gnss.containsKey("lastHorizontalAccuracyMetres"))
        assertFalse(gnss.containsKey("lastFixWallTimeUtcEpochMillis"))
        assertEquals(12L, imu["accelerometerAcceptedSampleCount"])
        assertFalse(imu.keys.any { it.contains("Timestamp") || it.contains("AccuracyStatus") })
        assertEquals(1L, buffer["completedChunkCount"])
        assertFalse(buffer.keys.any { it.contains("path", ignoreCase = true) })
        assertFalse(status.keys.any { it.contains("device", ignoreCase = true) })
    }

    @Test
    fun dispatcherRoutesEveryCommandAndLeavesUnknownMethodsUnimplemented() {
        val gateway = FakeGateway(sampleStatus().toMap())
        val dispatcher = RecorderBridgeDispatcher(gateway)

        assertTrue(dispatcher.dispatch(RecorderContract.GET_CAPABILITIES) is RecorderBridgeDispatchResult.Handled)
        assertTrue(dispatcher.dispatch(RecorderContract.GET_STATE) is RecorderBridgeDispatchResult.Handled)
        assertTrue(dispatcher.dispatch(RecorderContract.GET_STATUS) is RecorderBridgeDispatchResult.Handled)
        assertTrue(dispatcher.dispatch(RecorderContract.START_TRIP) is RecorderBridgeDispatchResult.Handled)
        assertTrue(dispatcher.dispatch(RecorderContract.STOP_TRIP) is RecorderBridgeDispatchResult.Handled)
        assertTrue(dispatcher.dispatch(RecorderContract.RECOVER_TRIP) is RecorderBridgeDispatchResult.Handled)
        assertEquals(RecorderBridgeDispatchResult.NotImplemented, dispatcher.dispatch("unknown"))
        assertEquals(2, gateway.statusCount)
        assertEquals(1, gateway.startCount)
        assertEquals(1, gateway.stopCount)
        assertEquals(1, gateway.recoverCount)
    }

    private fun sampleStatus(): RecorderStatusSnapshot =
        RecorderStatusSnapshot(
            lifecycle =
                RecorderStateSnapshot(
                    lifecycleState = RecorderLifecycleState.RECORDING,
                    tripId = TRIP_ID,
                    startedAtUtcEpochMillis = 1_786_200_000_000L,
                    startedAtElapsedRealtimeNanos = 987_654_321L,
                    recoveryCount = 1,
                ),
            gnss =
                GnssHealthSnapshot(
                    state = GnssAcquisitionState.ACTIVE,
                    acceptedSampleCount = 7,
                    firstSourceTimestampNanos = 100,
                    lastSourceTimestampNanos = 200,
                    lastTripElapsedNanos = 50,
                    lastHorizontalAccuracyMetres = 3.5f,
                    lastFixWallTimeUtcEpochMillis = 1_786_200_000_500L,
                ),
            imu =
                ImuHealthSnapshot(
                    state = ImuAcquisitionState.ACTIVE,
                    accelerometerConfiguration = sampleConfiguration(ImuSensorType.ACCELEROMETER),
                    gyroscopeConfiguration = sampleConfiguration(ImuSensorType.GYROSCOPE),
                    accelerometerAcceptedSampleCount = 12,
                    gyroscopeAcceptedSampleCount = 11,
                    accelerometerFirstSourceTimestampNanos = 100,
                    gyroscopeFirstSourceTimestampNanos = 101,
                ),
            buffer =
                TelemetryBufferHealthSnapshot(
                    state = TelemetryBufferState.ACTIVE,
                    completedChunkCount = 1,
                    persistedGnssSampleCount = 7,
                    persistedAccelerometerSampleCount = 12,
                    persistedGyroscopeSampleCount = 11,
                    persistedByteCount = 4096,
                    lastCompletedSequence = 0,
                    hasCommittedElapsedBoundary = true,
                ),
        )

    private fun sampleConfiguration(sensorType: ImuSensorType): ImuSensorConfiguration =
        ImuSensorConfiguration(
            sensorType = sensorType,
            effectiveSamplingPeriodMicros = IMU_REQUESTED_SAMPLING_PERIOD_MICROS,
            effectiveMaxReportLatencyMicros = IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS,
            fifoMaxEventCount = 100,
        )

    @Suppress("UNCHECKED_CAST")
    private fun Map<String, Any>.mapValue(key: String): Map<String, Any?> =
        getValue(key) as Map<String, Any?>

    private class FakeGateway(private val status: Map<String, Any>) : RecorderBridgeGateway {
        var statusCount = 0
        var startCount = 0
        var stopCount = 0
        var recoverCount = 0

        override fun capabilities(): Map<String, Any> = RecorderBridgeCapabilities().toMap()

        override fun status(): Map<String, Any> {
            statusCount += 1
            return status
        }

        override fun startTrip(): Map<String, Any> {
            startCount += 1
            return status
        }

        override fun stopTrip(): Map<String, Any> {
            stopCount += 1
            return status
        }

        override fun recoverTrip(): Map<String, Any> {
            recoverCount += 1
            return status
        }
    }

    companion object {
        private const val TRIP_ID = "d181f268-f3ef-4a43-a142-8bf0671dcd49"
    }
}
