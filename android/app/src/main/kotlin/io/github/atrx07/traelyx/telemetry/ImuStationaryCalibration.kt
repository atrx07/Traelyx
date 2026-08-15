package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.RawImuSample
import java.util.ArrayDeque
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

const val IMU_STATIONARY_CALIBRATION_VERSION = 1
const val STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED = 9.80665
const val DEFAULT_MIN_STATIONARY_DURATION_NANOS = 2_000_000_000L
const val DEFAULT_MAX_ACCELEROMETER_GRAVITY_DEVIATION_METRES_PER_SECOND_SQUARED = 0.75
const val DEFAULT_MAX_GYROSCOPE_MAGNITUDE_RADIANS_PER_SECOND = 0.05
const val DEFAULT_MAX_ACCELEROMETER_AXIS_STANDARD_DEVIATION_METRES_PER_SECOND_SQUARED = 0.15
const val DEFAULT_MAX_GYROSCOPE_AXIS_STANDARD_DEVIATION_RADIANS_PER_SECOND = 0.01

data class ImuStationaryCalibrationConfig(
    val calibrationVersion: Int = IMU_STATIONARY_CALIBRATION_VERSION,
    val standardGravityMetresPerSecondSquared: Double =
        STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED,
    val minimumStationaryDurationNanos: Long = DEFAULT_MIN_STATIONARY_DURATION_NANOS,
    val maxAccelerometerGravityDeviationMetresPerSecondSquared: Double =
        DEFAULT_MAX_ACCELEROMETER_GRAVITY_DEVIATION_METRES_PER_SECOND_SQUARED,
    val maxGyroscopeMagnitudeRadiansPerSecond: Double =
        DEFAULT_MAX_GYROSCOPE_MAGNITUDE_RADIANS_PER_SECOND,
    val maxAccelerometerAxisStandardDeviationMetresPerSecondSquared: Double =
        DEFAULT_MAX_ACCELEROMETER_AXIS_STANDARD_DEVIATION_METRES_PER_SECOND_SQUARED,
    val maxGyroscopeAxisStandardDeviationRadiansPerSecond: Double =
        DEFAULT_MAX_GYROSCOPE_AXIS_STANDARD_DEVIATION_RADIANS_PER_SECOND,
) {
    init {
        require(calibrationVersion == IMU_STATIONARY_CALIBRATION_VERSION)
        require(standardGravityMetresPerSecondSquared.isFinite())
        require(standardGravityMetresPerSecondSquared > 0.0)
        require(minimumStationaryDurationNanos > 0L)
        require(maxAccelerometerGravityDeviationMetresPerSecondSquared.isFinite())
        require(maxAccelerometerGravityDeviationMetresPerSecondSquared >= 0.0)
        require(maxGyroscopeMagnitudeRadiansPerSecond.isFinite())
        require(maxGyroscopeMagnitudeRadiansPerSecond >= 0.0)
        require(maxAccelerometerAxisStandardDeviationMetresPerSecondSquared.isFinite())
        require(maxAccelerometerAxisStandardDeviationMetresPerSecondSquared > 0.0)
        require(maxGyroscopeAxisStandardDeviationRadiansPerSecond.isFinite())
        require(maxGyroscopeAxisStandardDeviationRadiansPerSecond > 0.0)
    }
}

data class CalibrationVector3(
    val x: Double,
    val y: Double,
    val z: Double,
) {
    init {
        require(x.isFinite() && y.isFinite() && z.isFinite())
    }

    val magnitude: Double
        get() = sqrt(x * x + y * y + z * z)

    operator fun times(scale: Double): CalibrationVector3 {
        require(scale.isFinite())
        return CalibrationVector3(x * scale, y * scale, z * scale)
    }
}

enum class ImuCalibrationState {
    CALIBRATED,
    CALIBRATED_DEGRADED,
    INSUFFICIENT_EVIDENCE,
}

enum class ImuCalibrationEvidence {
    ACCELEROMETER_MISSING,
    GYROSCOPE_MISSING,
    SOURCE_DISCONTINUITY,
    ACCELEROMETER_NOT_GRAVITY_LIKE,
    GYROSCOPE_MOTION,
    ACCELEROMETER_UNSTABLE,
    GYROSCOPE_UNSTABLE,
    INSUFFICIENT_STATIONARY_DURATION,
    SENSOR_UNRELIABLE,
    INTERPOLATED_INPUT,
}

