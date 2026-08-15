package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
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

class TelemetryConfidencePipelineTest {
    @Test
    fun `supported sources produce eligible channels and corroborated motion`() {
        val points = movingPoints(durationSeconds = 5, yawRateRadiansPerSecond = PI / 180.0)
        val gnss =
            (0L..5L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 5.0f,
                    bearingDegrees = seconds.toFloat(),
                )
            }
        val final = confidence(derived(points, gnss)).frames().last()

        assertEquals(TelemetryConfidenceState.SUPPORTED, final.components.gnss.assessment.state)
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.accelerometer.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.gyroscope.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.calibration.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.orientation.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.deviceMovement.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.sourceAgreement.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            final.components.clockIntegrity.assessment.state,
        )
        TelemetryMetric.entries.forEach { metric ->
            assertEquals(metric, final.eligibility[metric].metric)
            assertEquals(TelemetryEligibility.ELIGIBLE, final.eligibility[metric].eligibility)
        }
    }

    @Test
    fun `accepted but imprecise GNSS degrades only GNSS-backed eligibility`() {
        val gnss =
            (0L..5L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 5.0f,
                    bearingDegrees = seconds.toFloat(),
                    horizontalAccuracyMetres = 30.0f,
                )
            }
        val final = confidence(derived(movingPoints(5, PI / 180.0), gnss)).frames().last()

        assertEquals(TelemetryConfidenceState.DEGRADED, final.components.gnss.assessment.state)
        assertTrue(
            TelemetryConfidenceReason.GNSS_HORIZONTAL_ACCURACY_REDUCED in
                final.components.gnss.assessment.reasons,
        )
        assertEquals(TelemetryEligibility.LIMITED, final.eligibility.filteredSpeed.eligibility)
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            final.eligibility.vehicleAcceleration.eligibility,
        )
        assertEquals(TelemetryEligibility.ELIGIBLE, final.eligibility.yawRate.eligibility)
        assertEquals(
            setOf(TelemetryConfidenceComponentKind.GNSS),
            final.eligibility.filteredSpeed.limitingComponents,
        )
    }

    @Test
    fun `hard GNSS rejection excludes GNSS metrics while IMU metrics remain eligible`() {
        val gnss =
            (0L..5L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 5.0f,
                    bearingDegrees = seconds.toFloat(),
                    horizontalAccuracyMetres = 80.0f,
                )
            }
        val final = confidence(derived(movingPoints(5, PI / 180.0), gnss)).frames().last()

        assertEquals(TelemetryConfidenceState.INVALIDATED, final.components.gnss.assessment.state)
        assertEquals(GnssDecision.EXCLUDED_LOW_ACCURACY, final.components.gnss.decision)
        assertEquals(TelemetryEligibility.EXCLUDED, final.eligibility.filteredSpeed.eligibility)
        assertEquals(
            DerivedChannelMissingReason.GNSS_SOURCE_REJECTED,
            final.eligibility.filteredSpeed.sourceMissingReason,
        )
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            final.eligibility.vehicleAcceleration.eligibility,
        )
        assertEquals(TelemetryEligibility.ELIGIBLE, final.eligibility.yawRate.eligibility)
    }

    @Test
    fun `stale GNSS remains auditable and excludes held motion state`() {
        val gnss =
            (0L..3L).map { seconds ->
                gnssSample(
                    timeNanos = seconds * SECOND_NANOS,
                    speedMetresPerSecond = 5.0f,
                    bearingDegrees = seconds.toFloat(),
                )
            }
        val final = confidence(derived(movingPoints(7, PI / 180.0), gnss)).frames().last()

        assertEquals(TelemetryConfidenceState.UNAVAILABLE, final.components.gnss.assessment.state)
        assertEquals(4L * SECOND_NANOS, final.components.gnss.sourceAgeNanos)
        assertTrue(
            TelemetryConfidenceReason.GNSS_SOURCE_STALE in
                final.components.gnss.assessment.reasons,
        )
        assertEquals(TelemetryEligibility.EXCLUDED, final.eligibility.filteredSpeed.eligibility)
        assertEquals(TelemetryEligibility.EXCLUDED, final.eligibility.movementState.eligibility)
        assertEquals(MovementState.UNKNOWN, derived(movingPoints(7, PI / 180.0), gnss).frames().last().movementState.state)
    }

    @Test
    fun `oversized IMU interpolation gap invalidates only affected inertial evidence`() {
        val points =
            movingPoints(5, PI / 180.0).filterNot {
                it.timeNanos == TEST_INTERVAL_NANOS
            }
        val frame =
            confidence(derived(points, movingGnss())).frames()
                .first { it.tripElapsedNanos == TEST_INTERVAL_NANOS }

        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            frame.components.accelerometer.assessment.state,
        )
        assertEquals(
            ImuMissingReason.INTERPOLATION_GAP_TOO_LARGE,
            frame.components.accelerometer.missingReason,
        )
        assertTrue(
            TelemetryConfidenceReason.IMU_INTERPOLATION_GAP_TOO_LARGE in
                frame.components.accelerometer.assessment.reasons,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            frame.eligibility.vehicleAcceleration.eligibility,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            frame.eligibility.filteredSpeed.eligibility,
        )
        assertEquals(
            setOf(TelemetryConfidenceComponentKind.ACCELEROMETER),
            frame.eligibility.vehicleAcceleration.limitingComponents,
        )
    }

    @Test
    fun `unreliable IMU and degraded calibration limit inertial metrics without constants`() {
        val calibration = calibration(degraded = true)
        val points =
            movingPoints(5, PI / 180.0).map {
                it.copy(
                    accelerometerAccuracyStatus = 0,
                    accelerometerFlags = setOf(ImuQualityFlag.SENSOR_UNRELIABLE),
                )
            }
        val final =
            confidence(
                derived(
                    points = points,
                    gnss = movingGnss(),
                    calibration = calibration,
                    contexts =
                        DerivedMotionContextTimeline.fixed(
                            calibration,
                            mount(calibration),
                        ),
                ),
            ).frames().last()

        assertEquals(
            TelemetryConfidenceState.DEGRADED,
            final.components.accelerometer.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.DEGRADED,
            final.components.calibration.assessment.state,
        )
        assertTrue(
            TelemetryConfidenceReason.IMU_SENSOR_UNRELIABLE in
                final.components.accelerometer.assessment.reasons,
        )
        assertEquals(
            TelemetryEligibility.LIMITED,
            final.eligibility.vehicleAcceleration.eligibility,
        )
        assertEquals(TelemetryEligibility.LIMITED, final.eligibility.yawRate.eligibility)
        assertTrue(
            TelemetryConfidenceComponentKind.CALIBRATION in
                final.eligibility.yawRate.limitingComponents,
        )
    }

    @Test
    fun `missing calibration and invalidated orientation exclude only dependent channels`() {
        val insufficient = insufficientCalibration()
        val missingContext =
            DerivedMotionContextTimeline.fixed(
                insufficient,
                VehicleMountAlignmentResolution.Unavailable(
                    VehicleMountAlignmentUnavailableReason.FORWARD_HINT_PARALLEL_TO_UP,
                ),
            )
        val missingFinal =
            confidence(
                derived(
                    points = movingPoints(5, PI / 180.0),
                    gnss = movingGnss(),
                    calibration = insufficient,
                    contexts = missingContext,
                ),
            ).frames().last()
        assertEquals(
            TelemetryConfidenceState.UNAVAILABLE,
            missingFinal.components.calibration.assessment.state,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            missingFinal.eligibility.vehicleAcceleration.eligibility,
        )
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            missingFinal.eligibility.filteredSpeed.eligibility,
        )

        val calibration = calibration()
        val invalidatedContext =
            DerivedMotionContextTimeline.fixed(
                calibration,
                VehicleMountAlignmentResolution.Unavailable(
                    VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED,
                ),
            )
        val invalidatedFinal =
            confidence(
                derived(
                    points = movingPoints(5, PI / 180.0),
                    gnss = movingGnss(),
                    calibration = calibration,
                    contexts = invalidatedContext,
                ),
            ).frames().last()
        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            invalidatedFinal.components.orientation.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            invalidatedFinal.components.deviceMovement.assessment.state,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            invalidatedFinal.eligibility.yawRate.eligibility,
        )
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            invalidatedFinal.eligibility.filteredSpeed.eligibility,
        )
    }

    @Test
    fun `unevaluated device movement is explicit and limits vehicle-frame metrics`() {
        val calibration = calibration()
        val contexts =
            DerivedMotionContextTimeline.fixed(
                calibration,
                mount(calibration, degraded = true),
            )
        val final =
            confidence(
                derived(
                    points = movingPoints(5, PI / 180.0),
                    gnss = movingGnss(),
                    calibration = calibration,
                    contexts = contexts,
                ),
            ).frames().last()

        assertEquals(
            TelemetryConfidenceState.DEGRADED,
            final.components.orientation.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.DEGRADED,
            final.components.deviceMovement.assessment.state,
        )
        assertTrue(
            TelemetryConfidenceReason.DEVICE_MOVEMENT_NOT_EVALUATED in
                final.components.deviceMovement.assessment.reasons,
        )
        assertEquals(
            TelemetryEligibility.LIMITED,
            final.eligibility.vehicleAcceleration.eligibility,
        )
        assertEquals(TelemetryEligibility.ELIGIBLE, final.eligibility.filteredSpeed.eligibility)

        val degradedEvidenceContext =
            DerivedMotionContextTimeline.fixed(
                calibration,
                mount(
                    calibration = calibration,
                    degraded = true,
                    movementEvidence =
                        VehicleMountAlignmentEvidence.SUBSEQUENT_CALIBRATION_DEGRADED,
                ),
            )
        val degradedEvidenceFinal =
            confidence(
                derived(
                    points = movingPoints(5, PI / 180.0),
                    gnss = movingGnss(),
                    calibration = calibration,
                    contexts = degradedEvidenceContext,
                ),
            ).frames().last()
        assertTrue(
            TelemetryConfidenceReason.DEVICE_MOVEMENT_EVIDENCE_DEGRADED in
                degradedEvidenceFinal.components.deviceMovement.assessment.reasons,
        )
    }

    @Test
    fun `partial clock discontinuity preserves healthy IMU eligibility`() {
        val gnss =
            movingGnss().mapIndexed { index, sample ->
                if (index == 5) {
                    sample.copy(
                        qualityFlags = setOf(GnssQualityFlag.CLOCK_DISCONTINUITY),
                    )
                } else {
                    sample
                }
            }
        val final = confidence(derived(movingPoints(5, PI / 180.0), gnss)).frames().last()

        assertEquals(
            TelemetryConfidenceState.DEGRADED,
            final.components.clockIntegrity.assessment.state,
        )
        assertEquals(
            setOf(TelemetryClockSource.GNSS),
            final.components.clockIntegrity.discontinuousSources,
        )
        assertEquals(TelemetryConfidenceState.INVALIDATED, final.components.gnss.assessment.state)
        assertEquals(TelemetryEligibility.EXCLUDED, final.eligibility.filteredSpeed.eligibility)
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            final.eligibility.vehicleAcceleration.eligibility,
        )
    }

    @Test
    fun `source disagreement excludes corroboration but not individual measurements`() {
        val final =
            confidence(
                derived(
                    points = movingPoints(5, yawRateRadiansPerSecond = 1.0),
                    gnss = movingGnss(bearingStepDegrees = 0.0f),
                ),
            ).frames().last()

        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            final.components.sourceAgreement.assessment.state,
        )
        assertTrue(
            requireNotNull(
                final.components.sourceAgreement
                    .absoluteYawHeadingRateDifferenceRadiansPerSecond,
            ) > 0.9,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            final.eligibility.corroboratedVehicleMotion.eligibility,
        )
        assertEquals(TelemetryEligibility.ELIGIBLE, final.eligibility.yawRate.eligibility)
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            final.eligibility.headingChangeRate.eligibility,
        )
    }

    @Test
    fun `confidence timeline is repeatable lazy and configuration is versioned`() {
        val timeline = confidence(derived(movingPoints(5, PI / 180.0), movingGnss()))
        val first = timeline.frames().toList()
        val second = timeline.frames().toList()

        assertEquals(timeline.frameCount, first.size.toLong())
        assertEquals(first, second)
        assertEquals(TELEMETRY_CONFIDENCE_VERSION, timeline.config.confidenceVersion)
        assertEquals(
            DEFAULT_PREFERRED_GNSS_HORIZONTAL_ACCURACY_METRES,
            timeline.config.preferredGnssHorizontalAccuracyMetres,
            0.0,
        )
        assertTrue(
            runCatching {
                TelemetryConfidenceConfig(
                    maximumYawHeadingRateDifferenceRadiansPerSecond = -1.0,
                )
            }.isFailure,
        )
        assertEquals(0L, first.first().components.gnss.sourceTripElapsedNanos)
        assertEquals(
            TelemetryConfidenceState.DEGRADED,
            first.first().components.gnss.assessment.state,
        )
    }

    private fun confidence(
        source: DerivedTelemetryTimeline,
        config: TelemetryConfidenceConfig = TelemetryConfidenceConfig(),
    ): TelemetryConfidenceTimeline = TelemetryConfidencePipeline.build(source, config)

    private fun derived(
        points: List<ImuPoint>,
        gnss: List<RawGnssSample>,
        calibration: ImuStationaryCalibrationResult = calibration(),
        contexts: DerivedMotionContextTimeline =
            DerivedMotionContextTimeline.fixed(calibration, mount(calibration)),
    ): DerivedTelemetryTimeline {
        val records = buildList {
            points.forEach { point ->
                add(
                    imuRecord(
                        sensorType = ImuSensorType.ACCELEROMETER,
                        timeNanos = point.timeNanos,
                        value = point.accelerationDevice,
                        accuracyStatus = point.accelerometerAccuracyStatus,
                        qualityFlags = point.accelerometerFlags,
                    ),
                )
                add(
                    imuRecord(
                        sensorType = ImuSensorType.GYROSCOPE,
                        timeNanos = point.timeNanos,
                        value = point.gyroscopeDevice,
                        accuracyStatus = point.gyroscopeAccuracyStatus,
                        qualityFlags = point.gyroscopeFlags,
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
        return (
            DerivedTelemetryPipeline.build(
                sourceTimeline = analysis,
                gnssSummary = gnssSummary,
                motionContexts = contexts,
                config = fastFilterConfig(),
            ) as DerivedTelemetryBuildResult.Success
        ).timeline
    }

    private fun movingPoints(
        durationSeconds: Int,
        yawRateRadiansPerSecond: Double,
    ): List<ImuPoint> =
        (0L..durationSeconds * 10L).map { index ->
            ImuPoint(
                timeNanos = index * TEST_INTERVAL_NANOS,
                accelerationDevice =
                    FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                gyroscopeDevice = FrameVector3(0.0, 0.0, yawRateRadiansPerSecond),
            )
        }

    private fun movingGnss(
        bearingStepDegrees: Float = 1.0f,
    ): List<RawGnssSample> =
        (0L..5L).map { seconds ->
            gnssSample(
                timeNanos = seconds * SECOND_NANOS,
                speedMetresPerSecond = 5.0f,
                bearingDegrees = seconds * bearingStepDegrees,
            )
        }

    private fun calibration(degraded: Boolean = false): ImuStationaryCalibrationResult =
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
                    gyroscopeBiasDeviceRadiansPerSecond = CalibrationVector3(0.0, 0.0, 0.0),
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
            diagnostics = diagnostics(),
        )

    private fun insufficientCalibration(): ImuStationaryCalibrationResult =
        ImuStationaryCalibrationResult(
            state = ImuCalibrationState.INSUFFICIENT_EVIDENCE,
            config = ImuStationaryCalibrationConfig(),
            calibration = null,
            evidence = setOf(ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION),
            diagnostics = diagnostics(),
        )

    private fun diagnostics(): ImuCalibrationDiagnostics =
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
        )

    private fun mount(
        calibration: ImuStationaryCalibrationResult,
        degraded: Boolean = false,
        movementEvidence: VehicleMountAlignmentEvidence =
            VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_NOT_EVALUATED,
    ): VehicleMountAlignmentResolution {
        val source = requireNotNull(calibration.calibration)
        val evidence = buildSet {
            add(VehicleMountAlignmentEvidence.EXPLICIT_DEVICE_FORWARD_HINT)
            if (degraded) {
                add(movementEvidence)
            }
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
        horizontalAccuracyMetres: Float = 5.0f,
    ): RawGnssSample =
        testGnssSample(
            tripElapsedNanos = timeNanos,
            sourceTimestampNanos = SOURCE_TIME_OFFSET_NANOS + timeNanos,
        ).copy(
            horizontalAccuracyMetres = horizontalAccuracyMetres,
            speedMetresPerSecond = speedMetresPerSecond,
            speedAccuracyMetresPerSecond = 0.1f,
            bearingDegrees = bearingDegrees,
            bearingAccuracyDegrees = 1.0f,
        )

    private fun imuRecord(
        sensorType: ImuSensorType,
        timeNanos: Long,
        value: FrameVector3,
        accuracyStatus: Int,
        qualityFlags: Set<ImuQualityFlag>,
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
                accuracyStatus = accuracyStatus,
                qualityFlags = qualityFlags,
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
        val accelerometerAccuracyStatus: Int = 3,
        val gyroscopeAccuracyStatus: Int = 3,
        val accelerometerFlags: Set<ImuQualityFlag> = emptySet(),
        val gyroscopeFlags: Set<ImuQualityFlag> = emptySet(),
    )

    private companion object {
        const val TEST_INTERVAL_NANOS = 100_000_000L
        const val SECOND_NANOS = 1_000_000_000L
        const val SOURCE_TIME_OFFSET_NANOS = 10_000_000_000L
    }
}
