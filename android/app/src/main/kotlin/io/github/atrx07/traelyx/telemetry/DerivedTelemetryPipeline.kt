package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.TelemetryChannel
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import java.util.ArrayDeque
import kotlin.math.PI
import kotlin.math.exp

class DerivedTelemetryTimeline internal constructor(
    val sourceTimeline: AnalysisTimeline,
    val gnssSummary: GnssProcessingSummary,
    val motionContexts: DerivedMotionContextTimeline,
    val config: DerivedTelemetryConfig,
) {
    val frameCount: Long
        get() = sourceTimeline.frameCount

    /** Returns a fresh bounded-memory processor on every call. */
    fun frames(): Sequence<DerivedTelemetryFrame> = sequence {
        val processor =
            DerivedTelemetryFrameProcessor(
                gnssSamples = gnssSummary.samples,
                motionContexts = motionContexts,
                config = config,
            )
        sourceTimeline.frames().forEach { frame -> yield(processor.process(frame)) }
    }
}

object DerivedTelemetryPipeline {
    fun build(
        sourceTimeline: AnalysisTimeline,
        gnssSummary: GnssProcessingSummary,
        motionContexts: DerivedMotionContextTimeline,
        config: DerivedTelemetryConfig = DerivedTelemetryConfig(),
    ): DerivedTelemetryBuildResult {
        if (sourceTimeline.config.intervalNanos > config.maximumContinuousImuGapNanos) {
            return DerivedTelemetryBuildResult.Invalid(
                errorCode = "derived_imu_gap_below_timeline_interval",
            )
        }
        val processed = gnssSummary.samples
        processed.forEachIndexed { index, sample ->
            val elapsed = requireNotNull(sample.rawSample.tripElapsedNanos)
            if (index > 0) {
                val previous = requireNotNull(processed[index - 1].rawSample.tripElapsedNanos)
                if (elapsed <= previous) {
                    return DerivedTelemetryBuildResult.Invalid(
                        errorCode = "derived_gnss_time_not_increasing",
                        sampleIndex = index,
                    )
                }
            }
        }
        val sourceGnss =
            sourceTimeline.trip
                .records(TelemetryChannel.GNSS)
                .map { (it as TelemetrySampleRecord.Gnss).sample }
                .iterator()
        processed.forEachIndexed { index, sample ->
            if (!sourceGnss.hasNext() || sourceGnss.next() != sample.rawSample) {
                return DerivedTelemetryBuildResult.Invalid(
                    errorCode = "derived_gnss_summary_trip_mismatch",
                    sampleIndex = index,
                )
            }
        }
        if (sourceGnss.hasNext()) {
            return DerivedTelemetryBuildResult.Invalid(
                errorCode = "derived_gnss_summary_trip_mismatch",
                sampleIndex = processed.size,
            )
        }
        return DerivedTelemetryBuildResult.Success(
            DerivedTelemetryTimeline(
                sourceTimeline = sourceTimeline,
                gnssSummary = gnssSummary,
                motionContexts = motionContexts,
                config = config,
            ),
        )
    }
}

private class DerivedTelemetryFrameProcessor(
    gnssSamples: List<ProcessedGnssSample>,
    motionContexts: DerivedMotionContextTimeline,
    private val config: DerivedTelemetryConfig,
) {
    private val contextCursor = MotionContextCursor(motionContexts.segments)
    private val gnssCursor = ProcessedGnssCursor(gnssSamples)
    private val acceleration = AccelerationChannelProcessor(config)
    private val jerk = JerkChannelProcessor(config)
    private val yaw = YawRateChannelProcessor(config)
    private val speed = SpeedChannelProcessor(config)
    private val heading = HeadingRateChannelProcessor(config)
    private val movement = MovementStateProcessor(config)
    private var previousContextIndex: Int? = null

    fun process(frame: AnalysisTimelineFrame): DerivedTelemetryFrame {
        val target = frame.tripElapsedNanos
        val selection = contextCursor.at(target)
        if (selection?.index != previousContextIndex) {
            acceleration.reset()
            jerk.reset()
            yaw.reset()
            previousContextIndex = selection?.index
        }
        val context = resolveMotionContext(selection?.segment, target)
        val accelerationValue =
            acceleration.process(
                target = target,
                source = frame.accelerometerDeviceMetresPerSecondSquared,
                context = context,
            )
        val jerkValue = jerk.process(target, accelerationValue)
        val yawValue =
            yaw.process(
                target = target,
                source = frame.gyroscopeDeviceRadiansPerSecond,
                context = context,
            )

        gnssCursor.forEachThrough(target) { sample ->
            speed.consume(sample)?.let(movement::consume)
            heading.consume(sample)
        }
        val speedValue = speed.valueAt(target)
        val headingValue = heading.valueAt(target)
        val movementValue = movement.valueAt(target, speedValue)

        return DerivedTelemetryFrame(
            tripElapsedNanos = target,
            filteredSpeedMetresPerSecond = speedValue,
            vehicleAccelerationMetresPerSecondSquared = accelerationValue,
            vehicleJerkMetresPerSecondCubed = jerkValue,
            yawRateRadiansPerSecond = yawValue,
            headingChangeRateRadiansPerSecond = headingValue,
            movementState = movementValue,
        )
    }

    private fun resolveMotionContext(
        segment: DerivedMotionContextSegment?,
        target: Long,
    ): MotionContextResolution {
        if (segment == null) {
            return MotionContextResolution.Unavailable(
                DerivedChannelUnavailable(DerivedChannelMissingReason.CONTEXT_TIMELINE_GAP),
            )
        }
        val calibration = segment.calibrationResult.calibration
            ?: return MotionContextResolution.Unavailable(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.CALIBRATION_INSUFFICIENT,
                    calibrationEvidence = segment.calibrationResult.evidence,
                ),
            )
        if (calibration.endTripElapsedNanos > target) {
            return MotionContextResolution.Unavailable(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.CALIBRATION_AFTER_TARGET,
                    calibrationEvidence = segment.calibrationResult.evidence,
                ),
            )
        }
        val mount =
            when (val resolution = segment.mountAlignment) {
                is VehicleMountAlignmentResolution.Available -> resolution.alignment
                is VehicleMountAlignmentResolution.Unavailable ->
                    return MotionContextResolution.Unavailable(
                        DerivedChannelUnavailable(
                            reason = DerivedChannelMissingReason.MOUNT_ALIGNMENT_UNAVAILABLE,
                            mountUnavailableReason = resolution.reason,
                            calibrationEvidence = segment.calibrationResult.evidence,
                        ),
                    )
            }
        if (
            mount.sourceCalibrationStartTripElapsedNanos != calibration.startTripElapsedNanos ||
            mount.sourceCalibrationEndTripElapsedNanos != calibration.endTripElapsedNanos
        ) {
            return MotionContextResolution.Unavailable(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.CALIBRATION_MOUNT_MISMATCH,
                    calibrationEvidence = segment.calibrationResult.evidence,
                ),
            )
        }
        return MotionContextResolution.Available(
            ResolvedMotionContext(
                calibration = calibration,
                calibrationState = segment.calibrationResult.state,
                calibrationEvidence = segment.calibrationResult.evidence,
                mount = mount,
            ),
        )
    }
}

