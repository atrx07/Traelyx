package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GnssSampleMapperTest {
    @Test
    fun `maps complete source evidence without changing units or clocks`() {
        val result =
            GnssSampleMapper.map(
                reading =
                    validReading().copy(
                        sourceTimestampNanos = 8_500_000_000L,
                        sourceWallTimeUtcEpochMillis = 1_800_000_000_000L,
                        altitudeMetres = 224.25,
                        verticalAccuracyMetres = 3.5f,
                        speedMetresPerSecond = 12.25f,
                        speedAccuracyMetresPerSecond = 0.8f,
                        bearingDegrees = 271.5f,
                        bearingAccuracyDegrees = 4.0f,
                    ),
                tripStartedAtElapsedRealtimeNanos = 8_000_000_000L,
                previousSourceTimestampNanos = 8_250_000_000L,
            )

        val sample = (result as GnssSampleMappingResult.Accepted).sample
        assertEquals(500_000_000L, sample.tripElapsedNanos)
        assertEquals(8_500_000_000L, sample.sourceTimestampNanos)
        assertEquals(1_800_000_000_000L, sample.sourceWallTimeUtcEpochMillis)
        assertEquals(12.25f, sample.speedMetresPerSecond)
        assertEquals(271.5f, sample.bearingDegrees)
        assertEquals("gps", sample.provider)
        assertTrue(sample.qualityFlags.isEmpty())
    }

    @Test
    fun `preserves optional missingness instead of fabricating zeros`() {
        val result =
            GnssSampleMapper.map(
                reading = validReading(),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
            )

        val sample = (result as GnssSampleMappingResult.Accepted).sample
        assertNull(sample.altitudeMetres)
        assertNull(sample.verticalAccuracyMetres)
        assertNull(sample.speedMetresPerSecond)
        assertNull(sample.speedAccuracyMetresPerSecond)
        assertNull(sample.bearingDegrees)
        assertNull(sample.bearingAccuracyDegrees)
    }

    @Test
    fun `retains low accuracy mock and clock problems as auditable flags`() {
        val result =
            GnssSampleMapper.map(
                reading =
                    validReading().copy(
                        sourceTimestampNanos = 5_000L,
                        horizontalAccuracyMetres = 75.0f,
                        isMockSignal = true,
                    ),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = 6_000L,
            )

        val sample = (result as GnssSampleMappingResult.Accepted).sample
        assertNull(sample.tripElapsedNanos)
        assertTrue(GnssQualityFlag.GNSS_LOW_ACCURACY in sample.qualityFlags)
        assertTrue(GnssQualityFlag.CLOCK_DISCONTINUITY in sample.qualityFlags)
        assertTrue(GnssQualityFlag.MOCK_LOCATION_SIGNAL in sample.qualityFlags)
        assertTrue(sample.isMockSignal)
    }

    @Test
    fun `marks a source timestamp from before the trip epoch`() {
        val result =
            GnssSampleMapper.map(
                reading = validReading().copy(sourceTimestampNanos = 999L),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
            )

        val sample = (result as GnssSampleMappingResult.Accepted).sample
        assertNull(sample.tripElapsedNanos)
        assertTrue(GnssQualityFlag.CLOCK_DISCONTINUITY in sample.qualityFlags)
    }

    @Test
    fun `rejects invalid mandatory and optional evidence`() {
        assertRejected(
            validReading().copy(horizontalAccuracyMetres = null),
            GnssSampleRejectionReason.INVALID_HORIZONTAL_ACCURACY,
        )
        assertRejected(
            validReading().copy(latitudeDegrees = 91.0),
            GnssSampleRejectionReason.INVALID_COORDINATES,
        )
        assertRejected(
            validReading().copy(speedMetresPerSecond = -1.0f),
            GnssSampleRejectionReason.INVALID_OPTIONAL_FIELD,
        )
        assertRejected(
            validReading().copy(provider = ""),
            GnssSampleRejectionReason.INVALID_PROVIDER,
        )
        assertRejected(
            validReading().copy(sourceTimestampNanos = -1L),
            GnssSampleRejectionReason.INVALID_SOURCE_TIMESTAMP,
        )
    }

    @Test
    fun `threshold itself is accepted without a low accuracy flag`() {
        val result =
            GnssSampleMapper.map(
                validReading().copy(
                    horizontalAccuracyMetres = GNSS_LOW_ACCURACY_THRESHOLD_METRES,
                ),
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
            )

        val sample = (result as GnssSampleMappingResult.Accepted).sample
        assertFalse(GnssQualityFlag.GNSS_LOW_ACCURACY in sample.qualityFlags)
    }

    private fun assertRejected(
        reading: PlatformLocationReading,
        expected: GnssSampleRejectionReason,
    ) {
        val result =
            GnssSampleMapper.map(
                reading,
                tripStartedAtElapsedRealtimeNanos = 1_000L,
                previousSourceTimestampNanos = null,
            )
        assertEquals(expected, (result as GnssSampleMappingResult.Rejected).reason)
    }

    private fun validReading(): PlatformLocationReading =
        PlatformLocationReading(
            sourceTimestampNanos = 2_000L,
            sourceWallTimeUtcEpochMillis = 1_800_000_000_000L,
            latitudeDegrees = 12.9716,
            longitudeDegrees = 77.5946,
            horizontalAccuracyMetres = 4.0f,
            altitudeMetres = null,
            verticalAccuracyMetres = null,
            speedMetresPerSecond = null,
            speedAccuracyMetresPerSecond = null,
            bearingDegrees = null,
            bearingAccuracyDegrees = null,
            provider = "gps",
            isMockSignal = false,
        )
}
