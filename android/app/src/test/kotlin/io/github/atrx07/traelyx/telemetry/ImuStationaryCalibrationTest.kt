package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.testImuSample
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ImuStationaryCalibrationTest {
    @Test
    fun `stable stationary evidence estimates observable accelerometer and gyro biases`() {
        val result =
            calibrate(
                frames =
                    frames(
                        count = 5,
                        accelerometer = { CalibrationVector3(0.1, -0.2, 10.2) },
                        gyroscope = { CalibrationVector3(0.01, -0.02, 0.005) },
                    ),
            )

        assertEquals(ImuCalibrationState.CALIBRATED, result.state)
        val calibration = requireNotNull(result.calibration)
        assertEquals(5, calibration.sampleCount)
        assertEquals(0L, calibration.startTripElapsedNanos)
        assertEquals(40L, calibration.endTripElapsedNanos)
        assertVector(CalibrationVector3(0.1, -0.2, 10.2), calibration.meanAccelerometerDeviceMetresPerSecondSquared)
        assertVector(CalibrationVector3(0.01, -0.02, 0.005), calibration.gyroscopeBiasDeviceRadiansPerSecond)
        assertEquals(
            calibration.meanAccelerometerDeviceMetresPerSecondSquared.magnitude - 9.80665,
            calibration.observableAccelerometerRadialBiasMetresPerSecondSquared,
            1e-12,
        )
        assertEquals(1.0, calibration.gravityDirectionDevice.magnitude, 1e-12)
        assertTrue(result.evidence.isEmpty())
    }

    @Test
    fun `unreliable raw sensor status remains visible and degrades calibration`() {
        val flags = setOf(ImuQualityFlag.SENSOR_UNRELIABLE)
        val result =
            calibrate(
                frames =
                    frames(
                        count = 5,
                        accelerometerAccuracyStatus = 0,
                        accelerometerFlags = flags,
                    ),
            )

        assertEquals(ImuCalibrationState.CALIBRATED_DEGRADED, result.state)
        assertEquals(setOf(ImuCalibrationEvidence.SENSOR_UNRELIABLE), result.evidence)
        val calibration = requireNotNull(result.calibration)
        assertEquals(0, calibration.accelerometerMinimumAccuracyStatus)
        assertEquals(3, calibration.gyroscopeMinimumAccuracyStatus)
        assertEquals(flags, calibration.rawQualityFlags)
        assertEquals(0.0, calibration.observableAccelerometerRadialBiasDeviceMetresPerSecondSquared.x, 0.0)
        assertEquals(
            10.2 - 9.80665,
            calibration.observableAccelerometerRadialBiasDeviceMetresPerSecondSquared.z,
            1e-12,
        )
    }

    @Test
    fun `interpolated provenance is retained without fabricating poor accuracy`() {
        val result =
            calibrate(
                frames =
                    frames(
                        count = 5,
                        accelerometerAlignment = ImuAlignment.INTERPOLATED,
                        gyroscopeAlignment = ImuAlignment.INTERPOLATED,
                    ),
            )

        assertEquals(ImuCalibrationState.CALIBRATED, result.state)
        assertEquals(setOf(ImuCalibrationEvidence.INTERPOLATED_INPUT), result.evidence)
        val calibration = requireNotNull(result.calibration)
        assertEquals(5, calibration.accelerometerInterpolatedFrameCount)
        assertEquals(5, calibration.gyroscopeInterpolatedFrameCount)
    }

    @Test
    fun `missing channel fails explicitly instead of treating missing as zero`() {
        val frames =
            frames(count = 5).map {
                it.copy(
                    gyroscopeDeviceRadiansPerSecond =
                        ResampledImuValue.Missing(
                            targetElapsedNanos = it.tripElapsedNanos,
                            reason = ImuMissingReason.CHANNEL_UNAVAILABLE,
                        ),
                )
            }

        val result = calibrate(frames)

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertNull(result.calibration)
        assertTrue(ImuCalibrationEvidence.GYROSCOPE_MISSING in result.evidence)
        assertTrue(ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION in result.evidence)
        assertEquals(5L, result.diagnostics.gyroscopeMissingFrameCount)
    }

    @Test
    fun `angular motion and non-gravity acceleration cannot calibrate`() {
        val moving =
            frames(
                count = 5,
                accelerometer = { CalibrationVector3(0.0, 0.0, 12.0) },
                gyroscope = { CalibrationVector3(0.2, 0.0, 0.0) },
            )

        val result = calibrate(moving)

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertTrue(ImuCalibrationEvidence.ACCELEROMETER_NOT_GRAVITY_LIKE in result.evidence)
        assertEquals(5L, result.diagnostics.accelerometerNotGravityLikeFrameCount)
        assertEquals(0L, result.diagnostics.stationaryCandidateFrameCount)
    }

    @Test
    fun `quiet-looking but unstable axes fail the variance gate`() {
        val unstable =
            frames(
                count = 5,
                accelerometer = { index ->
                    CalibrationVector3(if (index % 2 == 0) 0.4 else -0.4, 0.0, 9.80665)
                },
            )

        val result =
            calibrate(
                unstable,
                config =
                    testConfig(
                        maxAccelerometerAxisStandardDeviationMetresPerSecondSquared = 0.05,
                    ),
            )

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertTrue(ImuCalibrationEvidence.ACCELEROMETER_UNSTABLE in result.evidence)
        assertEquals(1L, result.diagnostics.unstableWindowCount)
    }

    @Test
    fun `opposing gravity directions cannot average into a fabricated calibration`() {
        val flipping =
            frames(
                count = 6,
                accelerometer = { index ->
                    CalibrationVector3(
                        0.0,
                        0.0,
                        if (index % 2 == 0) 9.80665 else -9.80665,
                    )
                },
            )

        val result =
            calibrate(
                flipping,
                config =
                    ImuStationaryCalibrationConfig(
                        minimumStationaryDurationNanos = 50L,
                        maxAccelerometerAxisStandardDeviationMetresPerSecondSquared = 20.0,
                    ),
            )

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertTrue(ImuCalibrationEvidence.ACCELEROMETER_UNSTABLE in result.evidence)
        assertNull(result.calibration)
    }

    @Test
    fun `source discontinuity breaks candidates and remains auditable`() {
        val discontinuous = frames(count = 5).toMutableList()
        discontinuous[2] =
            discontinuous[2].copy(
                accelerometerDeviceMetresPerSecondSquared =
                    available(
                        elapsedNanos = 20L,
                        vector = CalibrationVector3(0.0, 0.0, 10.2),
                        flags = setOf(ImuQualityFlag.IMU_DROPOUT),
                    ),
            )

        val result = calibrate(discontinuous)

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertTrue(ImuCalibrationEvidence.SOURCE_DISCONTINUITY in result.evidence)
        assertEquals(1L, result.diagnostics.sourceDiscontinuityFrameCount)
        assertEquals(10L, result.diagnostics.longestCandidateDurationNanos)
    }

    @Test
    fun `calibrator selects a later stable window after motion`() {
        val input =
            frames(
                count = 7,
                gyroscope = { index ->
                    if (index < 2) {
                        CalibrationVector3(0.2, 0.0, 0.0)
                    } else {
                        CalibrationVector3(0.01, 0.0, 0.0)
                    }
                },
            )

        val result = calibrate(input)

        assertEquals(ImuCalibrationState.CALIBRATED, result.state)
        val calibration = requireNotNull(result.calibration)
        assertEquals(20L, calibration.startTripElapsedNanos)
        assertEquals(60L, calibration.endTripElapsedNanos)
        assertEquals(2L, result.diagnostics.gyroscopeMotionFrameCount)
    }

    @Test
    fun `candidate shorter than configured duration is insufficient`() {
        val result = calibrate(frames(count = 4))

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertTrue(ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION in result.evidence)
        assertEquals(30L, result.diagnostics.longestCandidateDurationNanos)
    }

    @Test
    fun `insufficient evidence still reports unreliable source status`() {
        val result =
            calibrate(
                frames(
                    count = 4,
                    accelerometerAccuracyStatus = 0,
                    accelerometerFlags = setOf(ImuQualityFlag.SENSOR_UNRELIABLE),
                ),
            )

        assertEquals(ImuCalibrationState.INSUFFICIENT_EVIDENCE, result.state)
        assertTrue(ImuCalibrationEvidence.SENSOR_UNRELIABLE in result.evidence)
        assertTrue(ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION in result.evidence)
    }

    @Test
    fun `default calibration contract is explicitly versioned`() {
        val config = ImuStationaryCalibrationConfig()

        assertEquals(IMU_STATIONARY_CALIBRATION_VERSION, config.calibrationVersion)
        assertEquals(9.80665, config.standardGravityMetresPerSecondSquared, 0.0)
        assertEquals(2_000_000_000L, config.minimumStationaryDurationNanos)
        assertEquals(0.75, config.maxAccelerometerGravityDeviationMetresPerSecondSquared, 0.0)
        assertEquals(0.05, config.maxGyroscopeMagnitudeRadiansPerSecond, 0.0)
        assertEquals(0.15, config.maxAccelerometerAxisStandardDeviationMetresPerSecondSquared, 0.0)
        assertEquals(0.01, config.maxGyroscopeAxisStandardDeviationRadiansPerSecond, 0.0)
    }

    @Test
    fun `production timeline path calibrates without rewriting raw records`() {
        val records =
            buildList {
                repeat(5) { index ->
                    val elapsedNanos = index * 10L
                    add(
                        TelemetrySampleRecord.Imu(
                            testImuSample(
                                sensorType = ImuSensorType.ACCELEROMETER,
                                tripElapsedNanos = elapsedNanos,
                                sourceTimestampNanos = 1_000L + elapsedNanos,
                            ).copy(x = 0.1f, y = -0.2f, z = 10.2f),
                        ),
                    )
                    add(
                        TelemetrySampleRecord.Imu(
                            testImuSample(
                                sensorType = ImuSensorType.GYROSCOPE,
                                tripElapsedNanos = elapsedNanos,
                                sourceTimestampNanos = 2_000L + elapsedNanos,
                            ).copy(x = 0.01f, y = -0.02f, z = 0.005f),
                        ),
                    )
                }
            }.sortedWith(TELEMETRY_SAMPLE_COMPARATOR)
        val encoded =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = 0L,
                records = records,
                createdAtUtcEpochMillis = 1_777_777_777_500L,
            ).bytes
        val trip =
            (RawTelemetryTripDecoder.decode(listOf(encoded)) as RawTelemetryTripDecodeResult.Success)
                .trip
        val rawBefore = trip.records().toList()
        val timeline =
            (AnalysisTimelineResampler.build(
                trip,
                AnalysisTimelineConfig(intervalNanos = 10L, maxImuInterpolationGapNanos = 10L),
            ) as AnalysisTimelineBuildResult.Success).timeline

        val result = ImuStationaryCalibrator.calibrate(timeline, testConfig())

        assertEquals(ImuCalibrationState.CALIBRATED, result.state)
        assertEquals(rawBefore, trip.records().toList())
        assertEquals(5, requireNotNull(result.calibration).sampleCount)
    }

    private fun calibrate(
        frames: List<AnalysisTimelineFrame>,
        config: ImuStationaryCalibrationConfig = testConfig(),
    ): ImuStationaryCalibrationResult =
        ImuStationaryCalibrator.calibrate(
            frames = frames.asSequence(),
            analysisIntervalNanos = 10L,
            config = config,
        )

    private fun testConfig(
        maxAccelerometerAxisStandardDeviationMetresPerSecondSquared: Double = 0.15,
    ): ImuStationaryCalibrationConfig =
        ImuStationaryCalibrationConfig(
            minimumStationaryDurationNanos = 40L,
            maxAccelerometerAxisStandardDeviationMetresPerSecondSquared =
                maxAccelerometerAxisStandardDeviationMetresPerSecondSquared,
        )

    private fun frames(
        count: Int,
        accelerometer: (Int) -> CalibrationVector3 = {
            CalibrationVector3(0.0, 0.0, 10.2)
        },
        gyroscope: (Int) -> CalibrationVector3 = {
            CalibrationVector3(0.0, 0.0, 0.0)
        },
        accelerometerAccuracyStatus: Int = 3,
        accelerometerFlags: Set<ImuQualityFlag> = emptySet(),
        accelerometerAlignment: ImuAlignment = ImuAlignment.EXACT,
        gyroscopeAlignment: ImuAlignment = ImuAlignment.EXACT,
    ): List<AnalysisTimelineFrame> =
        List(count) { index ->
            val elapsedNanos = index * 10L
            AnalysisTimelineFrame(
                tripElapsedNanos = elapsedNanos,
                gnssSamples = emptyList(),
                accelerometerDeviceMetresPerSecondSquared =
                    available(
                        elapsedNanos = elapsedNanos,
                        vector = accelerometer(index),
                        accuracyStatus = accelerometerAccuracyStatus,
                        flags = accelerometerFlags,
                        alignment = accelerometerAlignment,
                    ),
                gyroscopeDeviceRadiansPerSecond =
                    available(
                        elapsedNanos = elapsedNanos,
                        vector = gyroscope(index),
                        alignment = gyroscopeAlignment,
                    ),
            )
        }

    private fun available(
        elapsedNanos: Long,
        vector: CalibrationVector3,
        accuracyStatus: Int = 3,
        flags: Set<ImuQualityFlag> = emptySet(),
        alignment: ImuAlignment = ImuAlignment.EXACT,
    ): ResampledImuValue.Available =
        ResampledImuValue.Available(
            targetElapsedNanos = elapsedNanos,
            x = vector.x,
            y = vector.y,
            z = vector.z,
            alignment = alignment,
            lowerTripElapsedNanos = elapsedNanos,
            upperTripElapsedNanos = elapsedNanos,
            lowerSourceTimestampNanos = 1_000L + elapsedNanos,
            upperSourceTimestampNanos = 1_000L + elapsedNanos,
            accuracyStatus = accuracyStatus,
            qualityFlags = flags,
        )

    private fun assertVector(
        expected: CalibrationVector3,
        actual: CalibrationVector3,
    ) {
        assertEquals(expected.x, actual.x, 1e-12)
        assertEquals(expected.y, actual.y, 1e-12)
        assertEquals(expected.z, actual.z, 1e-12)
    }
}
