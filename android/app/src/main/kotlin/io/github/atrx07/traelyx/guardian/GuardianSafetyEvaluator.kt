package io.github.atrx07.traelyx.guardian

import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.telemetry.FrameVector3
import kotlin.math.abs
import kotlin.math.sqrt

/** Experimental, synthetic-governed rules. Never an injury/crash probability. */
object GuardianSafetyRulesV1 {
    const val VERSION = 1
    const val GRAVITY = 9.80665
    const val IMU_MAX_GAP_NS = 50_000_000L
    const val GNSS_MAX_GAP_NS = 1_500_000_000L
    const val CALIBRATION_NS = 3_000_000_000L
    const val SEVERE_DECELERATION = 6.0
    const val SEVERE_DURATION_NS = 1_000_000_000L
    const val IMPACT_DECELERATION = 25.0
    const val IMPACT_MIN_DURATION_NS = 40_000_000L
    const val IMPACT_MAX_DURATION_NS = 400_000_000L
    const val IMPACT_MIN_IMPULSE = 2.0
    const val SEVERE_COOLDOWN_NS = 300_000_000_000L
    const val CRASH_COOLDOWN_NS = 1_800_000_000_000L
}

enum class GuardianAlertKind(val wireName: String) {
    SEVERE_DRIVE("severe_drive"),
    POSSIBLE_CRASH("possible_crash"),
}

enum class GuardianEvaluationAvailability {
    DISABLED,
    CALIBRATING,
    MONITORING_EXPERIMENTAL,
    EVIDENCE_UNAVAILABLE,
}

/** Local monotonic evidence times only; the delivery layer creates a separate envelope. */
data class GuardianDetection(
    val kind: GuardianAlertKind,
    val evidenceStartedAtNanos: Long,
    val detectedAtNanos: Long,
    val ruleVersion: Int = GuardianSafetyRulesV1.VERSION,
) {
    init {
        require(evidenceStartedAtNanos >= 0 && detectedAtNanos >= evidenceStartedAtNanos)
        require(ruleVersion == GuardianSafetyRulesV1.VERSION)
    }
}

/** The integration must persist this with the same boot identity before enqueueing a detection. */
data class GuardianSafetyCooldowns(val lastSevereNanos: Long? = null, val lastCrashNanos: Long? = null) {
    init {
        require(lastSevereNanos == null || lastSevereNanos >= 0)
        require(lastCrashNanos == null || lastCrashNanos >= 0)
    }
}

/**
 * Single-consumer streaming evaluator. Input must be in source-time order within each channel.
 * The caller must bound/reorder acquisition and invalidate on lost evidence. No IO or network.
 * Null forward direction means the driver has not confirmed a rigid mount, so evaluation is off.
 * Raw samples and previous scoring outputs are never modified.
 */
