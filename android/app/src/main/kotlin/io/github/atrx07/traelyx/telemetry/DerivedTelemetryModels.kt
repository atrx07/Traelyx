package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag

const val DERIVED_TELEMETRY_VERSION = 1
const val DEFAULT_IMU_MEDIAN_WINDOW_SIZE = 3
const val DEFAULT_GNSS_MEDIAN_WINDOW_SIZE = 3
const val DEFAULT_JERK_SLOPE_WINDOW_SIZE = 7
const val DEFAULT_ACCELERATION_FILTER_TIME_CONSTANT_NANOS = 200_000_000L
const val DEFAULT_YAW_RATE_FILTER_TIME_CONSTANT_NANOS = 150_000_000L
const val DEFAULT_SPEED_FILTER_TIME_CONSTANT_NANOS = 1_000_000_000L
const val DEFAULT_HEADING_RATE_FILTER_TIME_CONSTANT_NANOS = 500_000_000L
const val DEFAULT_MAXIMUM_CONTINUOUS_IMU_GAP_NANOS = 50_000_000L
const val DEFAULT_MAXIMUM_DERIVED_GNSS_SOURCE_AGE_NANOS = 2_000_000_000L
const val DEFAULT_MAXIMUM_HEADING_SAMPLE_GAP_NANOS = 2_000_000_000L
const val DEFAULT_MOVING_ENTER_SPEED_METRES_PER_SECOND = 1.5
const val DEFAULT_STOPPED_ENTER_SPEED_METRES_PER_SECOND = 0.5
const val DEFAULT_MOVING_CONFIRMATION_DURATION_NANOS = 1_000_000_000L
const val DEFAULT_STOPPED_CONFIRMATION_DURATION_NANOS = 2_000_000_000L
const val DEFAULT_MOVING_CONFIRMATION_SAMPLE_COUNT = 2
const val DEFAULT_STOPPED_CONFIRMATION_SAMPLE_COUNT = 3

data class DerivedTelemetryConfig(
    val derivedVersion: Int = DERIVED_TELEMETRY_VERSION,
    val imuMedianWindowSize: Int = DEFAULT_IMU_MEDIAN_WINDOW_SIZE,
    val gnssMedianWindowSize: Int = DEFAULT_GNSS_MEDIAN_WINDOW_SIZE,
    val jerkSlopeWindowSize: Int = DEFAULT_JERK_SLOPE_WINDOW_SIZE,
    val accelerationFilterTimeConstantNanos: Long =
        DEFAULT_ACCELERATION_FILTER_TIME_CONSTANT_NANOS,
    val yawRateFilterTimeConstantNanos: Long = DEFAULT_YAW_RATE_FILTER_TIME_CONSTANT_NANOS,
    val speedFilterTimeConstantNanos: Long = DEFAULT_SPEED_FILTER_TIME_CONSTANT_NANOS,
    val headingRateFilterTimeConstantNanos: Long =
        DEFAULT_HEADING_RATE_FILTER_TIME_CONSTANT_NANOS,
    val maximumContinuousImuGapNanos: Long = DEFAULT_MAXIMUM_CONTINUOUS_IMU_GAP_NANOS,
    val maximumGnssSourceAgeNanos: Long = DEFAULT_MAXIMUM_DERIVED_GNSS_SOURCE_AGE_NANOS,
    val maximumHeadingSampleGapNanos: Long = DEFAULT_MAXIMUM_HEADING_SAMPLE_GAP_NANOS,
    val movingEnterSpeedMetresPerSecond: Double =
        DEFAULT_MOVING_ENTER_SPEED_METRES_PER_SECOND,
    val stoppedEnterSpeedMetresPerSecond: Double =
        DEFAULT_STOPPED_ENTER_SPEED_METRES_PER_SECOND,
    val movingConfirmationDurationNanos: Long = DEFAULT_MOVING_CONFIRMATION_DURATION_NANOS,
    val stoppedConfirmationDurationNanos: Long = DEFAULT_STOPPED_CONFIRMATION_DURATION_NANOS,
    val movingConfirmationSampleCount: Int = DEFAULT_MOVING_CONFIRMATION_SAMPLE_COUNT,
    val stoppedConfirmationSampleCount: Int = DEFAULT_STOPPED_CONFIRMATION_SAMPLE_COUNT,
    val courseConfig: OrientationFrameTransformConfig = OrientationFrameTransformConfig(),
) {
    init {
        require(derivedVersion == DERIVED_TELEMETRY_VERSION)
        requireOddWindow(imuMedianWindowSize)
        requireOddWindow(gnssMedianWindowSize)
        requireOddWindow(jerkSlopeWindowSize)
        require(jerkSlopeWindowSize >= 5)
        require(accelerationFilterTimeConstantNanos > 0L)
        require(yawRateFilterTimeConstantNanos > 0L)
        require(speedFilterTimeConstantNanos > 0L)
        require(headingRateFilterTimeConstantNanos > 0L)
        require(maximumContinuousImuGapNanos > 0L)
        require(maximumGnssSourceAgeNanos > 0L)
        require(maximumHeadingSampleGapNanos > 0L)
        require(movingEnterSpeedMetresPerSecond.isFinite())
        require(stoppedEnterSpeedMetresPerSecond.isFinite())
        require(stoppedEnterSpeedMetresPerSecond >= 0.0)
        require(movingEnterSpeedMetresPerSecond > stoppedEnterSpeedMetresPerSecond)
        require(movingConfirmationDurationNanos >= 0L)
        require(stoppedConfirmationDurationNanos >= 0L)
        require(movingConfirmationSampleCount >= 2)
        require(stoppedConfirmationSampleCount >= 2)
    }

    private fun requireOddWindow(size: Int) {
        require(size >= 3 && size % 2 == 1)
    }
}

