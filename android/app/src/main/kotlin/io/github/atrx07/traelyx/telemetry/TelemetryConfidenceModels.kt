package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag

const val TELEMETRY_CONFIDENCE_VERSION = 1
const val DEFAULT_PREFERRED_GNSS_HORIZONTAL_ACCURACY_METRES = 15.0
const val DEFAULT_MAXIMUM_YAW_HEADING_RATE_DIFFERENCE_RADIANS_PER_SECOND = 0.5
const val DEFAULT_MAXIMUM_SOURCE_AGREEMENT_AGE_NANOS = 1_000_000_000L

data class TelemetryConfidenceConfig(
    val confidenceVersion: Int = TELEMETRY_CONFIDENCE_VERSION,
    val preferredGnssHorizontalAccuracyMetres: Double =
        DEFAULT_PREFERRED_GNSS_HORIZONTAL_ACCURACY_METRES,
    val maximumYawHeadingRateDifferenceRadiansPerSecond: Double =
        DEFAULT_MAXIMUM_YAW_HEADING_RATE_DIFFERENCE_RADIANS_PER_SECOND,
    val maximumSourceAgreementAgeNanos: Long =
        DEFAULT_MAXIMUM_SOURCE_AGREEMENT_AGE_NANOS,
) {
    init {
        require(confidenceVersion == TELEMETRY_CONFIDENCE_VERSION)
        require(
            preferredGnssHorizontalAccuracyMetres.isFinite() &&
                preferredGnssHorizontalAccuracyMetres > 0.0,
        )
        require(
            maximumYawHeadingRateDifferenceRadiansPerSecond.isFinite() &&
                maximumYawHeadingRateDifferenceRadiansPerSecond >= 0.0,
        )
        require(maximumSourceAgreementAgeNanos >= 0L)
    }
}

enum class TelemetryConfidenceState {
    SUPPORTED,
    DEGRADED,
    UNAVAILABLE,
    INVALIDATED,
}

enum class TelemetryConfidenceComponentKind {
    GNSS,
    ACCELEROMETER,
    GYROSCOPE,
    CALIBRATION,
    ORIENTATION,
    SOURCE_AGREEMENT,
    DEVICE_MOVEMENT,
    CLOCK_INTEGRITY,
}

enum class TelemetryConfidenceReason {
    GNSS_SUPPORTED,
    GNSS_SOURCE_UNAVAILABLE,
    GNSS_SOURCE_STALE,
    GNSS_ANCHOR_ONLY,
    GNSS_HORIZONTAL_ACCURACY_REDUCED,
    GNSS_LOW_ACCURACY,
    GNSS_GAP,
    GNSS_IMPOSSIBLE_JUMP,
    GNSS_STATIONARY_OR_UNRESOLVED,
    GNSS_MOCK_LOCATION,
    GNSS_SOURCE_SPEED_IMPLAUSIBLE,
    IMU_EXACT,
    IMU_INTERPOLATED,
    IMU_SOURCE_UNAVAILABLE,
    IMU_SOURCE_DISCONTINUITY,
    IMU_INTERPOLATION_GAP_TOO_LARGE,
    IMU_DROPOUT,
    IMU_SENSOR_UNRELIABLE,
    IMU_CLOCK_DISCONTINUITY,
    CALIBRATION_SUPPORTED,
    CALIBRATION_DEGRADED,
    CALIBRATION_UNAVAILABLE,
    CALIBRATION_AFTER_TARGET,
    ORIENTATION_SUPPORTED,
    ORIENTATION_DEGRADED,
    ORIENTATION_UNAVAILABLE,
    ORIENTATION_REFERENCE_MISMATCH,
    DEVICE_MOVEMENT_STABLE,
    DEVICE_MOVEMENT_NOT_EVALUATED,
    DEVICE_MOVEMENT_INDETERMINATE,
    DEVICE_MOVEMENT_EVIDENCE_DEGRADED,
    DEVICE_MOVEMENT_INVALIDATED,
    DEVICE_MOVEMENT_UNAVAILABLE,
    SOURCE_AGREEMENT_CONSISTENT,
    SOURCE_AGREEMENT_DEGRADED_INPUT,
    SOURCE_AGREEMENT_CONFLICTING,
    SOURCE_AGREEMENT_NOT_APPLICABLE,
    SOURCE_AGREEMENT_SOURCE_UNAVAILABLE,
    SOURCE_AGREEMENT_SOURCE_STALE,
    CLOCK_SUPPORTED,
    CLOCK_PARTIAL_DISCONTINUITY,
    CLOCK_DISCONTINUITY,
    CLOCK_NOT_ASSESSED,
}

data class TelemetryConfidenceAssessment(
    val state: TelemetryConfidenceState,
    val reasons: Set<TelemetryConfidenceReason>,
) {
    init {
        require(reasons.isNotEmpty())
    }
}