private data class ContextSelection(
    val index: Int,
    val segment: DerivedMotionContextSegment,
)

private class MotionContextCursor(
    private val segments: List<DerivedMotionContextSegment>,
) {
    private var index = 0

    fun at(target: Long): ContextSelection? {
        while (index < segments.size) {
            val end = segments[index].endTripElapsedNanosExclusive ?: break
            if (target < end) break
            index += 1
        }
        val segment = segments.getOrNull(index) ?: return null
        if (target < segment.startTripElapsedNanos) return null
        val end = segment.endTripElapsedNanosExclusive
        if (end != null && target >= end) return null
        return ContextSelection(index, segment)
    }
}

private data class ResolvedMotionContext(
    val calibration: ImuBiasCalibration,
    val calibrationState: ImuCalibrationState,
    val calibrationEvidence: Set<ImuCalibrationEvidence>,
    val mount: VehicleMountAlignment,
) {
    val calibrationDegraded: Boolean
        get() = calibrationState == ImuCalibrationState.CALIBRATED_DEGRADED

    val degraded: Boolean
        get() =
            calibrationDegraded || mount.quality == VehicleMountAlignmentQuality.DEGRADED

    val evidence: Set<DerivedChannelEvidence>
        get() = buildSet {
            if (calibrationDegraded) add(DerivedChannelEvidence.CALIBRATION_DEGRADED)
            if (mount.quality == VehicleMountAlignmentQuality.DEGRADED) {
                add(DerivedChannelEvidence.MOUNT_ALIGNMENT_DEGRADED)
            }
        }
}

private sealed interface MotionContextResolution {
    data class Available(val context: ResolvedMotionContext) : MotionContextResolution

    data class Unavailable(val unavailable: DerivedChannelUnavailable) : MotionContextResolution
}

private class AccelerationChannelProcessor(
    private val config: DerivedTelemetryConfig,
) {
    private val median = RollingMedianVector(config.imuMedianWindowSize)
    private val lowPass = OnePoleVectorFilter(config.accelerationFilterTimeConstantNanos)
    private val provenance = MutableImuProvenance()
    private val evidence = mutableSetOf<DerivedChannelEvidence>()
    private var degraded = false
    private var previousTarget: Long? = null

    fun process(
        target: Long,
        source: ResampledImuValue,
        context: MotionContextResolution,
    ): DerivedVectorValue {
        if (context is MotionContextResolution.Unavailable) {
            reset()
            return DerivedVectorValue.Missing(target, context.unavailable)
        }
        if (source is ResampledImuValue.Missing) {
            reset()
            return DerivedVectorValue.Missing(
                target,
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.IMU_SOURCE_MISSING,
                    imuMissingReason = source.reason,
                ),
            )
        }
        source as ResampledImuValue.Available
        if (hasContinuityGap(target)) reset()
        previousTarget = target
        val resolved = (context as MotionContextResolution.Available).context
        val raw = FrameVector3(source.x, source.y, source.z)
        val reference = resolved.calibration.meanAccelerometerDeviceMetresPerSecondSquared
        val correctedDevice =
            raw - FrameVector3(reference.x, reference.y, reference.z)
        val vehicle = resolved.mount.deviceToVehicleForwardLeftUp.transform(correctedDevice)
        provenance.add(source)
        evidence +=
            setOf(
                DerivedChannelEvidence.MEDIAN_PREFILTERED,
                DerivedChannelEvidence.LOW_PASS_FILTERED,
                DerivedChannelEvidence.STATIONARY_REFERENCE_REMOVED,
                DerivedChannelEvidence.FIXED_GRAVITY_REFERENCE,
            )
        evidence += imuEvidence(source, resolved)
        degraded = degraded || isImuDegraded(source, resolved)
        val filtered = median.add(vehicle)?.let { lowPass.add(target, it) }
            ?: return missing(target, DerivedChannelMissingReason.FILTER_WARMUP)
        return DerivedVectorValue.Available(
            targetTripElapsedNanos = target,
            value = filtered,
            quality = quality(degraded),
            provenance = provenance.snapshot(resolved),
            evidence = evidence.toSet(),
        )
    }

    fun reset() {
        median.clear()
        lowPass.clear()
        provenance.clear()
        evidence.clear()
        degraded = false
        previousTarget = null
    }

    private fun hasContinuityGap(target: Long): Boolean {
        val previous = previousTarget ?: return false
        return target <= previous || target - previous > config.maximumContinuousImuGapNanos
    }
}