enum class DerivedChannelQuality {
    RESOLVED,
    DEGRADED,
}

enum class DerivedChannelEvidence {
    MEDIAN_PREFILTERED,
    LOW_PASS_FILTERED,
    ROBUST_MEDIAN_SLOPE,
    STATIONARY_REFERENCE_REMOVED,
    GYROSCOPE_BIAS_REMOVED,
    FIXED_GRAVITY_REFERENCE,
    IMU_INTERPOLATED,
    IMU_SENSOR_UNRELIABLE,
    IMU_RAW_QUALITY_FLAG,
    CALIBRATION_DEGRADED,
    MOUNT_ALIGNMENT_DEGRADED,
    GNSS_PLATFORM_SPEED,
    GNSS_GEODESIC_SPEED_FALLBACK,
    GNSS_SPEED_ACCURACY_UNAVAILABLE,
    GNSS_MOCK_LOCATION,
    GNSS_COURSE_DERIVATIVE,
    GNSS_SOURCE_HELD,
}

enum class DerivedChannelMissingReason {
    IMU_SOURCE_MISSING,
    CONTEXT_TIMELINE_GAP,
    CALIBRATION_INSUFFICIENT,
    CALIBRATION_AFTER_TARGET,
    CALIBRATION_MOUNT_MISMATCH,
    MOUNT_ALIGNMENT_UNAVAILABLE,
    FILTER_WARMUP,
    DERIVATIVE_WARMUP,
    GNSS_SOURCE_UNAVAILABLE,
    GNSS_SOURCE_REJECTED,
    GNSS_SPEED_UNAVAILABLE,
    GNSS_SPEED_IMPLAUSIBLE,
    GNSS_SOURCE_STALE,
    GNSS_COURSE_UNAVAILABLE,
}

data class DerivedChannelUnavailable(
    val reason: DerivedChannelMissingReason,
    val imuMissingReason: ImuMissingReason? = null,
    val mountUnavailableReason: VehicleMountAlignmentUnavailableReason? = null,
    val calibrationEvidence: Set<ImuCalibrationEvidence> = emptySet(),
    val gnssDecision: GnssDecision? = null,
    val gnssEvidence: Set<GnssProcessingEvidence> = emptySet(),
    val gnssRawQualityFlags: Set<GnssQualityFlag> = emptySet(),
    val gnssCourseUnavailableReason: GnssCourseUnavailableReason? = null,
)

