package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

const val ORIENTATION_FRAME_TRANSFORM_VERSION = 1
const val DEFAULT_MINIMUM_HORIZONTAL_REFERENCE_NORM = 0.1
const val DEFAULT_MAXIMUM_GRAVITY_DIRECTION_CHANGE_DEGREES = 10.0
const val DEFAULT_MINIMUM_GNSS_HEADING_SPEED_METRES_PER_SECOND = 3.0
const val DEFAULT_MAXIMUM_GNSS_BEARING_ACCURACY_DEGREES = 30.0
const val DEFAULT_MAXIMUM_GNSS_HEADING_AGE_NANOS = 2_000_000_000L

data class OrientationFrameTransformConfig(
    val transformVersion: Int = ORIENTATION_FRAME_TRANSFORM_VERSION,
    val minimumHorizontalReferenceNorm: Double =
        DEFAULT_MINIMUM_HORIZONTAL_REFERENCE_NORM,
    val maximumGravityDirectionChangeDegrees: Double =
        DEFAULT_MAXIMUM_GRAVITY_DIRECTION_CHANGE_DEGREES,
    val minimumGnssHeadingSpeedMetresPerSecond: Double =
        DEFAULT_MINIMUM_GNSS_HEADING_SPEED_METRES_PER_SECOND,
    val maximumGnssBearingAccuracyDegrees: Double =
        DEFAULT_MAXIMUM_GNSS_BEARING_ACCURACY_DEGREES,
    val maximumGnssHeadingAgeNanos: Long = DEFAULT_MAXIMUM_GNSS_HEADING_AGE_NANOS,
) {
    init {
        require(transformVersion == ORIENTATION_FRAME_TRANSFORM_VERSION)
        require(minimumHorizontalReferenceNorm.isFinite())
        require(minimumHorizontalReferenceNorm > 0.0 && minimumHorizontalReferenceNorm < 1.0)
        require(maximumGravityDirectionChangeDegrees.isFinite())
        require(maximumGravityDirectionChangeDegrees > 0.0)
        require(maximumGravityDirectionChangeDegrees < 180.0)
        require(minimumGnssHeadingSpeedMetresPerSecond.isFinite())
        require(minimumGnssHeadingSpeedMetresPerSecond > 0.0)
        require(maximumGnssBearingAccuracyDegrees.isFinite())
        require(maximumGnssBearingAccuracyDegrees > 0.0)
        require(maximumGnssBearingAccuracyDegrees <= 180.0)
        require(maximumGnssHeadingAgeNanos > 0L)
    }
}

