package io.github.atrx07.traelyx.telemetry

import java.security.MessageDigest
import java.util.concurrent.CancellationException

const val PROVISIONAL_EVENT_FEATURE_SCHEMA = "eventnet-native-derived-imu-proposal-v1"
const val PROVISIONAL_EVENT_WINDOW_NANOS = 6_000_000_000L
const val PROVISIONAL_EVENT_SAMPLES = 600

enum class ProvisionalFeatureRejection {
    INVALID_BOUNDS,
    UNSUPPORTED_CONFIGURATION,
    CONTEXT_UNAVAILABLE_OR_CHANGED,
    CALIBRATION_OR_MOUNT_UNRESOLVED,
    INCOMPLETE_OR_MISALIGNED_WINDOW,
    CHANNEL_UNAVAILABLE_OR_LIMITED,
    PROVENANCE_MISMATCH,
    FLOAT32_OVERFLOW,
}

sealed interface ProvisionalFeatureResult {
    data class Rejected(val reason: ProvisionalFeatureRejection) : ProvisionalFeatureResult

    /** Numeric readiness only: no driving-context, model, training or production admission. */
    class Window internal constructor(
        val startExclusiveNanos: Long,
        val endInclusiveNanos: Long,
        val contextSha256: String,
        val earliestSourceElapsedNanos: Long,
        val latestSourceElapsedNanos: Long,
        val maximumSourceLookaheadNanos: Long,
        values: FloatArray,
    ) : ProvisionalFeatureResult {
        val schema: String = PROVISIONAL_EVENT_FEATURE_SCHEMA
        val configuration: String = "native-M3-defaults-v1"
        private val tensor = values.copyOf()

        /** NCT [1,4,600]: forward/left/up m/s², then upward yaw rad/s. */
        fun copyTensor(): FloatArray = tensor.copyOf()
    }
}

/** Unwired development extractor. Reuses native preprocessing; never re-filters or fills gaps. */
object ProvisionalEventFeatureExtractor {
    fun extract(timeline: TelemetryConfidenceTimeline, startExclusiveNanos: Long): ProvisionalFeatureResult {
        if (startExclusiveNanos < 0L || startExclusiveNanos > Long.MAX_VALUE - PROVISIONAL_EVENT_WINDOW_NANOS) {
            return rejected(ProvisionalFeatureRejection.INVALID_BOUNDS)
        }
        val derived = timeline.sourceTimeline
        if (timeline.config != TelemetryConfidenceConfig() || derived.config != DerivedTelemetryConfig() ||
            derived.sourceTimeline.config != AnalysisTimelineConfig()) {
            return rejected(ProvisionalFeatureRejection.UNSUPPORTED_CONFIGURATION)
        }
        return extractFrames(
            timeline.synchronizedFrames(), derived.motionContexts, startExclusiveNanos,
        )
    }