data class DerivedChannelProvenance(
    val sourceStartTripElapsedNanos: Long,
    val sourceEndTripElapsedNanos: Long,
    val sourceStartTimestampNanos: Long,
    val sourceEndTimestampNanos: Long,
    val sourceSampleCount: Long,
    val minimumImuAccuracyStatus: Int? = null,
    val imuAlignments: Set<ImuAlignment> = emptySet(),
    val imuQualityFlags: Set<ImuQualityFlag> = emptySet(),
    val gnssDecisions: Set<GnssDecision> = emptySet(),
    val gnssEvidence: Set<GnssProcessingEvidence> = emptySet(),
    val gnssRawQualityFlags: Set<GnssQualityFlag> = emptySet(),
    val latestGnssSpeedAccuracyMetresPerSecond: Double? = null,
    val latestGnssBearingAccuracyDegrees: Double? = null,
    val calibrationStartTripElapsedNanos: Long? = null,
    val calibrationEndTripElapsedNanos: Long? = null,
    val calibrationState: ImuCalibrationState? = null,
    val calibrationEvidence: Set<ImuCalibrationEvidence> = emptySet(),
    val mountAlignmentQuality: VehicleMountAlignmentQuality? = null,
    val mountAlignmentEvidence: Set<VehicleMountAlignmentEvidence> = emptySet(),
) {
    init {
        require(sourceStartTripElapsedNanos >= 0L)
        require(sourceEndTripElapsedNanos >= sourceStartTripElapsedNanos)
        require(sourceStartTimestampNanos >= 0L)
        require(sourceEndTimestampNanos >= sourceStartTimestampNanos)
        require(sourceSampleCount > 0L)
        require(
            latestGnssSpeedAccuracyMetresPerSecond == null ||
                latestGnssSpeedAccuracyMetresPerSecond.isFinite() &&
                latestGnssSpeedAccuracyMetresPerSecond >= 0.0,
        )
        require(
            latestGnssBearingAccuracyDegrees == null ||
                latestGnssBearingAccuracyDegrees.isFinite() &&
                latestGnssBearingAccuracyDegrees >= 0.0,
        )
        require(
            (calibrationStartTripElapsedNanos == null) ==
                (calibrationEndTripElapsedNanos == null),
        )
        require((calibrationStartTripElapsedNanos == null) == (calibrationState == null))
        require((calibrationStartTripElapsedNanos == null) == (mountAlignmentQuality == null))
        if (calibrationStartTripElapsedNanos != null && calibrationEndTripElapsedNanos != null) {
            require(calibrationStartTripElapsedNanos >= 0L)
            require(calibrationEndTripElapsedNanos >= calibrationStartTripElapsedNanos)
        }
    }
}

sealed interface DerivedScalarValue {
    val targetTripElapsedNanos: Long

    data class Available(
        override val targetTripElapsedNanos: Long,
        val value: Double,
        val quality: DerivedChannelQuality,
        val provenance: DerivedChannelProvenance,
        val evidence: Set<DerivedChannelEvidence>,
    ) : DerivedScalarValue {
        init {
            require(targetTripElapsedNanos >= 0L)
            require(value.isFinite())
        }
    }

    data class Missing(
        override val targetTripElapsedNanos: Long,
        val unavailable: DerivedChannelUnavailable,
    ) : DerivedScalarValue {
        init {
            require(targetTripElapsedNanos >= 0L)
        }
    }
}

sealed interface DerivedVectorValue {
    val targetTripElapsedNanos: Long

    data class Available(
        override val targetTripElapsedNanos: Long,
        val value: FrameVector3,
        val quality: DerivedChannelQuality,
        val provenance: DerivedChannelProvenance,
        val evidence: Set<DerivedChannelEvidence>,
    ) : DerivedVectorValue {
        init {
            require(targetTripElapsedNanos >= 0L)
        }
    }

    data class Missing(
        override val targetTripElapsedNanos: Long,
        val unavailable: DerivedChannelUnavailable,
    ) : DerivedVectorValue {
        init {
            require(targetTripElapsedNanos >= 0L)
        }
    }
}

enum class MovementState {
    UNKNOWN,
    STOPPED,
    MOVING,
}