private class YawRateChannelProcessor(
    private val config: DerivedTelemetryConfig,
) {
    private val median = RollingMedianScalar(config.imuMedianWindowSize)
    private val lowPass = OnePoleScalarFilter(config.yawRateFilterTimeConstantNanos)
    private val provenance = MutableImuProvenance()
    private val evidence = mutableSetOf<DerivedChannelEvidence>()
    private var degraded = false
    private var previousTarget: Long? = null

    fun process(
        target: Long,
        source: ResampledImuValue,
        context: MotionContextResolution,
    ): DerivedScalarValue {
        if (context is MotionContextResolution.Unavailable) {
            reset()
            return DerivedScalarValue.Missing(target, context.unavailable)
        }
        if (source is ResampledImuValue.Missing) {
            reset()
            return DerivedScalarValue.Missing(
                target,
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.IMU_SOURCE_MISSING,
                    imuMissingReason = source.reason,
                ),
            )
        }
        source as ResampledImuValue.Available
        if (hasContinuityGap(target)) reset()
        previousTarget = target
        val resolved = (context as MotionContextResolution.Available).context
        val bias = resolved.calibration.gyroscopeBiasDeviceRadiansPerSecond
        val correctedDevice =
            FrameVector3(source.x - bias.x, source.y - bias.y, source.z - bias.z)
        val vehicle = resolved.mount.deviceToVehicleForwardLeftUp.transform(correctedDevice)
        provenance.add(source)
        evidence +=
            setOf(
                DerivedChannelEvidence.MEDIAN_PREFILTERED,
                DerivedChannelEvidence.LOW_PASS_FILTERED,
                DerivedChannelEvidence.GYROSCOPE_BIAS_REMOVED,
            )
        evidence += imuEvidence(source, resolved)
        degraded = degraded || isImuDegraded(source, resolved)
        val filtered = median.add(vehicle.z)?.let { lowPass.add(target, it) }
            ?: return scalarMissing(target, DerivedChannelMissingReason.FILTER_WARMUP)
        return DerivedScalarValue.Available(
            targetTripElapsedNanos = target,
            value = filtered,
            quality = quality(degraded),
            provenance = provenance.snapshot(resolved),
            evidence = evidence.toSet(),
        )
    }

    fun reset() {
        median.clear()
        lowPass.clear()
        provenance.clear()
        evidence.clear()
        degraded = false
        previousTarget = null
    }

    private fun hasContinuityGap(target: Long): Boolean {
        val previous = previousTarget ?: return false
        return target <= previous || target - previous > config.maximumContinuousImuGapNanos
    }
}

private class JerkChannelProcessor(
    private val config: DerivedTelemetryConfig,
) {
    private val window = ArrayDeque<DerivedVectorValue.Available>()

    fun process(
        target: Long,
        acceleration: DerivedVectorValue,
    ): DerivedVectorValue {
        if (acceleration is DerivedVectorValue.Missing) {
            reset()
            return DerivedVectorValue.Missing(target, acceleration.unavailable)
        }
        acceleration as DerivedVectorValue.Available
        val previous = window.peekLast()
        if (
            previous != null &&
            (target <= previous.targetTripElapsedNanos ||
                target - previous.targetTripElapsedNanos > config.maximumContinuousImuGapNanos)
        ) {
            reset()
        }
        window.addLast(acceleration)
        while (window.size > config.jerkSlopeWindowSize) window.removeFirst()
        if (window.size < config.jerkSlopeWindowSize) {
            return missing(target, DerivedChannelMissingReason.DERIVATIVE_WARMUP)
        }
        val values = window.toList()
        val slopes =
            values.zipWithNext { lower, upper ->
                val seconds =
                    (upper.targetTripElapsedNanos - lower.targetTripElapsedNanos).toDouble() /
                        NANOS_PER_SECOND
                (upper.value - lower.value) * (1.0 / seconds)
            }
        val jerk =
            FrameVector3(
                x = medianOf(slopes.map { it.x }),
                y = medianOf(slopes.map { it.y }),
                z = medianOf(slopes.map { it.z }),
            )
        return DerivedVectorValue.Available(
            targetTripElapsedNanos = target,
            value = jerk,
            quality =
                quality(values.any { it.quality == DerivedChannelQuality.DEGRADED }),
            provenance = acceleration.provenance,
            evidence =
                values.flatMapTo(mutableSetOf()) { it.evidence } +
                    DerivedChannelEvidence.ROBUST_MEDIAN_SLOPE,
        )
    }

    fun reset() {
        window.clear()
    }
}