data class GnssTelemetryConfidence(
    val assessment: TelemetryConfidenceAssessment,
    val sourceTripElapsedNanos: Long?,
    val sourceAgeNanos: Long?,
    val horizontalAccuracyMetres: Double?,
    val speedAccuracyMetresPerSecond: Double?,
    val bearingAccuracyDegrees: Double?,
    val decision: GnssDecision?,
    val processingEvidence: Set<GnssProcessingEvidence>,
    val rawQualityFlags: Set<GnssQualityFlag>,
) {
    init {
        require((sourceTripElapsedNanos == null) == (sourceAgeNanos == null))
        require((sourceTripElapsedNanos == null) == (decision == null))
        require(sourceTripElapsedNanos == null || sourceTripElapsedNanos >= 0L)
        require(sourceAgeNanos == null || sourceAgeNanos >= 0L)
        requireFiniteNonNegative(horizontalAccuracyMetres)
        requireFiniteNonNegative(speedAccuracyMetresPerSecond)
        requireFiniteNonNegative(bearingAccuracyDegrees)
    }
}

data class ImuTelemetryConfidence(
    val component: TelemetryConfidenceComponentKind,
    val assessment: TelemetryConfidenceAssessment,
    val alignment: ImuAlignment?,
    val lowerTripElapsedNanos: Long?,
    val upperTripElapsedNanos: Long?,
    val lowerSourceTimestampNanos: Long?,
    val upperSourceTimestampNanos: Long?,
    val accuracyStatus: Int?,
    val qualityFlags: Set<ImuQualityFlag>,
    val missingReason: ImuMissingReason?,
) {
    init {
        require(
            component == TelemetryConfidenceComponentKind.ACCELEROMETER ||
                component == TelemetryConfidenceComponentKind.GYROSCOPE,
        )
        require((alignment == null) == (missingReason != null))
        require((alignment == null) == (lowerTripElapsedNanos == null))
        require((alignment == null) == (upperTripElapsedNanos == null))
        require((alignment == null) == (lowerSourceTimestampNanos == null))
        require((alignment == null) == (upperSourceTimestampNanos == null))
        require((alignment == null) == (accuracyStatus == null))
        if (alignment != null) {
            require(requireNotNull(lowerTripElapsedNanos) >= 0L)
            require(requireNotNull(upperTripElapsedNanos) >= lowerTripElapsedNanos)
            require(requireNotNull(lowerSourceTimestampNanos) >= 0L)
            require(requireNotNull(upperSourceTimestampNanos) >= lowerSourceTimestampNanos)
        }
    }
}

data class CalibrationTelemetryConfidence(
    val assessment: TelemetryConfidenceAssessment,
    val state: ImuCalibrationState?,
    val sourceStartTripElapsedNanos: Long?,
    val sourceEndTripElapsedNanos: Long?,
    val evidence: Set<ImuCalibrationEvidence>,
) {
    init {
        require(
            (sourceStartTripElapsedNanos == null) ==
                (sourceEndTripElapsedNanos == null),
        )
        if (sourceStartTripElapsedNanos != null && sourceEndTripElapsedNanos != null) {
            require(sourceStartTripElapsedNanos >= 0L)
            require(sourceEndTripElapsedNanos >= sourceStartTripElapsedNanos)
        }
    }
}

data class OrientationTelemetryConfidence(
    val assessment: TelemetryConfidenceAssessment,
    val quality: VehicleMountAlignmentQuality?,
    val evidence: Set<VehicleMountAlignmentEvidence>,
    val unavailableReason: VehicleMountAlignmentUnavailableReason?,
)

data class DeviceMovementTelemetryConfidence(
    val assessment: TelemetryConfidenceAssessment,
    val mountQuality: VehicleMountAlignmentQuality?,
    val mountEvidence: Set<VehicleMountAlignmentEvidence>,
    val mountUnavailableReason: VehicleMountAlignmentUnavailableReason?,
)

enum class TelemetryClockSource {
    ACCELEROMETER,
    GYROSCOPE,
    GNSS,
}

data class ClockIntegrityTelemetryConfidence(
    val assessment: TelemetryConfidenceAssessment,
    val assessedSources: Set<TelemetryClockSource>,
    val discontinuousSources: Set<TelemetryClockSource>,
) {
    init {
        require(discontinuousSources.all { it in assessedSources })
    }
}

data class SourceAgreementTelemetryConfidence(
    val assessment: TelemetryConfidenceAssessment,
    val absoluteYawHeadingRateDifferenceRadiansPerSecond: Double?,
    val maximumAllowedDifferenceRadiansPerSecond: Double,
    val yawSourceTripElapsedNanos: Long?,
    val headingSourceTripElapsedNanos: Long?,
) {
    init {
        require(
            maximumAllowedDifferenceRadiansPerSecond.isFinite() &&
                maximumAllowedDifferenceRadiansPerSecond >= 0.0,
        )
        require(
            absoluteYawHeadingRateDifferenceRadiansPerSecond == null ||
                absoluteYawHeadingRateDifferenceRadiansPerSecond.isFinite() &&
                absoluteYawHeadingRateDifferenceRadiansPerSecond >= 0.0,
        )
        require(
            (yawSourceTripElapsedNanos == null) ==
                (headingSourceTripElapsedNanos == null),
        )
    }
}