class GuardianSafetyEvaluator(
    private val confirmedDeviceForward: FrameVector3?,
    restoredCooldowns: GuardianSafetyCooldowns = GuardianSafetyCooldowns(),
) {
    var availability = if (confirmedDeviceForward == null) {
        GuardianEvaluationAvailability.DISABLED
    } else {
        GuardianEvaluationAvailability.CALIBRATING
    }
        private set

    private var gravity: FrameVector3? = null
    private var forward: FrameVector3? = null
    private var gyro: RawImuSample? = null
    private var lastAcceleration: Long? = null
    private var lastGnss: Long? = null
    private var lastGyro: Long? = null
    private var fixes = ArrayDeque<SpeedFix>()
    private var calibration = Calibration()
    private var severeStart: Long? = null
    private var severePending: Candidate? = null
    private var impactStart: Long? = null
    private var impactImpulse = 0.0
    private var impactPending: Candidate? = null
    private var stoppedSince: Long? = null
    private var lastSevere: Long? = restoredCooldowns.lastSevereNanos
    private var lastCrash: Long? = restoredCooldowns.lastCrashNanos
    private var accumulatedTiltRadians = 0.0

    init {
        require(confirmedDeviceForward == null || abs(confirmedDeviceForward.magnitude - 1.0) < 1e-6)
    }

    fun cooldownSnapshot() = GuardianSafetyCooldowns(lastSevere, lastCrash)

    /** Queue overflow, process recovery, or evidence loss must call this before another input. */
    fun invalidate() {
        gravity = null
        forward = null
        gyro = null
        fixes.clear()
        calibration = Calibration()
        accumulatedTiltRadians = 0.0
        clearCandidates()
        availability = if (confirmedDeviceForward == null) GuardianEvaluationAvailability.DISABLED
        else GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE
        // Keep channel watermarks and cooldowns: invalid evidence cannot reset deduplication.
    }

    fun accept(sample: RawImuSample) {
        if (confirmedDeviceForward == null) return
        val time = sample.sourceTimestampNanos
        val previous = if (sample.sensorType == ImuSensorType.GYROSCOPE) lastGyro else lastAcceleration
        if (previous != null && time <= previous) {
            invalidate()
            return
        }
        if (sample.sensorType == ImuSensorType.GYROSCOPE) lastGyro = time else lastAcceleration = time
        if (sample.tripElapsedNanos == null || sample.accuracyStatus < 2 || sample.qualityFlags.isNotEmpty() ||
            (previous != null && time - previous > GuardianSafetyRulesV1.IMU_MAX_GAP_NS)) {
            invalidate()
            return
        }
        if (sample.sensorType == ImuSensorType.GYROSCOPE) {
            gravity?.let { reference ->
                accumulatedTiltRadians += vector(sample).projectedPerpendicularTo(reference.normalized()).magnitude *
                    (previous?.let { (time - it) / 1e9 } ?: 0.0)
            }
            if (vector(sample).magnitude > 0.5 || accumulatedTiltRadians > 0.1745329252) {
                invalidate()
            } else {
                gyro = sample
            }
            return
        }
        val angular = gyro
        val speed = fixes.lastOrNull()
        if (angular == null || angular.sourceTimestampNanos > time ||
            time - angular.sourceTimestampNanos > GuardianSafetyRulesV1.IMU_MAX_GAP_NS ||
            speed == null || speed.time > time || time - speed.time > GuardianSafetyRulesV1.GNSS_MAX_GAP_NS) {
            invalidate()
            return
        }
        val acceleration = vector(sample)
        if (gravity == null) {
            calibrate(time, acceleration, vector(angular).magnitude, speed.speed)
            return
        }
        availability = GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL
        val reference = requireNotNull(gravity)
        val delta = acceleration - reference
        val longitudinal = delta.dot(requireNotNull(forward))
        val vertical = abs(delta.dot(reference.normalized()))
        // Free fall, major tilt, and primarily vertical road shocks are not crash evidence.
        if (acceleration.magnitude < 4.0 || vertical > 0.5 * abs(longitudinal) + 2.0) {
            clearCandidates()
            return
        }
        val dt = previous?.let { (time - it) / 1e9 } ?: 0.0
        if (longitudinal <= -GuardianSafetyRulesV1.SEVERE_DECELERATION) {
            if (severeStart == null) severeStart = time
            val start = requireNotNull(severeStart)
            if (time - start >= GuardianSafetyRulesV1.SEVERE_DURATION_NS && severePending == null) {
                baseline(start)?.let { severePending = Candidate(start, time, it) }
            }
        } else {
            severeStart = null
        }
        if (longitudinal <= -GuardianSafetyRulesV1.IMPACT_DECELERATION) {
            if (impactStart == null) {
                impactStart = time
                impactImpulse = 0.0
            } else {
                impactImpulse += -longitudinal * dt
            }
        } else {
            impactStart?.let { start ->
                val duration = time - start
                if (duration in GuardianSafetyRulesV1.IMPACT_MIN_DURATION_NS..GuardianSafetyRulesV1.IMPACT_MAX_DURATION_NS &&
                    impactImpulse >= GuardianSafetyRulesV1.IMPACT_MIN_IMPULSE && impactPending == null) {
                    baseline(start)?.let { impactPending = Candidate(start, time, it) }
                }
            }
            impactStart = null
            impactImpulse = 0.0
        }
    }

    fun accept(sample: RawGnssSample): List<GuardianDetection> {
        if (confirmedDeviceForward == null) return emptyList()
        val time = sample.sourceTimestampNanos
        val previous = lastGnss
        if (previous != null && time <= previous) {
            invalidate()
            return emptyList()
        }
        lastGnss = time
        val speed = sample.speedMetresPerSecond?.toDouble()
        val accuracy = sample.speedAccuracyMetresPerSecond
        if (sample.tripElapsedNanos == null || sample.qualityFlags.isNotEmpty() || sample.isMockSignal ||
            speed == null || speed > 90.0 || accuracy == null || accuracy > 1.5f || sample.horizontalAccuracyMetres > 15f ||
            (previous != null && time - previous > GuardianSafetyRulesV1.GNSS_MAX_GAP_NS)) {
            invalidate()
            return emptyList()
        }
        // Reject physically implausible isolated speeds instead of accepting a spike as a baseline.
        val prior = fixes.lastOrNull()
        if (prior != null && abs(speed - prior.speed) / ((time - prior.time) / 1e9) > 15.0) {
            invalidate()
            return emptyList()
        }
        fixes.addLast(SpeedFix(time, speed))
        while (fixes.size > 16 || (fixes.isNotEmpty() && time - fixes.first().time > 15_000_000_000L)) fixes.removeFirst()
        if (gravity == null || lastAcceleration == null || lastGyro == null ||
            time < requireNotNull(lastAcceleration) || time - requireNotNull(lastAcceleration) > GuardianSafetyRulesV1.IMU_MAX_GAP_NS ||
            time < requireNotNull(lastGyro) || time - requireNotNull(lastGyro) > GuardianSafetyRulesV1.IMU_MAX_GAP_NS) {
            clearCandidates()
            return emptyList()
        }
        val result = mutableListOf<GuardianDetection>()
        val impact = impactPending
        if (impact != null) {
            if (time - impact.started > 12_000_000_000L) {
                impactPending = null
                stoppedSince = null
            } else if (speed <= 1.5 && impact.beforeSpeed - speed >= 6.0) {
                if (stoppedSince == null && time - impact.started <= 3_000_000_000L) stoppedSince = time
                if (stoppedSince?.let { time - it >= 5_000_000_000L } == true &&
                    cooldown(lastCrash, time, GuardianSafetyRulesV1.CRASH_COOLDOWN_NS)) {
                    result += GuardianDetection(GuardianAlertKind.POSSIBLE_CRASH, impact.started, time)
                    lastCrash = time
                    lastSevere = time
                    clearCandidates()
                }
            } else {
                stoppedSince = null
            }
        }
        val severe = severePending
        if (severe != null && impactPending == null) {
            val after = fixes.filter { it.time > severe.started }
            if (time - severe.started > 4_000_000_000L) {
                severePending = null
            } else if (after.size >= 2 && time >= severe.qualified &&
                after.takeLast(2).all { severe.beforeSpeed - it.speed >= 5.0 } &&
                cooldown(lastSevere, time, GuardianSafetyRulesV1.SEVERE_COOLDOWN_NS)) {
                result += GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, severe.started, time)
                lastSevere = time
                severePending = null
            }
        }
        return result
    }

    private fun baseline(time: Long): Double? {
        val before = fixes.filter { it.time <= time && time - it.time <= 3_000_000_000L }.takeLast(3)
        if (before.size < 3 || before.last().time - before.first().time < 1_500_000_000L ||
            before.any { it.speed < 8.0 } || before.maxOf { it.speed } - before.minOf { it.speed } > 3.0) return null
        return before.minOf { it.speed }
    }

    private fun calibrate(time: Long, acceleration: FrameVector3, angular: Double, speed: Double) {
        availability = GuardianEvaluationAvailability.CALIBRATING
        if (speed > 1.0 || angular > 0.05 || abs(acceleration.magnitude - GuardianSafetyRulesV1.GRAVITY) > 0.75) {
            calibration = Calibration()
            return
        }
        calibration.add(time, acceleration)
        if (time - calibration.start < GuardianSafetyRulesV1.CALIBRATION_NS) return
        if (calibration.maxStandardDeviation() > 0.15) {
            calibration = Calibration()
            return
        }
        val reference = calibration.mean
        val projected = requireNotNull(confirmedDeviceForward).projectedPerpendicularTo(reference.normalized())
        if (projected.magnitude < 0.5) {
            calibration = Calibration()
            return
        }
        gravity = reference
        forward = projected.normalized()
        availability = GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL
    }

    private fun clearCandidates() {
        severeStart = null
        severePending = null
        impactStart = null
        impactPending = null
        impactImpulse = 0.0
        stoppedSince = null
    }

    private fun vector(sample: RawImuSample) = FrameVector3(sample.x.toDouble(), sample.y.toDouble(), sample.z.toDouble())
    private fun cooldown(last: Long?, time: Long, duration: Long) = last == null || time - last >= duration
    private data class SpeedFix(val time: Long, val speed: Double)
    private data class Candidate(val started: Long, val qualified: Long, val beforeSpeed: Double)

    private class Calibration {
        var start = 0L
        var count = 0
        var mean = FrameVector3(0.0, 0.0, 0.0)
        private var m2 = FrameVector3(0.0, 0.0, 0.0)
        fun add(time: Long, value: FrameVector3) {
            if (count == 0) start = time
            count++
            val delta = value - mean
            mean += delta * (1.0 / count)
            val after = value - mean
            m2 += FrameVector3(delta.x * after.x, delta.y * after.y, delta.z * after.z)
        }
        fun maxStandardDeviation(): Double = sqrt(maxOf(m2.x, m2.y, m2.z) / count)
    }
}