data class ImuCalibrationDiagnostics(
    val totalFrameCount: Long,
    val pairedAvailableFrameCount: Long,
    val stationaryCandidateFrameCount: Long,
    val longestCandidateDurationNanos: Long,
    val accelerometerMissingFrameCount: Long,
    val gyroscopeMissingFrameCount: Long,
    val sourceDiscontinuityFrameCount: Long,
    val accelerometerNotGravityLikeFrameCount: Long,
    val gyroscopeMotionFrameCount: Long,
    val unstableWindowCount: Long,
) {
    init {
        require(
            listOf(
                totalFrameCount,
                pairedAvailableFrameCount,
                stationaryCandidateFrameCount,
                longestCandidateDurationNanos,
                accelerometerMissingFrameCount,
                gyroscopeMissingFrameCount,
                sourceDiscontinuityFrameCount,
                accelerometerNotGravityLikeFrameCount,
                gyroscopeMotionFrameCount,
                unstableWindowCount,
            ).all { it >= 0L },
        )
        require(pairedAvailableFrameCount <= totalFrameCount)
        require(stationaryCandidateFrameCount <= pairedAvailableFrameCount)
    }
}

data class ImuBiasCalibration(
    val calibrationVersion: Int = IMU_STATIONARY_CALIBRATION_VERSION,
    val startTripElapsedNanos: Long,
    val endTripElapsedNanos: Long,
    val sampleCount: Int,
    val meanAccelerometerDeviceMetresPerSecondSquared: CalibrationVector3,
    val gravityDirectionDevice: CalibrationVector3,
    val observableAccelerometerRadialBiasMetresPerSecondSquared: Double,
    val observableAccelerometerRadialBiasDeviceMetresPerSecondSquared: CalibrationVector3,
    val gyroscopeBiasDeviceRadiansPerSecond: CalibrationVector3,
    val accelerometerAxisStandardDeviationMetresPerSecondSquared: CalibrationVector3,
    val gyroscopeAxisStandardDeviationRadiansPerSecond: CalibrationVector3,
    val accelerometerMinimumAccuracyStatus: Int,
    val gyroscopeMinimumAccuracyStatus: Int,
    val accelerometerInterpolatedFrameCount: Int,
    val gyroscopeInterpolatedFrameCount: Int,
    val rawQualityFlags: Set<ImuQualityFlag>,
) {
    init {
        require(calibrationVersion == IMU_STATIONARY_CALIBRATION_VERSION)
        require(startTripElapsedNanos >= 0L)
        require(endTripElapsedNanos >= startTripElapsedNanos)
        require(sampleCount >= 2)
        require(observableAccelerometerRadialBiasMetresPerSecondSquared.isFinite())
        require(
            accelerometerMinimumAccuracyStatus in
                RawImuSample.MIN_SENSOR_ACCURACY_STATUS..RawImuSample.MAX_SENSOR_ACCURACY_STATUS,
        )
        require(
            gyroscopeMinimumAccuracyStatus in
                RawImuSample.MIN_SENSOR_ACCURACY_STATUS..RawImuSample.MAX_SENSOR_ACCURACY_STATUS,
        )
        require(accelerometerInterpolatedFrameCount in 0..sampleCount)
        require(gyroscopeInterpolatedFrameCount in 0..sampleCount)
        require(abs(gravityDirectionDevice.magnitude - 1.0) <= 1e-9)
        require(
            listOf(
                accelerometerAxisStandardDeviationMetresPerSecondSquared.x,
                accelerometerAxisStandardDeviationMetresPerSecondSquared.y,
                accelerometerAxisStandardDeviationMetresPerSecondSquared.z,
                gyroscopeAxisStandardDeviationRadiansPerSecond.x,
                gyroscopeAxisStandardDeviationRadiansPerSecond.y,
                gyroscopeAxisStandardDeviationRadiansPerSecond.z,
            ).all { it >= 0.0 },
        )
    }
}