private class SpeedChannelProcessor(
    private val config: DerivedTelemetryConfig,
) {
    private val median = RollingMedianScalar(config.gnssMedianWindowSize)
    private val lowPass = OnePoleScalarFilter(config.speedFilterTimeConstantNanos)
    private val provenance = MutableGnssProvenance()
    private val evidence = mutableSetOf<DerivedChannelEvidence>()
    private var degraded = false
    private var lastAcceptedSourceTime: Long? = null
    private var latestOutput: FilteredGnssScalar? = null
    private var unavailable =
        DerivedChannelUnavailable(DerivedChannelMissingReason.GNSS_SOURCE_UNAVAILABLE)

    fun consume(sample: ProcessedGnssSample): FilteredGnssScalar? {
        val sourceTime = requireNotNull(sample.rawSample.tripElapsedNanos)
        val selection = selectSpeed(sample)
        if (selection is SpeedSelection.Unavailable) {
            clear(selection.unavailable)
            return null
        }
        selection as SpeedSelection.Available
        val previousTime = lastAcceptedSourceTime
        if (
            sample.decision == GnssDecision.RESET_AFTER_GAP ||
            previousTime != null && sourceTime - previousTime > config.maximumGnssSourceAgeNanos
        ) {
            clear(DerivedChannelUnavailable(DerivedChannelMissingReason.FILTER_WARMUP))
        }
        lastAcceptedSourceTime = sourceTime
        provenance.addSpeed(sample)
        evidence += selection.evidence
        evidence +=
            setOf(
                DerivedChannelEvidence.MEDIAN_PREFILTERED,
                DerivedChannelEvidence.LOW_PASS_FILTERED,
            )
        degraded = degraded || selection.degraded
        val filtered = median.add(selection.value)?.let { lowPass.add(sourceTime, it) }
        if (filtered == null) {
            unavailable = DerivedChannelUnavailable(DerivedChannelMissingReason.FILTER_WARMUP)
            return null
        }
        val output =
            FilteredGnssScalar(
                sourceTripElapsedNanos = sourceTime,
                value = filtered,
                quality = quality(degraded),
                provenance = provenance.snapshot(),
                evidence = evidence.toSet(),
            )
        latestOutput = output
        return output
    }

    fun valueAt(target: Long): DerivedScalarValue {
        val output = latestOutput ?: return DerivedScalarValue.Missing(target, unavailable)
        val age = target - output.sourceTripElapsedNanos
        if (age < 0L || age > config.maximumGnssSourceAgeNanos) {
            return scalarMissing(target, DerivedChannelMissingReason.GNSS_SOURCE_STALE)
        }
        return DerivedScalarValue.Available(
            targetTripElapsedNanos = target,
            value = output.value,
            quality = output.quality,
            provenance = output.provenance,
            evidence =
                if (age > 0L) {
                    output.evidence + DerivedChannelEvidence.GNSS_SOURCE_HELD
                } else {
                    output.evidence
                },
        )
    }

    private fun selectSpeed(sample: ProcessedGnssSample): SpeedSelection {
        if (sample.decision in HARD_REJECTED_SPEED_DECISIONS) {
            return SpeedSelection.Unavailable(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.GNSS_SOURCE_REJECTED,
                    gnssDecision = sample.decision,
                    gnssEvidence = sample.evidence,
                    gnssRawQualityFlags = sample.rawSample.qualityFlags,
                ),
            )
        }
        if (GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE in sample.evidence) {
            return SpeedSelection.Unavailable(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.GNSS_SPEED_IMPLAUSIBLE,
                    gnssDecision = sample.decision,
                    gnssEvidence = sample.evidence,
                    gnssRawQualityFlags = sample.rawSample.qualityFlags,
                ),
            )
        }
        val raw = sample.rawSample
        val platform = raw.speedMetresPerSecond?.toDouble()
        val fallback =
            sample.apparentSpeedMetresPerSecond
                ?.takeIf { sample.decision == GnssDecision.ACCEPTED_RESOLVED_DISTANCE }
        val value = platform ?: fallback
            ?: return SpeedSelection.Unavailable(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.GNSS_SPEED_UNAVAILABLE,
                    gnssDecision = sample.decision,
                    gnssEvidence = sample.evidence,
                    gnssRawQualityFlags = sample.rawSample.qualityFlags,
                ),
            )
        val mock =
            raw.isMockSignal || GnssQualityFlag.MOCK_LOCATION_SIGNAL in raw.qualityFlags
        val accuracyUnavailable = platform != null && raw.speedAccuracyMetresPerSecond == null
        val usedFallback = platform == null
        return SpeedSelection.Available(
            value = value,
            degraded = mock || accuracyUnavailable || usedFallback,
            evidence = buildSet {
                add(
                    if (usedFallback) {
                        DerivedChannelEvidence.GNSS_GEODESIC_SPEED_FALLBACK
                    } else {
                        DerivedChannelEvidence.GNSS_PLATFORM_SPEED
                    },
                )
                if (accuracyUnavailable) {
                    add(DerivedChannelEvidence.GNSS_SPEED_ACCURACY_UNAVAILABLE)
                }
                if (mock) add(DerivedChannelEvidence.GNSS_MOCK_LOCATION)
            },
        )
    }

    private fun clear(reason: DerivedChannelUnavailable) {
        median.clear()
        lowPass.clear()
        provenance.clear()
        evidence.clear()
        degraded = false
        lastAcceptedSourceTime = null
        latestOutput = null
        unavailable = reason
    }

    private sealed interface SpeedSelection {
        data class Available(
            val value: Double,
            val degraded: Boolean,
            val evidence: Set<DerivedChannelEvidence>,
        ) : SpeedSelection

        data class Unavailable(val unavailable: DerivedChannelUnavailable) : SpeedSelection
    }

    private companion object {
        val HARD_REJECTED_SPEED_DECISIONS =
            setOf(
                GnssDecision.EXCLUDED_LOW_ACCURACY,
                GnssDecision.EXCLUDED_CLOCK_DISCONTINUITY,
                GnssDecision.EXCLUDED_IMPOSSIBLE_JUMP,
            )
    }
}

