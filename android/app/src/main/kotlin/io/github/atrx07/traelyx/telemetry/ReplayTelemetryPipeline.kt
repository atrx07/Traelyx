package io.github.atrx07.traelyx.telemetry

class ReplayTelemetryTimeline internal constructor(
    val sourceTimeline: TelemetryConfidenceTimeline,
    val config: ReplayTelemetryConfig,
) {
    private val analysisTimeline = sourceTimeline.sourceTimeline.sourceTimeline

    val frameCount: Long
        get() {
            val duration =
                analysisTimeline.lastFrameElapsedNanos -
                    analysisTimeline.firstFrameElapsedNanos
            val completeIntervals = duration / config.intervalNanos
            val terminalPartial = if (duration % config.intervalNanos == 0L) 0L else 1L
            return 1L + completeIntervals + terminalPartial
        }

    /**
     * Returns a fresh bounded-memory reducer on every call. The first analysis frame is emitted
     * exactly, followed by trailing intervals `(previous replay time, replay time]`. A final
     * partial interval retains the exact terminal analysis timestamp.
     */
    fun frames(): Sequence<ReplayTelemetryFrame> = sequence {
        val firstElapsed = analysisTimeline.firstFrameElapsedNanos
        var currentGroup = -1L
        var accumulator: ReplayBucketAccumulator? = null
        sourceTimeline.synchronizedFrames().forEach { source ->
            val elapsed = source.derived.tripElapsedNanos
            val offset = elapsed - firstElapsed
            check(offset >= 0L)
            val group =
                if (offset == 0L) {
                    0L
                } else {
                    1L + (offset - 1L) / config.intervalNanos
                }
            if (group != currentGroup) {
                accumulator?.let { yield(it.build()) }
                val intervalStartExclusive =
                    if (group == 0L) {
                        null
                    } else {
                        firstElapsed + (group - 1L) * config.intervalNanos
                    }
                accumulator =
                    ReplayBucketAccumulator(
                        replayVersion = config.replayVersion,
                        firstTimelineElapsedNanos = firstElapsed,
                        group = group,
                        intervalStartExclusiveTripElapsedNanos = intervalStartExclusive,
                        replayIntervalNanos = config.intervalNanos,
                    )
                currentGroup = group
            }
            requireNotNull(accumulator).add(source)
        }
        accumulator?.let { yield(it.build()) }
    }
}

object ReplayTelemetryPipeline {
    fun build(
        sourceTimeline: TelemetryConfidenceTimeline,
        config: ReplayTelemetryConfig = ReplayTelemetryConfig(),
    ): ReplayTelemetryBuildResult {
        val sourceInterval = sourceTimeline.sourceTimeline.sourceTimeline.config.intervalNanos
        if (config.intervalNanos < sourceInterval) {
            return ReplayTelemetryBuildResult.Invalid(
                errorCode = "replay_interval_below_analysis_interval",
            )
        }
        if (config.intervalNanos % sourceInterval != 0L) {
            return ReplayTelemetryBuildResult.Invalid(
                errorCode = "replay_interval_not_multiple_of_analysis_interval",
            )
        }
        return ReplayTelemetryBuildResult.Success(
            ReplayTelemetryTimeline(sourceTimeline = sourceTimeline, config = config),
        )
    }
}

