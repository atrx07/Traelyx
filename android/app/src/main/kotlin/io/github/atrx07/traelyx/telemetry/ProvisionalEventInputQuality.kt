package io.github.atrx07.traelyx.telemetry

const val PROVISIONAL_EVENT_FEATURE_SCHEMA_V2 = "eventnet-native-derived-imu-proposal-v2"
const val PROVISIONAL_INTERPOLATION_QUALITY_POLICY = "bounded-native-imu-interpolation-development-v1"

/** Per [acceleration, gyroscope] target: current interpolation, history, native LIMITED. */
const val FEATURE_CURRENT_INTERPOLATION = 1
const val FEATURE_HISTORY_INTERPOLATION = 2
const val FEATURE_NATIVE_METRIC_LIMITED = 4

internal enum class ProvisionalFeaturePolicy {
    STRICT_V1,
    INTERPOLATION_V2,
}

/** Required v2 sidecar. Never upgrades the original confidence/eligibility. */
class ProvisionalEventInputQuality internal constructor(
    masks: ByteArray,
    minimumAccuracy: IntArray,
    maximumBracket: LongArray,
    maximumLookahead: LongArray,
    val calibrationAccelerometerInterpolatedFrames: Int,
    val calibrationGyroscopeInterpolatedFrames: Int,
) {
    val policy: String = PROVISIONAL_INTERPOLATION_QUALITY_POLICY
    private val flags = masks.copyOf()
    private val accuracy = minimumAccuracy.copyOf()
    private val brackets = maximumBracket.copyOf()
    private val lookahead = maximumLookahead.copyOf()
    val nativeMetricsLimited: Boolean = flags.any { it.toInt() and FEATURE_NATIVE_METRIC_LIMITED != 0 }
    val hasInterpolationEvidence: Boolean = flags.any { it.toInt() != 0 } ||
        calibrationAccelerometerInterpolatedFrames > 0 || calibrationGyroscopeInterpolatedFrames > 0

    init {
        require(flags.size == 2 * PROVISIONAL_EVENT_SAMPLES && flags.all { it.toInt() in 0..7 })
        require(accuracy.size == 2 && accuracy.all { it in 1..3 })
        require(brackets.size == 2 && brackets.all { it in 0L..DEFAULT_MAX_IMU_INTERPOLATION_GAP_NANOS })
        require(lookahead.size == 2 && lookahead.indices.all { lookahead[it] in 0L..brackets[it] })
        require(calibrationAccelerometerInterpolatedFrames >= 0 && calibrationGyroscopeInterpolatedFrames >= 0)
    }

    fun copyMasks(): ByteArray = flags.copyOf()
    fun copyMinimumAccuracyStatus(): IntArray = accuracy.copyOf()
    fun copyMaximumCurrentBracketNanos(): LongArray = brackets.copyOf()
    fun copyMaximumCurrentLookaheadNanos(): LongArray = lookahead.copyOf()

    fun count(channel: Int, flag: Int): Int {
        require(channel in 0..1)
        require(flag in setOf(FEATURE_CURRENT_INTERPOLATION, FEATURE_HISTORY_INTERPOLATION, FEATURE_NATIVE_METRIC_LIMITED))
        return (0 until PROVISIONAL_EVENT_SAMPLES).count {
            flags[channel * PROVISIONAL_EVENT_SAMPLES + it].toInt() and flag != 0
        }
    }
}

/** Separate development API: callers must bind v2 schema AND sidecar; no model admission. */
object ProvisionalInterpolatedEventFeatureExtractor {
    fun extract(timeline: TelemetryConfidenceTimeline, startExclusiveNanos: Long): ProvisionalFeatureResult =
        ProvisionalEventFeatureExtractor.extractWithPolicy(timeline, startExclusiveNanos, ProvisionalFeaturePolicy.INTERPOLATION_V2)
}

internal class ProvisionalInputQualityCollector {
    private val masks = ByteArray(2 * PROVISIONAL_EVENT_SAMPLES)
    private val minimumAccuracy = intArrayOf(3, 3)
    private val maximumBracket = LongArray(2)
    private val maximumLookahead = LongArray(2)

    fun accept(pair: ConfidenceTelemetryFramePair, index: Int): Boolean {
        val components = pair.confidence.components
        if (components.calibration.assessment != TelemetryConfidenceAssessment(TelemetryConfidenceState.SUPPORTED,
                setOf(TelemetryConfidenceReason.CALIBRATION_SUPPORTED)) ||
            components.orientation.assessment != TelemetryConfidenceAssessment(TelemetryConfidenceState.SUPPORTED,
                setOf(TelemetryConfidenceReason.ORIENTATION_SUPPORTED)) ||
            components.deviceMovement.assessment != TelemetryConfidenceAssessment(TelemetryConfidenceState.SUPPORTED,
                setOf(TelemetryConfidenceReason.DEVICE_MOVEMENT_STABLE))) return false
        val acc = pair.derived.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available ?: return false
        val yaw = pair.derived.yawRateRadiansPerSecond as? DerivedScalarValue.Available ?: return false
        return acceptChannel(0, index, pair.derived.tripElapsedNanos, components.accelerometer,
            acc.quality, acc.evidence, acc.provenance, pair.confidence.eligibility.vehicleAcceleration) &&
            acceptChannel(1, index, pair.derived.tripElapsedNanos, components.gyroscope,
                yaw.quality, yaw.evidence, yaw.provenance, pair.confidence.eligibility.yawRate)
    }

