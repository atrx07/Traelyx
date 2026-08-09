package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GnssHealthTrackerTest {
    @Test
    fun `counts quality evidence without exposing coordinates`() {
        val published = mutableListOf<GnssHealthSnapshot>()
        val tracker = GnssHealthTracker(published::add)
        tracker.beginRegistration()
        tracker.registered(providerEnabled = true)
        tracker.accepted(sampleWithAllQualityFlags())
        tracker.rejected()
        tracker.providerDisabled()

        val snapshot = tracker.current()
        assertEquals(GnssAcquisitionState.PROVIDER_DISABLED, snapshot.state)
        assertEquals(1L, snapshot.acceptedSampleCount)
        assertEquals(1L, snapshot.rejectedSampleCount)
        assertEquals(1L, snapshot.lowAccuracySampleCount)
        assertEquals(1L, snapshot.clockDiscontinuityCount)
        assertEquals(1L, snapshot.mockSignalCount)
        assertEquals(1L, snapshot.providerDisabledCount)
        assertEquals(4_000L, snapshot.firstSourceTimestampNanos)
        assertEquals(4_000L, snapshot.lastSourceTimestampNanos)
        assertNull(snapshot.lastTripElapsedNanos)
        assertEquals(80.0f, snapshot.lastHorizontalAccuracyMetres)
        assertTrue(snapshot.lastFixHadSpeed)
        assertFalse(snapshot.lastFixHadBearing)
        assertTrue(published.isNotEmpty())
    }

    @Test
    fun `registration failure and stop remain explicit`() {
        val tracker = GnssHealthTracker()
        tracker.beginRegistration()
        tracker.registrationFailed("gnss_provider_unavailable")

        val failed = tracker.current()
        assertEquals(GnssAcquisitionState.ERROR, failed.state)
        assertEquals(1L, failed.registrationFailureCount)
        assertEquals("gnss_provider_unavailable", failed.errorCode)

        tracker.stopped()
        assertEquals(GnssAcquisitionState.STOPPED, tracker.current().state)
    }

    private fun sampleWithAllQualityFlags(): RawGnssSample =
        RawGnssSample(
            tripElapsedNanos = null,
            sourceTimestampNanos = 4_000L,
            sourceWallTimeUtcEpochMillis = 1_800_000_000_000L,
            latitudeDegrees = 12.9716,
            longitudeDegrees = 77.5946,
            horizontalAccuracyMetres = 80.0f,
            altitudeMetres = null,
            verticalAccuracyMetres = null,
            speedMetresPerSecond = 3.0f,
            speedAccuracyMetresPerSecond = 1.0f,
            bearingDegrees = null,
            bearingAccuracyDegrees = null,
            provider = "gps",
            isMockSignal = true,
            qualityFlags =
                setOf(
                    GnssQualityFlag.GNSS_LOW_ACCURACY,
                    GnssQualityFlag.CLOCK_DISCONTINUITY,
                    GnssQualityFlag.MOCK_LOCATION_SIGNAL,
                ),
        )
}