private class ReplayBucketAccumulator(
    private val replayVersion: Int,
    private val firstTimelineElapsedNanos: Long,
    private val group: Long,
    private val intervalStartExclusiveTripElapsedNanos: Long?,
    private val replayIntervalNanos: Long,
) {
    private val speed = ScalarReplayReducer(TelemetryMetric.FILTERED_SPEED)
    private val acceleration = VectorReplayReducer(TelemetryMetric.VEHICLE_ACCELERATION)
    private val jerk = VectorReplayReducer(TelemetryMetric.VEHICLE_JERK)
    private val yaw = ScalarReplayReducer(TelemetryMetric.YAW_RATE)
    private val heading = ScalarReplayReducer(TelemetryMetric.HEADING_CHANGE_RATE)
    private val movement = MovementReplayReducer()
    private val confidence = ConfidenceReplayReducer()
    private val corroborated =
        EligibilityReplayReducer(TelemetryMetric.CORROBORATED_VEHICLE_MOTION)
    private var sourceStartTripElapsedNanos: Long? = null
    private var sourceEndTripElapsedNanos: Long? = null
    private var sourceFrameCount = 0L
    private var representativeConfidenceFrame: TelemetryConfidenceFrame? = null

    fun add(source: ConfidenceTelemetryFramePair) {
        val derived = source.derived
        val confidenceFrame = source.confidence
        val target = derived.tripElapsedNanos
        check(target == confidenceFrame.tripElapsedNanos)
        val previousEnd = sourceEndTripElapsedNanos
        check(previousEnd == null || target > previousEnd)
        sourceStartTripElapsedNanos = sourceStartTripElapsedNanos ?: target
        sourceEndTripElapsedNanos = target
        sourceFrameCount += 1L
        representativeConfidenceFrame = confidenceFrame
        speed.add(
            derived.filteredSpeedMetresPerSecond,
            confidenceFrame.eligibility.filteredSpeed,
        )
        acceleration.add(
            derived.vehicleAccelerationMetresPerSecondSquared,
            confidenceFrame.eligibility.vehicleAcceleration,
        )
        jerk.add(
            derived.vehicleJerkMetresPerSecondCubed,
            confidenceFrame.eligibility.vehicleJerk,
        )
        yaw.add(derived.yawRateRadiansPerSecond, confidenceFrame.eligibility.yawRate)
        heading.add(
            derived.headingChangeRateRadiansPerSecond,
            confidenceFrame.eligibility.headingChangeRate,
        )
        movement.add(derived.movementState, confidenceFrame.eligibility.movementState)
        confidence.add(confidenceFrame.components)
        corroborated.add(confidenceFrame.eligibility.corroboratedVehicleMotion)
    }

    fun build(): ReplayTelemetryFrame {
        val start = requireNotNull(sourceStartTripElapsedNanos)
        val end = requireNotNull(sourceEndTripElapsedNanos)
        val coverage =
            when {
                group == 0L -> ReplayIntervalCoverage.INITIAL_SAMPLE
                (end - firstTimelineElapsedNanos) % replayIntervalNanos == 0L ->
                    ReplayIntervalCoverage.COMPLETE_INTERVAL
                else -> ReplayIntervalCoverage.PARTIAL_TERMINAL_INTERVAL
            }
        return ReplayTelemetryFrame(
            replayVersion = replayVersion,
            tripElapsedNanos = end,
            intervalStartExclusiveTripElapsedNanos = intervalStartExclusiveTripElapsedNanos,
            sourceStartTripElapsedNanos = start,
            sourceEndTripElapsedNanos = end,
            sourceFrameCount = sourceFrameCount,
            intervalCoverage = coverage,
            filteredSpeedMetresPerSecond = speed.build(),
            vehicleAccelerationMetresPerSecondSquared = acceleration.build(),
            vehicleJerkMetresPerSecondCubed = jerk.build(),
            yawRateRadiansPerSecond = yaw.build(),
            headingChangeRateRadiansPerSecond = heading.build(),
            movementState = movement.build(),
            confidence = confidence.build(),
            corroboratedVehicleMotionEligibility = corroborated.build(),
            representativeConfidenceFrame = requireNotNull(representativeConfidenceFrame),
        )
    }
}

private class ScalarReplayReducer(
    private val metric: TelemetryMetric,
) {
    private var representative: DerivedScalarValue? = null
    private var minimum: DerivedScalarValue.Available? = null
    private var maximum: DerivedScalarValue.Available? = null
    private var availableFrameCount = 0L
    private var missingFrameCount = 0L
    private val missingReasons = mutableSetOf<DerivedChannelMissingReason>()
    private val observedQualities = mutableSetOf<DerivedChannelQuality>()
    private val eligibility = EligibilityReplayReducer(metric)

    fun add(
        value: DerivedScalarValue,
        assessment: TelemetryEligibilityAssessment,
    ) {
        representative = value
        eligibility.add(assessment)
        when (value) {
            is DerivedScalarValue.Available -> {
                availableFrameCount += 1L
                observedQualities += value.quality
                if (minimum == null || value.value < requireNotNull(minimum).value) minimum = value
                if (maximum == null || value.value > requireNotNull(maximum).value) maximum = value
            }
            is DerivedScalarValue.Missing -> {
                missingFrameCount += 1L
                missingReasons += value.unavailable.reason
            }
        }
    }

    fun build(): ReplayScalarChannel =
        ReplayScalarChannel(
            representative = requireNotNull(representative),
            minimum = minimum,
            maximum = maximum,
            availableFrameCount = availableFrameCount,
            missingFrameCount = missingFrameCount,
            missingReasons = missingReasons.toSet(),
            observedQualities = observedQualities.toSet(),
            coverage = replayChannelCoverage(availableFrameCount, missingFrameCount),
            eligibility = eligibility.build(),
        )
}

