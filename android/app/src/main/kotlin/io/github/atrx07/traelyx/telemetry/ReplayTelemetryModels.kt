package io.github.atrx07.traelyx.telemetry

const val REPLAY_TELEMETRY_VERSION = 1
const val DEFAULT_REPLAY_INTERVAL_NANOS = 100_000_000L

data class ReplayTelemetryConfig(
    val replayVersion: Int = REPLAY_TELEMETRY_VERSION,
    val intervalNanos: Long = DEFAULT_REPLAY_INTERVAL_NANOS,
) {
    init {
        require(replayVersion == REPLAY_TELEMETRY_VERSION)
        require(intervalNanos > 0L)
    }
}

enum class ReplayIntervalCoverage {
    INITIAL_SAMPLE,
    COMPLETE_INTERVAL,
    PARTIAL_TERMINAL_INTERVAL,
}

enum class ReplayChannelCoverage {
    AVAILABLE,
    PARTIAL,
    MISSING,
}

data class ReplayEligibilitySummary(
    val representative: TelemetryEligibilityAssessment,
    val mostRestrictive: TelemetryEligibility,
    val observed: Set<TelemetryEligibility>,
    val reasons: Set<TelemetryEligibilityReason>,
    val requiredComponents: Set<TelemetryConfidenceComponentKind>,
    val limitingComponents: Set<TelemetryConfidenceComponentKind>,
) {
    init {
        require(observed.isNotEmpty())
        require(representative.eligibility in observed)
        require(mostRestrictive in observed)
        require(reasons.isNotEmpty())
        require(limitingComponents.all { it in requiredComponents })
    }
}

data class ReplayScalarChannel(
    val representative: DerivedScalarValue,
    val minimum: DerivedScalarValue.Available?,
    val maximum: DerivedScalarValue.Available?,
    val availableFrameCount: Long,
    val missingFrameCount: Long,
    val missingReasons: Set<DerivedChannelMissingReason>,
    val observedQualities: Set<DerivedChannelQuality>,
    val coverage: ReplayChannelCoverage,
    val eligibility: ReplayEligibilitySummary,
) {
    init {
        require(availableFrameCount >= 0L)
        require(missingFrameCount >= 0L)
        require(availableFrameCount + missingFrameCount > 0L)
        require((availableFrameCount == 0L) == (minimum == null))
        require((availableFrameCount == 0L) == (maximum == null))
        require((availableFrameCount == 0L) == observedQualities.isEmpty())
        require((missingFrameCount == 0L) == missingReasons.isEmpty())
        require(
            coverage ==
                replayCoverage(
                    availableFrameCount = availableFrameCount,
                    missingFrameCount = missingFrameCount,
                ),
        )
        if (minimum != null && maximum != null) require(minimum.value <= maximum.value)
    }
}

data class ReplayVectorAxisEnvelope(
    val minimum: DerivedVectorValue.Available,
    val maximum: DerivedVectorValue.Available,
)

data class ReplayVectorChannel(
    val representative: DerivedVectorValue,
    val x: ReplayVectorAxisEnvelope?,
    val y: ReplayVectorAxisEnvelope?,
    val z: ReplayVectorAxisEnvelope?,
    val availableFrameCount: Long,
    val missingFrameCount: Long,
    val missingReasons: Set<DerivedChannelMissingReason>,
    val observedQualities: Set<DerivedChannelQuality>,
    val coverage: ReplayChannelCoverage,
    val eligibility: ReplayEligibilitySummary,
) {
    init {
        require(availableFrameCount >= 0L)
        require(missingFrameCount >= 0L)
        require(availableFrameCount + missingFrameCount > 0L)
        require((availableFrameCount == 0L) == (x == null))
        require((availableFrameCount == 0L) == (y == null))
        require((availableFrameCount == 0L) == (z == null))
        require((availableFrameCount == 0L) == observedQualities.isEmpty())
        require((missingFrameCount == 0L) == missingReasons.isEmpty())
        require(
            coverage ==
                replayCoverage(
                    availableFrameCount = availableFrameCount,
                    missingFrameCount = missingFrameCount,
                ),
        )
        if (x != null) require(x.minimum.value.x <= x.maximum.value.x)
        if (y != null) require(y.minimum.value.y <= y.maximum.value.y)
        if (z != null) require(z.minimum.value.z <= z.maximum.value.z)
    }
}

data class ReplayMovementChannel(
    val representative: DerivedMovementState,
    val observedStates: Set<MovementState>,
    val observedQualities: Set<DerivedChannelQuality>,
    val eligibility: ReplayEligibilitySummary,
) {
    init {
        require(observedStates.isNotEmpty())
        require(representative.state in observedStates)
        require(representative.quality == null || representative.quality in observedQualities)
    }
}

data class ReplayConfidenceComponentSummary(
    val representative: TelemetryConfidenceAssessment,
    val mostSevere: TelemetryConfidenceState,
    val observedStates: Set<TelemetryConfidenceState>,
    val reasons: Set<TelemetryConfidenceReason>,
) {
    init {
        require(observedStates.isNotEmpty())
        require(representative.state in observedStates)
        require(mostSevere in observedStates)
        require(reasons.isNotEmpty())
    }
}

data class ReplayConfidenceSummary(
    val gnss: ReplayConfidenceComponentSummary,
    val accelerometer: ReplayConfidenceComponentSummary,
    val gyroscope: ReplayConfidenceComponentSummary,
    val calibration: ReplayConfidenceComponentSummary,
    val orientation: ReplayConfidenceComponentSummary,
    val sourceAgreement: ReplayConfidenceComponentSummary,
    val deviceMovement: ReplayConfidenceComponentSummary,
    val clockIntegrity: ReplayConfidenceComponentSummary,
)