data class FrameVector3(
    val x: Double,
    val y: Double,
    val z: Double,
) {
    init {
        require(x.isFinite() && y.isFinite() && z.isFinite())
    }

    val magnitude: Double
        get() = sqrt(x * x + y * y + z * z)

    operator fun plus(other: FrameVector3): FrameVector3 =
        FrameVector3(x + other.x, y + other.y, z + other.z)

    operator fun minus(other: FrameVector3): FrameVector3 =
        FrameVector3(x - other.x, y - other.y, z - other.z)

    operator fun times(scale: Double): FrameVector3 {
        require(scale.isFinite())
        return FrameVector3(x * scale, y * scale, z * scale)
    }

    fun dot(other: FrameVector3): Double = x * other.x + y * other.y + z * other.z

    fun cross(other: FrameVector3): FrameVector3 =
        FrameVector3(
            x = y * other.z - z * other.y,
            y = z * other.x - x * other.z,
            z = x * other.y - y * other.x,
        )

    fun normalized(): FrameVector3 {
        require(magnitude > VECTOR_NORM_EPSILON)
        return this * (1.0 / magnitude)
    }

    fun projectedPerpendicularTo(unitAxis: FrameVector3): FrameVector3 =
        run {
            require(abs(unitAxis.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
            this - unitAxis * dot(unitAxis)
        }

    fun angleDegreesTo(other: FrameVector3): Double {
        val denominator = magnitude * other.magnitude
        require(denominator > VECTOR_NORM_EPSILON)
        return acos((dot(other) / denominator).coerceIn(-1.0, 1.0)) * 180.0 / PI
    }

    companion object {
        val DEVICE_RIGHT = FrameVector3(1.0, 0.0, 0.0)
        val DEVICE_TOP = FrameVector3(0.0, 1.0, 0.0)
        val DEVICE_SCREEN_OUT = FrameVector3(0.0, 0.0, 1.0)
        val ENU_EAST = FrameVector3(1.0, 0.0, 0.0)
        val ENU_NORTH = FrameVector3(0.0, 1.0, 0.0)
        val ENU_UP = FrameVector3(0.0, 0.0, 1.0)
    }
}

class FrameTransformMatrix private constructor(
    val row0: FrameVector3,
    val row1: FrameVector3,
    val row2: FrameVector3,
) {
    init {
        require(abs(row0.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(row1.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(row2.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(row0.dot(row1)) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(row0.dot(row2)) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(row1.dot(row2)) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(determinant - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
    }

    val determinant: Double
        get() = row0.dot(row1.cross(row2))

    fun transform(source: FrameVector3): FrameVector3 =
        FrameVector3(
            x = row0.dot(source),
            y = row1.dot(source),
            z = row2.dot(source),
        )

    operator fun times(sourceTransform: FrameTransformMatrix): FrameTransformMatrix {
        val column0 =
            FrameVector3(sourceTransform.row0.x, sourceTransform.row1.x, sourceTransform.row2.x)
        val column1 =
            FrameVector3(sourceTransform.row0.y, sourceTransform.row1.y, sourceTransform.row2.y)
        val column2 =
            FrameVector3(sourceTransform.row0.z, sourceTransform.row1.z, sourceTransform.row2.z)
        return ofRows(
            FrameVector3(row0.dot(column0), row0.dot(column1), row0.dot(column2)),
            FrameVector3(row1.dot(column0), row1.dot(column1), row1.dot(column2)),
            FrameVector3(row2.dot(column0), row2.dot(column1), row2.dot(column2)),
        )
    }

    companion object {
        fun ofRows(
            row0: FrameVector3,
            row1: FrameVector3,
            row2: FrameVector3,
        ): FrameTransformMatrix = FrameTransformMatrix(row0, row1, row2)

        fun identity(): FrameTransformMatrix =
            ofRows(
                FrameVector3.DEVICE_RIGHT,
                FrameVector3.DEVICE_TOP,
                FrameVector3.DEVICE_SCREEN_OUT,
            )
    }
}

enum class NavigationFrameConvention {
    EAST_NORTH_UP,
}

enum class VehicleFrameConvention {
    FORWARD_LEFT_UP,
}

enum class TiltOrientationQuality {
    RESOLVED,
    DEGRADED,
}

enum class TiltOrientationEvidence {
    CALIBRATION_DEGRADED,
    DEVICE_TOP_HORIZONTAL_REFERENCE,
    DEVICE_RIGHT_HORIZONTAL_REFERENCE_FALLBACK,
    GEOGRAPHIC_YAW_UNOBSERVABLE,
}

enum class TiltOrientationUnavailableReason {
    CALIBRATION_INSUFFICIENT,
}

data class TiltOrientation(
    val transformVersion: Int = ORIENTATION_FRAME_TRANSFORM_VERSION,
    val quality: TiltOrientationQuality,
    val sourceCalibrationStartTripElapsedNanos: Long,
    val sourceCalibrationEndTripElapsedNanos: Long,
    val upDevice: FrameVector3,
    val deviceToLeveledRightForwardUp: FrameTransformMatrix,
    val evidence: Set<TiltOrientationEvidence>,
) {
    init {
        require(transformVersion == ORIENTATION_FRAME_TRANSFORM_VERSION)
        require(sourceCalibrationStartTripElapsedNanos >= 0L)
        require(sourceCalibrationEndTripElapsedNanos >= sourceCalibrationStartTripElapsedNanos)
        require(abs(upDevice.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(TiltOrientationEvidence.GEOGRAPHIC_YAW_UNOBSERVABLE in evidence)
        require(
            (TiltOrientationEvidence.DEVICE_TOP_HORIZONTAL_REFERENCE in evidence) xor
                (TiltOrientationEvidence.DEVICE_RIGHT_HORIZONTAL_REFERENCE_FALLBACK in evidence),
        )
        require(
            (quality == TiltOrientationQuality.DEGRADED) ==
                (TiltOrientationEvidence.CALIBRATION_DEGRADED in evidence),
        )
    }
}

sealed interface TiltOrientationResolution {
    data class Available(val orientation: TiltOrientation) : TiltOrientationResolution

    data class Unavailable(
        val reason: TiltOrientationUnavailableReason,
        val calibrationEvidence: Set<ImuCalibrationEvidence>,
    ) : TiltOrientationResolution
}

object TiltOrientationResolver {
    fun resolve(
        calibrationResult: ImuStationaryCalibrationResult,
        config: OrientationFrameTransformConfig = OrientationFrameTransformConfig(),
    ): TiltOrientationResolution {
        val calibration = calibrationResult.calibration
            ?: return TiltOrientationResolution.Unavailable(
                reason = TiltOrientationUnavailableReason.CALIBRATION_INSUFFICIENT,
                calibrationEvidence = calibrationResult.evidence,
            )
        val up = calibration.gravityDirectionDevice.toFrameVector().normalized()
        val preferredForward = FrameVector3.DEVICE_TOP.projectedPerpendicularTo(up)
        val useFallback = preferredForward.magnitude < config.minimumHorizontalReferenceNorm
        val forwardSeed =
            if (useFallback) {
                FrameVector3.DEVICE_RIGHT.projectedPerpendicularTo(up)
            } else {
                preferredForward
            }
        val forward = forwardSeed.normalized()
        val right = forward.cross(up).normalized()
        val correctedForward = up.cross(right).normalized()
        val degraded = calibrationResult.state == ImuCalibrationState.CALIBRATED_DEGRADED
        val evidence = buildSet {
            add(TiltOrientationEvidence.GEOGRAPHIC_YAW_UNOBSERVABLE)
            add(
                if (useFallback) {
                    TiltOrientationEvidence.DEVICE_RIGHT_HORIZONTAL_REFERENCE_FALLBACK
                } else {
                    TiltOrientationEvidence.DEVICE_TOP_HORIZONTAL_REFERENCE
                },
            )
            if (degraded) add(TiltOrientationEvidence.CALIBRATION_DEGRADED)
        }
        return TiltOrientationResolution.Available(
            TiltOrientation(
                quality =
                    if (degraded) {
                        TiltOrientationQuality.DEGRADED
                    } else {
                        TiltOrientationQuality.RESOLVED
                    },
                sourceCalibrationStartTripElapsedNanos = calibration.startTripElapsedNanos,
                sourceCalibrationEndTripElapsedNanos = calibration.endTripElapsedNanos,
                upDevice = up,
                deviceToLeveledRightForwardUp =
                    FrameTransformMatrix.ofRows(right, correctedForward, up),
                evidence = evidence,
            ),
        )
    }
}

enum class OrientationChangeState {
    CONSISTENT,
    INVALIDATED,
    INDETERMINATE,
}

enum class OrientationChangeEvidence {
    GRAVITY_DIRECTION_CHANGED,
    SUBSEQUENT_CALIBRATION_DEGRADED,
    SUBSEQUENT_CALIBRATION_INSUFFICIENT,
    SUBSEQUENT_CALIBRATION_NOT_LATER,
    YAW_CHANGE_UNOBSERVABLE,
}

data class OrientationChangeResult(
    val transformVersion: Int = ORIENTATION_FRAME_TRANSFORM_VERSION,
    val state: OrientationChangeState,
    val referenceCalibrationStartTripElapsedNanos: Long,
    val referenceCalibrationEndTripElapsedNanos: Long,
    val subsequentCalibrationStartTripElapsedNanos: Long?,
    val subsequentCalibrationEndTripElapsedNanos: Long?,
    val gravityDirectionChangeDegrees: Double?,
    val evidence: Set<OrientationChangeEvidence>,
) {
    init {
        require(transformVersion == ORIENTATION_FRAME_TRANSFORM_VERSION)
        require(referenceCalibrationStartTripElapsedNanos >= 0L)
        require(
            referenceCalibrationEndTripElapsedNanos >=
                referenceCalibrationStartTripElapsedNanos,
        )
        require(
            (subsequentCalibrationStartTripElapsedNanos == null) ==
                (subsequentCalibrationEndTripElapsedNanos == null),
        )
        if (
            subsequentCalibrationStartTripElapsedNanos != null &&
            subsequentCalibrationEndTripElapsedNanos != null
        ) {
            require(subsequentCalibrationStartTripElapsedNanos >= 0L)
            require(
                subsequentCalibrationEndTripElapsedNanos >=
                    subsequentCalibrationStartTripElapsedNanos,
            )
        }
        require(
            gravityDirectionChangeDegrees == null ||
                gravityDirectionChangeDegrees.isFinite() &&
                gravityDirectionChangeDegrees in 0.0..180.0,
        )
        require(OrientationChangeEvidence.YAW_CHANGE_UNOBSERVABLE in evidence)
        require(
            (state == OrientationChangeState.INVALIDATED) ==
                (OrientationChangeEvidence.GRAVITY_DIRECTION_CHANGED in evidence),
        )
        require(
            (state == OrientationChangeState.INDETERMINATE) ==
                (gravityDirectionChangeDegrees == null),
        )
    }
}

object StationaryOrientationChangeDetector {
    fun compare(
        reference: TiltOrientation,
        subsequentCalibration: ImuStationaryCalibrationResult,
        config: OrientationFrameTransformConfig = OrientationFrameTransformConfig(),
    ): OrientationChangeResult {
        val subsequent = subsequentCalibration.calibration
            ?: return OrientationChangeResult(
                state = OrientationChangeState.INDETERMINATE,
                referenceCalibrationStartTripElapsedNanos =
                    reference.sourceCalibrationStartTripElapsedNanos,
                referenceCalibrationEndTripElapsedNanos =
                    reference.sourceCalibrationEndTripElapsedNanos,
                subsequentCalibrationStartTripElapsedNanos = null,
                subsequentCalibrationEndTripElapsedNanos = null,
                gravityDirectionChangeDegrees = null,
                evidence =
                    setOf(
                        OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_INSUFFICIENT,
                        OrientationChangeEvidence.YAW_CHANGE_UNOBSERVABLE,
                    ),
            )
        if (subsequent.startTripElapsedNanos <= reference.sourceCalibrationEndTripElapsedNanos) {
            return OrientationChangeResult(
                state = OrientationChangeState.INDETERMINATE,
                referenceCalibrationStartTripElapsedNanos =
                    reference.sourceCalibrationStartTripElapsedNanos,
                referenceCalibrationEndTripElapsedNanos =
                    reference.sourceCalibrationEndTripElapsedNanos,
                subsequentCalibrationStartTripElapsedNanos = subsequent.startTripElapsedNanos,
                subsequentCalibrationEndTripElapsedNanos = subsequent.endTripElapsedNanos,
                gravityDirectionChangeDegrees = null,
                evidence =
                    setOf(
                        OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_NOT_LATER,
                        OrientationChangeEvidence.YAW_CHANGE_UNOBSERVABLE,
                    ),
            )
        }
        val angle =
            reference.upDevice.angleDegreesTo(
                subsequent.gravityDirectionDevice.toFrameVector(),
            )
        val changed = angle > config.maximumGravityDirectionChangeDegrees
        return OrientationChangeResult(
            state =
                if (changed) {
                    OrientationChangeState.INVALIDATED
                } else {
                    OrientationChangeState.CONSISTENT
                },
            referenceCalibrationStartTripElapsedNanos =
                reference.sourceCalibrationStartTripElapsedNanos,
            referenceCalibrationEndTripElapsedNanos =
                reference.sourceCalibrationEndTripElapsedNanos,
            subsequentCalibrationStartTripElapsedNanos = subsequent.startTripElapsedNanos,
            subsequentCalibrationEndTripElapsedNanos = subsequent.endTripElapsedNanos,
            gravityDirectionChangeDegrees = angle,
            evidence = buildSet {
                add(OrientationChangeEvidence.YAW_CHANGE_UNOBSERVABLE)
                if (changed) add(OrientationChangeEvidence.GRAVITY_DIRECTION_CHANGED)
                if (subsequentCalibration.state == ImuCalibrationState.CALIBRATED_DEGRADED) {
                    add(OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_DEGRADED)
                }
            },
        )
    }
}

enum class VehicleMountAlignmentQuality {
    RESOLVED,
    DEGRADED,
}

enum class VehicleMountAlignmentEvidence {
    EXPLICIT_DEVICE_FORWARD_HINT,
    REFERENCE_CALIBRATION_DEGRADED,
    ORIENTATION_CHANGE_NOT_EVALUATED,
    ORIENTATION_CHANGE_INDETERMINATE,
    SUBSEQUENT_CALIBRATION_DEGRADED,
}

enum class VehicleMountAlignmentUnavailableReason {
    ORIENTATION_CHANGE_REFERENCE_MISMATCH,
    ORIENTATION_INVALIDATED,
    FORWARD_HINT_PARALLEL_TO_UP,
}

data class VehicleMountAlignment(
    val transformVersion: Int = ORIENTATION_FRAME_TRANSFORM_VERSION,
    val quality: VehicleMountAlignmentQuality,
    val sourceCalibrationStartTripElapsedNanos: Long,
    val sourceCalibrationEndTripElapsedNanos: Long,
    val forwardDevice: FrameVector3,
    val leftDevice: FrameVector3,
    val upDevice: FrameVector3,
    val deviceToVehicleForwardLeftUp: FrameTransformMatrix,
    val evidence: Set<VehicleMountAlignmentEvidence>,
) {
    init {
        require(transformVersion == ORIENTATION_FRAME_TRANSFORM_VERSION)
        require(sourceCalibrationStartTripElapsedNanos >= 0L)
        require(sourceCalibrationEndTripElapsedNanos >= sourceCalibrationStartTripElapsedNanos)
        require(VehicleMountAlignmentEvidence.EXPLICIT_DEVICE_FORWARD_HINT in evidence)
        require(abs(forwardDevice.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(leftDevice.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(upDevice.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(forwardDevice.cross(leftDevice).approximatelyEquals(upDevice))
        require(
            deviceToVehicleForwardLeftUp.transform(forwardDevice)
                .approximatelyEquals(FrameVector3(1.0, 0.0, 0.0)),
        )
        require(
            deviceToVehicleForwardLeftUp.transform(leftDevice)
                .approximatelyEquals(FrameVector3(0.0, 1.0, 0.0)),
        )
        require(
            deviceToVehicleForwardLeftUp.transform(upDevice)
                .approximatelyEquals(FrameVector3(0.0, 0.0, 1.0)),
        )
        require(
            (quality == VehicleMountAlignmentQuality.DEGRADED) ==
                evidence.any {
                    it == VehicleMountAlignmentEvidence.REFERENCE_CALIBRATION_DEGRADED ||
                        it == VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_NOT_EVALUATED ||
                        it == VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_INDETERMINATE ||
                        it == VehicleMountAlignmentEvidence.SUBSEQUENT_CALIBRATION_DEGRADED
                },
        )
    }
}

sealed interface VehicleMountAlignmentResolution {
    data class Available(val alignment: VehicleMountAlignment) : VehicleMountAlignmentResolution

    data class Unavailable(
        val reason: VehicleMountAlignmentUnavailableReason,
    ) : VehicleMountAlignmentResolution
}

object VehicleMountAlignmentResolver {
    fun resolve(
        orientation: TiltOrientation,
        explicitForwardHintDevice: FrameVector3,
        orientationChange: OrientationChangeResult? = null,
        config: OrientationFrameTransformConfig = OrientationFrameTransformConfig(),
    ): VehicleMountAlignmentResolution {
        if (
            orientationChange != null &&
            (orientationChange.referenceCalibrationStartTripElapsedNanos !=
                orientation.sourceCalibrationStartTripElapsedNanos ||
                orientationChange.referenceCalibrationEndTripElapsedNanos !=
                orientation.sourceCalibrationEndTripElapsedNanos)
        ) {
            return VehicleMountAlignmentResolution.Unavailable(
                VehicleMountAlignmentUnavailableReason.ORIENTATION_CHANGE_REFERENCE_MISMATCH,
            )
        }
        if (orientationChange?.state == OrientationChangeState.INVALIDATED) {
            return VehicleMountAlignmentResolution.Unavailable(
                VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED,
            )
        }
        val projectedForward = explicitForwardHintDevice.projectedPerpendicularTo(orientation.upDevice)
        if (projectedForward.magnitude < config.minimumHorizontalReferenceNorm) {
            return VehicleMountAlignmentResolution.Unavailable(
                VehicleMountAlignmentUnavailableReason.FORWARD_HINT_PARALLEL_TO_UP,
            )
        }
        val forward = projectedForward.normalized()
        val left = orientation.upDevice.cross(forward).normalized()
        val correctedForward = left.cross(orientation.upDevice).normalized()
        val changeState = orientationChange?.state
        val changeEvidence = orientationChange?.evidence.orEmpty()
        val degraded =
            orientation.quality == TiltOrientationQuality.DEGRADED ||
                orientationChange == null ||
                changeState == OrientationChangeState.INDETERMINATE ||
                OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_DEGRADED in changeEvidence
        val evidence = buildSet {
            add(VehicleMountAlignmentEvidence.EXPLICIT_DEVICE_FORWARD_HINT)
            if (orientation.quality == TiltOrientationQuality.DEGRADED) {
                add(VehicleMountAlignmentEvidence.REFERENCE_CALIBRATION_DEGRADED)
            }
            if (orientationChange == null) {
                add(VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_NOT_EVALUATED)
            }
            if (changeState == OrientationChangeState.INDETERMINATE) {
                add(VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_INDETERMINATE)
            }
            if (
                OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_DEGRADED in
                changeEvidence
            ) {
                add(VehicleMountAlignmentEvidence.SUBSEQUENT_CALIBRATION_DEGRADED)
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
                sourceCalibrationStartTripElapsedNanos =
                    orientation.sourceCalibrationStartTripElapsedNanos,
                sourceCalibrationEndTripElapsedNanos =
                    orientation.sourceCalibrationEndTripElapsedNanos,
                forwardDevice = correctedForward,
                leftDevice = left,
                upDevice = orientation.upDevice,
                deviceToVehicleForwardLeftUp =
                    FrameTransformMatrix.ofRows(
                        correctedForward,
                        left,
                        orientation.upDevice,
                    ),
                evidence = evidence,
            ),
        )
    }
}

enum class GnssCourseQuality {
    RESOLVED,
    DEGRADED,
}

enum class GnssCourseEvidence {
    MOCK_LOCATION_SIGNAL,
}

enum class GnssCourseUnavailableReason {
    GNSS_SAMPLE_REJECTED,
    BEARING_UNAVAILABLE,
    SPEED_UNAVAILABLE,
    SPEED_BELOW_HEADING_THRESHOLD,
    BEARING_ACCURACY_UNAVAILABLE,
    BEARING_ACCURACY_TOO_LOW,
    SOURCE_SPEED_IMPLAUSIBLE,
    COURSE_SOURCE_AFTER_TARGET,
    COURSE_TOO_OLD,
}

data class ResolvedGnssCourse(
    val transformVersion: Int = ORIENTATION_FRAME_TRANSFORM_VERSION,
    val quality: GnssCourseQuality,
    val targetTripElapsedNanos: Long,
    val sourceTripElapsedNanos: Long,
    val sourceAgeNanos: Long,
    val bearingDegreesEastOfTrueNorth: Double,
    val bearingAccuracyDegrees: Double,
    val speedMetresPerSecond: Double,
    val forwardEnu: FrameVector3,
    val leftEnu: FrameVector3,
    val vehicleForwardLeftUpToEnu: FrameTransformMatrix,
    val sourceDecision: GnssDecision,
    val sourceEvidence: Set<GnssProcessingEvidence>,
    val evidence: Set<GnssCourseEvidence>,
) {
    init {
        require(transformVersion == ORIENTATION_FRAME_TRANSFORM_VERSION)
        require(targetTripElapsedNanos >= 0L)
        require(sourceTripElapsedNanos >= 0L)
        require(sourceAgeNanos >= 0L)
        require(targetTripElapsedNanos - sourceTripElapsedNanos == sourceAgeNanos)
        require(bearingDegreesEastOfTrueNorth in 0.0..<360.0)
        require(bearingAccuracyDegrees.isFinite() && bearingAccuracyDegrees >= 0.0)
        require(speedMetresPerSecond.isFinite() && speedMetresPerSecond >= 0.0)
        require(abs(forwardEnu.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(leftEnu.magnitude - 1.0) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(abs(forwardEnu.dot(leftEnu)) <= MATRIX_ORTHONORMAL_TOLERANCE)
        require(
            vehicleForwardLeftUpToEnu.transform(FrameVector3(1.0, 0.0, 0.0))
                .approximatelyEquals(forwardEnu),
        )
        require(
            vehicleForwardLeftUpToEnu.transform(FrameVector3(0.0, 1.0, 0.0))
                .approximatelyEquals(leftEnu),
        )
        require(
            (quality == GnssCourseQuality.DEGRADED) ==
                (GnssCourseEvidence.MOCK_LOCATION_SIGNAL in evidence),
        )
    }
}

sealed interface GnssCourseResolution {
    data class Available(val course: ResolvedGnssCourse) : GnssCourseResolution

    data class Unavailable(
        val reason: GnssCourseUnavailableReason,
        val sourceDecision: GnssDecision,
        val sourceEvidence: Set<GnssProcessingEvidence>,
    ) : GnssCourseResolution
}

object GnssCourseResolver {
    fun resolve(
        sample: ProcessedGnssSample,
        targetTripElapsedNanos: Long,
        config: OrientationFrameTransformConfig = OrientationFrameTransformConfig(),
    ): GnssCourseResolution {
        require(targetTripElapsedNanos >= 0L)
        if (sample.decision !in USABLE_HEADING_DECISIONS) {
            return unavailable(GnssCourseUnavailableReason.GNSS_SAMPLE_REJECTED, sample)
        }
        if (
            GnssProcessingEvidence.RAW_LOW_ACCURACY in sample.evidence ||
            GnssProcessingEvidence.RAW_CLOCK_DISCONTINUITY in sample.evidence
        ) {
            return unavailable(GnssCourseUnavailableReason.GNSS_SAMPLE_REJECTED, sample)
        }
        if (GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE in sample.evidence) {
            return unavailable(GnssCourseUnavailableReason.SOURCE_SPEED_IMPLAUSIBLE, sample)
        }
        val raw = sample.rawSample
        val sourceTripElapsedNanos = requireNotNull(raw.tripElapsedNanos)
        if (sourceTripElapsedNanos > targetTripElapsedNanos) {
            return unavailable(GnssCourseUnavailableReason.COURSE_SOURCE_AFTER_TARGET, sample)
        }
        val sourceAgeNanos = targetTripElapsedNanos - sourceTripElapsedNanos
        if (sourceAgeNanos > config.maximumGnssHeadingAgeNanos) {
            return unavailable(GnssCourseUnavailableReason.COURSE_TOO_OLD, sample)
        }
        val bearing = raw.bearingDegrees?.toDouble()
            ?: return unavailable(GnssCourseUnavailableReason.BEARING_UNAVAILABLE, sample)
        val speed = raw.speedMetresPerSecond?.toDouble()
            ?: return unavailable(GnssCourseUnavailableReason.SPEED_UNAVAILABLE, sample)
        if (speed < config.minimumGnssHeadingSpeedMetresPerSecond) {
            return unavailable(
                GnssCourseUnavailableReason.SPEED_BELOW_HEADING_THRESHOLD,
                sample,
            )
        }
        val accuracy = raw.bearingAccuracyDegrees?.toDouble()
            ?: return unavailable(
                GnssCourseUnavailableReason.BEARING_ACCURACY_UNAVAILABLE,
                sample,
            )
        if (accuracy > config.maximumGnssBearingAccuracyDegrees) {
            return unavailable(GnssCourseUnavailableReason.BEARING_ACCURACY_TOO_LOW, sample)
        }

        val radians = bearing * PI / 180.0
        val forward = FrameVector3(sin(radians), cos(radians), 0.0).normalized()
        val left = FrameVector3.ENU_UP.cross(forward).normalized()
        val degraded =
            raw.isMockSignal || GnssQualityFlag.MOCK_LOCATION_SIGNAL in raw.qualityFlags
        return GnssCourseResolution.Available(
            ResolvedGnssCourse(
                quality =
                    if (degraded) {
                        GnssCourseQuality.DEGRADED
                    } else {
                        GnssCourseQuality.RESOLVED
                    },
                targetTripElapsedNanos = targetTripElapsedNanos,
                sourceTripElapsedNanos = sourceTripElapsedNanos,
                sourceAgeNanos = sourceAgeNanos,
                bearingDegreesEastOfTrueNorth = bearing,
                bearingAccuracyDegrees = accuracy,
                speedMetresPerSecond = speed,
                forwardEnu = forward,
                leftEnu = left,
                vehicleForwardLeftUpToEnu =
                    FrameTransformMatrix.ofRows(
                        FrameVector3(sin(radians), -cos(radians), 0.0),
                        FrameVector3(cos(radians), sin(radians), 0.0),
                        FrameVector3.ENU_UP,
                    ),
                sourceDecision = sample.decision,
                sourceEvidence = sample.evidence,
                evidence =
                    if (degraded) {
                        setOf(GnssCourseEvidence.MOCK_LOCATION_SIGNAL)
                    } else {
                        emptySet()
                    },
            ),
        )
    }

    private fun unavailable(
        reason: GnssCourseUnavailableReason,
        sample: ProcessedGnssSample,
    ): GnssCourseResolution.Unavailable =
        GnssCourseResolution.Unavailable(
            reason = reason,
            sourceDecision = sample.decision,
            sourceEvidence = sample.evidence,
        )

    private val USABLE_HEADING_DECISIONS =
        setOf(
            GnssDecision.ACCEPTED_ANCHOR,
            GnssDecision.ACCEPTED_RESOLVED_DISTANCE,
            GnssDecision.ACCEPTED_MOTION_SUPPORTED_DISTANCE,
            GnssDecision.RESET_AFTER_GAP,
        )
}

enum class WorldFrameTransformQuality {
    RESOLVED,
    DEGRADED,
}

enum class WorldFrameTransformEvidence {
    MOUNT_ALIGNMENT_DEGRADED,
    GNSS_COURSE_DEGRADED,
}

enum class WorldFrameTransformUnavailableReason {
    MOUNT_ALIGNMENT_UNAVAILABLE,
    GNSS_COURSE_UNAVAILABLE,
    MOUNT_CALIBRATION_AFTER_TARGET,
}

data class WorldFrameTransform(
    val transformVersion: Int = ORIENTATION_FRAME_TRANSFORM_VERSION,
    val quality: WorldFrameTransformQuality,
    val navigationConvention: NavigationFrameConvention = NavigationFrameConvention.EAST_NORTH_UP,
    val vehicleConvention: VehicleFrameConvention = VehicleFrameConvention.FORWARD_LEFT_UP,
    val targetTripElapsedNanos: Long,
    val mountCalibrationEndTripElapsedNanos: Long,
    val gnssCourseSourceTripElapsedNanos: Long,
    val deviceToVehicleForwardLeftUp: FrameTransformMatrix,
    val vehicleForwardLeftUpToEnu: FrameTransformMatrix,
    val deviceToWorldEnu: FrameTransformMatrix,
    val mountAlignmentEvidence: Set<VehicleMountAlignmentEvidence>,
    val gnssCourseEvidence: Set<GnssCourseEvidence>,
    val evidence: Set<WorldFrameTransformEvidence>,
) {
    init {
        require(transformVersion == ORIENTATION_FRAME_TRANSFORM_VERSION)
        require(targetTripElapsedNanos >= 0L)
        require(mountCalibrationEndTripElapsedNanos >= 0L)
        require(mountCalibrationEndTripElapsedNanos <= targetTripElapsedNanos)
        require(gnssCourseSourceTripElapsedNanos in 0L..targetTripElapsedNanos)
        require(
            deviceToWorldEnu.approximatelyEquals(
                vehicleForwardLeftUpToEnu * deviceToVehicleForwardLeftUp,
            ),
        )
        require(
            (quality == WorldFrameTransformQuality.DEGRADED) == evidence.isNotEmpty(),
        )
    }
}

sealed interface WorldFrameTransformResolution {
    data class Available(val transform: WorldFrameTransform) : WorldFrameTransformResolution

    data class Unavailable(
        val reason: WorldFrameTransformUnavailableReason,
        val mountReason: VehicleMountAlignmentUnavailableReason? = null,
        val courseReason: GnssCourseUnavailableReason? = null,
    ) : WorldFrameTransformResolution
}

object WorldFrameTransformResolver {
    fun resolve(
        mountAlignment: VehicleMountAlignmentResolution,
        gnssCourse: GnssCourseResolution,
    ): WorldFrameTransformResolution {
        val mount =
            when (mountAlignment) {
                is VehicleMountAlignmentResolution.Available -> mountAlignment.alignment
                is VehicleMountAlignmentResolution.Unavailable ->
                    return WorldFrameTransformResolution.Unavailable(
                        reason = WorldFrameTransformUnavailableReason.MOUNT_ALIGNMENT_UNAVAILABLE,
                        mountReason = mountAlignment.reason,
                    )
            }
        val course =
            when (gnssCourse) {
                is GnssCourseResolution.Available -> gnssCourse.course
                is GnssCourseResolution.Unavailable ->
                    return WorldFrameTransformResolution.Unavailable(
                        reason = WorldFrameTransformUnavailableReason.GNSS_COURSE_UNAVAILABLE,
                        courseReason = gnssCourse.reason,
                    )
            }
        if (mount.sourceCalibrationEndTripElapsedNanos > course.targetTripElapsedNanos) {
            return WorldFrameTransformResolution.Unavailable(
                reason = WorldFrameTransformUnavailableReason.MOUNT_CALIBRATION_AFTER_TARGET,
            )
        }
        val evidence = buildSet {
            if (mount.quality == VehicleMountAlignmentQuality.DEGRADED) {
                add(WorldFrameTransformEvidence.MOUNT_ALIGNMENT_DEGRADED)
            }
            if (course.quality == GnssCourseQuality.DEGRADED) {
                add(WorldFrameTransformEvidence.GNSS_COURSE_DEGRADED)
            }
        }
        return WorldFrameTransformResolution.Available(
            WorldFrameTransform(
                quality =
                    if (evidence.isEmpty()) {
                        WorldFrameTransformQuality.RESOLVED
                    } else {
                        WorldFrameTransformQuality.DEGRADED
                    },
                targetTripElapsedNanos = course.targetTripElapsedNanos,
                mountCalibrationEndTripElapsedNanos =
                    mount.sourceCalibrationEndTripElapsedNanos,
                gnssCourseSourceTripElapsedNanos = course.sourceTripElapsedNanos,
                deviceToVehicleForwardLeftUp = mount.deviceToVehicleForwardLeftUp,
                vehicleForwardLeftUpToEnu = course.vehicleForwardLeftUpToEnu,
                deviceToWorldEnu =
                    course.vehicleForwardLeftUpToEnu *
                        mount.deviceToVehicleForwardLeftUp,
                mountAlignmentEvidence = mount.evidence,
                gnssCourseEvidence = course.evidence,
                evidence = evidence,
            ),
        )
    }
}

private fun CalibrationVector3.toFrameVector(): FrameVector3 = FrameVector3(x, y, z)

private fun FrameVector3.approximatelyEquals(other: FrameVector3): Boolean =
    abs(x - other.x) <= MATRIX_ORTHONORMAL_TOLERANCE &&
        abs(y - other.y) <= MATRIX_ORTHONORMAL_TOLERANCE &&
        abs(z - other.z) <= MATRIX_ORTHONORMAL_TOLERANCE

private fun FrameTransformMatrix.approximatelyEquals(other: FrameTransformMatrix): Boolean =
    row0.approximatelyEquals(other.row0) &&
        row1.approximatelyEquals(other.row1) &&
        row2.approximatelyEquals(other.row2)

private const val VECTOR_NORM_EPSILON = 1e-12
private const val MATRIX_ORTHONORMAL_TOLERANCE = 1e-9