data class ImuStationaryCalibrationResult(
    val state: ImuCalibrationState,
    val config: ImuStationaryCalibrationConfig,
    val calibration: ImuBiasCalibration?,
    val evidence: Set<ImuCalibrationEvidence>,
    val diagnostics: ImuCalibrationDiagnostics,
) {
    init {
        require((state == ImuCalibrationState.INSUFFICIENT_EVIDENCE) == (calibration == null))
        require(
            state == ImuCalibrationState.INSUFFICIENT_EVIDENCE ||
                (state == ImuCalibrationState.CALIBRATED_DEGRADED) ==
                    (ImuCalibrationEvidence.SENSOR_UNRELIABLE in evidence),
        )
        require(
            state != ImuCalibrationState.INSUFFICIENT_EVIDENCE || evidence.isNotEmpty(),
        )
    }
}

/**
 * Finds the quietest bounded stationary candidate on the aligned native timeline.
 *
 * A single stationary orientation identifies zero-rate gyroscope bias and only
 * the accelerometer bias component parallel to the observed gravity vector. The
 * raw device-frame samples, status, and flags remain unchanged and authoritative.
 */
object ImuStationaryCalibrator {
    fun calibrate(
        timeline: AnalysisTimeline,
        config: ImuStationaryCalibrationConfig = ImuStationaryCalibrationConfig(),
    ): ImuStationaryCalibrationResult =
        calibrate(
            frames = timeline.frames(),
            analysisIntervalNanos = timeline.config.intervalNanos,
            config = config,
        )

