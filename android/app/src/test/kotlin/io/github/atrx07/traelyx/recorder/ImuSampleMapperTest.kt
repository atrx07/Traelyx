package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ImuSampleMapperTest {
    @Test
    fun `preserves accelerometer device axes units accuracy and source clock`() {
        val result =
            ImuSampleMapper.map(
                reading =
                    PlatformImuReading(
                        sensorType = ImuSensorType.ACCELEROMETER,
                        sourceTimestampNanos = 8_500_000_000L,
                        x = 1.25f,
                        y = -2.5f,
                        z = 9.75f,
                        accuracyStatus = 3,
                    ),
                tripStartedAtElapsedRealtimeNanos = 8_000_000_000L,
                previousSourceTimestampNanos = 8_490_000_000L,
                effectiveSamplingPeriodMicros = 10_000,
            )

        val sample = (result as ImuSampleMappingResult.Accepted).sample
        assertEquals(ImuSensorType.ACCELEROMETER, sample.sensorType)
        assertEquals(500_000_000L, sample.tripElapsedNanos)
        assertEquals(8_500_000_000L, sample.sourceTimestampNanos)
        assertEquals(1.25f, sample.x)
        assertEquals(-2.5f, sample.y)
        assertEquals(9.75f, sample.z)
        assertEquals(3, sample.accuracyStatus)
        assertTrue(sample.qualityFlags.isEmpty())
    }

    @Test
    fun `preserves gyroscope radians per second without frame conversion`() {
        val result =
            ImuSampleMapper.map(
                reading = validReading(ImuSensorType.GYROSCOPE).copy(x = -0.2f, y = 0.1f, z = 0.4f),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
                effectiveSamplingPeriodMicros = 10_000,
            )

        val sample = (result as ImuSampleMappingResult.Accepted).sample
        assertEquals(ImuSensorType.GYROSCOPE, sample.sensorType)
        assertEquals(-0.2f, sample.x)
        assertEquals(0.1f, sample.y)
        assertEquals(0.4f, sample.z)
    }

    @Test
    fun `marks source ordering and unreliable accuracy without fabricating trip time`() {
        val result =
            ImuSampleMapper.map(
                reading = validReading().copy(sourceTimestampNanos = 5_000L, accuracyStatus = 0),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = 6_000L,
                effectiveSamplingPeriodMicros = 10_000,
            )

        val sample = (result as ImuSampleMappingResult.Accepted).sample
        assertNull(sample.tripElapsedNanos)
        assertTrue(ImuQualityFlag.CLOCK_DISCONTINUITY in sample.qualityFlags)
        assertTrue(ImuQualityFlag.SENSOR_UNRELIABLE in sample.qualityFlags)
    }

    @Test
    fun `marks a gap larger than five effective sampling periods`() {
        val result =
            ImuSampleMapper.map(
                reading = validReading().copy(sourceTimestampNanos = 61_000_001L),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = 1_000_000L,
                effectiveSamplingPeriodMicros = 10_000,
            )

        val sample = (result as ImuSampleMappingResult.Accepted).sample
        assertTrue(ImuQualityFlag.IMU_DROPOUT in sample.qualityFlags)
    }

    @Test
    fun `does not mark exactly five periods as a dropout`() {
        val result =
            ImuSampleMapper.map(
                reading = validReading().copy(sourceTimestampNanos = 51_000_000L),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = 1_000_000L,
                effectiveSamplingPeriodMicros = 10_000,
            )

        val sample = (result as ImuSampleMappingResult.Accepted).sample
        assertTrue(ImuQualityFlag.IMU_DROPOUT !in sample.qualityFlags)
    }

    @Test
    fun `rejects malformed source evidence`() {
        assertRejected(
            validReading().copy(sourceTimestampNanos = -1L),
            ImuSampleRejectionReason.INVALID_SOURCE_TIMESTAMP,
        )
        assertRejected(
            validReading().copy(x = Float.NaN),
            ImuSampleRejectionReason.INVALID_VECTOR,
        )
        assertRejected(
            validReading().copy(accuracyStatus = 4),
            ImuSampleRejectionReason.INVALID_ACCURACY_STATUS,
        )

        val invalidPeriod =
            ImuSampleMapper.map(
                reading = validReading(),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
                effectiveSamplingPeriodMicros = 0,
            )
        assertEquals(
            ImuSampleRejectionReason.INVALID_SAMPLING_PERIOD,
            (invalidPeriod as ImuSampleMappingResult.Rejected).reason,
        )
    }

    private fun assertRejected(
        reading: PlatformImuReading,
        expected: ImuSampleRejectionReason,
    ) {
        val result =
            ImuSampleMapper.map(
                reading = reading,
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
                effectiveSamplingPeriodMicros = 10_000,
            )
        assertEquals(expected, (result as ImuSampleMappingResult.Rejected).reason)
    }

    private fun validReading(
        sensorType: ImuSensorType = ImuSensorType.ACCELEROMETER,
    ): PlatformImuReading =
        PlatformImuReading(
            sensorType = sensorType,
            sourceTimestampNanos = 2_000_000L,
            x = 0.1f,
            y = 0.2f,
            z = 9.8f,
            accuracyStatus = 3,
        )
}
