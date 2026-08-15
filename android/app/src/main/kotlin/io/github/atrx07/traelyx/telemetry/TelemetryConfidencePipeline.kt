package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import kotlin.math.abs

class TelemetryConfidenceTimeline internal constructor(
    val sourceTimeline: DerivedTelemetryTimeline,
    val config: TelemetryConfidenceConfig,
) {
    val frameCount: Long
        get() = sourceTimeline.frameCount

    /** Returns a fresh bounded-memory confidence processor on every call. */
    fun frames(): Sequence<TelemetryConfidenceFrame> = sequence {
        val sourceFrames = sourceTimeline.sourceTimeline.frames().iterator()
        val derivedFrames = sourceTimeline.frames().iterator()
        val processor =
            TelemetryConfidenceFrameProcessor(
                gnssSamples = sourceTimeline.gnssSummary.samples,
                motionContexts = sourceTimeline.motionContexts.segments,
                maximumGnssSourceAgeNanos =
                    sourceTimeline.config.maximumGnssSourceAgeNanos,
                config = config,
            )
        while (sourceFrames.hasNext() && derivedFrames.hasNext()) {
            val source = sourceFrames.next()
            val derived = derivedFrames.next()
            check(source.tripElapsedNanos == derived.tripElapsedNanos)
            yield(processor.process(source, derived))
        }
        check(!sourceFrames.hasNext() && !derivedFrames.hasNext())
    }
}

object TelemetryConfidencePipeline {
    fun build(
        sourceTimeline: DerivedTelemetryTimeline,
        config: TelemetryConfidenceConfig = TelemetryConfidenceConfig(),
    ): TelemetryConfidenceTimeline =
        TelemetryConfidenceTimeline(
            sourceTimeline = sourceTimeline,
            config = config,
        )
}