data class TelemetryConfidenceComponents(
    val gnss: GnssTelemetryConfidence,
    val accelerometer: ImuTelemetryConfidence,
    val gyroscope: ImuTelemetryConfidence,
    val calibration: CalibrationTelemetryConfidence,
    val orientation: OrientationTelemetryConfidence,
    val sourceAgreement: SourceAgreementTelemetryConfidence,
    val deviceMovement: DeviceMovementTelemetryConfidence,
    val clockIntegrity: ClockIntegrityTelemetryConfidence,
) {
    init {
        require(accelerometer.component == TelemetryConfidenceComponentKind.ACCELEROMETER)
        require(gyroscope.component == TelemetryConfidenceComponentKind.GYROSCOPE)
    }
}

enum class TelemetryMetric {
    FILTERED_SPEED,
    VEHICLE_ACCELERATION,
    VEHICLE_JERK,
    YAW_RATE,
    HEADING_CHANGE_RATE,
    MOVEMENT_STATE,
    CORROBORATED_VEHICLE_MOTION,
}

enum class TelemetryEligibility {
    ELIGIBLE,
    LIMITED,
    EXCLUDED,
}

enum class TelemetryEligibilityReason {
    ALL_REQUIRED_EVIDENCE_SUPPORTED,
    CHANNEL_UNAVAILABLE,
    CHANNEL_DEGRADED,
    MOVEMENT_STATE_UNKNOWN,
    MOVEMENT_STATE_NOT_MOVING,
    REQUIRED_COMPONENT_DEGRADED,
    REQUIRED_COMPONENT_UNAVAILABLE,
    REQUIRED_COMPONENT_INVALIDATED,
}

data class TelemetryEligibilityAssessment(
    val metric: TelemetryMetric,
    val eligibility: TelemetryEligibility,
    val reasons: Set<TelemetryEligibilityReason>,
    val requiredComponents: Set<TelemetryConfidenceComponentKind>,
    val limitingComponents: Set<TelemetryConfidenceComponentKind>,
    val sourceMissingReason: DerivedChannelMissingReason? = null,
) {
    init {
        require(reasons.isNotEmpty())
        require(limitingComponents.all { it in requiredComponents })
        require(
            eligibility != TelemetryEligibility.ELIGIBLE ||
                limitingComponents.isEmpty(),
        )
        require(
            sourceMissingReason == null ||
                TelemetryEligibilityReason.CHANNEL_UNAVAILABLE in reasons,
        )
    }
}

data class TelemetryEligibilitySet(
    val filteredSpeed: TelemetryEligibilityAssessment,
    val vehicleAcceleration: TelemetryEligibilityAssessment,
    val vehicleJerk: TelemetryEligibilityAssessment,
    val yawRate: TelemetryEligibilityAssessment,
    val headingChangeRate: TelemetryEligibilityAssessment,
    val movementState: TelemetryEligibilityAssessment,
    val corroboratedVehicleMotion: TelemetryEligibilityAssessment,
) {
    init {
        require(filteredSpeed.metric == TelemetryMetric.FILTERED_SPEED)
        require(vehicleAcceleration.metric == TelemetryMetric.VEHICLE_ACCELERATION)
        require(vehicleJerk.metric == TelemetryMetric.VEHICLE_JERK)
        require(yawRate.metric == TelemetryMetric.YAW_RATE)
        require(headingChangeRate.metric == TelemetryMetric.HEADING_CHANGE_RATE)
        require(movementState.metric == TelemetryMetric.MOVEMENT_STATE)
        require(
            corroboratedVehicleMotion.metric ==
                TelemetryMetric.CORROBORATED_VEHICLE_MOTION,
        )
    }

    operator fun get(metric: TelemetryMetric): TelemetryEligibilityAssessment =
        when (metric) {
            TelemetryMetric.FILTERED_SPEED -> filteredSpeed
            TelemetryMetric.VEHICLE_ACCELERATION -> vehicleAcceleration
            TelemetryMetric.VEHICLE_JERK -> vehicleJerk
            TelemetryMetric.YAW_RATE -> yawRate
            TelemetryMetric.HEADING_CHANGE_RATE -> headingChangeRate
            TelemetryMetric.MOVEMENT_STATE -> movementState
            TelemetryMetric.CORROBORATED_VEHICLE_MOTION -> corroboratedVehicleMotion
        }
}

data class TelemetryConfidenceFrame(
    val confidenceVersion: Int = TELEMETRY_CONFIDENCE_VERSION,
    val tripElapsedNanos: Long,
    val components: TelemetryConfidenceComponents,
    val eligibility: TelemetryEligibilitySet,
) {
    init {
        require(confidenceVersion == TELEMETRY_CONFIDENCE_VERSION)
        require(tripElapsedNanos >= 0L)
    }
}

private fun requireFiniteNonNegative(value: Double?) {
    require(value == null || value.isFinite() && value >= 0.0)
}