private class VectorReplayReducer(
    private val metric: TelemetryMetric,
) {
    private var representative: DerivedVectorValue? = null
    private val x = VectorAxisReducer { it.x }
    private val y = VectorAxisReducer { it.y }
    private val z = VectorAxisReducer { it.z }
    private var availableFrameCount = 0L
    private var missingFrameCount = 0L
    private val missingReasons = mutableSetOf<DerivedChannelMissingReason>()
    private val observedQualities = mutableSetOf<DerivedChannelQuality>()
    private val eligibility = EligibilityReplayReducer(metric)

    fun add(
        value: DerivedVectorValue,
        assessment: TelemetryEligibilityAssessment,
    ) {
        representative = value
        eligibility.add(assessment)
        when (value) {
            is DerivedVectorValue.Available -> {
                availableFrameCount += 1L
                observedQualities += value.quality
                x.add(value)
                y.add(value)
                z.add(value)
            }
            is DerivedVectorValue.Missing -> {
                missingFrameCount += 1L
                missingReasons += value.unavailable.reason
            }
        }
    }

    fun build(): ReplayVectorChannel =
        ReplayVectorChannel(
            representative = requireNotNull(representative),
            x = x.build(),
            y = y.build(),
            z = z.build(),
            availableFrameCount = availableFrameCount,
            missingFrameCount = missingFrameCount,
            missingReasons = missingReasons.toSet(),
            observedQualities = observedQualities.toSet(),
            coverage = replayChannelCoverage(availableFrameCount, missingFrameCount),
            eligibility = eligibility.build(),
        )
}

private class VectorAxisReducer(
    private val value: (FrameVector3) -> Double,
) {
    private var minimum: DerivedVectorValue.Available? = null
    private var maximum: DerivedVectorValue.Available? = null

    fun add(sample: DerivedVectorValue.Available) {
        if (minimum == null || value(sample.value) < value(requireNotNull(minimum).value)) {
            minimum = sample
        }
        if (maximum == null || value(sample.value) > value(requireNotNull(maximum).value)) {
            maximum = sample
        }
    }

    fun build(): ReplayVectorAxisEnvelope? {
        val minimum = minimum ?: return null
        return ReplayVectorAxisEnvelope(minimum = minimum, maximum = requireNotNull(maximum))
    }
}

private class MovementReplayReducer {
    private var representative: DerivedMovementState? = null
    private val observedStates = mutableSetOf<MovementState>()
    private val observedQualities = mutableSetOf<DerivedChannelQuality>()
    private val eligibility = EligibilityReplayReducer(TelemetryMetric.MOVEMENT_STATE)

    fun add(
        value: DerivedMovementState,
        assessment: TelemetryEligibilityAssessment,
    ) {
        representative = value
        observedStates += value.state
        value.quality?.let { observedQualities += it }
        eligibility.add(assessment)
    }

    fun build(): ReplayMovementChannel =
        ReplayMovementChannel(
            representative = requireNotNull(representative),
            observedStates = observedStates.toSet(),
            observedQualities = observedQualities.toSet(),
            eligibility = eligibility.build(),
        )
}