    /** Internal seam for generated failure fixtures; production callers use the timeline entry point. */
    internal fun extractFrames(
        frames: Sequence<ConfidenceTelemetryFramePair>,
        contexts: DerivedMotionContextTimeline,
        startExclusiveNanos: Long,
    ): ProvisionalFeatureResult {
        if (startExclusiveNanos < 0L || startExclusiveNanos > Long.MAX_VALUE - PROVISIONAL_EVENT_WINDOW_NANOS) {
            return rejected(ProvisionalFeatureRejection.INVALID_BOUNDS)
        }
        val end = startExclusiveNanos + PROVISIONAL_EVENT_WINDOW_NANOS
        val first = startExclusiveNanos + DEFAULT_ANALYSIS_INTERVAL_NANOS
        val context = contexts.segments.singleOrNull {
            it.startTripElapsedNanos <= first &&
                (it.endTripElapsedNanosExclusive == null || it.endTripElapsedNanosExclusive > end)
        } ?: return rejected(ProvisionalFeatureRejection.CONTEXT_UNAVAILABLE_OR_CHANGED)
        val calibration = context.calibrationResult.calibration
        val mount = (context.mountAlignment as? VehicleMountAlignmentResolution.Available)?.alignment
        if (calibration == null || mount == null ||
            context.calibrationResult.state != ImuCalibrationState.CALIBRATED ||
            context.calibrationResult.config != ImuStationaryCalibrationConfig() ||
            mount.quality != VehicleMountAlignmentQuality.RESOLVED ||
            calibration.endTripElapsedNanos > first ||
            mount.sourceCalibrationStartTripElapsedNanos != calibration.startTripElapsedNanos ||
            mount.sourceCalibrationEndTripElapsedNanos != calibration.endTripElapsedNanos) {
            return rejected(ProvisionalFeatureRejection.CALIBRATION_OR_MOUNT_UNRESOLVED)
        }
        val values = FloatArray(4 * PROVISIONAL_EVENT_SAMPLES)
        var count = 0
        var earliest = Long.MAX_VALUE
        var latest = 0L
        var lookahead = 0L
        for ((frame, confidence) in frames) {
            if (Thread.currentThread().isInterrupted) throw CancellationException()
            val target = frame.tripElapsedNanos
            if (target <= startExclusiveNanos) continue
            if (target > end) break
            if (count >= PROVISIONAL_EVENT_SAMPLES || target != first + count * DEFAULT_ANALYSIS_INTERVAL_NANOS) {
                return rejected(ProvisionalFeatureRejection.INCOMPLETE_OR_MISALIGNED_WINDOW)
            }
            val acceleration = frame.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available
            val yaw = frame.yawRateRadiansPerSecond as? DerivedScalarValue.Available
            if (acceleration == null || yaw == null ||
                acceleration.quality != DerivedChannelQuality.RESOLVED || yaw.quality != DerivedChannelQuality.RESOLVED ||
                confidence.eligibility.vehicleAcceleration.eligibility != TelemetryEligibility.ELIGIBLE ||
                confidence.eligibility.yawRate.eligibility != TelemetryEligibility.ELIGIBLE) {
                return rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED)
            }
            for (provenance in listOf(acceleration.provenance, yaw.provenance)) {
                if (provenance.calibrationStartTripElapsedNanos != calibration.startTripElapsedNanos ||
                    provenance.calibrationEndTripElapsedNanos != calibration.endTripElapsedNanos ||
                    provenance.calibrationState != ImuCalibrationState.CALIBRATED ||
                    provenance.mountAlignmentQuality != VehicleMountAlignmentQuality.RESOLVED ||
                    provenance.sourceStartTripElapsedNanos > target ||
                    provenance.sourceEndTripElapsedNanos < target ||
                    provenance.imuQualityFlags.isNotEmpty()) {
                    return rejected(ProvisionalFeatureRejection.PROVENANCE_MISMATCH)
                }
                earliest = minOf(earliest, provenance.sourceStartTripElapsedNanos)
                latest = maxOf(latest, provenance.sourceEndTripElapsedNanos)
                lookahead = maxOf(lookahead, provenance.sourceEndTripElapsedNanos - target)
            }
            val row = doubleArrayOf(acceleration.value.x, acceleration.value.y, acceleration.value.z, yaw.value)
            row.forEachIndexed { channel, value ->
                val converted = value.toFloat()
                if (!converted.isFinite()) return rejected(ProvisionalFeatureRejection.FLOAT32_OVERFLOW)
                values[channel * PROVISIONAL_EVENT_SAMPLES + count] = converted
            }
            count++
        }
        if (count != PROVISIONAL_EVENT_SAMPLES) {
            return rejected(ProvisionalFeatureRejection.INCOMPLETE_OR_MISALIGNED_WINDOW)
        }
        // Defaults are pinned above. Bind the context and every calibration value/flag,
        // canonicalizing the only set; include mount basis rather than object identity.
        val identity = listOf(
            PROVISIONAL_EVENT_FEATURE_SCHEMA, "native-M3-defaults-v1",
            context.startTripElapsedNanos, context.endTripElapsedNanosExclusive,
            calibration.copy(rawQualityFlags = calibration.rawQualityFlags.sortedBy { it.name }.toSet()),
            mount.forwardDevice, mount.leftDevice, mount.upDevice,
        ).joinToString("|")
        val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        return ProvisionalFeatureResult.Window(startExclusiveNanos, end, digest, earliest, latest, lookahead, values)
    }

    private fun rejected(reason: ProvisionalFeatureRejection) = ProvisionalFeatureResult.Rejected(reason)
}