    internal fun calibrate(
        frames: Sequence<AnalysisTimelineFrame>,
        analysisIntervalNanos: Long,
        config: ImuStationaryCalibrationConfig = ImuStationaryCalibrationConfig(),
    ): ImuStationaryCalibrationResult {
        require(analysisIntervalNanos > 0L)
        val minimumIntervals =
            ceilingDivide(config.minimumStationaryDurationNanos, analysisIntervalNanos)
        val minimumSampleCountLong = minimumIntervals + 1L
        require(minimumSampleCountLong in 2L..Int.MAX_VALUE.toLong())
        val minimumSampleCount = minimumSampleCountLong.toInt()

        val observedEvidence = mutableSetOf<ImuCalibrationEvidence>()
        val window = RollingCalibrationWindow(minimumSampleCount)
        var best: WindowSnapshot? = null
        var currentCandidateStartNanos: Long? = null
        var longestCandidateDurationNanos = 0L
        var totalFrameCount = 0L
        var pairedAvailableFrameCount = 0L
        var stationaryCandidateFrameCount = 0L
        var accelerometerMissingFrameCount = 0L
        var gyroscopeMissingFrameCount = 0L
        var sourceDiscontinuityFrameCount = 0L
        var accelerometerNotGravityLikeFrameCount = 0L
        var gyroscopeMotionFrameCount = 0L
        var unstableWindowCount = 0L
        var previousFrameElapsedNanos: Long? = null

        fun breakCandidate() {
            window.clear()
            currentCandidateStartNanos = null
        }

        for (frame in frames) {
            val previousElapsed = previousFrameElapsedNanos
            require(
                previousElapsed == null ||
                    (frame.tripElapsedNanos > previousElapsed &&
                        frame.tripElapsedNanos - previousElapsed == analysisIntervalNanos),
            )
            previousFrameElapsedNanos = frame.tripElapsedNanos
            totalFrameCount++
            val accelerometer =
                frame.accelerometerDeviceMetresPerSecondSquared as? ResampledImuValue.Available
            val gyroscope =
                frame.gyroscopeDeviceRadiansPerSecond as? ResampledImuValue.Available
            if (
                accelerometer?.hasUnreliableEvidence() == true ||
                gyroscope?.hasUnreliableEvidence() == true
            ) {
                observedEvidence += ImuCalibrationEvidence.SENSOR_UNRELIABLE
            }
            if (
                accelerometer?.alignment == ImuAlignment.INTERPOLATED ||
                gyroscope?.alignment == ImuAlignment.INTERPOLATED
            ) {
                observedEvidence += ImuCalibrationEvidence.INTERPOLATED_INPUT
            }
            if (accelerometer == null || gyroscope == null) {
                if (accelerometer == null) {
                    accelerometerMissingFrameCount++
                    observedEvidence += ImuCalibrationEvidence.ACCELEROMETER_MISSING
                }
                if (gyroscope == null) {
                    gyroscopeMissingFrameCount++
                    observedEvidence += ImuCalibrationEvidence.GYROSCOPE_MISSING
                }
                breakCandidate()
                continue
            }
            pairedAvailableFrameCount++

            if (accelerometer.hasDiscontinuityEvidence() || gyroscope.hasDiscontinuityEvidence()) {
                sourceDiscontinuityFrameCount++
                observedEvidence += ImuCalibrationEvidence.SOURCE_DISCONTINUITY
                breakCandidate()
                continue
            }

            val accelerometerVector = accelerometer.vector()
            if (
                abs(
                    accelerometerVector.magnitude -
                        config.standardGravityMetresPerSecondSquared,
                ) > config.maxAccelerometerGravityDeviationMetresPerSecondSquared
            ) {
                accelerometerNotGravityLikeFrameCount++
                observedEvidence += ImuCalibrationEvidence.ACCELEROMETER_NOT_GRAVITY_LIKE
                breakCandidate()
                continue
            }

            val gyroscopeVector = gyroscope.vector()
            if (gyroscopeVector.magnitude > config.maxGyroscopeMagnitudeRadiansPerSecond) {
                gyroscopeMotionFrameCount++
                observedEvidence += ImuCalibrationEvidence.GYROSCOPE_MOTION
                breakCandidate()
                continue
            }

            stationaryCandidateFrameCount++
            val candidateStart = currentCandidateStartNanos ?: frame.tripElapsedNanos
            currentCandidateStartNanos = candidateStart
            longestCandidateDurationNanos =
                max(longestCandidateDurationNanos, frame.tripElapsedNanos - candidateStart)
            window.add(
                CalibrationFrame(
                    tripElapsedNanos = frame.tripElapsedNanos,
                    accelerometer = accelerometerVector,
                    gyroscope = gyroscopeVector,
                    accelerometerAlignment = accelerometer.alignment,
                    gyroscopeAlignment = gyroscope.alignment,
                    accelerometerAccuracyStatus = accelerometer.accuracyStatus,
                    gyroscopeAccuracyStatus = gyroscope.accuracyStatus,
                    rawQualityFlags = accelerometer.qualityFlags + gyroscope.qualityFlags,
                ),
            )
            if (!window.isFull) continue

            val statistics = window.statistics()
            val accelerometerStable =
                statistics.accelerometerStandardDeviation.maxAxis() <=
                    config.maxAccelerometerAxisStandardDeviationMetresPerSecondSquared &&
                    abs(
                        statistics.accelerometerMean.magnitude -
                            config.standardGravityMetresPerSecondSquared,
                    ) <= config.maxAccelerometerGravityDeviationMetresPerSecondSquared
            val gyroscopeStable =
                statistics.gyroscopeStandardDeviation.maxAxis() <=
                    config.maxGyroscopeAxisStandardDeviationRadiansPerSecond
            if (!accelerometerStable || !gyroscopeStable) {
                unstableWindowCount++
                if (!accelerometerStable) {
                    observedEvidence += ImuCalibrationEvidence.ACCELEROMETER_UNSTABLE
                }
                if (!gyroscopeStable) {
                    observedEvidence += ImuCalibrationEvidence.GYROSCOPE_UNSTABLE
                }
                continue
            }

            val score =
                statistics.accelerometerStandardDeviation.maxAxis() /
                    config.maxAccelerometerAxisStandardDeviationMetresPerSecondSquared +
                    statistics.gyroscopeStandardDeviation.maxAxis() /
                    config.maxGyroscopeAxisStandardDeviationRadiansPerSecond
            val currentBest = best
            if (currentBest == null || score < currentBest.score) {
                best = window.snapshot(score, statistics)
            }
        }

        val diagnostics =
            ImuCalibrationDiagnostics(
                totalFrameCount = totalFrameCount,
                pairedAvailableFrameCount = pairedAvailableFrameCount,
                stationaryCandidateFrameCount = stationaryCandidateFrameCount,
                longestCandidateDurationNanos = longestCandidateDurationNanos,
                accelerometerMissingFrameCount = accelerometerMissingFrameCount,
                gyroscopeMissingFrameCount = gyroscopeMissingFrameCount,
                sourceDiscontinuityFrameCount = sourceDiscontinuityFrameCount,
                accelerometerNotGravityLikeFrameCount =
                    accelerometerNotGravityLikeFrameCount,
                gyroscopeMotionFrameCount = gyroscopeMotionFrameCount,
                unstableWindowCount = unstableWindowCount,
            )
        val selected = best
        if (selected == null) {
            if (longestCandidateDurationNanos < config.minimumStationaryDurationNanos) {
                observedEvidence += ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION
            }
            if (observedEvidence.isEmpty()) {
                observedEvidence += ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION
            }
            return ImuStationaryCalibrationResult(
                state = ImuCalibrationState.INSUFFICIENT_EVIDENCE,
                config = config,
                calibration = null,
                evidence = observedEvidence.toSet(),
                diagnostics = diagnostics,
            )
        }

        val selectedFlags = selected.frames.flatMapTo(mutableSetOf()) { it.rawQualityFlags }
        val selectedEvidence = mutableSetOf<ImuCalibrationEvidence>()
        val sensorUnreliable =
            ImuQualityFlag.SENSOR_UNRELIABLE in selectedFlags ||
                selected.frames.any {
                    it.accelerometerAccuracyStatus <= RawImuSample.SENSOR_STATUS_UNRELIABLE ||
                        it.gyroscopeAccuracyStatus <= RawImuSample.SENSOR_STATUS_UNRELIABLE
                }
        if (sensorUnreliable) selectedEvidence += ImuCalibrationEvidence.SENSOR_UNRELIABLE
        if (
            selected.frames.any {
                it.accelerometerAlignment == ImuAlignment.INTERPOLATED ||
                    it.gyroscopeAlignment == ImuAlignment.INTERPOLATED
            }
        ) {
            selectedEvidence += ImuCalibrationEvidence.INTERPOLATED_INPUT
        }

        val meanAccelerometer = selected.statistics.accelerometerMean
        val gravityDirection = meanAccelerometer * (1.0 / meanAccelerometer.magnitude)
        val radialBias =
            meanAccelerometer.magnitude - config.standardGravityMetresPerSecondSquared
        val calibration =
            ImuBiasCalibration(
                startTripElapsedNanos = selected.frames.first().tripElapsedNanos,
                endTripElapsedNanos = selected.frames.last().tripElapsedNanos,
                sampleCount = selected.frames.size,
                meanAccelerometerDeviceMetresPerSecondSquared = meanAccelerometer,
                gravityDirectionDevice = gravityDirection,
                observableAccelerometerRadialBiasMetresPerSecondSquared = radialBias,
                observableAccelerometerRadialBiasDeviceMetresPerSecondSquared =
                    gravityDirection * radialBias,
                gyroscopeBiasDeviceRadiansPerSecond = selected.statistics.gyroscopeMean,
                accelerometerAxisStandardDeviationMetresPerSecondSquared =
                    selected.statistics.accelerometerStandardDeviation,
                gyroscopeAxisStandardDeviationRadiansPerSecond =
                    selected.statistics.gyroscopeStandardDeviation,
                accelerometerMinimumAccuracyStatus =
                    selected.frames.minOf { it.accelerometerAccuracyStatus },
                gyroscopeMinimumAccuracyStatus =
                    selected.frames.minOf { it.gyroscopeAccuracyStatus },
                accelerometerInterpolatedFrameCount =
                    selected.frames.count { it.accelerometerAlignment == ImuAlignment.INTERPOLATED },
                gyroscopeInterpolatedFrameCount =
                    selected.frames.count { it.gyroscopeAlignment == ImuAlignment.INTERPOLATED },
                rawQualityFlags = selectedFlags,
            )
        return ImuStationaryCalibrationResult(
            state =
                if (sensorUnreliable) {
                    ImuCalibrationState.CALIBRATED_DEGRADED
                } else {
                    ImuCalibrationState.CALIBRATED
                },
            config = config,
            calibration = calibration,
            evidence = selectedEvidence.toSet(),
            diagnostics = diagnostics,
        )
    }

