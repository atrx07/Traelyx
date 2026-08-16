package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.testGnssSample
import io.github.atrx07.traelyx.recorder.testImuSample
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReplayTelemetryPipelineTest {
    @Test
    fun `replay cadence is versioned and fails closed against incompatible analysis cadence`() {
        val confidence = confidence(points(), gnss())

        assertEquals(REPLAY_TELEMETRY_VERSION, ReplayTelemetryConfig().replayVersion)
        assertEquals(DEFAULT_REPLAY_INTERVAL_NANOS, ReplayTelemetryConfig().intervalNanos)
        assertTrue(runCatching { ReplayTelemetryConfig(replayVersion = 2) }.isFailure)
        assertTrue(runCatching { ReplayTelemetryConfig(intervalNanos = 0L) }.isFailure)
        assertEquals(
            "replay_interval_below_analysis_interval",
            (ReplayTelemetryPipeline.build(
                confidence,
                ReplayTelemetryConfig(intervalNanos = TEST_INTERVAL_NANOS / 2L),
            ) as ReplayTelemetryBuildResult.Invalid).errorCode,
        )
        assertEquals(
            "replay_interval_not_multiple_of_analysis_interval",
            (ReplayTelemetryPipeline.build(
                confidence,
                ReplayTelemetryConfig(intervalNanos = TEST_INTERVAL_NANOS * 5L / 2L),
            ) as ReplayTelemetryBuildResult.Invalid).errorCode,
        )
    }

    @Test
    fun `reducer emits exact first fixed cadence and terminal timestamps`() {
        val timeline = replay(points(), gnss(), replayIntervalNanos = 3L * TEST_INTERVAL_NANOS)
        val frames = timeline.frames().toList()

        assertEquals(5L, timeline.frameCount)
        assertEquals(
            listOf(0L, 300_000_000L, 600_000_000L, 900_000_000L, 1_000_000_000L),
            frames.map { it.tripElapsedNanos },
        )
        assertEquals(listOf(1L, 3L, 3L, 3L, 1L), frames.map { it.sourceFrameCount })
        assertEquals(
            listOf(null, 0L, 300_000_000L, 600_000_000L, 900_000_000L),
            frames.map { it.intervalStartExclusiveTripElapsedNanos },
        )
        assertEquals(
            listOf(0L, 100_000_000L, 400_000_000L, 700_000_000L, 1_000_000_000L),
            frames.map { it.sourceStartTripElapsedNanos },
        )
        assertEquals(ReplayIntervalCoverage.INITIAL_SAMPLE, frames.first().intervalCoverage)
        assertEquals(ReplayIntervalCoverage.COMPLETE_INTERVAL, frames[3].intervalCoverage)
        assertEquals(
            ReplayIntervalCoverage.PARTIAL_TERMINAL_INTERVAL,
            frames.last().intervalCoverage,
        )
        frames.forEach { frame ->
            assertEquals(frame.tripElapsedNanos, frame.sourceEndTripElapsedNanos)
            assertEquals(
                frame.tripElapsedNanos,
                frame.representativeConfidenceFrame.tripElapsedNanos,
            )
        }
    }

    @Test
    fun `scalar and vector envelopes preserve extrema with their exact provenance`() {
        val points =
            points { index ->
                val longitudinal =
                    when (index) {
                        3L, 4L, 5L -> 6.0
                        7L, 8L -> -4.0
                        else -> index.toDouble() / 10.0
                    }
                FrameVector3(
                    x = -index.toDouble() / 20.0,
                    y = longitudinal,
                    z = STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED,
                )
            }
        val confidence = confidence(points, gnss())
        val source = confidence.sourceTimeline.frames().toList()
        val frame =
            replay(confidence, replayIntervalNanos = 5L * TEST_INTERVAL_NANOS)
                .frames()
                .first { it.tripElapsedNanos == 500_000_000L }
        val sourceWindow = source.filter { it.tripElapsedNanos in 100_000_000L..500_000_000L }
        val availableAcceleration =
            sourceWindow.mapNotNull {
                it.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available
            }
        val expectedMinimumX = availableAcceleration.minBy { it.value.x }
        val expectedMaximumX = availableAcceleration.maxBy { it.value.x }
        val availableSpeed =
            sourceWindow.mapNotNull {
                it.filteredSpeedMetresPerSecond as? DerivedScalarValue.Available
            }

        assertEquals(expectedMinimumX, frame.vehicleAccelerationMetresPerSecondSquared.x?.minimum)
        assertEquals(expectedMaximumX, frame.vehicleAccelerationMetresPerSecondSquared.x?.maximum)
        assertEquals(
            availableAcceleration.minBy { it.value.y },
            frame.vehicleAccelerationMetresPerSecondSquared.y?.minimum,
        )
        assertEquals(
            availableAcceleration.maxBy { it.value.y },
            frame.vehicleAccelerationMetresPerSecondSquared.y?.maximum,
        )
        assertEquals(
            availableSpeed.minBy { it.value },
            frame.filteredSpeedMetresPerSecond.minimum,
        )
        assertEquals(
            availableSpeed.maxBy { it.value },
            frame.filteredSpeedMetresPerSecond.maximum,
        )
        assertEquals(
            availableAcceleration.size.toLong(),
            frame.vehicleAccelerationMetresPerSecondSquared.availableFrameCount,
        )
    }

    @Test
    fun `missing IMU interval remains explicit and cannot be smoothed away`() {
        val points = points().filterNot { it.timeNanos == 500_000_000L }
        val frame =
            replay(points, gnss(), replayIntervalNanos = 3L * TEST_INTERVAL_NANOS)
                .frames()
                .first { it.tripElapsedNanos == 600_000_000L }
        val acceleration = frame.vehicleAccelerationMetresPerSecondSquared

        assertEquals(ReplayChannelCoverage.PARTIAL, acceleration.coverage)
        assertTrue(acceleration.availableFrameCount > 0L)
        assertTrue(acceleration.missingFrameCount > 0L)
        assertTrue(DerivedChannelMissingReason.IMU_SOURCE_MISSING in acceleration.missingReasons)
        assertTrue(DerivedChannelMissingReason.FILTER_WARMUP in acceleration.missingReasons)
        assertTrue(acceleration.representative is DerivedVectorValue.Missing)
        assertEquals(TelemetryEligibility.EXCLUDED, acceleration.eligibility.mostRestrictive)
        assertEquals(3L, frame.sourceFrameCount)
    }

    @Test
    fun `confidence summaries retain supported degraded and invalidated evidence`() {
        val gnss =
            gnss { index ->
                when (index) {
                    2L -> 20.0f
                    3L -> 60.0f
                    else -> 5.0f
                }
            }
        val confidence = confidence(points(), gnss)
        val replayFrame =
            replay(confidence, replayIntervalNanos = 3L * TEST_INTERVAL_NANOS)
                .frames()
                .first { it.tripElapsedNanos == 300_000_000L }
        val sourceConfidence =
            confidence.frames().first { it.tripElapsedNanos == 300_000_000L }

        assertEquals(
            setOf(
                TelemetryConfidenceState.SUPPORTED,
                TelemetryConfidenceState.DEGRADED,
                TelemetryConfidenceState.INVALIDATED,
            ),
            replayFrame.confidence.gnss.observedStates,
        )
        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            replayFrame.confidence.gnss.mostSevere,
        )
        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            replayFrame.confidence.gnss.representative.state,
        )
        assertTrue(
            TelemetryConfidenceReason.GNSS_HORIZONTAL_ACCURACY_REDUCED in
                replayFrame.confidence.gnss.reasons,
        )
        assertTrue(
            TelemetryConfidenceReason.GNSS_LOW_ACCURACY in
                replayFrame.confidence.gnss.reasons,
        )
        assertEquals(sourceConfidence, replayFrame.representativeConfidenceFrame)
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            replayFrame.filteredSpeedMetresPerSecond.eligibility.mostRestrictive,
        )
        assertTrue(
            TelemetryEligibility.LIMITED in
                replayFrame.filteredSpeedMetresPerSecond.eligibility.observed,
        )
    }

    @Test
    fun `movement and corroborated eligibility transitions stay visible within a window`() {
        val frame =
            replay(points(), gnss(), replayIntervalNanos = 10L * TEST_INTERVAL_NANOS)
                .frames()
                .first { it.tripElapsedNanos == 1_000_000_000L }

        assertTrue(MovementState.UNKNOWN in frame.movementState.observedStates)
        assertTrue(MovementState.MOVING in frame.movementState.observedStates)
        assertEquals(MovementState.MOVING, frame.movementState.representative.state)
        assertTrue(
            TelemetryEligibility.EXCLUDED in
                frame.corroboratedVehicleMotionEligibility.observed,
        )
        assertTrue(
            TelemetryEligibility.ELIGIBLE in
                frame.corroboratedVehicleMotionEligibility.observed,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            frame.corroboratedVehicleMotionEligibility.mostRestrictive,
        )
    }

    @Test
    fun `replay iteration is repeatable lazy and independent from analysis density`() {
        val timeline = replay(points(), gnss(), replayIntervalNanos = 2L * TEST_INTERVAL_NANOS)
        val first = timeline.frames().toList()
        val second = timeline.frames().toList()

        assertEquals(first, second)
        assertEquals(timeline.frameCount, first.size.toLong())
        assertEquals(first.take(2), timeline.frames().take(2).toList())
        assertTrue(timeline.frameCount < timeline.sourceTimeline.frameCount)
        assertEquals(2L * TEST_INTERVAL_NANOS, timeline.config.intervalNanos)
    }

    @Test
    fun `single source frame remains one exact replay frame`() {
        val onlyPoint = points().take(1)
        val onlyGnss = gnss().take(1)
        val timeline = replay(onlyPoint, onlyGnss, replayIntervalNanos = 3L * TEST_INTERVAL_NANOS)
        val frame = timeline.frames().single()

        assertEquals(1L, timeline.frameCount)
        assertEquals(0L, frame.tripElapsedNanos)
        assertEquals(ReplayIntervalCoverage.INITIAL_SAMPLE, frame.intervalCoverage)
        assertNull(frame.intervalStartExclusiveTripElapsedNanos)
        assertEquals(1L, frame.sourceFrameCount)
    }

    private fun replay(
        points: List<ImuPoint>,
        gnss: List<RawGnssSample>,
        replayIntervalNanos: Long,
    ): ReplayTelemetryTimeline = replay(confidence(points, gnss), replayIntervalNanos)

    private fun replay(
        confidence: TelemetryConfidenceTimeline,
        replayIntervalNanos: Long,
    ): ReplayTelemetryTimeline =
        (ReplayTelemetryPipeline.build(
            confidence,
            ReplayTelemetryConfig(intervalNanos = replayIntervalNanos),
        ) as ReplayTelemetryBuildResult.Success).timeline

    private fun confidence(
        points: List<ImuPoint>,
        gnss: List<RawGnssSample>,
    ): TelemetryConfidenceTimeline =
        TelemetryConfidencePipeline.build(derived(points, gnss))

    private fun derived(
        points: List<ImuPoint>,
        gnss: List<RawGnssSample>,
    ): DerivedTelemetryTimeline {
        val records = buildList {
            points.forEach { point ->
                add(
                    imuRecord(
                        sensorType = ImuSensorType.ACCELEROMETER,
                        timeNanos = point.timeNanos,
                        value = point.accelerationDevice,
                    ),
                )
                add(
                    imuRecord(
                        sensorType = ImuSensorType.GYROSCOPE,
                        timeNanos = point.timeNanos,
                        value = point.gyroscopeDevice,
                    ),
                )
            }
            gnss.forEach { add(TelemetrySampleRecord.Gnss(it)) }
        }
        val trip = decodeTrip(encode(records))
        val analysis =
            (AnalysisTimelineResampler.build(
                trip,
                AnalysisTimelineConfig(
                    intervalNanos = TEST_INTERVAL_NANOS,
                    maxImuInterpolationGapNanos = TEST_INTERVAL_NANOS,
                ),
            ) as AnalysisTimelineBuildResult.Success).timeline
        val gnssSummary =
            (GnssSanityFilter.process(trip) as GnssProcessingResult.Success).summary
        val calibration = calibration()
        return (
            DerivedTelemetryPipeline.build(
                sourceTimeline = analysis,
                gnssSummary = gnssSummary,
                motionContexts =
                    DerivedMotionContextTimeline.fixed(calibration, mount(calibration)),
                config =
                    DerivedTelemetryConfig(
                        accelerationFilterTimeConstantNanos = 1L,
                        yawRateFilterTimeConstantNanos = 1L,
                        speedFilterTimeConstantNanos = 1L,
                        headingRateFilterTimeConstantNanos = 1L,
                        maximumContinuousImuGapNanos = TEST_INTERVAL_NANOS,
                        movingConfirmationDurationNanos = 0L,
                        stoppedConfirmationDurationNanos = 0L,
                    ),
            ) as DerivedTelemetryBuildResult.Success
        ).timeline
    }

    private fun points(
        acceleration: (Long) -> FrameVector3 = {
            FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED)
        },
    ): List<ImuPoint> =
        (0L..10L).map { index ->
            ImuPoint(
                timeNanos = index * TEST_INTERVAL_NANOS,
                accelerationDevice = acceleration(index),
                gyroscopeDevice = FrameVector3(0.0, 0.0, 0.05),
            )
        }

    private fun gnss(
        horizontalAccuracy: (Long) -> Float = { 5.0f },
    ): List<RawGnssSample> =
        (0L..10L).map { index ->
            val time = index * TEST_INTERVAL_NANOS
            testGnssSample(
                tripElapsedNanos = time,
                sourceTimestampNanos = SOURCE_TIME_OFFSET_NANOS + time,
            ).copy(
                latitudeDegrees = 37.0 + index * 0.00005,
                longitudeDegrees = -122.0,
                horizontalAccuracyMetres = horizontalAccuracy(index),
                speedMetresPerSecond = 10.0f,
                speedAccuracyMetresPerSecond = 0.1f,
                bearingDegrees = 0.0f,
                bearingAccuracyDegrees = 1.0f,
            )
        }

    private fun calibration(): ImuStationaryCalibrationResult =
        ImuStationaryCalibrationResult(
            state = ImuCalibrationState.CALIBRATED,
            config = ImuStationaryCalibrationConfig(),
            calibration =
                ImuBiasCalibration(
                    startTripElapsedNanos = 0L,
                    endTripElapsedNanos = 0L,
                    sampleCount = 2,
                    meanAccelerometerDeviceMetresPerSecondSquared =
                        CalibrationVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                    gravityDirectionDevice = CalibrationVector3(0.0, 0.0, 1.0),
                    observableAccelerometerRadialBiasMetresPerSecondSquared = 0.0,
                    observableAccelerometerRadialBiasDeviceMetresPerSecondSquared =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    gyroscopeBiasDeviceRadiansPerSecond = CalibrationVector3(0.0, 0.0, 0.0),
                    accelerometerAxisStandardDeviationMetresPerSecondSquared =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    gyroscopeAxisStandardDeviationRadiansPerSecond =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    accelerometerMinimumAccuracyStatus = 3,
                    gyroscopeMinimumAccuracyStatus = 3,
                    accelerometerInterpolatedFrameCount = 0,
                    gyroscopeInterpolatedFrameCount = 0,
                    rawQualityFlags = emptySet(),
                ),
            evidence = emptySet(),
            diagnostics =
                ImuCalibrationDiagnostics(
                    totalFrameCount = 2L,
                    pairedAvailableFrameCount = 2L,
                    stationaryCandidateFrameCount = 2L,
                    longestCandidateDurationNanos = 0L,
                    accelerometerMissingFrameCount = 0L,
                    gyroscopeMissingFrameCount = 0L,
                    sourceDiscontinuityFrameCount = 0L,
                    accelerometerNotGravityLikeFrameCount = 0L,
                    gyroscopeMotionFrameCount = 0L,
                    unstableWindowCount = 0L,
                ),
        )

    private fun mount(
        calibration: ImuStationaryCalibrationResult,
    ): VehicleMountAlignmentResolution {
        val source = requireNotNull(calibration.calibration)
        return VehicleMountAlignmentResolution.Available(
            VehicleMountAlignment(
                quality = VehicleMountAlignmentQuality.RESOLVED,
                sourceCalibrationStartTripElapsedNanos = source.startTripElapsedNanos,
                sourceCalibrationEndTripElapsedNanos = source.endTripElapsedNanos,
                forwardDevice = FrameVector3.DEVICE_TOP,
                leftDevice = FrameVector3.DEVICE_RIGHT * -1.0,
                upDevice = FrameVector3.DEVICE_SCREEN_OUT,
                deviceToVehicleForwardLeftUp =
                    FrameTransformMatrix.ofRows(
                        FrameVector3.DEVICE_TOP,
                        FrameVector3.DEVICE_RIGHT * -1.0,
                        FrameVector3.DEVICE_SCREEN_OUT,
                    ),
                evidence = setOf(VehicleMountAlignmentEvidence.EXPLICIT_DEVICE_FORWARD_HINT),
            ),
        )
    }

    private fun imuRecord(
        sensorType: ImuSensorType,
        timeNanos: Long,
        value: FrameVector3,
    ): TelemetrySampleRecord.Imu =
        TelemetrySampleRecord.Imu(
            testImuSample(
                sensorType = sensorType,
                tripElapsedNanos = timeNanos,
                sourceTimestampNanos = SOURCE_TIME_OFFSET_NANOS + timeNanos,
            ).copy(
                x = value.x.toFloat(),
                y = value.y.toFloat(),
                z = value.z.toFloat(),
                accuracyStatus = 3,
                qualityFlags = emptySet<ImuQualityFlag>(),
            ),
        )

    private fun decodeTrip(chunks: List<ByteArray>): DecodedRawTelemetryTrip =
        (RawTelemetryTripDecoder.decode(chunks) as RawTelemetryTripDecodeResult.Success).trip

    private fun encode(records: List<TelemetrySampleRecord>): List<ByteArray> {
        val ordered = records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR)
        val groups = mutableListOf<MutableList<TelemetrySampleRecord>>()
        ordered.forEach { record ->
            val current = groups.lastOrNull()
            val shouldStartNew =
                current == null ||
                    current.size == 256 ||
                    record.tripElapsedNanos - current.first().tripElapsedNanos > SECOND_NANOS
            if (shouldStartNew) groups += mutableListOf(record) else current.add(record)
        }
        return groups.mapIndexed { index, group ->
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = index.toLong(),
                records = group,
                createdAtUtcEpochMillis = 1_777_777_777_500L + index,
            ).bytes
        }
    }

    private data class ImuPoint(
        val timeNanos: Long,
        val accelerationDevice: FrameVector3,
        val gyroscopeDevice: FrameVector3,
    )

    private companion object {
        const val TEST_INTERVAL_NANOS = 100_000_000L
        const val SECOND_NANOS = 1_000_000_000L
        const val SOURCE_TIME_OFFSET_NANOS = 10_000_000_000L
    }
}
