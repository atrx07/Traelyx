package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GnssSanityFilterTest {
    @Test
    fun `decoded trip production path processes only ordered GNSS evidence`() {
        val records =
            listOf(
                TelemetrySampleRecord.Gnss(sample(elapsedNanos = 0L, longitudeDegrees = 0.0)),
                TelemetrySampleRecord.Gnss(
                    sample(elapsedNanos = SECOND, longitudeDegrees = 0.0001),
                ),
            )
        val encoded =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = 0,
                records = records,
                createdAtUtcEpochMillis = 1_777_777_777_500L,
            ).bytes
        val trip =
            (RawTelemetryTripDecoder.decode(listOf(encoded)) as RawTelemetryTripDecodeResult.Success)
                .trip

        val result = GnssSanityFilter.process(trip) as GnssProcessingResult.Success

        assertEquals(2, result.summary.samples.size)
        assertEquals(11.119, result.summary.totalDistanceMetres, 0.01)
    }

    @Test
    fun `resolved straight segments accumulate deterministic geodesic distance`() {
        val summary =
            process(
                sample(elapsedNanos = 0L, longitudeDegrees = 0.0, accuracyMetres = 1.0f),
                sample(elapsedNanos = SECOND, longitudeDegrees = 0.0001, accuracyMetres = 1.0f),
                sample(elapsedNanos = 2 * SECOND, longitudeDegrees = 0.0002, accuracyMetres = 1.0f),
            )

        assertEquals(
            listOf(
                GnssDecision.ACCEPTED_ANCHOR,
                GnssDecision.ACCEPTED_RESOLVED_DISTANCE,
                GnssDecision.ACCEPTED_RESOLVED_DISTANCE,
            ),
            summary.samples.map { it.decision },
        )
        assertEquals(22.239, summary.totalDistanceMetres, 0.01)
        assertEquals(summary.totalDistanceMetres, summary.resolvedDistanceMetres, 0.0)
        assertEquals(0.0, summary.motionSupportedDistanceMetres, 0.0)
        assertEquals(11.119, summary.samples[1].distanceIncrementMetres, 0.01)
        assertEquals(9.119, summary.samples[1].minimumPlausibleSpeedMetresPerSecond!!, 0.01)
    }

    @Test
    fun `great-circle distance takes the short path across the antimeridian`() {
        val summary =
            process(
                sample(elapsedNanos = 0L, longitudeDegrees = 179.999, accuracyMetres = 1.0f),
                sample(
                    elapsedNanos = 5 * SECOND,
                    longitudeDegrees = -179.999,
                    accuracyMetres = 1.0f,
                ),
            )

        assertEquals(GnssDecision.ACCEPTED_RESOLVED_DISTANCE, summary.samples.last().decision)
        assertEquals(222.39, summary.totalDistanceMetres, 0.1)
    }

    @Test
    fun `stationary jitter and unresolved within-accuracy movement do not add distance`() {
        val summary =
            process(
                sample(
                    elapsedNanos = 0L,
                    longitudeDegrees = 0.0,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = 0.1f,
                ),
                sample(
                    elapsedNanos = SECOND,
                    longitudeDegrees = 0.00001,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = 0.2f,
                ),
                sample(
                    elapsedNanos = 2 * SECOND,
                    longitudeDegrees = 0.00002,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = null,
                ),
            )

        assertEquals(GnssDecision.EXCLUDED_STATIONARY_JITTER, summary.samples[1].decision)
        assertTrue(
            GnssProcessingEvidence.SOURCE_SPEED_SUPPORTS_STATIONARY in
                summary.samples[1].evidence,
        )
        assertEquals(
            GnssDecision.EXCLUDED_UNRESOLVED_WITHIN_ACCURACY,
            summary.samples[2].decision,
        )
        assertEquals(0.0, summary.totalDistanceMetres, 0.0)
    }

    @Test
    fun `source motion can support limited distance inside the accuracy envelope`() {
        val summary =
            process(
                sample(
                    elapsedNanos = 0L,
                    longitudeDegrees = 0.0,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = 5.0f,
                ),
                sample(
                    elapsedNanos = SECOND,
                    longitudeDegrees = 0.00001,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = 5.0f,
                ),
            )

        val accepted = summary.samples.last()
        assertEquals(GnssDecision.ACCEPTED_MOTION_SUPPORTED_DISTANCE, accepted.decision)
        assertTrue(GnssProcessingEvidence.SEGMENT_WITHIN_ACCURACY in accepted.evidence)
        assertTrue(GnssProcessingEvidence.SOURCE_SPEED_SUPPORTS_MOTION in accepted.evidence)
        assertEquals(1.112, summary.totalDistanceMetres, 0.01)
        assertEquals(summary.totalDistanceMetres, summary.motionSupportedDistanceMetres, 0.0)
    }

    @Test
    fun `low accuracy and clock discontinuity break the distance chain`() {
        val lowAccuracy =
            sample(
                elapsedNanos = SECOND,
                longitudeDegrees = 0.01,
                accuracyMetres = 60.0f,
                qualityFlags = setOf(GnssQualityFlag.GNSS_LOW_ACCURACY),
            )
        val clockDiscontinuity =
            sample(
                elapsedNanos = 4 * SECOND,
                longitudeDegrees = 0.02,
                qualityFlags = setOf(GnssQualityFlag.CLOCK_DISCONTINUITY),
            )
        val summary =
            process(
                sample(elapsedNanos = 0L, longitudeDegrees = 0.0),
                lowAccuracy,
                sample(elapsedNanos = 2 * SECOND, longitudeDegrees = 0.0001),
                sample(elapsedNanos = 3 * SECOND, longitudeDegrees = 0.0002),
                clockDiscontinuity,
                sample(elapsedNanos = 5 * SECOND, longitudeDegrees = 0.0003),
            )

        assertEquals(GnssDecision.EXCLUDED_LOW_ACCURACY, summary.samples[1].decision)
        assertEquals(GnssDecision.ACCEPTED_ANCHOR, summary.samples[2].decision)
        assertEquals(GnssDecision.ACCEPTED_RESOLVED_DISTANCE, summary.samples[3].decision)
        assertEquals(GnssDecision.EXCLUDED_CLOCK_DISCONTINUITY, summary.samples[4].decision)
        assertEquals(GnssDecision.ACCEPTED_ANCHOR, summary.samples[5].decision)
        assertEquals(11.119, summary.totalDistanceMetres, 0.01)
    }

    @Test
    fun `gap resets while an impossible jump is isolated from the anchor`() {
        val summary =
            process(
                sample(elapsedNanos = 0L, longitudeDegrees = 0.0, accuracyMetres = 1.0f),
                sample(elapsedNanos = SECOND, longitudeDegrees = 1.0, accuracyMetres = 1.0f),
                sample(elapsedNanos = 2 * SECOND, longitudeDegrees = 0.0001, accuracyMetres = 1.0f),
                sample(elapsedNanos = 8 * SECOND, longitudeDegrees = 0.0002, accuracyMetres = 1.0f),
                sample(elapsedNanos = 9 * SECOND, longitudeDegrees = 0.0003, accuracyMetres = 1.0f),
            )

        val impossible = summary.samples[1]
        assertEquals(GnssDecision.EXCLUDED_IMPOSSIBLE_JUMP, impossible.decision)
        assertTrue(GnssProcessingEvidence.IMPOSSIBLE_JUMP in impossible.evidence)
        assertTrue(impossible.minimumPlausibleSpeedMetresPerSecond!! > 100.0)
        assertEquals(0L, summary.samples[2].previousAnchorElapsedNanos)
        assertEquals(GnssDecision.ACCEPTED_RESOLVED_DISTANCE, summary.samples[2].decision)
        assertEquals(GnssDecision.RESET_AFTER_GAP, summary.samples[3].decision)
        assertEquals(GnssDecision.ACCEPTED_RESOLVED_DISTANCE, summary.samples[4].decision)
        assertEquals(22.239, summary.totalDistanceMetres, 0.01)
    }

    @Test
    fun `mock signal remains evidence and implausible source speed cannot prove motion`() {
        val mockFlags = setOf(GnssQualityFlag.MOCK_LOCATION_SIGNAL)
        val summary =
            process(
                sample(
                    elapsedNanos = 0L,
                    longitudeDegrees = 0.0,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = 500.0f,
                    isMockSignal = true,
                    qualityFlags = mockFlags,
                ),
                sample(
                    elapsedNanos = SECOND,
                    longitudeDegrees = 0.00001,
                    accuracyMetres = 5.0f,
                    speedMetresPerSecond = 500.0f,
                    isMockSignal = true,
                    qualityFlags = mockFlags,
                ),
            )

        val current = summary.samples.last()
        assertEquals(GnssDecision.EXCLUDED_UNRESOLVED_WITHIN_ACCURACY, current.decision)
        assertTrue(GnssProcessingEvidence.RAW_MOCK_LOCATION_SIGNAL in current.evidence)
        assertTrue(GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE in current.evidence)
        assertEquals(0.0, summary.totalDistanceMetres, 0.0)
    }

    @Test
    fun `empty input is explicit and non-monotonic input fails closed`() {
        val empty =
            GnssSanityFilter.processSamples(emptySequence()) as GnssProcessingResult.Success
        assertEquals(0, empty.summary.samples.size)
        assertEquals(0.0, empty.summary.totalDistanceMetres, 0.0)

        val invalid =
            GnssSanityFilter.processSamples(
                sequenceOf(
                    sample(elapsedNanos = SECOND, longitudeDegrees = 0.0),
                    sample(elapsedNanos = SECOND, longitudeDegrees = 0.0001),
                ),
            ) as GnssProcessingResult.Invalid
        assertEquals("gnss_time_order_invalid", invalid.errorCode)
        assertEquals(1, invalid.sampleIndex)

        val missingTime =
            GnssSanityFilter.processSamples(
                sequenceOf(sample(elapsedNanos = 0L, longitudeDegrees = 0.0).copy(tripElapsedNanos = null)),
            ) as GnssProcessingResult.Invalid
        assertEquals("gnss_trip_time_missing", missingTime.errorCode)
        assertEquals(0, missingTime.sampleIndex)
    }

    @Test
    fun `processing thresholds are explicit versioned configuration`() {
        val config = GnssProcessingConfig()

        assertEquals(GNSS_PROCESSING_VERSION, config.processingVersion)
        assertEquals(50.0, config.maximumHorizontalAccuracyMetres, 0.0)
        assertEquals(5 * SECOND, config.maximumGapNanos)
        assertEquals(100.0, config.maximumPlausibleSpeedMetresPerSecond, 0.0)
        assertEquals(0.75, config.stationarySpeedThresholdMetresPerSecond, 0.0)
    }

    private fun process(vararg samples: RawGnssSample): GnssProcessingSummary =
        (GnssSanityFilter.processSamples(samples.asSequence()) as GnssProcessingResult.Success)
            .summary

    private fun sample(
        elapsedNanos: Long,
        longitudeDegrees: Double,
        accuracyMetres: Float = 1.0f,
        speedMetresPerSecond: Float? = 10.0f,
        isMockSignal: Boolean = false,
        qualityFlags: Set<GnssQualityFlag> = emptySet(),
    ): RawGnssSample =
        RawGnssSample(
            tripElapsedNanos = elapsedNanos,
            sourceTimestampNanos = SECOND + elapsedNanos,
            sourceWallTimeUtcEpochMillis = 1_777_777_777_000L + elapsedNanos / 1_000_000L,
            latitudeDegrees = 0.0,
            longitudeDegrees = longitudeDegrees,
            horizontalAccuracyMetres = accuracyMetres,
            altitudeMetres = null,
            verticalAccuracyMetres = null,
            speedMetresPerSecond = speedMetresPerSecond,
            speedAccuracyMetresPerSecond = null,
            bearingDegrees = null,
            bearingAccuracyDegrees = null,
            provider = "gps",
            isMockSignal = isMockSignal,
            qualityFlags = qualityFlags,
        )

    private companion object {
        const val SECOND = 1_000_000_000L
    }
}