    private fun ceilingDivide(
        value: Long,
        divisor: Long,
    ): Long = value / divisor + if (value % divisor == 0L) 0L else 1L

    private fun ResampledImuValue.Available.vector(): CalibrationVector3 =
        CalibrationVector3(x, y, z)

    private fun ResampledImuValue.Available.hasDiscontinuityEvidence(): Boolean =
        ImuQualityFlag.CLOCK_DISCONTINUITY in qualityFlags ||
            ImuQualityFlag.IMU_DROPOUT in qualityFlags

    private fun ResampledImuValue.Available.hasUnreliableEvidence(): Boolean =
        accuracyStatus <= RawImuSample.SENSOR_STATUS_UNRELIABLE ||
            ImuQualityFlag.SENSOR_UNRELIABLE in qualityFlags
}

private data class CalibrationFrame(
    val tripElapsedNanos: Long,
    val accelerometer: CalibrationVector3,
    val gyroscope: CalibrationVector3,
    val accelerometerAlignment: ImuAlignment,
    val gyroscopeAlignment: ImuAlignment,
    val accelerometerAccuracyStatus: Int,
    val gyroscopeAccuracyStatus: Int,
    val rawQualityFlags: Set<ImuQualityFlag>,
)

private data class WindowStatistics(
    val accelerometerMean: CalibrationVector3,
    val gyroscopeMean: CalibrationVector3,
    val accelerometerStandardDeviation: CalibrationVector3,
    val gyroscopeStandardDeviation: CalibrationVector3,
)

