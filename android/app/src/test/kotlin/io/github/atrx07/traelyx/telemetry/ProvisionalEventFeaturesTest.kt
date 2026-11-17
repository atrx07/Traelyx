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

    private fun rejected(reason: ProvisionalFeatureRejection, result: ProvisionalFeatureResult) {
        assertEquals(reason, (result as ProvisionalFeatureResult.Rejected).reason)
    }

    private fun timeline(unreliableAt: Long? = null, gyroscopeOffsetNanos: Long = 0L): TelemetryConfidenceTimeline {
        val records = (0L..700L).flatMap { i ->
            val time = i * STEP
            listOf(ImuSensorType.ACCELEROMETER, ImuSensorType.GYROSCOPE).map { sensor ->
                val sampleTime = time + if (sensor == ImuSensorType.GYROSCOPE) gyroscopeOffsetNanos else 0L
                val value = if (sensor == ImuSensorType.ACCELEROMETER)
                    FrameVector3(1.0, 2.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED + 3.0)
                else FrameVector3(0.0, 0.0, 0.4)
                TelemetrySampleRecord.Imu(testImuSample(sensorType = sensor, tripElapsedNanos = sampleTime,
                    sourceTimestampNanos = 10 * SECOND + sampleTime).copy(x = value.x.toFloat(), y = value.y.toFloat(),
                    z = value.z.toFloat(), accuracyStatus = if (time == unreliableAt) 0 else 3,
                    qualityFlags = if (time == unreliableAt) setOf(ImuQualityFlag.SENSOR_UNRELIABLE) else emptySet()))
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
                accelerometerInterpolatedFrameCount = 0, gyroscopeInterpolatedFrameCount = 0, rawQualityFlags = emptySet()),
            emptySet(), ImuCalibrationDiagnostics(2, 2, 2, 0, 0, 0, 0, 0, 0, 0),
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
