package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ImuHealthTrackerTest {
    @Test
    fun `tracks both sensors and quality without retaining vectors`() {
        val published = mutableListOf<ImuHealthSnapshot>()
        val tracker = ImuHealthTracker(published::add)
        val accelerometerConfig = configuration(ImuSensorType.ACCELEROMETER, fifoCount = 100)
        val gyroscopeConfig = configuration(ImuSensorType.GYROSCOPE, fifoCount = 0)
        tracker.beginRegistration(accelerometerConfig, gyroscopeConfig)
        tracker.registered()
        tracker.accepted(sample(ImuSensorType.ACCELEROMETER, 2_000L))
        tracker.accepted(sample(ImuSensorType.GYROSCOPE, 3_000L))
        tracker.rejected()
        tracker.accuracyChanged(ImuSensorType.GYROSCOPE, 2)

        val snapshot = tracker.current()
        assertEquals(ImuAcquisitionState.ACTIVE, snapshot.state)
        assertEquals(1L, snapshot.accelerometerAcceptedSampleCount)
        assertEquals(1L, snapshot.gyroscopeAcceptedSampleCount)
        assertEquals(1L, snapshot.rejectedSampleCount)
        assertEquals(2L, snapshot.unreliableAccuracySampleCount)
        assertEquals(2L, snapshot.clockDiscontinuityCount)
        assertEquals(2L, snapshot.dropoutCount)
        assertEquals(1L, snapshot.accuracyChangeCount)
        assertEquals(2_000L, snapshot.accelerometerFirstSourceTimestampNanos)
        assertEquals(3_000L, snapshot.gyroscopeLastSourceTimestampNanos)
        assertNull(snapshot.accelerometerLastTripElapsedNanos)
        assertEquals(2, snapshot.gyroscopeLastAccuracyStatus)
        assertTrue(snapshot.accelerometerConfiguration!!.batchingAvailable)
        assertFalse(snapshot.gyroscopeConfiguration!!.batchingAvailable)
        assertTrue(published.isNotEmpty())
    }

    @Test
    fun `registration failure and stop are explicit`() {
        val tracker = ImuHealthTracker()
        tracker.beginRegistration(
            accelerometerConfiguration = configuration(ImuSensorType.ACCELEROMETER),
            gyroscopeConfiguration = null,
        )
        tracker.registrationFailed("imu_gyroscope_unavailable")

        val failed = tracker.current()
        assertEquals(ImuAcquisitionState.ERROR, failed.state)
        assertEquals(1L, failed.registrationFailureCount)
        assertEquals("imu_gyroscope_unavailable", failed.errorCode)

        tracker.stopped()
        assertEquals(ImuAcquisitionState.STOPPED, tracker.current().state)
    }

    private fun configuration(
        sensorType: ImuSensorType,
        fifoCount: Int = 100,
    ): ImuSensorConfiguration =
        ImuSensorConfiguration(
            sensorType = sensorType,
            effectiveSamplingPeriodMicros = 10_000,
            effectiveMaxReportLatencyMicros = if (fifoCount > 0) 1_000_000 else 0,
            fifoMaxEventCount = fifoCount,
        )

    private fun sample(
        sensorType: ImuSensorType,
        timestamp: Long,
    ): RawImuSample =
        RawImuSample(
            sensorType = sensorType,
            tripElapsedNanos = null,
            sourceTimestampNanos = timestamp,
            x = 1.0f,
            y = 2.0f,
            z = 3.0f,
            accuracyStatus = 0,
            qualityFlags =
                setOf(
                    ImuQualityFlag.CLOCK_DISCONTINUITY,
                    ImuQualityFlag.IMU_DROPOUT,
                    ImuQualityFlag.SENSOR_UNRELIABLE,
                ),
        )
}