private class TelemetryConfidenceFrameProcessor(
    gnssSamples: List<ProcessedGnssSample>,
    motionContexts: List<DerivedMotionContextSegment>,
    private val maximumGnssSourceAgeNanos: Long,
    private val config: TelemetryConfidenceConfig,
) {
    private val gnssCursor = ConfidenceGnssCursor(gnssSamples)
    private val contextCursor = ConfidenceContextCursor(motionContexts)

    fun process(
        source: AnalysisTimelineFrame,
        derived: DerivedTelemetryFrame,
    ): TelemetryConfidenceFrame {
        val target = source.tripElapsedNanos
        val latestGnss = gnssCursor.latestThrough(target)
        val gnss = gnssConfidence(target, latestGnss)
        val accelerometer =
            imuConfidence(
                component = TelemetryConfidenceComponentKind.ACCELEROMETER,
                source = source.accelerometerDeviceMetresPerSecondSquared,
            )
        val gyroscope =
            imuConfidence(
                component = TelemetryConfidenceComponentKind.GYROSCOPE,
                source = source.gyroscopeDeviceRadiansPerSecond,
            )
        val context = contextConfidence(contextCursor.at(target), target)
        val clock = clockConfidence(accelerometer, gyroscope, gnss)
        val sourceAgreement = sourceAgreement(target, derived)
        val components =
            TelemetryConfidenceComponents(
                gnss = gnss,
                accelerometer = accelerometer,
                gyroscope = gyroscope,
                calibration = context.calibration,
                orientation = context.orientation,
                sourceAgreement = sourceAgreement,
                deviceMovement = context.deviceMovement,
                clockIntegrity = clock,
            )
        return TelemetryConfidenceFrame(
            tripElapsedNanos = target,
            components = components,
            eligibility = eligibility(derived, components),
        )
    }

    private fun gnssConfidence(
        target: Long,
        sample: ProcessedGnssSample?,
    ): GnssTelemetryConfidence {
        if (sample == null) {
            return GnssTelemetryConfidence(
                assessment =
                    assessment(
                        TelemetryConfidenceState.UNAVAILABLE,
                        TelemetryConfidenceReason.GNSS_SOURCE_UNAVAILABLE,
                    ),
                sourceTripElapsedNanos = null,
                sourceAgeNanos = null,
                horizontalAccuracyMetres = null,
                speedAccuracyMetresPerSecond = null,
                bearingAccuracyDegrees = null,
                decision = null,
                processingEvidence = emptySet(),
                rawQualityFlags = emptySet(),
            )
        }
        val raw = sample.rawSample
        val sourceTime = requireNotNull(raw.tripElapsedNanos)
        val age = target - sourceTime
        val reasons = mutableSetOf<TelemetryConfidenceReason>()
        val state =
            when {
                age > maximumGnssSourceAgeNanos -> {
                    reasons += TelemetryConfidenceReason.GNSS_SOURCE_STALE
                    TelemetryConfidenceState.UNAVAILABLE
                }
                sample.decision == GnssDecision.EXCLUDED_CLOCK_DISCONTINUITY -> {
                    reasons += TelemetryConfidenceReason.CLOCK_DISCONTINUITY
                    TelemetryConfidenceState.INVALIDATED
                }
                sample.decision == GnssDecision.EXCLUDED_LOW_ACCURACY -> {
                    reasons += TelemetryConfidenceReason.GNSS_LOW_ACCURACY
                    TelemetryConfidenceState.INVALIDATED
                }
                sample.decision == GnssDecision.EXCLUDED_IMPOSSIBLE_JUMP -> {
                    reasons += TelemetryConfidenceReason.GNSS_IMPOSSIBLE_JUMP
                    TelemetryConfidenceState.INVALIDATED
                }
                else -> {
                    if (sample.decision == GnssDecision.ACCEPTED_ANCHOR) {
                        reasons += TelemetryConfidenceReason.GNSS_ANCHOR_ONLY
                    }
                    if (sample.decision == GnssDecision.RESET_AFTER_GAP) {
                        reasons += TelemetryConfidenceReason.GNSS_GAP
                    }
                    if (
                        sample.decision == GnssDecision.EXCLUDED_STATIONARY_JITTER ||
                        sample.decision ==
                        GnssDecision.EXCLUDED_UNRESOLVED_WITHIN_ACCURACY
                    ) {
                        reasons +=
                            TelemetryConfidenceReason.GNSS_STATIONARY_OR_UNRESOLVED
                    }
                    if (
                        raw.horizontalAccuracyMetres.toDouble() >
                        config.preferredGnssHorizontalAccuracyMetres
                    ) {
                        reasons +=
                            TelemetryConfidenceReason.GNSS_HORIZONTAL_ACCURACY_REDUCED
                    }
                    if (
                        GnssProcessingEvidence.SEGMENT_GAP in sample.evidence
                    ) {
                        reasons += TelemetryConfidenceReason.GNSS_GAP
                    }
                    if (
                        GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE in sample.evidence
                    ) {
                        reasons += TelemetryConfidenceReason.GNSS_SOURCE_SPEED_IMPLAUSIBLE
                    }
                    if (
                        raw.isMockSignal ||
                        GnssQualityFlag.MOCK_LOCATION_SIGNAL in raw.qualityFlags ||
                        GnssProcessingEvidence.RAW_MOCK_LOCATION_SIGNAL in sample.evidence
                    ) {
                        reasons += TelemetryConfidenceReason.GNSS_MOCK_LOCATION
                    }
                    if (reasons.isEmpty()) {
                        reasons += TelemetryConfidenceReason.GNSS_SUPPORTED
                        TelemetryConfidenceState.SUPPORTED
                    } else {
                        TelemetryConfidenceState.DEGRADED
                    }
                }
            }
        return GnssTelemetryConfidence(
            assessment = TelemetryConfidenceAssessment(state, reasons),
            sourceTripElapsedNanos = sourceTime,
            sourceAgeNanos = age,
            horizontalAccuracyMetres = raw.horizontalAccuracyMetres.toDouble(),
            speedAccuracyMetresPerSecond = raw.speedAccuracyMetresPerSecond?.toDouble(),
            bearingAccuracyDegrees = raw.bearingAccuracyDegrees?.toDouble(),
            decision = sample.decision,
            processingEvidence = sample.evidence,
            rawQualityFlags = raw.qualityFlags,
        )
    }

    private fun imuConfidence(
        component: TelemetryConfidenceComponentKind,
        source: ResampledImuValue,
    ): ImuTelemetryConfidence {
        if (source is ResampledImuValue.Missing) {
            val (state, reason) =
                when (source.reason) {
                    ImuMissingReason.SOURCE_DISCONTINUITY ->
                        TelemetryConfidenceState.INVALIDATED to
                            TelemetryConfidenceReason.IMU_SOURCE_DISCONTINUITY
                    ImuMissingReason.INTERPOLATION_GAP_TOO_LARGE ->
                        TelemetryConfidenceState.INVALIDATED to
                            TelemetryConfidenceReason.IMU_INTERPOLATION_GAP_TOO_LARGE
                    ImuMissingReason.CHANNEL_UNAVAILABLE,
                    ImuMissingReason.OUTSIDE_SOURCE_COVERAGE,
                    ->
                        TelemetryConfidenceState.UNAVAILABLE to
                            TelemetryConfidenceReason.IMU_SOURCE_UNAVAILABLE
                }
            return ImuTelemetryConfidence(
                component = component,
                assessment = assessment(state, reason),
                alignment = null,
                lowerTripElapsedNanos = null,
                upperTripElapsedNanos = null,
                lowerSourceTimestampNanos = null,
                upperSourceTimestampNanos = null,
                accuracyStatus = null,
                qualityFlags = emptySet(),
                missingReason = source.reason,
            )
        }
        source as ResampledImuValue.Available
        val reasons = mutableSetOf<TelemetryConfidenceReason>()
        if (source.alignment == ImuAlignment.EXACT) {
            reasons += TelemetryConfidenceReason.IMU_EXACT
        } else {
            reasons += TelemetryConfidenceReason.IMU_INTERPOLATED
        }
        if (ImuQualityFlag.IMU_DROPOUT in source.qualityFlags) {
            reasons += TelemetryConfidenceReason.IMU_DROPOUT
        }
        if (ImuQualityFlag.CLOCK_DISCONTINUITY in source.qualityFlags) {
            reasons += TelemetryConfidenceReason.IMU_CLOCK_DISCONTINUITY
        }
        if (
            source.accuracyStatus <= 0 ||
            ImuQualityFlag.SENSOR_UNRELIABLE in source.qualityFlags
        ) {
            reasons += TelemetryConfidenceReason.IMU_SENSOR_UNRELIABLE
        }
        val state =
            when {
                ImuQualityFlag.CLOCK_DISCONTINUITY in source.qualityFlags ||
                    ImuQualityFlag.IMU_DROPOUT in source.qualityFlags ->
                    TelemetryConfidenceState.INVALIDATED
                source.alignment == ImuAlignment.INTERPOLATED ||
                    source.accuracyStatus <= 0 ||
                    source.qualityFlags.isNotEmpty() ->
                    TelemetryConfidenceState.DEGRADED
                else -> TelemetryConfidenceState.SUPPORTED
            }
        return ImuTelemetryConfidence(
            component = component,
            assessment = TelemetryConfidenceAssessment(state, reasons),
            alignment = source.alignment,
            lowerTripElapsedNanos = source.lowerTripElapsedNanos,
            upperTripElapsedNanos = source.upperTripElapsedNanos,
            lowerSourceTimestampNanos = source.lowerSourceTimestampNanos,
            upperSourceTimestampNanos = source.upperSourceTimestampNanos,
            accuracyStatus = source.accuracyStatus,
            qualityFlags = source.qualityFlags,
            missingReason = null,
        )
    }

    private fun contextConfidence(
        segment: DerivedMotionContextSegment?,
        target: Long,
    ): ContextConfidence {
        if (segment == null) return unavailableContext()
        val result = segment.calibrationResult
        val calibration = result.calibration
        if (calibration == null) {
            return ContextConfidence(
                calibration =
                    CalibrationTelemetryConfidence(
                        assessment =
                            assessment(
                                TelemetryConfidenceState.UNAVAILABLE,
                                TelemetryConfidenceReason.CALIBRATION_UNAVAILABLE,
                            ),
                        state = result.state,
                        sourceStartTripElapsedNanos = null,
                        sourceEndTripElapsedNanos = null,
                        evidence = result.evidence,
                    ),
                orientation = unavailableOrientation(),
                deviceMovement = unavailableDeviceMovement(),
            )
        }
        if (calibration.endTripElapsedNanos > target) {
            return ContextConfidence(
                calibration =
                    CalibrationTelemetryConfidence(
                        assessment =
                            assessment(
                                TelemetryConfidenceState.UNAVAILABLE,
                                TelemetryConfidenceReason.CALIBRATION_AFTER_TARGET,
                            ),
                        state = result.state,
                        sourceStartTripElapsedNanos = calibration.startTripElapsedNanos,
                        sourceEndTripElapsedNanos = calibration.endTripElapsedNanos,
                        evidence = result.evidence,
                    ),
                orientation = unavailableOrientation(),
                deviceMovement = unavailableDeviceMovement(),
            )
        }
        val calibrationConfidence =
            CalibrationTelemetryConfidence(
                assessment =
                    if (result.state == ImuCalibrationState.CALIBRATED_DEGRADED) {
                        assessment(
                            TelemetryConfidenceState.DEGRADED,
                            TelemetryConfidenceReason.CALIBRATION_DEGRADED,
                        )
                    } else {
                        assessment(
                            TelemetryConfidenceState.SUPPORTED,
                            TelemetryConfidenceReason.CALIBRATION_SUPPORTED,
                        )
                    },
                state = result.state,
                sourceStartTripElapsedNanos = calibration.startTripElapsedNanos,
                sourceEndTripElapsedNanos = calibration.endTripElapsedNanos,
                evidence = result.evidence,
            )
        return when (val resolution = segment.mountAlignment) {
            is VehicleMountAlignmentResolution.Unavailable -> {
                val invalidated =
                    resolution.reason ==
                        VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED
                ContextConfidence(
                    calibration = calibrationConfidence,
                    orientation =
                        OrientationTelemetryConfidence(
                            assessment =
                                assessment(
                                    if (invalidated) {
                                        TelemetryConfidenceState.INVALIDATED
                                    } else {
                                        TelemetryConfidenceState.UNAVAILABLE
                                    },
                                    TelemetryConfidenceReason.ORIENTATION_UNAVAILABLE,
                                ),
                            quality = null,
                            evidence = emptySet(),
                            unavailableReason = resolution.reason,
                        ),
                    deviceMovement =
                        DeviceMovementTelemetryConfidence(
                            assessment =
                                assessment(
                                    if (invalidated) {
                                        TelemetryConfidenceState.INVALIDATED
                                    } else {
                                        TelemetryConfidenceState.UNAVAILABLE
                                    },
                                    if (invalidated) {
                                        TelemetryConfidenceReason.DEVICE_MOVEMENT_INVALIDATED
                                    } else {
                                        TelemetryConfidenceReason.DEVICE_MOVEMENT_UNAVAILABLE
                                    },
                                ),
                            mountQuality = null,
                            mountEvidence = emptySet(),
                            mountUnavailableReason = resolution.reason,
                        ),
                )
            }
            is VehicleMountAlignmentResolution.Available -> {
                val mount = resolution.alignment
                if (
                    mount.sourceCalibrationStartTripElapsedNanos !=
                    calibration.startTripElapsedNanos ||
                    mount.sourceCalibrationEndTripElapsedNanos !=
                    calibration.endTripElapsedNanos
                ) {
                    return ContextConfidence(
                        calibration = calibrationConfidence,
                        orientation =
                            OrientationTelemetryConfidence(
                                assessment =
                                    assessment(
                                        TelemetryConfidenceState.INVALIDATED,
                                        TelemetryConfidenceReason.ORIENTATION_REFERENCE_MISMATCH,
                                    ),
                                quality = mount.quality,
                                evidence = mount.evidence,
                                unavailableReason = null,
                            ),
                        deviceMovement = unavailableDeviceMovement(),
                    )
                }
                ContextConfidence(
                    calibration = calibrationConfidence,
                    orientation = orientationConfidence(mount),
                    deviceMovement = deviceMovementConfidence(mount),
                )
            }
        }
    }

    private fun orientationConfidence(
        mount: VehicleMountAlignment,
    ): OrientationTelemetryConfidence =
        OrientationTelemetryConfidence(
            assessment =
                if (mount.quality == VehicleMountAlignmentQuality.DEGRADED) {
                    assessment(
                        TelemetryConfidenceState.DEGRADED,
                        TelemetryConfidenceReason.ORIENTATION_DEGRADED,
                    )
                } else {
                    assessment(
                        TelemetryConfidenceState.SUPPORTED,
                        TelemetryConfidenceReason.ORIENTATION_SUPPORTED,
                    )
                },
            quality = mount.quality,
            evidence = mount.evidence,
            unavailableReason = null,
        )

    private fun deviceMovementConfidence(
        mount: VehicleMountAlignment,
    ): DeviceMovementTelemetryConfidence {
        val reasons = mutableSetOf<TelemetryConfidenceReason>()
        if (
            VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_NOT_EVALUATED in mount.evidence
        ) {
            reasons += TelemetryConfidenceReason.DEVICE_MOVEMENT_NOT_EVALUATED
        }
        if (
            VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_INDETERMINATE in mount.evidence
        ) {
            reasons += TelemetryConfidenceReason.DEVICE_MOVEMENT_INDETERMINATE
        }
        if (
            VehicleMountAlignmentEvidence.SUBSEQUENT_CALIBRATION_DEGRADED in mount.evidence
        ) {
            reasons += TelemetryConfidenceReason.DEVICE_MOVEMENT_EVIDENCE_DEGRADED
        }
        val state =
            if (reasons.isEmpty()) {
                reasons += TelemetryConfidenceReason.DEVICE_MOVEMENT_STABLE
                TelemetryConfidenceState.SUPPORTED
            } else {
                TelemetryConfidenceState.DEGRADED
            }
        return DeviceMovementTelemetryConfidence(
            assessment = TelemetryConfidenceAssessment(state, reasons),
            mountQuality = mount.quality,
            mountEvidence = mount.evidence,
            mountUnavailableReason = null,
        )
    }

    private fun clockConfidence(
        accelerometer: ImuTelemetryConfidence,
        gyroscope: ImuTelemetryConfidence,
        gnss: GnssTelemetryConfidence,
    ): ClockIntegrityTelemetryConfidence {
        val assessed = mutableSetOf<TelemetryClockSource>()
        val discontinuous = mutableSetOf<TelemetryClockSource>()
        assessImuClock(
            accelerometer,
            TelemetryClockSource.ACCELEROMETER,
            assessed,
            discontinuous,
        )
        assessImuClock(
            gyroscope,
            TelemetryClockSource.GYROSCOPE,
            assessed,
            discontinuous,
        )
        if (
            gnss.sourceTripElapsedNanos != null &&
            TelemetryConfidenceReason.GNSS_SOURCE_STALE !in gnss.assessment.reasons
        ) {
            assessed += TelemetryClockSource.GNSS
            if (
                gnss.decision == GnssDecision.EXCLUDED_CLOCK_DISCONTINUITY ||
                GnssQualityFlag.CLOCK_DISCONTINUITY in gnss.rawQualityFlags ||
                GnssProcessingEvidence.RAW_CLOCK_DISCONTINUITY in gnss.processingEvidence
            ) {
                discontinuous += TelemetryClockSource.GNSS
            }
        }
        val assessment =
            when {
                assessed.isEmpty() ->
                    assessment(
                        TelemetryConfidenceState.UNAVAILABLE,
                        TelemetryConfidenceReason.CLOCK_NOT_ASSESSED,
                    )
                discontinuous.isEmpty() ->
                    assessment(
                        TelemetryConfidenceState.SUPPORTED,
                        TelemetryConfidenceReason.CLOCK_SUPPORTED,
                    )
                discontinuous.size == assessed.size ->
                    assessment(
                        TelemetryConfidenceState.INVALIDATED,
                        TelemetryConfidenceReason.CLOCK_DISCONTINUITY,
                    )
                else ->
                    assessment(
                        TelemetryConfidenceState.DEGRADED,
                        TelemetryConfidenceReason.CLOCK_PARTIAL_DISCONTINUITY,
                    )
            }
        return ClockIntegrityTelemetryConfidence(
            assessment = assessment,
            assessedSources = assessed,
            discontinuousSources = discontinuous,
        )
    }

    private fun sourceAgreement(
        target: Long,
        derived: DerivedTelemetryFrame,
    ): SourceAgreementTelemetryConfidence {
        if (derived.movementState.state != MovementState.MOVING) {
            return unavailableAgreement(TelemetryConfidenceReason.SOURCE_AGREEMENT_NOT_APPLICABLE)
        }
        val yaw = derived.yawRateRadiansPerSecond as? DerivedScalarValue.Available
        val heading =
            derived.headingChangeRateRadiansPerSecond as? DerivedScalarValue.Available
        if (yaw == null || heading == null) {
            return unavailableAgreement(
                TelemetryConfidenceReason.SOURCE_AGREEMENT_SOURCE_UNAVAILABLE,
            )
        }
        val yawSource = yaw.provenance.sourceEndTripElapsedNanos
        val headingSource = heading.provenance.sourceEndTripElapsedNanos
        if (
            abs(target - yawSource) > config.maximumSourceAgreementAgeNanos ||
            abs(target - headingSource) > config.maximumSourceAgreementAgeNanos
        ) {
            return unavailableAgreement(
                TelemetryConfidenceReason.SOURCE_AGREEMENT_SOURCE_STALE,
            )
        }
        val difference = abs(yaw.value - heading.value)
        val assessment =
            when {
                difference >
                    config.maximumYawHeadingRateDifferenceRadiansPerSecond ->
                    assessment(
                        TelemetryConfidenceState.INVALIDATED,
                        TelemetryConfidenceReason.SOURCE_AGREEMENT_CONFLICTING,
                    )
                yaw.quality == DerivedChannelQuality.DEGRADED ||
                    heading.quality == DerivedChannelQuality.DEGRADED ->
                    assessment(
                        TelemetryConfidenceState.DEGRADED,
                        TelemetryConfidenceReason.SOURCE_AGREEMENT_DEGRADED_INPUT,
                        TelemetryConfidenceReason.SOURCE_AGREEMENT_CONSISTENT,
                    )
                else ->
                    assessment(
                        TelemetryConfidenceState.SUPPORTED,
                        TelemetryConfidenceReason.SOURCE_AGREEMENT_CONSISTENT,
                    )
            }
        return SourceAgreementTelemetryConfidence(
            assessment = assessment,
            absoluteYawHeadingRateDifferenceRadiansPerSecond = difference,
            maximumAllowedDifferenceRadiansPerSecond =
                config.maximumYawHeadingRateDifferenceRadiansPerSecond,
            yawSourceTripElapsedNanos = yawSource,
            headingSourceTripElapsedNanos = headingSource,
        )
    }

    private fun eligibility(
        derived: DerivedTelemetryFrame,
        components: TelemetryConfidenceComponents,
    ): TelemetryEligibilitySet {
        val inertialContext =
            listOf(
                TelemetryConfidenceComponentKind.CALIBRATION to
                    components.calibration.assessment,
                TelemetryConfidenceComponentKind.ORIENTATION to
                    components.orientation.assessment,
                TelemetryConfidenceComponentKind.DEVICE_MOVEMENT to
                    components.deviceMovement.assessment,
            )
        val accelerometerRequirements =
            listOf(
                TelemetryConfidenceComponentKind.ACCELEROMETER to
                    components.accelerometer.assessment,
            ) + inertialContext
        val gyroscopeRequirements =
            listOf(
                TelemetryConfidenceComponentKind.GYROSCOPE to
                    components.gyroscope.assessment,
            ) + inertialContext
        val gnssRequirements =
            listOf(
                TelemetryConfidenceComponentKind.GNSS to components.gnss.assessment,
            )
        val speed =
            scalarEligibility(
                TelemetryMetric.FILTERED_SPEED,
                derived.filteredSpeedMetresPerSecond,
                gnssRequirements,
            )
        val acceleration =
            vectorEligibility(
                TelemetryMetric.VEHICLE_ACCELERATION,
                derived.vehicleAccelerationMetresPerSecondSquared,
                accelerometerRequirements,
            )
        val jerk =
            vectorEligibility(
                TelemetryMetric.VEHICLE_JERK,
                derived.vehicleJerkMetresPerSecondCubed,
                accelerometerRequirements,
            )
        val yaw =
            scalarEligibility(
                TelemetryMetric.YAW_RATE,
                derived.yawRateRadiansPerSecond,
                gyroscopeRequirements,
            )
        val heading =
            scalarEligibility(
                TelemetryMetric.HEADING_CHANGE_RATE,
                derived.headingChangeRateRadiansPerSecond,
                gnssRequirements,
            )
        val movement = movementEligibility(derived.movementState, gnssRequirements)
        val corroborated =
            corroboratedEligibility(
                derived = derived,
                requirements =
                    listOf(
                        TelemetryConfidenceComponentKind.GNSS to
                            components.gnss.assessment,
                        TelemetryConfidenceComponentKind.ACCELEROMETER to
                            components.accelerometer.assessment,
                        TelemetryConfidenceComponentKind.GYROSCOPE to
                            components.gyroscope.assessment,
                        TelemetryConfidenceComponentKind.CALIBRATION to
                            components.calibration.assessment,
                        TelemetryConfidenceComponentKind.ORIENTATION to
                            components.orientation.assessment,
                        TelemetryConfidenceComponentKind.SOURCE_AGREEMENT to
                            components.sourceAgreement.assessment,
                        TelemetryConfidenceComponentKind.DEVICE_MOVEMENT to
                            components.deviceMovement.assessment,
                        TelemetryConfidenceComponentKind.CLOCK_INTEGRITY to
                            components.clockIntegrity.assessment,
                    ),
            )
        return TelemetryEligibilitySet(
            filteredSpeed = speed,
            vehicleAcceleration = acceleration,
            vehicleJerk = jerk,
            yawRate = yaw,
            headingChangeRate = heading,
            movementState = movement,
            corroboratedVehicleMotion = corroborated,
        )
    }

    private fun scalarEligibility(
        metric: TelemetryMetric,
        value: DerivedScalarValue,
        requirements: List<Pair<TelemetryConfidenceComponentKind, TelemetryConfidenceAssessment>>,
    ): TelemetryEligibilityAssessment =
        channelEligibility(
            metric = metric,
            available = value is DerivedScalarValue.Available,
            degraded =
                (value as? DerivedScalarValue.Available)?.quality ==
                    DerivedChannelQuality.DEGRADED,
            missingReason =
                (value as? DerivedScalarValue.Missing)?.unavailable?.reason,
            requirements = requirements,
        )

    private fun vectorEligibility(
        metric: TelemetryMetric,
        value: DerivedVectorValue,
        requirements: List<Pair<TelemetryConfidenceComponentKind, TelemetryConfidenceAssessment>>,
    ): TelemetryEligibilityAssessment =
        channelEligibility(
            metric = metric,
            available = value is DerivedVectorValue.Available,
            degraded =
                (value as? DerivedVectorValue.Available)?.quality ==
                    DerivedChannelQuality.DEGRADED,
            missingReason =
                (value as? DerivedVectorValue.Missing)?.unavailable?.reason,
            requirements = requirements,
        )

    private fun movementEligibility(
        movement: DerivedMovementState,
        requirements: List<Pair<TelemetryConfidenceComponentKind, TelemetryConfidenceAssessment>>,
    ): TelemetryEligibilityAssessment {
        if (movement.state == MovementState.UNKNOWN) {
            val required = requirements.mapTo(mutableSetOf()) { it.first }
            val limiting =
                requirements.filter { it.second.state != TelemetryConfidenceState.SUPPORTED }
                    .mapTo(mutableSetOf()) { it.first }
            return TelemetryEligibilityAssessment(
                metric = TelemetryMetric.MOVEMENT_STATE,
                eligibility = TelemetryEligibility.EXCLUDED,
                reasons = setOf(TelemetryEligibilityReason.MOVEMENT_STATE_UNKNOWN),
                requiredComponents = required,
                limitingComponents = limiting,
            )
        }
        return channelEligibility(
            metric = TelemetryMetric.MOVEMENT_STATE,
            available = true,
            degraded = movement.quality == DerivedChannelQuality.DEGRADED,
            missingReason = null,
            requirements = requirements,
        )
    }

    private fun corroboratedEligibility(
        derived: DerivedTelemetryFrame,
        requirements: List<Pair<TelemetryConfidenceComponentKind, TelemetryConfidenceAssessment>>,
    ): TelemetryEligibilityAssessment {
        if (derived.movementState.state != MovementState.MOVING) {
            val required = requirements.mapTo(mutableSetOf()) { it.first }
            val limiting =
                requirements.filter { it.second.state != TelemetryConfidenceState.SUPPORTED }
                    .mapTo(mutableSetOf()) { it.first }
            return TelemetryEligibilityAssessment(
                metric = TelemetryMetric.CORROBORATED_VEHICLE_MOTION,
                eligibility = TelemetryEligibility.EXCLUDED,
                reasons =
                    setOf(
                        if (derived.movementState.state == MovementState.UNKNOWN) {
                            TelemetryEligibilityReason.MOVEMENT_STATE_UNKNOWN
                        } else {
                            TelemetryEligibilityReason.MOVEMENT_STATE_NOT_MOVING
                        },
                    ),
                requiredComponents = required,
                limitingComponents = limiting,
            )
        }
        val scalarValues =
            listOf(
                derived.filteredSpeedMetresPerSecond,
                derived.yawRateRadiansPerSecond,
                derived.headingChangeRateRadiansPerSecond,
            )
        val vectorValues =
            listOf(
                derived.vehicleAccelerationMetresPerSecondSquared,
                derived.vehicleJerkMetresPerSecondCubed,
            )
        return channelEligibility(
            metric = TelemetryMetric.CORROBORATED_VEHICLE_MOTION,
            available =
                scalarValues.all { it is DerivedScalarValue.Available } &&
                    vectorValues.all { it is DerivedVectorValue.Available },
            degraded =
                scalarValues.any {
                    (it as? DerivedScalarValue.Available)?.quality ==
                        DerivedChannelQuality.DEGRADED
                } ||
                    vectorValues.any {
                        (it as? DerivedVectorValue.Available)?.quality ==
                            DerivedChannelQuality.DEGRADED
                    },
            missingReason = null,
            requirements = requirements,
        )
    }

    private fun channelEligibility(
        metric: TelemetryMetric,
        available: Boolean,
        degraded: Boolean,
        missingReason: DerivedChannelMissingReason?,
        requirements: List<Pair<TelemetryConfidenceComponentKind, TelemetryConfidenceAssessment>>,
    ): TelemetryEligibilityAssessment {
        val required = requirements.mapTo(mutableSetOf()) { it.first }
        val limiting =
            requirements.filter { it.second.state != TelemetryConfidenceState.SUPPORTED }
                .mapTo(mutableSetOf()) { it.first }
        val reasons = mutableSetOf<TelemetryEligibilityReason>()
        if (!available) reasons += TelemetryEligibilityReason.CHANNEL_UNAVAILABLE
        if (degraded) reasons += TelemetryEligibilityReason.CHANNEL_DEGRADED
        if (requirements.any { it.second.state == TelemetryConfidenceState.DEGRADED }) {
            reasons += TelemetryEligibilityReason.REQUIRED_COMPONENT_DEGRADED
        }
        if (requirements.any { it.second.state == TelemetryConfidenceState.UNAVAILABLE }) {
            reasons += TelemetryEligibilityReason.REQUIRED_COMPONENT_UNAVAILABLE
        }
        if (requirements.any { it.second.state == TelemetryConfidenceState.INVALIDATED }) {
            reasons += TelemetryEligibilityReason.REQUIRED_COMPONENT_INVALIDATED
        }
        val eligibility =
            when {
                !available ||
                    TelemetryEligibilityReason.REQUIRED_COMPONENT_UNAVAILABLE in reasons ||
                    TelemetryEligibilityReason.REQUIRED_COMPONENT_INVALIDATED in reasons ->
                    TelemetryEligibility.EXCLUDED
                degraded ||
                    TelemetryEligibilityReason.REQUIRED_COMPONENT_DEGRADED in reasons ->
                    TelemetryEligibility.LIMITED
                else -> TelemetryEligibility.ELIGIBLE
            }
        if (eligibility == TelemetryEligibility.ELIGIBLE) {
            reasons += TelemetryEligibilityReason.ALL_REQUIRED_EVIDENCE_SUPPORTED
        }
        return TelemetryEligibilityAssessment(
            metric = metric,
            eligibility = eligibility,
            reasons = reasons,
            requiredComponents = required,
            limitingComponents = limiting,
            sourceMissingReason = missingReason,
        )
    }

    private fun unavailableContext(): ContextConfidence =
        ContextConfidence(
            calibration =
                CalibrationTelemetryConfidence(
                    assessment =
                        assessment(
                            TelemetryConfidenceState.UNAVAILABLE,
                            TelemetryConfidenceReason.CALIBRATION_UNAVAILABLE,
                        ),
                    state = null,
                    sourceStartTripElapsedNanos = null,
                    sourceEndTripElapsedNanos = null,
                    evidence = emptySet(),
                ),
            orientation = unavailableOrientation(),
            deviceMovement = unavailableDeviceMovement(),
        )

    private fun unavailableOrientation(): OrientationTelemetryConfidence =
        OrientationTelemetryConfidence(
            assessment =
                assessment(
                    TelemetryConfidenceState.UNAVAILABLE,
                    TelemetryConfidenceReason.ORIENTATION_UNAVAILABLE,
                ),
            quality = null,
            evidence = emptySet(),
            unavailableReason = null,
        )

    private fun unavailableDeviceMovement(): DeviceMovementTelemetryConfidence =
        DeviceMovementTelemetryConfidence(
            assessment =
                assessment(
                    TelemetryConfidenceState.UNAVAILABLE,
                    TelemetryConfidenceReason.DEVICE_MOVEMENT_UNAVAILABLE,
                ),
            mountQuality = null,
            mountEvidence = emptySet(),
            mountUnavailableReason = null,
        )

    private fun unavailableAgreement(
        reason: TelemetryConfidenceReason,
    ): SourceAgreementTelemetryConfidence =
        SourceAgreementTelemetryConfidence(
            assessment = assessment(TelemetryConfidenceState.UNAVAILABLE, reason),
            absoluteYawHeadingRateDifferenceRadiansPerSecond = null,
            maximumAllowedDifferenceRadiansPerSecond =
                config.maximumYawHeadingRateDifferenceRadiansPerSecond,
            yawSourceTripElapsedNanos = null,
            headingSourceTripElapsedNanos = null,
        )
}