private class HeadingRateChannelProcessor(
    private val config: DerivedTelemetryConfig,
) {
    private val median = RollingMedianScalar(config.gnssMedianWindowSize)
    private val lowPass = OnePoleScalarFilter(config.headingRateFilterTimeConstantNanos)
    private val provenance = MutableGnssProvenance()
    private val evidence = mutableSetOf<DerivedChannelEvidence>()
    private var degraded = false
    private var previousCourse: CourseObservation? = null
    private var latestOutput: FilteredGnssScalar? = null
    private var unavailable =
        DerivedChannelUnavailable(DerivedChannelMissingReason.GNSS_SOURCE_UNAVAILABLE)

    fun consume(sample: ProcessedGnssSample) {
        val sourceTime = requireNotNull(sample.rawSample.tripElapsedNanos)
        val courseResolution =
            GnssCourseResolver.resolve(
                sample = sample,
                targetTripElapsedNanos = sourceTime,
                config = config.courseConfig,
            )
        if (courseResolution is GnssCourseResolution.Unavailable) {
            clear(
                DerivedChannelUnavailable(
                    reason = DerivedChannelMissingReason.GNSS_COURSE_UNAVAILABLE,
                    gnssDecision = sample.decision,
                    gnssEvidence = sample.evidence,
                    gnssRawQualityFlags = sample.rawSample.qualityFlags,
                    gnssCourseUnavailableReason = courseResolution.reason,
                ),
            )
            return
        }
        val course = (courseResolution as GnssCourseResolution.Available).course
        val current =
            CourseObservation(
                course = course,
                sourceTimestampNanos = sample.rawSample.sourceTimestampNanos,
                rawQualityFlags = sample.rawSample.qualityFlags,
            )
        val previous = previousCourse
        if (previous == null) {
            clear(DerivedChannelUnavailable(DerivedChannelMissingReason.FILTER_WARMUP))
            previousCourse = current
            provenance.addCourse(current)
            return
        }
        val elapsed = sourceTime - previous.course.sourceTripElapsedNanos
        if (elapsed <= 0L || elapsed > config.maximumHeadingSampleGapNanos) {
            clear(DerivedChannelUnavailable(DerivedChannelMissingReason.FILTER_WARMUP))
            previousCourse = current
            provenance.addCourse(current)
            return
        }
        val deltaRadians =
            wrapRadians(
                Math.toRadians(course.bearingDegreesEastOfTrueNorth) -
                    Math.toRadians(previous.course.bearingDegreesEastOfTrueNorth),
            )
        val rawRate = deltaRadians / (elapsed.toDouble() / NANOS_PER_SECOND)
        previousCourse = current
        provenance.addCourse(current)
        evidence +=
            setOf(
                DerivedChannelEvidence.MEDIAN_PREFILTERED,
                DerivedChannelEvidence.LOW_PASS_FILTERED,
                DerivedChannelEvidence.GNSS_COURSE_DERIVATIVE,
            )
        if (course.quality == GnssCourseQuality.DEGRADED) {
            evidence += DerivedChannelEvidence.GNSS_MOCK_LOCATION
            degraded = true
        }
        val filtered = median.add(rawRate)?.let { lowPass.add(sourceTime, it) }
        if (filtered == null) {
            unavailable = DerivedChannelUnavailable(DerivedChannelMissingReason.FILTER_WARMUP)
            return
        }
        latestOutput =
            FilteredGnssScalar(
                sourceTripElapsedNanos = sourceTime,
                value = filtered,
                quality = quality(degraded),
                provenance = provenance.snapshot(),
                evidence = evidence.toSet(),
            )
    }

    fun valueAt(target: Long): DerivedScalarValue {
        val output = latestOutput ?: return DerivedScalarValue.Missing(target, unavailable)
        val age = target - output.sourceTripElapsedNanos
        if (age < 0L || age > config.maximumGnssSourceAgeNanos) {
            return scalarMissing(target, DerivedChannelMissingReason.GNSS_SOURCE_STALE)
        }
        return DerivedScalarValue.Available(
            targetTripElapsedNanos = target,
            value = output.value,
            quality = output.quality,
            provenance = output.provenance,
            evidence =
                if (age > 0L) {
                    output.evidence + DerivedChannelEvidence.GNSS_SOURCE_HELD
                } else {
                    output.evidence
                },
        )
    }

    private fun clear(reason: DerivedChannelUnavailable) {
        median.clear()
        lowPass.clear()
        provenance.clear()
        evidence.clear()
        degraded = false
        previousCourse = null
        latestOutput = null
        unavailable = reason
    }
}