enum class MovementStateEvidence {
    SPEED_UNAVAILABLE,
    PENDING_STOPPED_CONFIRMATION,
    PENDING_MOVING_CONFIRMATION,
    CONFIRMED_STOPPED,
    CONFIRMED_MOVING,
    HYSTERESIS_HOLD,
    SPEED_DEGRADED,
}

data class DerivedMovementState(
    val targetTripElapsedNanos: Long,
    val state: MovementState,
    val quality: DerivedChannelQuality?,
    val supportingSampleCount: Int,
    val supportingDurationNanos: Long,
    val latestSpeedSourceTripElapsedNanos: Long?,
    val evidence: Set<MovementStateEvidence>,
) {
    init {
        require(targetTripElapsedNanos >= 0L)
        require(supportingSampleCount >= 0)
        require(supportingDurationNanos >= 0L)
        require(
            latestSpeedSourceTripElapsedNanos == null ||
                latestSpeedSourceTripElapsedNanos in 0L..targetTripElapsedNanos,
        )
        require((state == MovementState.UNKNOWN) == (quality == null))
    }
}

data class DerivedTelemetryFrame(
    val derivedVersion: Int = DERIVED_TELEMETRY_VERSION,
    val tripElapsedNanos: Long,
    val filteredSpeedMetresPerSecond: DerivedScalarValue,
    val vehicleAccelerationMetresPerSecondSquared: DerivedVectorValue,
    val vehicleJerkMetresPerSecondCubed: DerivedVectorValue,
    val yawRateRadiansPerSecond: DerivedScalarValue,
    val headingChangeRateRadiansPerSecond: DerivedScalarValue,
    val movementState: DerivedMovementState,
) {
    init {
        require(derivedVersion == DERIVED_TELEMETRY_VERSION)
        require(tripElapsedNanos >= 0L)
        require(filteredSpeedMetresPerSecond.targetTripElapsedNanos == tripElapsedNanos)
        require(vehicleAccelerationMetresPerSecondSquared.targetTripElapsedNanos == tripElapsedNanos)
        require(vehicleJerkMetresPerSecondCubed.targetTripElapsedNanos == tripElapsedNanos)
        require(yawRateRadiansPerSecond.targetTripElapsedNanos == tripElapsedNanos)
        require(headingChangeRateRadiansPerSecond.targetTripElapsedNanos == tripElapsedNanos)
        require(movementState.targetTripElapsedNanos == tripElapsedNanos)
    }
}

data class DerivedMotionContextSegment(
    val startTripElapsedNanos: Long,
    val endTripElapsedNanosExclusive: Long?,
    val calibrationResult: ImuStationaryCalibrationResult,
    val mountAlignment: VehicleMountAlignmentResolution,
) {
    init {
        require(startTripElapsedNanos >= 0L)
        require(
            endTripElapsedNanosExclusive == null ||
                endTripElapsedNanosExclusive > startTripElapsedNanos,
        )
    }
}

class DerivedMotionContextTimeline(segments: List<DerivedMotionContextSegment>) {
    val segments: List<DerivedMotionContextSegment> = segments.toList()

    init {
        this.segments.forEachIndexed { index, segment ->
            if (index > 0) {
                val previous = this.segments[index - 1]
                val previousEnd = requireNotNull(previous.endTripElapsedNanosExclusive) {
                    "Only the final derived-motion context segment may be open-ended"
                }
                require(segment.startTripElapsedNanos >= previousEnd)
            }
        }
    }

    companion object {
        fun fixed(
            calibrationResult: ImuStationaryCalibrationResult,
            mountAlignment: VehicleMountAlignmentResolution,
            startTripElapsedNanos: Long = 0L,
        ): DerivedMotionContextTimeline =
            DerivedMotionContextTimeline(
                listOf(
                    DerivedMotionContextSegment(
                        startTripElapsedNanos = startTripElapsedNanos,
                        endTripElapsedNanosExclusive = null,
                        calibrationResult = calibrationResult,
                        mountAlignment = mountAlignment,
                    ),
                ),
            )
    }
}

sealed interface DerivedTelemetryBuildResult {
    data class Success(val timeline: DerivedTelemetryTimeline) : DerivedTelemetryBuildResult

    data class Invalid(
        val errorCode: String,
        val sampleIndex: Int? = null,
    ) : DerivedTelemetryBuildResult
}
