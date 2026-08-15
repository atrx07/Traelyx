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
import kotlin.math.PI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DerivedTelemetryPipelineTest {
    @Test
    fun `stationary evidence resolves zero motion without becoming a moving vehicle`() {
        val bias = FrameVector3(0.01, -0.02, 0.03)
        val points =
            (0L..50L).map { index ->
                ImuPoint(
                    timeNanos = index * TEST_INTERVAL_NANOS,
                    accelerationDevice = FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                    gyroscopeDevice = bias,
                )
            }
        val gnss =
            (0L..5L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 0.0f,
                    bearingDegrees = 0.0f,
                )
            }
        val calibration = calibration(gyroscopeBias = bias)
        val derived = derived(points, gnss, calibration = calibration)
        val final = derived.frames().last()

        assertScalar(0.0, final.filteredSpeedMetresPerSecond)
        assertVector(FrameVector3(0.0, 0.0, 0.0), final.vehicleAccelerationMetresPerSecondSquared)
        assertVector(FrameVector3(0.0, 0.0, 0.0), final.vehicleJerkMetresPerSecondCubed)
        assertScalar(0.0, final.yawRateRadiansPerSecond)
        assertEquals(MovementState.STOPPED, final.movementState.state)
        assertTrue(MovementStateEvidence.CONFIRMED_STOPPED in final.movementState.evidence)
        assertEquals(
            GnssCourseUnavailableReason.GNSS_SAMPLE_REJECTED,
            (final.headingChangeRateRadiansPerSecond as DerivedScalarValue.Missing)
                .unavailable
                .gnssCourseUnavailableReason,
        )
    }

    @Test
    fun `vehicle axes and robust jerk keep forward left and up signs`() {
        val points =
            (0L..12L).map { index ->
                val seconds = index * TEST_INTERVAL_NANOS / NANOS_PER_SECOND
                val desiredVehicle = FrameVector3(2.0 * seconds, -3.0 * seconds, 4.0 * seconds)
                ImuPoint(
                    timeNanos = index * TEST_INTERVAL_NANOS,
                    accelerationDevice =
                        FrameVector3(
                            x = -desiredVehicle.y,
                            y = desiredVehicle.x,
                            z = STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED + desiredVehicle.z,
                        ),
                    gyroscopeDevice = FrameVector3(0.0, 0.0, 0.0),
                )
            }
        val derived =
            derived(
                points = points,
                gnss = emptyList(),
                config = fastFilterConfig(),
            )
        val final = derived.frames().last()

        assertVector(
            expected = FrameVector3(2.2, -3.3, 4.4),
            actual = final.vehicleAccelerationMetresPerSecondSquared,
            tolerance = 1e-5,
        )
        assertVector(
            expected = FrameVector3(2.0, -3.0, 4.0),
            actual = final.vehicleJerkMetresPerSecondCubed,
            tolerance = 1e-4,
        )
        val acceleration =
            final.vehicleAccelerationMetresPerSecondSquared as DerivedVectorValue.Available
        assertTrue(DerivedChannelEvidence.STATIONARY_REFERENCE_REMOVED in acceleration.evidence)
        assertTrue(DerivedChannelEvidence.FIXED_GRAVITY_REFERENCE in acceleration.evidence)
        val jerk = final.vehicleJerkMetresPerSecondCubed as DerivedVectorValue.Available
        assertTrue(DerivedChannelEvidence.ROBUST_MEDIAN_SLOPE in jerk.evidence)
    }

    @Test
    fun `isolated accelerometer spike is rejected before jerk derivation`() {
        val points =
            (0L..12L).map { index ->
                ImuPoint(
                    timeNanos = index * TEST_INTERVAL_NANOS,
                    accelerationDevice =
                        FrameVector3(
                            x = 0.0,
                            y = if (index == 5L) 100.0 else 0.0,
                            z = STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED,
                        ),
                    gyroscopeDevice = FrameVector3(0.0, 0.0, 0.0),
                )
            }
        val final =
            derived(
                points = points,
                gnss = emptyList(),
                config = fastFilterConfig(),
            ).frames().last()

        assertVector(FrameVector3(0.0, 0.0, 0.0), final.vehicleAccelerationMetresPerSecondSquared)
        assertVector(FrameVector3(0.0, 0.0, 0.0), final.vehicleJerkMetresPerSecondCubed)
    }

    @Test
    fun `gyro yaw and GNSS heading derivative handle north wrap and moving hysteresis`() {
        val bias = FrameVector3(0.01, -0.02, 0.03)
        val points =
            (0L..40L).map { index ->
                ImuPoint(
                    timeNanos = index * TEST_INTERVAL_NANOS,
                    accelerationDevice = FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                    gyroscopeDevice = FrameVector3(bias.x, bias.y, bias.z + 0.5),
                )
            }
        val bearings = listOf(359.0f, 0.0f, 1.0f, 2.0f, 3.0f)
        val gnss =
            bearings.mapIndexed { index, bearing ->
                gnssSample(
                    timeNanos = index * SECOND_NANOS,
                    speedMetresPerSecond = 5.0f,
                    bearingDegrees = bearing,
                )
            }
        val final =
            derived(
                points = points,
                gnss = gnss,
                calibration = calibration(gyroscopeBias = bias),
                config = fastFilterConfig(),
            ).frames().last()

        assertScalar(0.5, final.yawRateRadiansPerSecond, tolerance = 1e-6)
        assertScalar(PI / 180.0, final.headingChangeRateRadiansPerSecond, tolerance = 1e-9)
        assertEquals(MovementState.MOVING, final.movementState.state)
        assertTrue(MovementStateEvidence.CONFIRMED_MOVING in final.movementState.evidence)
        val heading = final.headingChangeRateRadiansPerSecond as DerivedScalarValue.Available
        assertTrue(DerivedChannelEvidence.GNSS_COURSE_DERIVATIVE in heading.evidence)
    }

    @Test
    fun `median speed filter rejects one spike and movement remains stopped`() {
        val points = stationaryPoints(durationSeconds = 6)
        val speeds = listOf(0.0f, 0.0f, 0.0f, 10.0f, 0.0f, 0.0f, 0.0f)
        val gnss =
            speeds.mapIndexed { index, speed ->
                gnssSample(
                    timeNanos = index * SECOND_NANOS,
                    speedMetresPerSecond = speed,
                    bearingDegrees = 0.0f,
                )
            }
        val final =
            derived(
                points = points,
                gnss = gnss,
                config = fastFilterConfig(),
            ).frames().last()

        assertScalar(0.0, final.filteredSpeedMetresPerSecond)
        assertEquals(MovementState.STOPPED, final.movementState.state)
        assertTrue(MovementStateEvidence.CONFIRMED_STOPPED in final.movementState.evidence)
    }

    @Test
    fun `movement hysteresis holds moving state inside the threshold band`() {
        val speeds = listOf(5.0f, 5.0f, 5.0f, 5.0f, 1.0f, 1.0f, 1.0f)
        val gnss =
            speeds.mapIndexed { index, speed ->
                gnssSample(
                    timeNanos = index * SECOND_NANOS,
                    speedMetresPerSecond = speed,
                    bearingDegrees = 0.0f,
                )
            }
        val final =
            derived(
                points = stationaryPoints(durationSeconds = 6),
                gnss = gnss,
                config = fastFilterConfig(),
            ).frames().last()

        assertScalar(1.0, final.filteredSpeedMetresPerSecond)
        assertEquals(MovementState.MOVING, final.movementState.state)
        assertTrue(MovementStateEvidence.HYSTERESIS_HOLD in final.movementState.evidence)
    }

    @Test
    fun `stale GNSS speed becomes missing and clears movement state`() {
        val gnss =
            (0L..2L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 5.0f,
                    bearingDegrees = 0.0f,
                )
            }
        val frames =
            derived(
                points = stationaryPoints(durationSeconds = 5),
                gnss = gnss,
                config = fastFilterConfig(),
            ).frames().associateBy { it.tripElapsedNanos }

        assertTrue(frames.getValue(4_000_000_000L).filteredSpeedMetresPerSecond is DerivedScalarValue.Available)
        val stale =
            frames.getValue(5_000_000_000L).filteredSpeedMetresPerSecond
                as DerivedScalarValue.Missing
        assertEquals(DerivedChannelMissingReason.GNSS_SOURCE_STALE, stale.unavailable.reason)
        assertEquals(MovementState.UNKNOWN, frames.getValue(5_000_000_000L).movementState.state)
        assertTrue(
            MovementStateEvidence.SPEED_UNAVAILABLE in
                frames.getValue(5_000_000_000L).movementState.evidence,
        )
    }

    @Test
    fun `resolved GNSS displacement supplies degraded speed only when platform speed is absent`() {
        val gnss =
            (0L..3L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 0.0f,
                    bearingDegrees = 90.0f,
                ).copy(
                    longitudeDegrees = 77.5946 + seconds * 0.0002,
                    speedMetresPerSecond = null,
                    speedAccuracyMetresPerSecond = null,
                )
            }
        val final =
            derived(
                points = stationaryPoints(durationSeconds = 3),
                gnss = gnss,
                config = fastFilterConfig(),
            ).frames().last()
        val speed = final.filteredSpeedMetresPerSecond as DerivedScalarValue.Available

        assertTrue(speed.value > 10.0)
        assertEquals(DerivedChannelQuality.DEGRADED, speed.quality)
        assertTrue(DerivedChannelEvidence.GNSS_GEODESIC_SPEED_FALLBACK in speed.evidence)
    }

    @Test
    fun `IMU interpolation gap propagates and restarts filter warmup`() {
        val times =
            listOf(
                0L,
                100_000_000L,
                200_000_000L,
                500_000_000L,
                600_000_000L,
                700_000_000L,
            )
        val points =
            times.map { time ->
                ImuPoint(
                    timeNanos = time,
                    accelerationDevice = FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                    gyroscopeDevice = FrameVector3(0.0, 0.0, 0.0),
                )
            }
        val frames = derived(points, emptyList()).frames().associateBy { it.tripElapsedNanos }

        assertTrue(
            frames.getValue(200_000_000L).vehicleAccelerationMetresPerSecondSquared
                is DerivedVectorValue.Available,
        )
        val gap =
            frames.getValue(300_000_000L).vehicleAccelerationMetresPerSecondSquared
                as DerivedVectorValue.Missing
        assertEquals(DerivedChannelMissingReason.IMU_SOURCE_MISSING, gap.unavailable.reason)
        assertEquals(ImuMissingReason.INTERPOLATION_GAP_TOO_LARGE, gap.unavailable.imuMissingReason)
        val restarted =
            frames.getValue(500_000_000L).vehicleAccelerationMetresPerSecondSquared
                as DerivedVectorValue.Missing
        assertEquals(DerivedChannelMissingReason.FILTER_WARMUP, restarted.unavailable.reason)
    }

    @Test
    fun `context gaps and moved phone segments fail frame channels closed`() {
        val points = stationaryPoints(durationSeconds = 1)
        val calibration = calibration()
        val availableMount = mount(calibration)
        val contexts =
            DerivedMotionContextTimeline(
                listOf(
                    DerivedMotionContextSegment(
                        startTripElapsedNanos = 0L,
                        endTripElapsedNanosExclusive = 500_000_000L,
                        calibrationResult = calibration,
                        mountAlignment = availableMount,
                    ),
                    DerivedMotionContextSegment(
                        startTripElapsedNanos = 700_000_000L,
                        endTripElapsedNanosExclusive = null,
                        calibrationResult = calibration,
                        mountAlignment =
                            VehicleMountAlignmentResolution.Unavailable(
                                VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED,
                            ),
                    ),
                ),
            )
        val frames =
            derived(
                points = points,
                gnss = emptyList(),
                contexts = contexts,
                calibration = calibration,
            ).frames().associateBy { it.tripElapsedNanos }

        assertTrue(
            frames.getValue(400_000_000L).vehicleAccelerationMetresPerSecondSquared
                is DerivedVectorValue.Available,
        )
        assertEquals(
            DerivedChannelMissingReason.CONTEXT_TIMELINE_GAP,
            (frames.getValue(500_000_000L).vehicleAccelerationMetresPerSecondSquared
                    as DerivedVectorValue.Missing)
                .unavailable
                .reason,
        )
        val moved =
            frames.getValue(700_000_000L).vehicleAccelerationMetresPerSecondSquared
                as DerivedVectorValue.Missing
        assertEquals(DerivedChannelMissingReason.MOUNT_ALIGNMENT_UNAVAILABLE, moved.unavailable.reason)
        assertEquals(
            VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED,
            moved.unavailable.mountUnavailableReason,
        )
        assertEquals(
            moved.unavailable,
            (frames.getValue(700_000_000L).vehicleJerkMetresPerSecondCubed
                    as DerivedVectorValue.Missing)
                .unavailable,
        )
    }

    @Test
    fun `interpolation calibration and mount degradation propagate explicitly`() {
        val points =
            (0L..3L).map { index ->
                ImuPoint(
                    timeNanos = index * 200_000_000L,
                    accelerationDevice = FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                    gyroscopeDevice = FrameVector3(0.0, 0.0, 0.0),
                )
            }
        val calibration = calibration(degraded = true)
        val contexts =
            DerivedMotionContextTimeline.fixed(
                calibrationResult = calibration,
                mountAlignment = mount(calibration, degraded = true),
            )
        val final =
            derived(
                points = points,
                gnss = emptyList(),
                calibration = calibration,
                contexts = contexts,
                interpolationGapNanos = 200_000_000L,
            ).frames().last()
        val acceleration =
            final.vehicleAccelerationMetresPerSecondSquared as DerivedVectorValue.Available

        assertEquals(DerivedChannelQuality.DEGRADED, acceleration.quality)
        assertTrue(DerivedChannelEvidence.IMU_INTERPOLATED in acceleration.evidence)
        assertTrue(DerivedChannelEvidence.CALIBRATION_DEGRADED in acceleration.evidence)
        assertTrue(DerivedChannelEvidence.MOUNT_ALIGNMENT_DEGRADED in acceleration.evidence)
        assertEquals(setOf(ImuAlignment.EXACT, ImuAlignment.INTERPOLATED), acceleration.provenance.imuAlignments)
        assertEquals(ImuCalibrationState.CALIBRATED_DEGRADED, acceleration.provenance.calibrationState)
        assertTrue(ImuCalibrationEvidence.SENSOR_UNRELIABLE in acceleration.provenance.calibrationEvidence)
        assertEquals(VehicleMountAlignmentQuality.DEGRADED, acceleration.provenance.mountAlignmentQuality)
    }

    @Test
    fun `builder rejects timeline mismatch and derived gap below analysis cadence`() {
        val points = stationaryPoints(durationSeconds = 1)
        val rawGnss = listOf(gnssSample(0L, 0.0f, 0.0f))
        val source = sourcePipeline(points, rawGnss)
        val calibration = calibration()
        val contexts = DerivedMotionContextTimeline.fixed(calibration, mount(calibration))
        val tooSmallGap =
            DerivedTelemetryPipeline.build(
                sourceTimeline = source.timeline,
                gnssSummary = source.gnss,
                motionContexts = contexts,
                config = DerivedTelemetryConfig(maximumContinuousImuGapNanos = 50_000_000L),
            ) as DerivedTelemetryBuildResult.Invalid
        assertEquals("derived_imu_gap_below_timeline_interval", tooSmallGap.errorCode)

        val changedRaw = source.gnss.samples.single().rawSample.copy(bearingDegrees = 90.0f)
        val mismatched =
            source.gnss.copy(
                samples = listOf(source.gnss.samples.single().copy(rawSample = changedRaw)),
            )
        val mismatch =
            DerivedTelemetryPipeline.build(
                sourceTimeline = source.timeline,
                gnssSummary = mismatched,
                motionContexts = contexts,
                config = fastFilterConfig(),
            ) as DerivedTelemetryBuildResult.Invalid
        assertEquals("derived_gnss_summary_trip_mismatch", mismatch.errorCode)
        assertEquals(0, mismatch.sampleIndex)
    }

    @Test
    fun `derived timeline is repeatable lazy and defaults are versioned`() {
        val config = DerivedTelemetryConfig()
        assertEquals(DERIVED_TELEMETRY_VERSION, config.derivedVersion)
        assertEquals(3, config.imuMedianWindowSize)
        assertEquals(3, config.gnssMedianWindowSize)
        assertEquals(7, config.jerkSlopeWindowSize)
        assertEquals(1.5, config.movingEnterSpeedMetresPerSecond, 0.0)
        assertEquals(0.5, config.stoppedEnterSpeedMetresPerSecond, 0.0)

        val timeline =
            derived(
                points = stationaryPoints(durationSeconds = 1),
                gnss = emptyList(),
            )
        val first = timeline.frames().toList()
        val second = timeline.frames().toList()
        assertEquals(timeline.frameCount, first.size.toLong())
        assertEquals(first, second)
    }

    private fun derived(
        points: List<ImuPoint>,
        gnss: List<RawGnssSample>,
        calibration: ImuStationaryCalibrationResult = calibration(),
        contexts: DerivedMotionContextTimeline =
            DerivedMotionContextTimeline.fixed(calibration, mount(calibration)),
        config: DerivedTelemetryConfig = fastFilterConfig(),
        interpolationGapNanos: Long = TEST_INTERVAL_NANOS,
    ): DerivedTelemetryTimeline {
        val source = sourcePipeline(points, gnss, interpolationGapNanos)
        return (
            DerivedTelemetryPipeline.build(
                sourceTimeline = source.timeline,
                gnssSummary = source.gnss,
                motionContexts = contexts,
                config = config,
            ) as DerivedTelemetryBuildResult.Success
        ).timeline
    }

    private fun sourcePipeline(
        points: List<ImuPoint>,
        gnss: List<RawGnssSample>,
        interpolationGapNanos: Long = TEST_INTERVAL_NANOS,
    ): SourcePipeline {
        val records = buildList {
            points.forEach { point ->
                add(imuRecord(ImuSensorType.ACCELEROMETER, point.timeNanos, point.accelerationDevice))
                add(imuRecord(ImuSensorType.GYROSCOPE, point.timeNanos, point.gyroscopeDevice))
            }
            gnss.forEach { add(TelemetrySampleRecord.Gnss(it)) }
        }
        val trip = decodeTrip(encode(records))
        val timeline =
            (AnalysisTimelineResampler.build(
                trip,
                AnalysisTimelineConfig(
                    intervalNanos = TEST_INTERVAL_NANOS,
                    maxImuInterpolationGapNanos = interpolationGapNanos,
                ),
            ) as AnalysisTimelineBuildResult.Success).timeline
        val summary =
            (GnssSanityFilter.process(trip) as GnssProcessingResult.Success).summary
        return SourcePipeline(timeline, summary)
    }

    private fun stationaryPoints(durationSeconds: Int): List<ImuPoint> =
        (0L..durationSeconds * 10L).map { index ->
            ImuPoint(
                timeNanos = index * TEST_INTERVAL_NANOS,
                accelerationDevice = FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                gyroscopeDevice = FrameVector3(0.0, 0.0, 0.0),
            )
        }

    private fun calibration(
        gyroscopeBias: FrameVector3 = FrameVector3(0.0, 0.0, 0.0),
        degraded: Boolean = false,
    ): ImuStationaryCalibrationResult =
        ImuStationaryCalibrationResult(
            state =
                if (degraded) {
                    ImuCalibrationState.CALIBRATED_DEGRADED
                } else {
                    ImuCalibrationState.CALIBRATED
                },
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
                    gyroscopeBiasDeviceRadiansPerSecond =
                        CalibrationVector3(gyroscopeBias.x, gyroscopeBias.y, gyroscopeBias.z),
                    accelerometerAxisStandardDeviationMetresPerSecondSquared =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    gyroscopeAxisStandardDeviationRadiansPerSecond =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    accelerometerMinimumAccuracyStatus = if (degraded) 0 else 3,
                    gyroscopeMinimumAccuracyStatus = 3,
                    accelerometerInterpolatedFrameCount = 0,
                    gyroscopeInterpolatedFrameCount = 0,
                    rawQualityFlags =
                        if (degraded) {
                            setOf(ImuQualityFlag.SENSOR_UNRELIABLE)
                        } else {
                            emptySet()
                        },
                ),
            evidence =
                if (degraded) {
                    setOf(ImuCalibrationEvidence.SENSOR_UNRELIABLE)
                } else {
                    emptySet()
                },
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
        degraded: Boolean = false,
    ): VehicleMountAlignmentResolution {
        val source = requireNotNull(calibration.calibration)
        val evidence = buildSet {
            add(VehicleMountAlignmentEvidence.EXPLICIT_DEVICE_FORWARD_HINT)
            if (degraded) add(VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_NOT_EVALUATED)
        }
        return VehicleMountAlignmentResolution.Available(
            VehicleMountAlignment(
                quality =
                    if (degraded) {
                        VehicleMountAlignmentQuality.DEGRADED
                    } else {
                        VehicleMountAlignmentQuality.RESOLVED
                    },
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
                evidence = evidence,
            ),
        )
    }

    private fun fastFilterConfig(): DerivedTelemetryConfig =
        DerivedTelemetryConfig(
            accelerationFilterTimeConstantNanos = 1L,
            yawRateFilterTimeConstantNanos = 1L,
            speedFilterTimeConstantNanos = 1L,
            headingRateFilterTimeConstantNanos = 1L,
            maximumContinuousImuGapNanos = TEST_INTERVAL_NANOS,
        )

    private fun gnssSample(
        timeNanos: Long,
        speedMetresPerSecond: Float,
        bearingDegrees: Float,
    ): RawGnssSample =
        testGnssSample(
            tripElapsedNanos = timeNanos,
            sourceTimestampNanos = SOURCE_TIME_OFFSET_NANOS + timeNanos,
        ).copy(
            speedMetresPerSecond = speedMetresPerSecond,
            speedAccuracyMetresPerSecond = 0.1f,
            bearingDegrees = bearingDegrees,
            bearingAccuracyDegrees = 1.0f,
        )

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

    private fun assertScalar(
        expected: Double,
        actual: DerivedScalarValue,
        tolerance: Double = 1e-5,
    ) {
        assertEquals(expected, (actual as DerivedScalarValue.Available).value, tolerance)
    }

    private fun assertVector(
        expected: FrameVector3,
        actual: DerivedVectorValue,
        tolerance: Double = 1e-5,
    ) {
        val value = (actual as DerivedVectorValue.Available).value
        assertEquals(expected.x, value.x, tolerance)
        assertEquals(expected.y, value.y, tolerance)
        assertEquals(expected.z, value.z, tolerance)
    }

    private data class ImuPoint(
        val timeNanos: Long,
        val accelerationDevice: FrameVector3,
        val gyroscopeDevice: FrameVector3,
    )

    private data class SourcePipeline(
        val timeline: AnalysisTimeline,
        val gnss: GnssProcessingSummary,
    )

    private companion object {
        const val TEST_INTERVAL_NANOS = 100_000_000L
        const val SECOND_NANOS = 1_000_000_000L
        const val SOURCE_TIME_OFFSET_NANOS = 10_000_000_000L
        const val NANOS_PER_SECOND = 1_000_000_000.0
    }
}