private data class CourseObservation(
    val course: ResolvedGnssCourse,
    val sourceTimestampNanos: Long,
    val rawQualityFlags: Set<GnssQualityFlag>,
)

private data class FilteredGnssScalar(
    val sourceTripElapsedNanos: Long,
    val value: Double,
    val quality: DerivedChannelQuality,
    val provenance: DerivedChannelProvenance,
    val evidence: Set<DerivedChannelEvidence>,
)

private class MovementStateProcessor(
    private val config: DerivedTelemetryConfig,
) {
    private var stableState = MovementState.UNKNOWN
    private var candidateState: MovementState? = null
    private var candidateStartSourceTime: Long? = null
    private var candidateSampleCount = 0
    private var latestSpeed: FilteredGnssScalar? = null

    fun consume(speed: FilteredGnssScalar) {
        latestSpeed = speed
        val requested =
            when {
                speed.value >= config.movingEnterSpeedMetresPerSecond -> MovementState.MOVING
                speed.value <= config.stoppedEnterSpeedMetresPerSecond -> MovementState.STOPPED
                else -> null
            }
        if (requested == null || requested == stableState) {
            clearCandidate()
            return
        }
        if (candidateState != requested) {
            candidateState = requested
            candidateStartSourceTime = speed.sourceTripElapsedNanos
            candidateSampleCount = 1
        } else {
            candidateSampleCount += 1
        }
        val duration = speed.sourceTripElapsedNanos - requireNotNull(candidateStartSourceTime)
        val requiredDuration =
            if (requested == MovementState.MOVING) {
                config.movingConfirmationDurationNanos
            } else {
                config.stoppedConfirmationDurationNanos
            }
        val requiredSamples =
            if (requested == MovementState.MOVING) {
                config.movingConfirmationSampleCount
            } else {
                config.stoppedConfirmationSampleCount
            }
        if (duration >= requiredDuration && candidateSampleCount >= requiredSamples) {
            stableState = requested
            clearCandidate()
        }
    }

    fun valueAt(
        target: Long,
        speed: DerivedScalarValue,
    ): DerivedMovementState {
        if (speed is DerivedScalarValue.Missing) {
            reset()
            return DerivedMovementState(
                targetTripElapsedNanos = target,
                state = MovementState.UNKNOWN,
                quality = null,
                supportingSampleCount = 0,
                supportingDurationNanos = 0L,
                latestSpeedSourceTripElapsedNanos = null,
                evidence = setOf(MovementStateEvidence.SPEED_UNAVAILABLE),
            )
        }
        speed as DerivedScalarValue.Available
        val current = requireNotNull(latestSpeed)
        val candidateDuration =
            candidateStartSourceTime?.let { current.sourceTripElapsedNanos - it } ?: 0L
        val stateEvidence = buildSet {
            when {
                candidateState == MovementState.MOVING ->
                    add(MovementStateEvidence.PENDING_MOVING_CONFIRMATION)
                candidateState == MovementState.STOPPED ->
                    add(MovementStateEvidence.PENDING_STOPPED_CONFIRMATION)
                stableState == MovementState.MOVING ->
                    add(MovementStateEvidence.CONFIRMED_MOVING)
                stableState == MovementState.STOPPED ->
                    add(MovementStateEvidence.CONFIRMED_STOPPED)
                else -> add(MovementStateEvidence.HYSTERESIS_HOLD)
            }
            if (
                candidateState == null &&
                stableState != MovementState.UNKNOWN &&
                speed.value > config.stoppedEnterSpeedMetresPerSecond &&
                speed.value < config.movingEnterSpeedMetresPerSecond
            ) {
                add(MovementStateEvidence.HYSTERESIS_HOLD)
            }
            if (speed.quality == DerivedChannelQuality.DEGRADED) {
                add(MovementStateEvidence.SPEED_DEGRADED)
            }
        }
        return DerivedMovementState(
            targetTripElapsedNanos = target,
            state = stableState,
            quality = speed.quality.takeIf { stableState != MovementState.UNKNOWN },
            supportingSampleCount = candidateSampleCount,
            supportingDurationNanos = candidateDuration,
            latestSpeedSourceTripElapsedNanos = current.sourceTripElapsedNanos,
            evidence = stateEvidence,
        )
    }

    private fun reset() {
        stableState = MovementState.UNKNOWN
        latestSpeed = null
        clearCandidate()
    }

    private fun clearCandidate() {
        candidateState = null
        candidateStartSourceTime = null
        candidateSampleCount = 0
    }
}

private class ProcessedGnssCursor(
    private val samples: List<ProcessedGnssSample>,
) {
    private var index = 0

    fun forEachThrough(
        target: Long,
        consume: (ProcessedGnssSample) -> Unit,
    ) {
        while (index < samples.size) {
            val sample = samples[index]
            if (requireNotNull(sample.rawSample.tripElapsedNanos) > target) break
            consume(sample)
            index += 1
        }
    }
}