private data class ContextConfidence(
    val calibration: CalibrationTelemetryConfidence,
    val orientation: OrientationTelemetryConfidence,
    val deviceMovement: DeviceMovementTelemetryConfidence,
)

private class ConfidenceGnssCursor(
    private val samples: List<ProcessedGnssSample>,
) {
    private var index = 0
    private var latest: ProcessedGnssSample? = null

    fun latestThrough(target: Long): ProcessedGnssSample? {
        while (index < samples.size) {
            val sample = samples[index]
            if (requireNotNull(sample.rawSample.tripElapsedNanos) > target) break
            latest = sample
            index += 1
        }
        return latest
    }
}

private class ConfidenceContextCursor(
    private val segments: List<DerivedMotionContextSegment>,
) {
    private var index = 0

    fun at(target: Long): DerivedMotionContextSegment? {
        while (index < segments.size) {
            val end = segments[index].endTripElapsedNanosExclusive ?: break
            if (target < end) break
            index += 1
        }
        val segment = segments.getOrNull(index) ?: return null
        if (target < segment.startTripElapsedNanos) return null
        val end = segment.endTripElapsedNanosExclusive
        if (end != null && target >= end) return null
        return segment
    }
}

private fun assessImuClock(
    confidence: ImuTelemetryConfidence,
    source: TelemetryClockSource,
    assessed: MutableSet<TelemetryClockSource>,
    discontinuous: MutableSet<TelemetryClockSource>,
) {
    val hasClockEvidence =
        confidence.alignment != null ||
            confidence.missingReason == ImuMissingReason.SOURCE_DISCONTINUITY
    if (!hasClockEvidence) return
    assessed += source
    if (
        ImuQualityFlag.CLOCK_DISCONTINUITY in confidence.qualityFlags ||
        confidence.missingReason == ImuMissingReason.SOURCE_DISCONTINUITY
    ) {
        discontinuous += source
    }
}

private fun assessment(
    state: TelemetryConfidenceState,
    vararg reasons: TelemetryConfidenceReason,
): TelemetryConfidenceAssessment =
    TelemetryConfidenceAssessment(state, reasons.toSet())