    private fun acceptChannel(
        channel: Int,
        index: Int,
        target: Long,
        source: ImuTelemetryConfidence,
        quality: DerivedChannelQuality,
        evidence: Set<DerivedChannelEvidence>,
        provenance: DerivedChannelProvenance,
        eligibility: TelemetryEligibilityAssessment,
    ): Boolean {
        val lower = source.lowerTripElapsedNanos ?: return false
        val upper = source.upperTripElapsedNanos ?: return false
        val status = source.accuracyStatus ?: return false
        val minimum = provenance.minimumImuAccuracyStatus ?: return false
        if (status !in 1..3 || minimum !in 1..3 || minimum > status ||
            source.qualityFlags.isNotEmpty() || provenance.imuQualityFlags.isNotEmpty() ||
            source.missingReason != null || lower > target || upper < target ||
            upper - lower > DEFAULT_MAX_IMU_INTERPOLATION_GAP_NANOS) return false
        val current = source.alignment == ImuAlignment.INTERPOLATED
        val expectedSource = if (current) {
            if (lower >= target || upper <= target) return false
            TelemetryConfidenceAssessment(TelemetryConfidenceState.DEGRADED, setOf(TelemetryConfidenceReason.IMU_INTERPOLATED))
        } else {
            if (source.alignment != ImuAlignment.EXACT || lower != target || upper != target) return false
            TelemetryConfidenceAssessment(TelemetryConfidenceState.SUPPORTED, setOf(TelemetryConfidenceReason.IMU_EXACT))
        }
        if (source.assessment != expectedSource) return false
        val sourceStart = source.lowerSourceTimestampNanos ?: return false
        val sourceEnd = source.upperSourceTimestampNanos ?: return false
        if (sourceEnd < sourceStart || (current && sourceEnd == sourceStart) || (!current && sourceEnd != sourceStart) ||
            sourceEnd - sourceStart > DEFAULT_MAX_IMU_INTERPOLATION_GAP_NANOS ||
            provenance.sourceStartTripElapsedNanos > lower || provenance.sourceEndTripElapsedNanos < upper ||
            provenance.sourceStartTimestampNanos > sourceStart || provenance.sourceEndTimestampNanos < sourceEnd) return false
        val history = ImuAlignment.INTERPOLATED in provenance.imuAlignments
        if (source.alignment !in provenance.imuAlignments || (current && !history) ||
            provenance.imuAlignments.any { it != ImuAlignment.EXACT && it != ImuAlignment.INTERPOLATED }) return false
        val expectedEvidence = mutableSetOf(DerivedChannelEvidence.MEDIAN_PREFILTERED, DerivedChannelEvidence.LOW_PASS_FILTERED)
        if (channel == 0) expectedEvidence += setOf(DerivedChannelEvidence.STATIONARY_REFERENCE_REMOVED, DerivedChannelEvidence.FIXED_GRAVITY_REFERENCE)
        else expectedEvidence += DerivedChannelEvidence.GYROSCOPE_BIAS_REMOVED
        if (history) expectedEvidence += DerivedChannelEvidence.IMU_INTERPOLATED
        if (evidence != expectedEvidence || quality !=
            (if (history) DerivedChannelQuality.DEGRADED else DerivedChannelQuality.RESOLVED)) return false
        val sensor = if (channel == 0) TelemetryConfidenceComponentKind.ACCELEROMETER else TelemetryConfidenceComponentKind.GYROSCOPE
        val required = setOf(sensor, TelemetryConfidenceComponentKind.CALIBRATION,
            TelemetryConfidenceComponentKind.ORIENTATION, TelemetryConfidenceComponentKind.DEVICE_MOVEMENT)
        val reasons = buildSet {
            if (history) add(TelemetryEligibilityReason.CHANNEL_DEGRADED)
            if (current) add(TelemetryEligibilityReason.REQUIRED_COMPONENT_DEGRADED)
            if (!history && !current) add(TelemetryEligibilityReason.ALL_REQUIRED_EVIDENCE_SUPPORTED)
        }
        if (source.component != sensor || eligibility.sourceMissingReason != null ||
            eligibility.requiredComponents != required || eligibility.limitingComponents != (if (current) setOf(sensor) else emptySet()) ||
            eligibility.reasons != reasons || eligibility.eligibility !=
            (if (history || current) TelemetryEligibility.LIMITED else TelemetryEligibility.ELIGIBLE)) return false
        masks[channel * PROVISIONAL_EVENT_SAMPLES + index] =
            ((if (current) FEATURE_CURRENT_INTERPOLATION else 0) or
                (if (history) FEATURE_HISTORY_INTERPOLATION else 0) or
                (if (eligibility.eligibility == TelemetryEligibility.LIMITED) FEATURE_NATIVE_METRIC_LIMITED else 0)).toByte()
        minimumAccuracy[channel] = minOf(minimumAccuracy[channel], status, minimum)
        maximumBracket[channel] = maxOf(maximumBracket[channel], upper - lower)
        maximumLookahead[channel] = maxOf(maximumLookahead[channel], upper - target)
        return true
    }

    fun snapshot(calibration: ImuBiasCalibration): ProvisionalEventInputQuality = ProvisionalEventInputQuality(
        masks, minimumAccuracy, maximumBracket, maximumLookahead,
        calibration.accelerometerInterpolatedFrameCount, calibration.gyroscopeInterpolatedFrameCount,
    )
}