private class RollingMedianScalar(
    private val capacity: Int,
) {
    private val values = ArrayDeque<Double>()

    fun add(value: Double): Double? {
        values.addLast(value)
        while (values.size > capacity) values.removeFirst()
        return if (values.size == capacity) medianOf(values.toList()) else null
    }

    fun clear() {
        values.clear()
    }
}

private class RollingMedianVector(
    private val capacity: Int,
) {
    private val values = ArrayDeque<FrameVector3>()

    fun add(value: FrameVector3): FrameVector3? {
        values.addLast(value)
        while (values.size > capacity) values.removeFirst()
        if (values.size < capacity) return null
        return FrameVector3(
            x = medianOf(values.map { it.x }),
            y = medianOf(values.map { it.y }),
            z = medianOf(values.map { it.z }),
        )
    }

    fun clear() {
        values.clear()
    }
}

private class OnePoleScalarFilter(
    private val timeConstantNanos: Long,
) {
    private var previousTime: Long? = null
    private var previousValue: Double? = null

    fun add(
        time: Long,
        value: Double,
    ): Double {
        val priorTime = previousTime
        val priorValue = previousValue
        val output =
            if (priorTime == null || priorValue == null) {
                value
            } else {
                val alpha = 1.0 - exp(-(time - priorTime).toDouble() / timeConstantNanos.toDouble())
                priorValue + alpha * (value - priorValue)
            }
        previousTime = time
        previousValue = output
        return output
    }

    fun clear() {
        previousTime = null
        previousValue = null
    }
}

private class OnePoleVectorFilter(
    private val timeConstantNanos: Long,
) {
    private val x = OnePoleScalarFilter(timeConstantNanos)
    private val y = OnePoleScalarFilter(timeConstantNanos)
    private val z = OnePoleScalarFilter(timeConstantNanos)

    fun add(
        time: Long,
        value: FrameVector3,
    ): FrameVector3 =
        FrameVector3(
            x = x.add(time, value.x),
            y = y.add(time, value.y),
            z = z.add(time, value.z),
        )

    fun clear() {
        x.clear()
        y.clear()
        z.clear()
    }
}

private class MutableImuProvenance {
    private var sourceStartTrip: Long? = null
    private var sourceEndTrip: Long? = null
    private var sourceStartTimestamp: Long? = null
    private var sourceEndTimestamp: Long? = null
    private var sampleCount = 0L
    private var minimumAccuracyStatus: Int? = null
    private val alignments = mutableSetOf<ImuAlignment>()
    private val qualityFlags = mutableSetOf<ImuQualityFlag>()

    fun add(source: ResampledImuValue.Available) {
        sourceStartTrip = minNullable(sourceStartTrip, source.lowerTripElapsedNanos)
        sourceEndTrip = maxNullable(sourceEndTrip, source.upperTripElapsedNanos)
        sourceStartTimestamp = minNullable(sourceStartTimestamp, source.lowerSourceTimestampNanos)
        sourceEndTimestamp = maxNullable(sourceEndTimestamp, source.upperSourceTimestampNanos)
        sampleCount += 1L
        minimumAccuracyStatus =
            minimumAccuracyStatus?.let { minOf(it, source.accuracyStatus) } ?: source.accuracyStatus
        alignments += source.alignment
        qualityFlags += source.qualityFlags
    }

    fun snapshot(context: ResolvedMotionContext): DerivedChannelProvenance =
        DerivedChannelProvenance(
            sourceStartTripElapsedNanos = requireNotNull(sourceStartTrip),
            sourceEndTripElapsedNanos = requireNotNull(sourceEndTrip),
            sourceStartTimestampNanos = requireNotNull(sourceStartTimestamp),
            sourceEndTimestampNanos = requireNotNull(sourceEndTimestamp),
            sourceSampleCount = sampleCount,
            minimumImuAccuracyStatus = minimumAccuracyStatus,
            imuAlignments = alignments.toSet(),
            imuQualityFlags = qualityFlags.toSet(),
            calibrationStartTripElapsedNanos = context.calibration.startTripElapsedNanos,
            calibrationEndTripElapsedNanos = context.calibration.endTripElapsedNanos,
            calibrationState = context.calibrationState,
            calibrationEvidence = context.calibrationEvidence,
            mountAlignmentQuality = context.mount.quality,
            mountAlignmentEvidence = context.mount.evidence,
        )

    fun clear() {
        sourceStartTrip = null
        sourceEndTrip = null
        sourceStartTimestamp = null
        sourceEndTimestamp = null
        sampleCount = 0L
        minimumAccuracyStatus = null
        alignments.clear()
        qualityFlags.clear()
    }
}

private class MutableGnssProvenance {
    private var sourceStartTrip: Long? = null
    private var sourceEndTrip: Long? = null
    private var sourceStartTimestamp: Long? = null
    private var sourceEndTimestamp: Long? = null
    private var sampleCount = 0L
    private val decisions = mutableSetOf<GnssDecision>()
    private val processingEvidence = mutableSetOf<GnssProcessingEvidence>()
    private val rawQualityFlags = mutableSetOf<GnssQualityFlag>()
    private var latestSpeedAccuracy: Double? = null
    private var latestBearingAccuracy: Double? = null

