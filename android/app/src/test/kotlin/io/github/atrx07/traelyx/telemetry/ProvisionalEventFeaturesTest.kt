package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.testImuSample
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProvisionalEventFeaturesTest {
    @Test
    fun `native preprocessing feeds physical units and exact NCT order without second bias removal`() {
        val timeline = timeline()
        val window = ProvisionalEventFeatureExtractor.extract(timeline, SECOND) as ProvisionalFeatureResult.Window
        assertEquals(SECOND, window.startExclusiveNanos)
        assertEquals(7 * SECOND, window.endInclusiveNanos)
        assertEquals(2400, window.copyTensor().size)
        val expected = timeline.synchronizedFrames().filter { it.derived.tripElapsedNanos > SECOND }
            .take(600).toList()
        val actual = window.copyTensor()
        expected.forEachIndexed { index, pair ->
            val acc = pair.derived.vehicleAccelerationMetresPerSecondSquared as DerivedVectorValue.Available
            val yaw = pair.derived.yawRateRadiansPerSecond as DerivedScalarValue.Available
            assertEquals(acc.value.x.toFloat(), actual[index], 0f)
            assertEquals(acc.value.y.toFloat(), actual[600 + index], 0f)
            assertEquals(acc.value.z.toFloat(), actual[1200 + index], 0f)
            assertEquals(yaw.value.toFloat(), actual[1800 + index], 0f)
        }
        assertEquals(2f, actual[0], 1e-5f)
        assertEquals(-1f, actual[600], 1e-5f)
        assertEquals(3f, actual[1200], 1e-5f)
        assertEquals(0.4f, actual[1800], 1e-5f)
        assertTrue(window.earliestSourceElapsedNanos <= SECOND + STEP)
        assertEquals(7 * SECOND, window.latestSourceElapsedNanos)
        assertEquals(0L, window.maximumSourceLookaheadNanos)
        assertEquals(64, window.contextSha256.length)
        actual[0] = 999f
        assertEquals(2f, window.copyTensor()[0], 1e-5f)
        assertArrayEquals(window.copyTensor(), (ProvisionalEventFeatureExtractor.extract(timeline, SECOND)
            as ProvisionalFeatureResult.Window).copyTensor(), 0f)
    }

    @Test
    fun `missing duplicate shifted or short windows fail rather than fill`() {
        val timeline = timeline()
        val frames = timeline.synchronizedFrames().toList()
        val context = timeline.sourceTimeline.motionContexts
        for (candidate in listOf(
            frames.filter { it.derived.tripElapsedNanos != 4 * SECOND },
            frames.flatMap { if (it.derived.tripElapsedNanos == 4 * SECOND) listOf(it, it) else listOf(it) },
            frames.filter { it.derived.tripElapsedNanos < 7 * SECOND },
        )) {
            rejected(ProvisionalFeatureRejection.INCOMPLETE_OR_MISALIGNED_WINDOW,
                ProvisionalEventFeatureExtractor.extractFrames(candidate.asSequence(), context, SECOND))
        }
        rejected(ProvisionalFeatureRejection.INCOMPLETE_OR_MISALIGNED_WINDOW,
            ProvisionalEventFeatureExtractor.extract(timeline, SECOND + 1))
    }

    @Test
    fun `unreliable real pipeline and warmup channels never produce a window`() {
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalEventFeatureExtractor.extract(timeline(unreliableAt = 4 * SECOND), SECOND))
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalEventFeatureExtractor.extract(timeline(), 0L))
    }

    @Test
    fun `clean asynchronous IMU is limited by native interpolation and strict proposal rejects it`() {
        val t = timeline(gyroscopeOffsetNanos = 1_000_000L)
        val frame = t.synchronizedFrames().first { it.derived.tripElapsedNanos > SECOND }
        assertEquals(TelemetryEligibility.LIMITED, frame.confidence.eligibility.yawRate.eligibility)
        assertEquals(DerivedChannelQuality.DEGRADED,
            (frame.derived.yawRateRadiansPerSecond as DerivedScalarValue.Available).quality)
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalEventFeatureExtractor.extract(t, SECOND))
    }

    @Test
    fun `limited yaw eligibility excludes otherwise finite resolved features`() {
        val t = timeline()
        val frames = t.synchronizedFrames().map { pair ->
            if (pair.derived.tripElapsedNanos != 4 * SECOND) pair else pair.copy(
                confidence = pair.confidence.copy(eligibility = pair.confidence.eligibility.copy(
                    yawRate = pair.confidence.eligibility.yawRate.copy(eligibility = TelemetryEligibility.LIMITED),
                )),
            )
        }
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalEventFeatureExtractor.extractFrames(frames, t.sourceTimeline.motionContexts, SECOND))
    }

    @Test
    fun `context transition and unresolved mount are rejected`() {
        val t = timeline()
        val source = t.sourceTimeline.motionContexts.segments.single()
        val contexts = DerivedMotionContextTimeline(listOf(
            source.copy(endTripElapsedNanosExclusive = 4 * SECOND),
            source.copy(startTripElapsedNanos = 4 * SECOND),
        ))
        rejected(ProvisionalFeatureRejection.CONTEXT_UNAVAILABLE_OR_CHANGED,
            ProvisionalEventFeatureExtractor.extractFrames(t.synchronizedFrames(), contexts, SECOND))
        val unresolved = DerivedMotionContextTimeline(listOf(source.copy(
            mountAlignment = VehicleMountAlignmentResolution.Unavailable(
                VehicleMountAlignmentUnavailableReason.FORWARD_HINT_PARALLEL_TO_UP),
        )))
        rejected(ProvisionalFeatureRejection.CALIBRATION_OR_MOUNT_UNRESOLVED,
            ProvisionalEventFeatureExtractor.extractFrames(t.synchronizedFrames(), unresolved, SECOND))
    }

    @Test
    fun `calibration provenance cannot be substituted and float overflow cannot be clipped`() {
        val t = timeline()
        for ((overflow, reason) in listOf(false to ProvisionalFeatureRejection.PROVENANCE_MISMATCH,
            true to ProvisionalFeatureRejection.FLOAT32_OVERFLOW)) {
            val frames = t.synchronizedFrames().map { pair ->
                if (pair.derived.tripElapsedNanos != 4 * SECOND) pair else {
                    val acc = pair.derived.vehicleAccelerationMetresPerSecondSquared as DerivedVectorValue.Available
                    pair.copy(derived = pair.derived.copy(vehicleAccelerationMetresPerSecondSquared =
                        if (overflow) acc.copy(value = FrameVector3(Double.MAX_VALUE, 0.0, 0.0)) else
                            acc.copy(provenance = acc.provenance.copy(calibrationEndTripElapsedNanos = STEP))))
                }
            }
            rejected(reason, ProvisionalEventFeatureExtractor.extractFrames(frames, t.sourceTimeline.motionContexts, SECOND))
        }
    }

    @Test
    fun `bracketing source availability is preserved rather than counted as inference time`() {
        val t = timeline()
        val frames = t.synchronizedFrames().map { pair ->
            val acc = pair.derived.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available
            if (acc == null) pair else pair.copy(derived = pair.derived.copy(
                vehicleAccelerationMetresPerSecondSquared = acc.copy(provenance = acc.provenance.copy(
                    sourceEndTripElapsedNanos = acc.provenance.sourceEndTripElapsedNanos + STEP,
                    sourceEndTimestampNanos = acc.provenance.sourceEndTimestampNanos + STEP,
                )),
            ))
        }
        val window = ProvisionalEventFeatureExtractor.extractFrames(frames, t.sourceTimeline.motionContexts, SECOND)
            as ProvisionalFeatureResult.Window
        assertEquals(STEP, window.maximumSourceLookaheadNanos)
        assertEquals(7 * SECOND + STEP, window.latestSourceElapsedNanos)
    }

    @Test
    fun `unsupported pipeline config and overflowing bounds fail before reading features`() {
        val t = timeline()
        val changed = TelemetryConfidencePipeline.build(t.sourceTimeline, TelemetryConfidenceConfig(
            preferredGnssHorizontalAccuracyMetres = 10.0,
        ))
        rejected(ProvisionalFeatureRejection.UNSUPPORTED_CONFIGURATION,
            ProvisionalEventFeatureExtractor.extract(changed, SECOND))
        for (start in listOf(-1L, Long.MAX_VALUE)) {
            rejected(ProvisionalFeatureRejection.INVALID_BOUNDS, ProvisionalEventFeatureExtractor.extract(t, start))
        }
    }

    @Test
    fun `context identity changes with calibration values and cancelled work propagates`() {
        val t = timeline()
        val base = ProvisionalEventFeatureExtractor.extract(t, SECOND) as ProvisionalFeatureResult.Window
        val context = t.sourceTimeline.motionContexts.segments.single()
        val calibration = requireNotNull(context.calibrationResult.calibration)
        val changed = DerivedMotionContextTimeline(listOf(context.copy(calibrationResult = context.calibrationResult.copy(
            calibration = calibration.copy(sampleCount = 3),
        ))))
        val second = ProvisionalEventFeatureExtractor.extractFrames(t.synchronizedFrames(), changed, SECOND)
            as ProvisionalFeatureResult.Window
        assertNotEquals(base.contextSha256, second.contextSha256)
        Thread.currentThread().interrupt()
        try {
            var cancelled = false
            try { ProvisionalEventFeatureExtractor.extract(t, SECOND) }
            catch (_: java.util.concurrent.CancellationException) { cancelled = true }
            assertTrue(cancelled)
        } finally { Thread.interrupted() }
        assertFalse(Thread.currentThread().isInterrupted)
    }

    @Test
    fun `v2 accepts clean asynchronous input and retains native limited evidence without mutation`() {
        val t = timeline(gyroscopeOffsetNanos = 1_000_000L)
        val before = t.synchronizedFrames().toList()
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalEventFeatureExtractor.extract(t, SECOND))
        val window = ProvisionalInterpolatedEventFeatureExtractor.extract(t, SECOND) as ProvisionalFeatureResult.Window
        val q = requireNotNull(window.inputQuality)
        assertEquals(PROVISIONAL_EVENT_FEATURE_SCHEMA_V2, window.schema)
        assertTrue(q.nativeMetricsLimited)
        assertTrue(q.hasInterpolationEvidence)
        assertEquals(0, q.count(0, FEATURE_CURRENT_INTERPOLATION))
        assertEquals(600, q.count(1, FEATURE_CURRENT_INTERPOLATION))
        assertEquals(600, q.count(1, FEATURE_HISTORY_INTERPOLATION))
        assertEquals(600, q.count(1, FEATURE_NATIVE_METRIC_LIMITED))
        assertEquals(STEP, q.copyMaximumCurrentBracketNanos()[1])
        assertEquals(1_000_000L, q.copyMaximumCurrentLookaheadNanos()[1])
        assertEquals(1_000_000L, window.maximumSourceLookaheadNanos)
        assertEquals(before, t.synchronizedFrames().toList())
        before.filter { it.derived.tripElapsedNanos > SECOND }.forEachIndexed { i, frame ->
            val yaw = frame.derived.yawRateRadiansPerSecond as DerivedScalarValue.Available
            assertEquals(yaw.value.toFloat(), window.copyTensor()[1800 + i], 0f)
            assertEquals(TelemetryEligibility.LIMITED, frame.confidence.eligibility.yawRate.eligibility)
        }
    }

    @Test
    fun `v2 exact windows match v1 values with distinct schema identity and clean sidecar`() {
        val t = timeline()
        val v1 = ProvisionalEventFeatureExtractor.extract(t, SECOND) as ProvisionalFeatureResult.Window
        val v2 = ProvisionalInterpolatedEventFeatureExtractor.extract(t, SECOND) as ProvisionalFeatureResult.Window
        assertArrayEquals(v1.copyTensor(), v2.copyTensor(), 0f)
        assertEquals(PROVISIONAL_EVENT_FEATURE_SCHEMA, v1.schema)
        assertEquals(null, v1.inputQuality)
        assertNotEquals(v1.contextSha256, v2.contextSha256)
        val q = requireNotNull(v2.inputQuality)
        assertFalse(q.nativeMetricsLimited)
        assertFalse(q.hasInterpolationEvidence)
        assertEquals(1200, q.copyMasks().size)
        assertTrue(q.copyMasks().all { it.toInt() == 0 })
    }

    @Test
    fun `v2 sidecar arrays cannot be changed through caller copies`() {
        val window = ProvisionalInterpolatedEventFeatureExtractor.extract(timeline(gyroscopeOffsetNanos = 1_000_000L), SECOND)
            as ProvisionalFeatureResult.Window
        val q = requireNotNull(window.inputQuality)
        q.copyMasks()[600] = 0
        q.copyMinimumAccuracyStatus()[1] = -1
        q.copyMaximumCurrentBracketNanos()[1] = Long.MAX_VALUE
        q.copyMaximumCurrentLookaheadNanos()[1] = Long.MAX_VALUE
        assertEquals(7, q.copyMasks()[600].toInt())
        assertEquals(3, q.copyMinimumAccuracyStatus()[1])
        assertEquals(STEP, q.copyMaximumCurrentBracketNanos()[1])
        assertEquals(1_000_000L, q.copyMaximumCurrentLookaheadNanos()[1])
    }

    @Test
    fun `v2 distinguishes historical interpolation from exact current samples`() {
        val t = timeline(gyroscopeOffsetNanos = 1_000_000L, offsetUntilNanos = SECOND/2)
        val frame = t.synchronizedFrames().first { it.derived.tripElapsedNanos > SECOND }
        assertEquals(TelemetryConfidenceState.SUPPORTED, frame.confidence.components.gyroscope.assessment.state)
        assertEquals(TelemetryEligibility.LIMITED, frame.confidence.eligibility.yawRate.eligibility)
        val q = requireNotNull((ProvisionalInterpolatedEventFeatureExtractor.extract(t, SECOND)
            as ProvisionalFeatureResult.Window).inputQuality)
        assertEquals(0, q.count(1, FEATURE_CURRENT_INTERPOLATION))
        assertEquals(600, q.count(1, FEATURE_HISTORY_INTERPOLATION))
        assertEquals(600, q.count(1, FEATURE_NATIVE_METRIC_LIMITED))
        assertEquals(0L, q.copyMaximumCurrentBracketNanos()[1])
        assertTrue(q.nativeMetricsLimited)
    }

    @Test
    fun `v2 retains bounded missing-sample interpolation but rejects oversized gap`() {
        val t = timeline(gyroscopeMissingRange = 4*SECOND..4*SECOND)
        val q = requireNotNull((ProvisionalInterpolatedEventFeatureExtractor.extract(t, SECOND)
            as ProvisionalFeatureResult.Window).inputQuality)
        assertEquals(1, q.count(1, FEATURE_CURRENT_INTERPOLATION))
        assertEquals(301, q.count(1, FEATURE_HISTORY_INTERPOLATION))
        assertEquals(301, q.count(1, FEATURE_NATIVE_METRIC_LIMITED))
        assertEquals(2*STEP, q.copyMaximumCurrentBracketNanos()[1])
        val ceiling = timeline(gyroscopeMissingRange = 4*SECOND..(4*SECOND+3*STEP))
        val ceilingQuality = requireNotNull((ProvisionalInterpolatedEventFeatureExtractor.extract(ceiling, SECOND)
            as ProvisionalFeatureResult.Window).inputQuality)
        assertEquals(DEFAULT_MAX_IMU_INTERPOLATION_GAP_NANOS, ceilingQuality.copyMaximumCurrentBracketNanos()[1])
        val gap = timeline(gyroscopeMissingRange = (4*SECOND-10*STEP)..(4*SECOND+10*STEP))
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalInterpolatedEventFeatureExtractor.extract(gap, SECOND))
    }

    @Test
    fun `v2 rejects unreliable history and current dropout clock or unreliable source`() {
        for (flag in listOf(ImuQualityFlag.SENSOR_UNRELIABLE, ImuQualityFlag.CLOCK_DISCONTINUITY, ImuQualityFlag.IMU_DROPOUT)) {
            rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
                ProvisionalInterpolatedEventFeatureExtractor.extract(timeline(flagAt = 4*SECOND, sourceFlag = flag), SECOND))
        }
        rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
            ProvisionalInterpolatedEventFeatureExtractor.extract(timeline(unreliableAt = SECOND/2), SECOND))
    }

    @Test
    fun `v2 rejects forged limited reasons brackets evidence and accuracy`() {
        val t = timeline(gyroscopeOffsetNanos = 1_000_000L)
        val cases: List<(ConfidenceTelemetryFramePair) -> ConfidenceTelemetryFramePair> = listOf(
            { p -> p.copy(confidence = p.confidence.copy(components = p.confidence.components.copy(
                deviceMovement = p.confidence.components.deviceMovement.copy(assessment = TelemetryConfidenceAssessment(
                    TelemetryConfidenceState.DEGRADED, setOf(TelemetryConfidenceReason.DEVICE_MOVEMENT_NOT_EVALUATED)))))) },
            { p -> p.copy(confidence = p.confidence.copy(components = p.confidence.components.copy(
                gyroscope = p.confidence.components.gyroscope.copy(assessment = TelemetryConfidenceAssessment(
                    TelemetryConfidenceState.DEGRADED, setOf(TelemetryConfidenceReason.IMU_INTERPOLATED, TelemetryConfidenceReason.IMU_SENSOR_UNRELIABLE)))))) },
            { p -> p.copy(confidence = p.confidence.copy(components = p.confidence.components.copy(
                gyroscope = p.confidence.components.gyroscope.copy(upperTripElapsedNanos = p.derived.tripElapsedNanos + 100_000_000L,
                    upperSourceTimestampNanos = 10*SECOND + p.derived.tripElapsedNanos + 100_000_000L)))) },
            { p -> val yaw = p.derived.yawRateRadiansPerSecond as DerivedScalarValue.Available
                p.copy(derived = p.derived.copy(yawRateRadiansPerSecond = yaw.copy(
                    evidence = yaw.evidence + DerivedChannelEvidence.CALIBRATION_DEGRADED))) },
            { p -> val yaw = p.derived.yawRateRadiansPerSecond as DerivedScalarValue.Available
                p.copy(derived = p.derived.copy(yawRateRadiansPerSecond = yaw.copy(
                    provenance = yaw.provenance.copy(minimumImuAccuracyStatus = 0)))) },
            { p -> p.copy(confidence = p.confidence.copy(eligibility = p.confidence.eligibility.copy(
                yawRate = p.confidence.eligibility.yawRate.copy(limitingComponents = setOf(TelemetryConfidenceComponentKind.CALIBRATION))))) },
        )
        for (change in cases) {
            val frames = t.synchronizedFrames().map { if (it.derived.tripElapsedNanos == 4*SECOND) change(it) else it }
            rejected(ProvisionalFeatureRejection.CHANNEL_UNAVAILABLE_OR_LIMITED,
                ProvisionalEventFeatureExtractor.extractFrames(frames, t.sourceTimeline.motionContexts, SECOND,
                    ProvisionalFeaturePolicy.INTERPOLATION_V2))
        }
    }

    @Test
    fun `v2 still rejects calibration faults context changes bad bounds and unsupported configs`() {
        val t = timeline()
        val segment = t.sourceTimeline.motionContexts.segments.single()
        val calibration = requireNotNull(segment.calibrationResult.calibration)
        val badCalibration = DerivedMotionContextTimeline(listOf(segment.copy(calibrationResult = segment.calibrationResult.copy(
            calibration = calibration.copy(accelerometerMinimumAccuracyStatus = 0)))))
        rejected(ProvisionalFeatureRejection.CALIBRATION_OR_MOUNT_UNRESOLVED,
            ProvisionalEventFeatureExtractor.extractFrames(t.synchronizedFrames(), badCalibration, SECOND,
                ProvisionalFeaturePolicy.INTERPOLATION_V2))
        val changed = DerivedMotionContextTimeline(listOf(segment.copy(endTripElapsedNanosExclusive = 4*SECOND),
            segment.copy(startTripElapsedNanos = 4*SECOND)))
        rejected(ProvisionalFeatureRejection.CONTEXT_UNAVAILABLE_OR_CHANGED,
            ProvisionalEventFeatureExtractor.extractFrames(t.synchronizedFrames(), changed, SECOND,
                ProvisionalFeaturePolicy.INTERPOLATION_V2))
        rejected(ProvisionalFeatureRejection.INVALID_BOUNDS, ProvisionalInterpolatedEventFeatureExtractor.extract(t, Long.MAX_VALUE))
        val config = TelemetryConfidencePipeline.build(t.sourceTimeline, TelemetryConfidenceConfig(preferredGnssHorizontalAccuracyMetres = 10.0))
        rejected(ProvisionalFeatureRejection.UNSUPPORTED_CONFIGURATION, ProvisionalInterpolatedEventFeatureExtractor.extract(config, SECOND))
    }

    @Test
    fun `v2 exposes native calibration interpolation without changing calibration state`() {
        val t = timeline(calibrationInterpolatedFrames = 1)
        val q = requireNotNull((ProvisionalInterpolatedEventFeatureExtractor.extract(t, SECOND)
            as ProvisionalFeatureResult.Window).inputQuality)
        assertEquals(1, q.calibrationAccelerometerInterpolatedFrames)
        assertEquals(1, q.calibrationGyroscopeInterpolatedFrames)
        assertTrue(q.hasInterpolationEvidence)
        assertFalse(q.nativeMetricsLimited)
        assertEquals(ImuCalibrationState.CALIBRATED, t.sourceTimeline.motionContexts.segments.single().calibrationResult.state)
    }

    private fun rejected(reason: ProvisionalFeatureRejection, result: ProvisionalFeatureResult) {
        assertEquals(reason, (result as ProvisionalFeatureResult.Rejected).reason)
    }

    private fun timeline(
        unreliableAt: Long? = null,
        gyroscopeOffsetNanos: Long = 0L,
        offsetUntilNanos: Long = Long.MAX_VALUE,
        gyroscopeMissingRange: LongRange? = null,
        flagAt: Long? = null,
        sourceFlag: ImuQualityFlag = ImuQualityFlag.SENSOR_UNRELIABLE,
        calibrationInterpolatedFrames: Int = 0,
    ): TelemetryConfidenceTimeline {
        val records = (0L..700L).flatMap { i ->
            val time = i * STEP
            listOf(ImuSensorType.ACCELEROMETER, ImuSensorType.GYROSCOPE).mapNotNull { sensor ->
                if (sensor == ImuSensorType.GYROSCOPE && gyroscopeMissingRange != null && time in gyroscopeMissingRange) return@mapNotNull null
                val sampleTime = time + if (sensor == ImuSensorType.GYROSCOPE && time < offsetUntilNanos) gyroscopeOffsetNanos else 0L
                val value = if (sensor == ImuSensorType.ACCELEROMETER)
                    FrameVector3(1.0, 2.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED + 3.0)
                else FrameVector3(0.0, 0.0, 0.4)
                TelemetrySampleRecord.Imu(testImuSample(sensorType = sensor, tripElapsedNanos = sampleTime,
                    sourceTimestampNanos = 10 * SECOND + sampleTime).copy(x = value.x.toFloat(), y = value.y.toFloat(),
                    z = value.z.toFloat(), accuracyStatus = if (time == unreliableAt || (time == flagAt && sourceFlag == ImuQualityFlag.SENSOR_UNRELIABLE)) 0 else 3,
                    qualityFlags = if (time == unreliableAt) setOf(ImuQualityFlag.SENSOR_UNRELIABLE) else
                        if (time == flagAt) setOf(sourceFlag) else emptySet()))
            }
        }
        val chunks = records.chunked(100).mapIndexed { index, group -> TelemetryChunkCodec.encode(
            tripId = TEST_TRIP_ID, sequence = index.toLong(), records = group, createdAtUtcEpochMillis = 1_777_777_777_500L,
        ).bytes }
        val raw = (RawTelemetryTripDecoder.decode(chunks) as RawTelemetryTripDecodeResult.Success).trip
        val analysis = (AnalysisTimelineResampler.build(raw) as AnalysisTimelineBuildResult.Success).timeline
        val calibration = ImuStationaryCalibrationResult(
            ImuCalibrationState.CALIBRATED, ImuStationaryCalibrationConfig(),
            ImuBiasCalibration(startTripElapsedNanos = 0, endTripElapsedNanos = 0, sampleCount = 2,
                meanAccelerometerDeviceMetresPerSecondSquared = CalibrationVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED),
                gravityDirectionDevice = CalibrationVector3(0.0, 0.0, 1.0),
                observableAccelerometerRadialBiasMetresPerSecondSquared = 0.0,
                observableAccelerometerRadialBiasDeviceMetresPerSecondSquared = CalibrationVector3(0.0, 0.0, 0.0),
                gyroscopeBiasDeviceRadiansPerSecond = CalibrationVector3(0.0, 0.0, 0.0),
                accelerometerAxisStandardDeviationMetresPerSecondSquared = CalibrationVector3(0.0, 0.0, 0.0),
                gyroscopeAxisStandardDeviationRadiansPerSecond = CalibrationVector3(0.0, 0.0, 0.0),
                accelerometerMinimumAccuracyStatus = 3, gyroscopeMinimumAccuracyStatus = 3,
                accelerometerInterpolatedFrameCount = calibrationInterpolatedFrames,
                gyroscopeInterpolatedFrameCount = calibrationInterpolatedFrames, rawQualityFlags = emptySet()),
            if (calibrationInterpolatedFrames > 0) setOf(ImuCalibrationEvidence.INTERPOLATED_INPUT) else emptySet(),
            ImuCalibrationDiagnostics(2, 2, 2, 0, 0, 0, 0, 0, 0, 0),
        )
        val mount = VehicleMountAlignmentResolution.Available(VehicleMountAlignment(
            quality = VehicleMountAlignmentQuality.RESOLVED, sourceCalibrationStartTripElapsedNanos = 0,
            sourceCalibrationEndTripElapsedNanos = 0, forwardDevice = FrameVector3.DEVICE_TOP,
            leftDevice = FrameVector3.DEVICE_RIGHT * -1.0, upDevice = FrameVector3.DEVICE_SCREEN_OUT,
            deviceToVehicleForwardLeftUp = FrameTransformMatrix.ofRows(FrameVector3.DEVICE_TOP,
                FrameVector3.DEVICE_RIGHT * -1.0, FrameVector3.DEVICE_SCREEN_OUT),
            evidence = setOf(VehicleMountAlignmentEvidence.EXPLICIT_DEVICE_FORWARD_HINT),
        ))
        val derived = (DerivedTelemetryPipeline.build(analysis,
            (GnssSanityFilter.process(raw) as GnssProcessingResult.Success).summary,
            DerivedMotionContextTimeline.fixed(calibration, mount)) as DerivedTelemetryBuildResult.Success).timeline
        return TelemetryConfidencePipeline.build(derived)
    }

    private companion object {
        const val STEP = 10_000_000L
        const val SECOND = 1_000_000_000L
    }
}