data class ReplayTelemetryFrame(
    val replayVersion: Int = REPLAY_TELEMETRY_VERSION,
    val tripElapsedNanos: Long,
    val intervalStartExclusiveTripElapsedNanos: Long?,
    val sourceStartTripElapsedNanos: Long,
    val sourceEndTripElapsedNanos: Long,
    val sourceFrameCount: Long,
    val intervalCoverage: ReplayIntervalCoverage,
    val filteredSpeedMetresPerSecond: ReplayScalarChannel,
    val vehicleAccelerationMetresPerSecondSquared: ReplayVectorChannel,
    val vehicleJerkMetresPerSecondCubed: ReplayVectorChannel,
    val yawRateRadiansPerSecond: ReplayScalarChannel,
    val headingChangeRateRadiansPerSecond: ReplayScalarChannel,
    val movementState: ReplayMovementChannel,
    val confidence: ReplayConfidenceSummary,
    val corroboratedVehicleMotionEligibility: ReplayEligibilitySummary,
    val representativeConfidenceFrame: TelemetryConfidenceFrame,
) {
    init {
        require(replayVersion == REPLAY_TELEMETRY_VERSION)
        require(tripElapsedNanos >= 0L)
        require(sourceStartTripElapsedNanos >= 0L)
        require(sourceEndTripElapsedNanos >= sourceStartTripElapsedNanos)
        require(sourceEndTripElapsedNanos == tripElapsedNanos)
        require(sourceFrameCount > 0L)
        require(representativeConfidenceFrame.tripElapsedNanos == tripElapsedNanos)
        require(
            intervalStartExclusiveTripElapsedNanos == null ||
                intervalStartExclusiveTripElapsedNanos < sourceStartTripElapsedNanos,
        )
        require(
            (intervalCoverage == ReplayIntervalCoverage.INITIAL_SAMPLE) ==
                (intervalStartExclusiveTripElapsedNanos == null),
        )
        val representativeTargets =
            listOf(
                filteredSpeedMetresPerSecond.representative.targetTripElapsedNanos,
                vehicleAccelerationMetresPerSecondSquared.representative.targetTripElapsedNanos,
                vehicleJerkMetresPerSecondCubed.representative.targetTripElapsedNanos,
                yawRateRadiansPerSecond.representative.targetTripElapsedNanos,
                headingChangeRateRadiansPerSecond.representative.targetTripElapsedNanos,
                movementState.representative.targetTripElapsedNanos,
            )
        require(representativeTargets.all { it == tripElapsedNanos })
        val channelFrameCounts =
            listOf(
                filteredSpeedMetresPerSecond.availableFrameCount +
                    filteredSpeedMetresPerSecond.missingFrameCount,
                vehicleAccelerationMetresPerSecondSquared.availableFrameCount +
                    vehicleAccelerationMetresPerSecondSquared.missingFrameCount,
                vehicleJerkMetresPerSecondCubed.availableFrameCount +
                    vehicleJerkMetresPerSecondCubed.missingFrameCount,
                yawRateRadiansPerSecond.availableFrameCount +
                    yawRateRadiansPerSecond.missingFrameCount,
                headingChangeRateRadiansPerSecond.availableFrameCount +
                    headingChangeRateRadiansPerSecond.missingFrameCount,
            )
        require(channelFrameCounts.all { it == sourceFrameCount })
        val representativeEligibility = representativeConfidenceFrame.eligibility
        require(
            filteredSpeedMetresPerSecond.eligibility.representative ==
                representativeEligibility.filteredSpeed,
        )
        require(
            vehicleAccelerationMetresPerSecondSquared.eligibility.representative ==
                representativeEligibility.vehicleAcceleration,
        )
        require(
            vehicleJerkMetresPerSecondCubed.eligibility.representative ==
                representativeEligibility.vehicleJerk,
        )
        require(
            yawRateRadiansPerSecond.eligibility.representative ==
                representativeEligibility.yawRate,
        )
        require(
            headingChangeRateRadiansPerSecond.eligibility.representative ==
                representativeEligibility.headingChangeRate,
        )
        require(movementState.eligibility.representative == representativeEligibility.movementState)
        require(
            corroboratedVehicleMotionEligibility.representative ==
                representativeEligibility.corroboratedVehicleMotion,
        )
        val representativeComponents = representativeConfidenceFrame.components
        require(confidence.gnss.representative == representativeComponents.gnss.assessment)
        require(
            confidence.accelerometer.representative ==
                representativeComponents.accelerometer.assessment,
        )
        require(
            confidence.gyroscope.representative == representativeComponents.gyroscope.assessment,
        )
        require(
            confidence.calibration.representative ==
                representativeComponents.calibration.assessment,
        )
        require(
            confidence.orientation.representative ==
                representativeComponents.orientation.assessment,
        )
        require(
            confidence.sourceAgreement.representative ==
                representativeComponents.sourceAgreement.assessment,
        )
        require(
            confidence.deviceMovement.representative ==
                representativeComponents.deviceMovement.assessment,
        )
        require(
            confidence.clockIntegrity.representative ==
                representativeComponents.clockIntegrity.assessment,
        )
    }
}

sealed interface ReplayTelemetryBuildResult {
    data class Success(val timeline: ReplayTelemetryTimeline) : ReplayTelemetryBuildResult

    data class Invalid(val errorCode: String) : ReplayTelemetryBuildResult
}

private fun replayCoverage(
    availableFrameCount: Long,
    missingFrameCount: Long,
): ReplayChannelCoverage =
    when {
        availableFrameCount == 0L -> ReplayChannelCoverage.MISSING
        missingFrameCount == 0L -> ReplayChannelCoverage.AVAILABLE
        else -> ReplayChannelCoverage.PARTIAL
    }