    fun addSpeed(sample: ProcessedGnssSample) {
        add(
            tripElapsedNanos = requireNotNull(sample.rawSample.tripElapsedNanos),
            sourceTimestampNanos = sample.rawSample.sourceTimestampNanos,
            decision = sample.decision,
            evidence = sample.evidence,
        )
        latestSpeedAccuracy = sample.rawSample.speedAccuracyMetresPerSecond?.toDouble()
        rawQualityFlags += sample.rawSample.qualityFlags
    }

    fun addCourse(observation: CourseObservation) {
        add(
            tripElapsedNanos = observation.course.sourceTripElapsedNanos,
            sourceTimestampNanos = observation.sourceTimestampNanos,
            decision = observation.course.sourceDecision,
            evidence = observation.course.sourceEvidence,
        )
        latestBearingAccuracy = observation.course.bearingAccuracyDegrees
        rawQualityFlags += observation.rawQualityFlags
    }

    private fun add(
        tripElapsedNanos: Long,
        sourceTimestampNanos: Long,
        decision: GnssDecision,
        evidence: Set<GnssProcessingEvidence>,
    ) {
        sourceStartTrip = minNullable(sourceStartTrip, tripElapsedNanos)
        sourceEndTrip = maxNullable(sourceEndTrip, tripElapsedNanos)
        sourceStartTimestamp = minNullable(sourceStartTimestamp, sourceTimestampNanos)
        sourceEndTimestamp = maxNullable(sourceEndTimestamp, sourceTimestampNanos)
        sampleCount += 1L
        decisions += decision
        processingEvidence += evidence
    }

    fun snapshot(): DerivedChannelProvenance =
        DerivedChannelProvenance(
            sourceStartTripElapsedNanos = requireNotNull(sourceStartTrip),
            sourceEndTripElapsedNanos = requireNotNull(sourceEndTrip),
            sourceStartTimestampNanos = requireNotNull(sourceStartTimestamp),
            sourceEndTimestampNanos = requireNotNull(sourceEndTimestamp),
            sourceSampleCount = sampleCount,
            gnssDecisions = decisions.toSet(),
            gnssEvidence = processingEvidence.toSet(),
            gnssRawQualityFlags = rawQualityFlags.toSet(),
            latestGnssSpeedAccuracyMetresPerSecond = latestSpeedAccuracy,
            latestGnssBearingAccuracyDegrees = latestBearingAccuracy,
        )

    fun clear() {
        sourceStartTrip = null
        sourceEndTrip = null
        sourceStartTimestamp = null
        sourceEndTimestamp = null
        sampleCount = 0L
        decisions.clear()
        processingEvidence.clear()
        rawQualityFlags.clear()
        latestSpeedAccuracy = null
        latestBearingAccuracy = null
    }
}

private fun imuEvidence(
    source: ResampledImuValue.Available,
    context: ResolvedMotionContext,
): Set<DerivedChannelEvidence> = buildSet {
    addAll(context.evidence)
    if (source.alignment == ImuAlignment.INTERPOLATED) {
        add(DerivedChannelEvidence.IMU_INTERPOLATED)
    }
    if (source.accuracyStatus <= 0 || ImuQualityFlag.SENSOR_UNRELIABLE in source.qualityFlags) {
        add(DerivedChannelEvidence.IMU_SENSOR_UNRELIABLE)
    }
    if (source.qualityFlags.isNotEmpty()) {
        add(DerivedChannelEvidence.IMU_RAW_QUALITY_FLAG)
    }
}

private fun isImuDegraded(
    source: ResampledImuValue.Available,
    context: ResolvedMotionContext,
): Boolean =
    context.degraded ||
        source.alignment == ImuAlignment.INTERPOLATED ||
        source.accuracyStatus <= 0 ||
        source.qualityFlags.isNotEmpty()

private fun quality(degraded: Boolean): DerivedChannelQuality =
    if (degraded) DerivedChannelQuality.DEGRADED else DerivedChannelQuality.RESOLVED

private fun missing(
    target: Long,
    reason: DerivedChannelMissingReason,
): DerivedVectorValue.Missing =
    DerivedVectorValue.Missing(target, DerivedChannelUnavailable(reason))

private fun scalarMissing(
    target: Long,
    reason: DerivedChannelMissingReason,
): DerivedScalarValue.Missing =
    DerivedScalarValue.Missing(target, DerivedChannelUnavailable(reason))

private fun medianOf(values: List<Double>): Double {
    require(values.isNotEmpty())
    val sorted = values.sorted()
    val middle = sorted.size / 2
    return if (sorted.size % 2 == 1) {
        sorted[middle]
    } else {
        (sorted[middle - 1] + sorted[middle]) / 2.0
    }
}

private fun wrapRadians(value: Double): Double {
    var wrapped = value
    while (wrapped > PI) wrapped -= 2.0 * PI
    while (wrapped <= -PI) wrapped += 2.0 * PI
    return wrapped
}

private fun minNullable(
    current: Long?,
    candidate: Long,
): Long = current?.let { minOf(it, candidate) } ?: candidate

private fun maxNullable(
    current: Long?,
    candidate: Long,
): Long = current?.let { maxOf(it, candidate) } ?: candidate

private const val NANOS_PER_SECOND = 1_000_000_000.0
