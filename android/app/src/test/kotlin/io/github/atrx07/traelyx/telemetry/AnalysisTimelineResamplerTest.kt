package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.testGnssSample
import io.github.atrx07.traelyx.recorder.testImuSample
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalysisTimelineResamplerTest {
    @Test
    fun `timeline aligns sparse GNSS and bounded IMU without extrapolation`() {
        val trip =
            decodeTrip(
                encode(
                    sequence = 0,
                    records =
                        listOf(
                            imuRecord(ImuSensorType.ACCELEROMETER, 0L, 1_000L, 0.0f),
                            imuRecord(ImuSensorType.GYROSCOPE, 0L, 2_000L, 1.0f),
                            TelemetrySampleRecord.Gnss(
                                testGnssSample(
                                    tripElapsedNanos = 7L,
                                    sourceTimestampNanos = 3_007L,
                                ),
                            ),
                            imuRecord(ImuSensorType.ACCELEROMETER, 10L, 1_010L, 10.0f),
                        ),
                ),
                encode(
                    sequence = 1,
                    records =
                        listOf(
                            TelemetrySampleRecord.Gnss(
                                testGnssSample(
                                    tripElapsedNanos = 20L,
                                    sourceTimestampNanos = 3_020L,
                                ),
                            ),
                            imuRecord(ImuSensorType.ACCELEROMETER, 20L, 1_020L, 20.0f),
                            imuRecord(ImuSensorType.GYROSCOPE, 30L, 2_030L, 31.0f),
                        ),
                ),
            )
        val config = AnalysisTimelineConfig(intervalNanos = 5L, maxImuInterpolationGapNanos = 20L)
        val timeline =
            (AnalysisTimelineResampler.build(trip, config) as AnalysisTimelineBuildResult.Success).timeline
        val frames = timeline.frames().toList()

        assertEquals(7L, timeline.frameCount)
        assertEquals(listOf(0L, 5L, 10L, 15L, 20L, 25L, 30L), frames.map { it.tripElapsedNanos })
        assertEquals(listOf(7L), frames[1].gnssSamples.map { it.tripElapsedNanos })
        assertEquals(listOf(20L), frames[4].gnssSamples.map { it.tripElapsedNanos })
        assertEquals(2, frames.sumOf { it.gnssSamples.size })

        val interpolated =
            frames[1].accelerometerDeviceMetresPerSecondSquared as ResampledImuValue.Available
        assertEquals(ImuAlignment.INTERPOLATED, interpolated.alignment)
        assertEquals(5.0, interpolated.x, 0.0)
        assertEquals(0L, interpolated.lowerTripElapsedNanos)
        assertEquals(10L, interpolated.upperTripElapsedNanos)
        assertEquals(1_000L, interpolated.lowerSourceTimestampNanos)
        assertEquals(1_010L, interpolated.upperSourceTimestampNanos)

        val exact =
            frames[2].accelerometerDeviceMetresPerSecondSquared as ResampledImuValue.Available
        assertEquals(ImuAlignment.EXACT, exact.alignment)
        assertEquals(10.0, exact.x, 0.0)

        val gyroGap = frames[1].gyroscopeDeviceRadiansPerSecond as ResampledImuValue.Missing
        assertEquals(ImuMissingReason.INTERPOLATION_GAP_TOO_LARGE, gyroGap.reason)
        val noExtrapolation =
            frames[5].accelerometerDeviceMetresPerSecondSquared as ResampledImuValue.Missing
        assertEquals(ImuMissingReason.OUTSIDE_SOURCE_COVERAGE, noExtrapolation.reason)

        assertEquals(frames, timeline.frames().toList())
    }

    @Test
    fun `known discontinuity prevents interpolation and keeps exact raw evidence`() {
        val first =
            imuRecord(
                sensorType = ImuSensorType.ACCELEROMETER,
                elapsedNanos = 0L,
                sourceNanos = 1_000L,
                x = 0.0f,
            )
        val second =
            TelemetrySampleRecord.Imu(
                testImuSample(
                    tripElapsedNanos = 10L,
                    sourceTimestampNanos = 1_010L,
                ).copy(
                    x = 10.0f,
                    qualityFlags = setOf(ImuQualityFlag.IMU_DROPOUT),
                ),
            )
        val trip = decodeTrip(encode(sequence = 0, records = listOf(first, second)))
        val config = AnalysisTimelineConfig(intervalNanos = 5L, maxImuInterpolationGapNanos = 20L)
        val frames =
            (AnalysisTimelineResampler.build(trip, config) as AnalysisTimelineBuildResult.Success)
                .timeline
                .frames()
                .toList()

        val middle = frames[1].accelerometerDeviceMetresPerSecondSquared as ResampledImuValue.Missing
        assertEquals(ImuMissingReason.SOURCE_DISCONTINUITY, middle.reason)
        val exact = frames[2].accelerometerDeviceMetresPerSecondSquared as ResampledImuValue.Available
        assertEquals(ImuAlignment.EXACT, exact.alignment)
        assertTrue(ImuQualityFlag.IMU_DROPOUT in exact.qualityFlags)

        val unavailableGyro = frames.first().gyroscopeDeviceRadiansPerSecond as ResampledImuValue.Missing
        assertEquals(ImuMissingReason.CHANNEL_UNAVAILABLE, unavailableGyro.reason)
    }

    @Test
    fun `default analysis contract is explicitly versioned`() {
        val config = AnalysisTimelineConfig()

        assertEquals(ANALYSIS_TIMELINE_VERSION, config.timelineVersion)
        assertEquals(10_000_000L, config.intervalNanos)
        assertEquals(50_000_000L, config.maxImuInterpolationGapNanos)
    }

    private fun decodeTrip(vararg chunks: ByteArray): DecodedRawTelemetryTrip =
        (RawTelemetryTripDecoder.decode(chunks.toList()) as RawTelemetryTripDecodeResult.Success).trip

    private fun imuRecord(
        sensorType: ImuSensorType,
        elapsedNanos: Long,
        sourceNanos: Long,
        x: Float,
    ): TelemetrySampleRecord.Imu =
        TelemetrySampleRecord.Imu(
            testImuSample(
                sensorType = sensorType,
                tripElapsedNanos = elapsedNanos,
                sourceTimestampNanos = sourceNanos,
            ).copy(x = x),
        )

    private fun encode(
        sequence: Long,
        records: List<TelemetrySampleRecord>,
    ): ByteArray =
        TelemetryChunkCodec.encode(
            tripId = TEST_TRIP_ID,
            sequence = sequence,
            records = records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR),
            createdAtUtcEpochMillis = 1_777_777_777_500L + sequence,
        ).bytes
}