private class EligibilityReplayReducer(
    private val metric: TelemetryMetric,
) {
    private var representative: TelemetryEligibilityAssessment? = null
    private var mostRestrictive: TelemetryEligibility? = null
    private val observed = mutableSetOf<TelemetryEligibility>()
    private val reasons = mutableSetOf<TelemetryEligibilityReason>()
    private val requiredComponents = mutableSetOf<TelemetryConfidenceComponentKind>()
    private val limitingComponents = mutableSetOf<TelemetryConfidenceComponentKind>()

    fun add(value: TelemetryEligibilityAssessment) {
        require(value.metric == metric)
        representative = value
        observed += value.eligibility
        reasons += value.reasons
        requiredComponents += value.requiredComponents
        limitingComponents += value.limitingComponents
        val current = mostRestrictive
        if (
            current == null ||
            eligibilitySeverity(value.eligibility) > eligibilitySeverity(current)
        ) {
            mostRestrictive = value.eligibility
        }
    }

    fun build(): ReplayEligibilitySummary =
        ReplayEligibilitySummary(
            representative = requireNotNull(representative),
            mostRestrictive = requireNotNull(mostRestrictive),
            observed = observed.toSet(),
            reasons = reasons.toSet(),
            requiredComponents = requiredComponents.toSet(),
            limitingComponents = limitingComponents.toSet(),
        )
}

private class ConfidenceReplayReducer {
    private val gnss = ConfidenceComponentReplayReducer()
    private val accelerometer = ConfidenceComponentReplayReducer()
    private val gyroscope = ConfidenceComponentReplayReducer()
    private val calibration = ConfidenceComponentReplayReducer()
    private val orientation = ConfidenceComponentReplayReducer()
    private val sourceAgreement = ConfidenceComponentReplayReducer()
    private val deviceMovement = ConfidenceComponentReplayReducer()
    private val clockIntegrity = ConfidenceComponentReplayReducer()

    fun add(components: TelemetryConfidenceComponents) {
        gnss.add(components.gnss.assessment)
        accelerometer.add(components.accelerometer.assessment)
        gyroscope.add(components.gyroscope.assessment)
        calibration.add(components.calibration.assessment)
        orientation.add(components.orientation.assessment)
        sourceAgreement.add(components.sourceAgreement.assessment)
        deviceMovement.add(components.deviceMovement.assessment)
        clockIntegrity.add(components.clockIntegrity.assessment)
    }

    fun build(): ReplayConfidenceSummary =
        ReplayConfidenceSummary(
            gnss = gnss.build(),
            accelerometer = accelerometer.build(),
            gyroscope = gyroscope.build(),
            calibration = calibration.build(),
            orientation = orientation.build(),
            sourceAgreement = sourceAgreement.build(),
            deviceMovement = deviceMovement.build(),
            clockIntegrity = clockIntegrity.build(),
        )
}

private class ConfidenceComponentReplayReducer {
    private var representative: TelemetryConfidenceAssessment? = null
    private var mostSevere: TelemetryConfidenceState? = null
    private val observedStates = mutableSetOf<TelemetryConfidenceState>()
    private val reasons = mutableSetOf<TelemetryConfidenceReason>()

    fun add(value: TelemetryConfidenceAssessment) {
        representative = value
        observedStates += value.state
        reasons += value.reasons
        val current = mostSevere
        if (current == null || confidenceSeverity(value.state) > confidenceSeverity(current)) {
            mostSevere = value.state
        }
    }

    fun build(): ReplayConfidenceComponentSummary =
        ReplayConfidenceComponentSummary(
            representative = requireNotNull(representative),
            mostSevere = requireNotNull(mostSevere),
            observedStates = observedStates.toSet(),
            reasons = reasons.toSet(),
        )
}

private fun replayChannelCoverage(
    availableFrameCount: Long,
    missingFrameCount: Long,
): ReplayChannelCoverage =
    when {
        availableFrameCount == 0L -> ReplayChannelCoverage.MISSING
        missingFrameCount == 0L -> ReplayChannelCoverage.AVAILABLE
        else -> ReplayChannelCoverage.PARTIAL
    }

private fun eligibilitySeverity(value: TelemetryEligibility): Int =
    when (value) {
        TelemetryEligibility.ELIGIBLE -> 0
        TelemetryEligibility.LIMITED -> 1
        TelemetryEligibility.EXCLUDED -> 2
    }

private fun confidenceSeverity(value: TelemetryConfidenceState): Int =
    when (value) {
        TelemetryConfidenceState.SUPPORTED -> 0
        TelemetryConfidenceState.DEGRADED -> 1
        TelemetryConfidenceState.UNAVAILABLE -> 2
        TelemetryConfidenceState.INVALIDATED -> 3
    }
