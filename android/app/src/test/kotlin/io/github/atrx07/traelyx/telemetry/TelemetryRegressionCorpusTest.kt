package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.TelemetryChannel
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import kotlin.math.abs
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TelemetryRegressionCorpusTest {
    @Test
    fun `corpus is versioned synthetic private-route-safe and byte deterministic`() {
        assertEquals(1, TelemetryRegressionFixtureCorpus.VERSION)
        assertEquals(
            setOf(
                TelemetryRegressionScenario.STATIONARY,
                TelemetryRegressionScenario.SMOOTH_STRAIGHT,
                TelemetryRegressionScenario.SMOOTH_ACCELERATION,
                TelemetryRegressionScenario.BRAKING,
                TelemetryRegressionScenario.LEFT_CORNER,
                TelemetryRegressionScenario.RIGHT_CORNER,
                TelemetryRegressionScenario.POTHOLE,
                TelemetryRegressionScenario.PHONE_MOVE,
                TelemetryRegressionScenario.GNSS_LOSS,
                TelemetryRegressionScenario.MOTORCYCLE_VIBRATION,
            ),
            TelemetryRegressionFixtureCorpus.scenarios.toSet(),
        )

        TelemetryRegressionFixtureCorpus.scenarios.forEach { scenario ->
            val first = TelemetryRegressionFixtureCorpus.generate(scenario)
            val second = TelemetryRegressionFixtureCorpus.generate(scenario)
            assertEquals(first.corpusVersion, second.corpusVersion)
            assertEquals(first.scenario, second.scenario)
            assertEquals(first.records, second.records)
            val firstChunks = first.encodedChunks()
            val secondChunks = second.encodedChunks()
            assertEquals(firstChunks.size, secondChunks.size)
            firstChunks.zip(secondChunks).forEach { (left, right) ->
                assertArrayEquals(left, right)
            }
            first.records
                .asSequence()
                .filterIsInstance<TelemetrySampleRecord.Gnss>()
                .forEach { record ->
                    assertTrue(abs(record.sample.latitudeDegrees) < 0.01)
                    assertTrue(abs(record.sample.longitudeDegrees) < 0.01)
                }
        }
    }

    @Test
    fun `straight and stationary fixtures preserve vehicle motion boundaries`() {
        val stationary = run(TelemetryRegressionScenario.STATIONARY)
        val stationaryFrames = stationary.actionDerivedFrames()
        assertTrue(stationaryFrames.isNotEmpty())
        assertTrue(stationaryFrames.all { it.movementState.state == MovementState.STOPPED })
        assertTrue(stationaryFrames.scalarValues { it.filteredSpeedMetresPerSecond }.max() < 0.05)
        assertTrue(
            stationaryFrames.vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
                .maxOf { maxOf(abs(it.x), abs(it.y), abs(it.z)) } < 0.05,
        )

        val straight = run(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        val steady = straight.derivedFrames.inTimeRange(8_000_000_000L, 11_000_000_000L)
        assertTrue(steady.scalarValues { it.filteredSpeedMetresPerSecond }.average() in 8.0..10.5)
        assertTrue(steady.any { it.movementState.state == MovementState.MOVING })
        assertTrue(
            steady.vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
                .maxOf { maxOf(abs(it.x), abs(it.y), abs(it.z)) } < 0.10,
        )
        assertTrue(steady.scalarValues { it.yawRateRadiansPerSecond }.maxOf(::abs) < 0.01)
    }

    @Test
    fun `acceleration and braking fixtures preserve forward-axis sign and magnitude`() {
        val acceleration = run(TelemetryRegressionScenario.SMOOTH_ACCELERATION)
        val accelerationValues =
            acceleration.derivedFrames
                .inTimeRange(5_600_000_000L, 9_000_000_000L)
                .vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
        assertTrue(accelerationValues.map { it.x }.average() in 1.5..2.2)
        assertTrue(accelerationValues.maxOf { abs(it.y) } < 0.10)

        val braking = run(TelemetryRegressionScenario.BRAKING)
        val brakingValues =
            braking.derivedFrames
                .inTimeRange(5_600_000_000L, 7_500_000_000L)
                .vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
        assertTrue(brakingValues.map { it.x }.average() in -3.2..-2.5)
        assertTrue(brakingValues.maxOf { abs(it.y) } < 0.10)
    }

    @Test
    fun `left and right corner fixtures preserve lateral yaw and heading signs`() {
        val left = run(TelemetryRegressionScenario.LEFT_CORNER)
        val right = run(TelemetryRegressionScenario.RIGHT_CORNER)
        val leftFrames = left.derivedFrames.inTimeRange(6_000_000_000L, 10_500_000_000L)
        val rightFrames = right.derivedFrames.inTimeRange(6_000_000_000L, 10_500_000_000L)

        assertTrue(
            leftFrames.vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
                .map { it.y }.average() in 2.0..2.7,
        )
        assertTrue(leftFrames.scalarValues { it.yawRateRadiansPerSecond }.average() in 0.20..0.27)
        assertTrue(
            leftFrames.scalarValues { it.headingChangeRateRadiansPerSecond }.average() in 0.20..0.27,
        )
        assertTrue(
            rightFrames.vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
                .map { it.y }.average() in -2.7..-2.0,
        )
        assertTrue(rightFrames.scalarValues { it.yawRateRadiansPerSecond }.average() in -0.27..-0.20)
        assertTrue(
            rightFrames.scalarValues { it.headingChangeRateRadiansPerSecond }.average() in -0.27..-0.20,
        )
    }

    @Test
    fun `pothole fixture survives filtering and replay envelope reduction`() {
        val run = run(TelemetryRegressionScenario.POTHOLE)
        val derivedPeak =
            run.derivedFrames
                .inTimeRange(6_500_000_000L, 7_800_000_000L)
                .mapNotNull {
                    it.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available
                }
                .maxBy { it.value.z }
        assertTrue(derivedPeak.value.z > 1.0)
        assertTrue(abs(derivedPeak.value.x) < 0.10)
        assertTrue(abs(derivedPeak.value.y) < 0.10)

        val replayPeak =
            run.replayFrames
                .mapNotNull { it.vehicleAccelerationMetresPerSecondSquared.z?.maximum }
                .maxBy { it.value.z }
        assertEquals(derivedPeak, replayPeak)
    }

    @Test
    fun `phone movement invalidates orientation-dependent channels without a device offset`() {
        val run = run(TelemetryRegressionScenario.PHONE_MOVE)
        assertEquals(OrientationChangeState.INVALIDATED, run.orientationChange.state)
        assertTrue(
            OrientationChangeEvidence.GRAVITY_DIRECTION_CHANGED in
                run.orientationChange.evidence,
        )
        assertEquals(
            VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED,
            (run.mountAlignment as VehicleMountAlignmentResolution.Unavailable).reason,
        )

        val afterMove = run.derivedFrames.first { it.tripElapsedNanos == 6_000_000_000L }
        assertEquals(
            DerivedChannelMissingReason.MOUNT_ALIGNMENT_UNAVAILABLE,
            (afterMove.vehicleAccelerationMetresPerSecondSquared as DerivedVectorValue.Missing)
                .unavailable.reason,
        )
        val confidence = run.confidenceFrames.first { it.tripElapsedNanos == 6_000_000_000L }
        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            confidence.components.orientation.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.INVALIDATED,
            confidence.components.deviceMovement.assessment.state,
        )
        assertEquals(
            TelemetryEligibility.EXCLUDED,
            confidence.eligibility.vehicleAcceleration.eligibility,
        )
        assertTrue(
            run.replayFrames.any {
                it.confidence.deviceMovement.mostSevere == TelemetryConfidenceState.INVALIDATED
            },
        )
    }

    @Test
    fun `GNSS loss becomes unavailable and then recovers with explicit gap evidence`() {
        val run = run(TelemetryRegressionScenario.GNSS_LOSS)
        val duringLoss = run.confidenceFrames.first { it.tripElapsedNanos == 8_000_000_000L }
        assertEquals(TelemetryConfidenceState.UNAVAILABLE, duringLoss.components.gnss.assessment.state)
        assertEquals(TelemetryEligibility.EXCLUDED, duringLoss.eligibility.filteredSpeed.eligibility)
        assertEquals(
            MovementState.UNKNOWN,
            run.derivedFrames.first { it.tripElapsedNanos == 8_000_000_000L }.movementState.state,
        )
        assertEquals(
            TelemetryEligibility.ELIGIBLE,
            duringLoss.eligibility.vehicleAcceleration.eligibility,
        )

        val recovery =
            run.gnssSummary.samples.first {
                it.rawSample.tripElapsedNanos ==
                    TelemetryRegressionFixtureCorpus.GNSS_LOSS_END_NANOS
            }
        assertEquals(GnssDecision.RESET_AFTER_GAP, recovery.decision)
        assertTrue(GnssProcessingEvidence.SEGMENT_GAP in recovery.evidence)
        val recoveryConfidence =
            run.confidenceFrames.first {
                it.tripElapsedNanos == TelemetryRegressionFixtureCorpus.GNSS_LOSS_END_NANOS
            }
        assertEquals(TelemetryConfidenceState.DEGRADED, recoveryConfidence.components.gnss.assessment.state)
        assertTrue(
            TelemetryConfidenceReason.GNSS_GAP in
                recoveryConfidence.components.gnss.assessment.reasons,
        )
        assertTrue(
            run.replayFrames.any {
                it.confidence.gnss.mostSevere == TelemetryConfidenceState.UNAVAILABLE
            },
        )
    }

    @Test
    fun `motorcycle vibration fixture stays bounded and auditable`() {
        val run = run(TelemetryRegressionScenario.MOTORCYCLE_VIBRATION)
        val action = run.actionDerivedFrames()
        val acceleration = action.vectorValues { it.vehicleAccelerationMetresPerSecondSquared }
        assertTrue(acceleration.isNotEmpty())
        assertTrue(acceleration.maxOf { maxOf(abs(it.x), abs(it.y), abs(it.z)) } < 0.75)
        assertTrue(action.any { it.movementState.state == MovementState.MOVING })
        val finalConfidence = run.confidenceFrames.last()
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            finalConfidence.components.accelerometer.assessment.state,
        )
        assertEquals(
            TelemetryConfidenceState.SUPPORTED,
            finalConfidence.components.gyroscope.assessment.state,
        )
    }

    @Test
    fun `all fixtures replay deterministically from complete M3 pipeline`() {
        TelemetryRegressionFixtureCorpus.scenarios.forEach { scenario ->
            val run = run(scenario)
            assertEquals(run.analysisTimeline.frameCount, run.derivedFrames.size.toLong())
            assertEquals(run.derivedFrames, run.derivedTimeline.frames().toList())
            assertEquals(run.confidenceFrames, run.confidenceTimeline.frames().toList())
            assertEquals(run.replayFrames, run.replayTimeline.frames().toList())
            assertEquals(run.replayTimeline.frameCount, run.replayFrames.size.toLong())
            assertEquals(TelemetryRegressionFixtureCorpus.TRIP_END_NANOS, run.replayFrames.last().tripElapsedNanos)
        }
    }

    private fun run(scenario: TelemetryRegressionScenario): TelemetryRegressionRun {
        val fixture = TelemetryRegressionFixtureCorpus.generate(scenario)
        val chunks = fixture.encodedChunks()
        val trip =
            (RawTelemetryTripDecoder.decode(chunks) as RawTelemetryTripDecodeResult.Success).trip
        assertTrue(trip.records(TelemetryChannel.ACCELEROMETER).any())
        assertTrue(trip.records(TelemetryChannel.GYROSCOPE).any())
        assertTrue(trip.records(TelemetryChannel.GNSS).any())
        val analysisTimeline =
            (AnalysisTimelineResampler.build(
                trip,
                AnalysisTimelineConfig(
                    intervalNanos = TelemetryRegressionFixtureCorpus.SAMPLE_INTERVAL_NANOS,
                ),
            ) as AnalysisTimelineBuildResult.Success).timeline
        val gnssSummary =
            (GnssSanityFilter.process(trip) as GnssProcessingResult.Success).summary
        val referenceCalibration =
            ImuStationaryCalibrator.calibrate(
                frames =
                    analysisTimeline.frames().filter {
                        it.tripElapsedNanos <=
                            TelemetryRegressionFixtureCorpus.REFERENCE_CALIBRATION_END_NANOS
                    },
                analysisIntervalNanos = analysisTimeline.config.intervalNanos,
            )
        val subsequentCalibration =
            ImuStationaryCalibrator.calibrate(
                frames =
                    analysisTimeline.frames().filter {
                        it.tripElapsedNanos in
                            TelemetryRegressionFixtureCorpus.SUBSEQUENT_CALIBRATION_START_NANOS..
                                TelemetryRegressionFixtureCorpus.SUBSEQUENT_CALIBRATION_END_NANOS
                    },
                analysisIntervalNanos = analysisTimeline.config.intervalNanos,
            )
        val orientation =
            (TiltOrientationResolver.resolve(referenceCalibration) as TiltOrientationResolution.Available)
                .orientation
        val orientationChange =
            StationaryOrientationChangeDetector.compare(orientation, subsequentCalibration)
        val mountAlignment =
            VehicleMountAlignmentResolver.resolve(
                orientation = orientation,
                explicitForwardHintDevice = FrameVector3.DEVICE_TOP,
                orientationChange = orientationChange,
            )
        val contexts =
            if (scenario == TelemetryRegressionScenario.PHONE_MOVE) {
                val beforeMove =
                    VehicleMountAlignmentResolver.resolve(
                        orientation = orientation,
                        explicitForwardHintDevice = FrameVector3.DEVICE_TOP,
                    )
                DerivedMotionContextTimeline(
                    listOf(
                        DerivedMotionContextSegment(
                            startTripElapsedNanos = 0L,
                            endTripElapsedNanosExclusive =
                                TelemetryRegressionFixtureCorpus.PHONE_MOVE_START_NANOS,
                            calibrationResult = referenceCalibration,
                            mountAlignment = beforeMove,
                        ),
                        DerivedMotionContextSegment(
                            startTripElapsedNanos =
                                TelemetryRegressionFixtureCorpus.PHONE_MOVE_START_NANOS,
                            endTripElapsedNanosExclusive = null,
                            calibrationResult = referenceCalibration,
                            mountAlignment = mountAlignment,
                        ),
                    ),
                )
            } else {
                DerivedMotionContextTimeline.fixed(referenceCalibration, mountAlignment)
            }
        val derivedTimeline =
            (DerivedTelemetryPipeline.build(
                sourceTimeline = analysisTimeline,
                gnssSummary = gnssSummary,
                motionContexts = contexts,
            ) as DerivedTelemetryBuildResult.Success).timeline
        val confidenceTimeline = TelemetryConfidencePipeline.build(derivedTimeline)
        val replayTimeline =
            (ReplayTelemetryPipeline.build(confidenceTimeline) as ReplayTelemetryBuildResult.Success)
                .timeline
        return TelemetryRegressionRun(
            analysisTimeline = analysisTimeline,
            gnssSummary = gnssSummary,
            referenceCalibration = referenceCalibration,
            subsequentCalibration = subsequentCalibration,
            orientationChange = orientationChange,
            mountAlignment = mountAlignment,
            derivedTimeline = derivedTimeline,
            derivedFrames = derivedTimeline.frames().toList(),
            confidenceTimeline = confidenceTimeline,
            confidenceFrames = confidenceTimeline.frames().toList(),
            replayTimeline = replayTimeline,
            replayFrames = replayTimeline.frames().toList(),
        )
    }

    private fun TelemetryRegressionRun.actionDerivedFrames(): List<DerivedTelemetryFrame> =
        derivedFrames.inTimeRange(
            TelemetryRegressionFixtureCorpus.ACTION_START_NANOS,
            TelemetryRegressionFixtureCorpus.ACTION_END_NANOS,
        )

    private fun List<DerivedTelemetryFrame>.inTimeRange(
        startNanos: Long,
        endNanos: Long,
    ): List<DerivedTelemetryFrame> = filter { it.tripElapsedNanos in startNanos..endNanos }

    private fun List<DerivedTelemetryFrame>.scalarValues(
        select: (DerivedTelemetryFrame) -> DerivedScalarValue,
    ): List<Double> =
        mapNotNull { (select(it) as? DerivedScalarValue.Available)?.value }

    private fun List<DerivedTelemetryFrame>.vectorValues(
        select: (DerivedTelemetryFrame) -> DerivedVectorValue,
    ): List<FrameVector3> =
        mapNotNull { (select(it) as? DerivedVectorValue.Available)?.value }
}

private data class TelemetryRegressionRun(
    val analysisTimeline: AnalysisTimeline,
    val gnssSummary: GnssProcessingSummary,
    val referenceCalibration: ImuStationaryCalibrationResult,
    val subsequentCalibration: ImuStationaryCalibrationResult,
    val orientationChange: OrientationChangeResult,
    val mountAlignment: VehicleMountAlignmentResolution,
    val derivedTimeline: DerivedTelemetryTimeline,
    val derivedFrames: List<DerivedTelemetryFrame>,
    val confidenceTimeline: TelemetryConfidenceTimeline,
    val confidenceFrames: List<TelemetryConfidenceFrame>,
    val replayTimeline: ReplayTelemetryTimeline,
    val replayFrames: List<ReplayTelemetryFrame>,
)