private data class WindowSnapshot(
    val score: Double,
    val frames: List<CalibrationFrame>,
    val statistics: WindowStatistics,
)

private class RollingCalibrationWindow(
    private val capacity: Int,
) {
    private val frames = ArrayDeque<CalibrationFrame>(capacity)
    private val sums = DoubleArray(6)
    private val squaredSums = DoubleArray(6)

    val isFull: Boolean
        get() = frames.size == capacity

    fun add(frame: CalibrationFrame) {
        frames.addLast(frame)
        update(frame, 1.0)
        if (frames.size > capacity) {
            update(frames.removeFirst(), -1.0)
        }
    }

    fun clear() {
        frames.clear()
        sums.fill(0.0)
        squaredSums.fill(0.0)
    }

    fun statistics(): WindowStatistics {
        check(isFull)
        val means = DoubleArray(6) { sums[it] / frames.size.toDouble() }
        val standardDeviations =
            DoubleArray(6) {
                sqrt(max(0.0, squaredSums[it] / frames.size.toDouble() - means[it] * means[it]))
            }
        return WindowStatistics(
            accelerometerMean = CalibrationVector3(means[0], means[1], means[2]),
            gyroscopeMean = CalibrationVector3(means[3], means[4], means[5]),
            accelerometerStandardDeviation =
                CalibrationVector3(
                    standardDeviations[0],
                    standardDeviations[1],
                    standardDeviations[2],
                ),
            gyroscopeStandardDeviation =
                CalibrationVector3(
                    standardDeviations[3],
                    standardDeviations[4],
                    standardDeviations[5],
                ),
        )
    }

    fun snapshot(
        score: Double,
        statistics: WindowStatistics,
    ): WindowSnapshot =
        WindowSnapshot(
            score = score,
            frames = frames.toList(),
            statistics = statistics,
        )

    private fun update(
        frame: CalibrationFrame,
        direction: Double,
    ) {
        val values =
            doubleArrayOf(
                frame.accelerometer.x,
                frame.accelerometer.y,
                frame.accelerometer.z,
                frame.gyroscope.x,
                frame.gyroscope.y,
                frame.gyroscope.z,
            )
        for (index in values.indices) {
            sums[index] += direction * values[index]
            squaredSums[index] += direction * values[index] * values[index]
        }
    }
}

private fun CalibrationVector3.maxAxis(): Double = max(x, max(y, z))
