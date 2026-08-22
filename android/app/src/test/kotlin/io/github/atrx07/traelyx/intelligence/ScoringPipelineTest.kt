package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoringPipelineTest {
    @Test
    fun `scoring defaults machine IDs and fixed point policy are stable and versioned`() {
        val config = ScoringConfig()

        assertEquals(1, config.scoringVersion)
        assertEquals(3_000_000_000L, config.minimumMovingDurationNanos)
        assertEquals(500_000_000L, config.minimumControlOpportunityDurationNanos)
        assertEquals(800, config.minimumUsableEvidenceCoveragePermille)
        assertEquals(800, config.minimumFullEvidenceCoveragePermille)
        assertEquals(500, config.limitedEvidenceWeightPermille)
        assertEquals(2_000, config.severityMultiplierCapPermille)
        assertEquals(2, config.minimumOverallDimensionCount)
        assertEquals(15, config.overallRiskGuardrailMarginPoints)
        assertEquals(
            SCORE_WEIGHT_BASIS_POINTS_TOTAL,
            config.dimensionWeightsBasisPoints.values.sum(),
        )
        assertEquals(
            ScoringDimension.entries.size,
            ScoringDimension.entries.map { it.machineId }.toSet().size,
        )
        assertEquals(
            ScoreContributionRule.entries.size,
            ScoreContributionRule.entries.map { it.machineId }.toSet().size,
        )
        assertEquals(78, milliPointsToDisplayScore(77_500L))
        assertTrue(runCatching { ScoringConfig(scoringVersion = 2) }.isFailure)
        assertTrue(runCatching { ScoringConfig(limitedEvidenceWeightPermille = 1_000) }.isFailure)
        assertTrue(
            runCatching {
                ScoringConfig(
                    dimensionWeightsBasisPoints =
                        config.dimensionWeightsBasisPoints +
                            (ScoringDimension.SMOOTHNESS to 2_999),
                )
            }.isFailure,
        )
    }

    @Test
    fun `score retains an immutable configuration snapshot`() {
        val defaults = ScoringConfig()
        val mutablePenalties = defaults.contributionBasePenaltyPoints.toMutableMap()
        val audit =
            score(
                abruptBrakingFixture(),
                defaults.copy(contributionBasePenaltyPoints = mutablePenalties),
            )

        mutablePenalties[ScoreContributionRule.BRAKING_ABRUPT_TRANSITION] = 99
        assertEquals(
            12,
            audit.configSnapshot.contributionBasePenaltyPoints.getValue(
                ScoreContributionRule.BRAKING_ABRUPT_TRANSITION,
            ),
        )
        assertTrue(
            runCatching {
                @Suppress("UNCHECKED_CAST")
                val snapshot =
                    audit.configSnapshot.contributionBasePenaltyPoints as
                        MutableMap<ScoreContributionRule, Int>
                snapshot[ScoreContributionRule.BRAKING_ABRUPT_TRANSITION] = 99
            }.isFailure,
        )
    }

    @Test
    fun `absence of driving opportunity never becomes a falsely precise score`() {
        val stationary = score(TelemetryRegressionScenario.STATIONARY)
        assertEquals(TripScoreState.UNAVAILABLE, stationary.state)
        assertNull(stationary.overallDisplayScore)
        assertEquals(
            ScoreRankingStatus.INELIGIBLE_INSUFFICIENT_SCORE_EVIDENCE,
            stationary.rankingStatus,
        )
        assertTrue(stationary.availableOverallDimensions.isEmpty())
        assertTrue(
            ScoreUnavailableReason.INSUFFICIENT_MOVING_DURATION in
                stationary.dimension(ScoringDimension.SMOOTHNESS).unavailableReasons,
        )

        val smooth = score(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        val smoothness = smooth.dimension(ScoringDimension.SMOOTHNESS)
        assertEquals(ScoreDimensionState.FULL, smoothness.state)
        assertEquals(100, smoothness.displayScore)
        assertTrue(smoothness.contributions.isEmpty())
        assertEquals(TripScoreState.UNAVAILABLE, smooth.state)
        assertNull(smooth.overallDisplayScore)
        assertEquals(setOf(ScoringDimension.SMOOTHNESS), smooth.availableOverallDimensions)
        assertTrue(
            ScoreUnavailableReason.INSUFFICIENT_AVAILABLE_DIMENSIONS in
                smooth.unavailableReasons,
        )
        assertTrue(
            ScoreUnavailableReason.CONSISTENCY_BASELINE_NOT_AVAILABLE in
                smooth.dimension(ScoringDimension.CONSISTENCY).unavailableReasons,
        )
    }

    @Test
    fun `neutral vibration and road impact evidence are not driver control penalties`() {
        listOf(
            TelemetryRegressionScenario.MOTORCYCLE_VIBRATION,
            TelemetryRegressionScenario.POTHOLE,
        ).forEach { scenario ->
            val audit = score(scenario)
            val smoothness = audit.dimension(ScoringDimension.SMOOTHNESS)
            assertEquals("$scenario smoothness", 100, smoothness.displayScore)
            assertTrue("$scenario contributions", smoothness.contributions.isEmpty())
            assertTrue(
                audit.dimensions.values.flatMap { it.contributions }.none { contribution ->
                    contribution.supportingEventIds.any { eventId -> eventId.isBlank() }
                },
            )
        }
    }

    @Test
    fun `governed maneuvers score only dimensions with physical opportunity`() {
        val expectations =
            mapOf(
                TelemetryRegressionScenario.SMOOTH_ACCELERATION to
                    ScoringDimension.ACCELERATION_CONTROL,
                TelemetryRegressionScenario.BRAKING to ScoringDimension.BRAKING_CONTROL,
                TelemetryRegressionScenario.LEFT_CORNER to ScoringDimension.CORNERING_CONTROL,
                TelemetryRegressionScenario.RIGHT_CORNER to ScoringDimension.CORNERING_CONTROL,
            )
        expectations.forEach { (scenario, expectedDimension) ->
            val first = score(scenario)
            val second = score(scenario)
            assertEquals("$scenario should be repeatable", first, second)
            assertEquals(
                "$scenario dimensions=${first.dimensions}",
                TripScoreState.PROVISIONAL,
                first.state,
            )
            assertNotNull(first.overallDisplayScore)
            assertEquals(
                setOf(ScoringDimension.SMOOTHNESS, expectedDimension),
                first.availableOverallDimensions,
            )
            assertTrue(first.dimension(expectedDimension).displayScore in 0..100)
            assertEquals(
                ScoreRankingStatus.INELIGIBLE_PROVISIONAL_SCORE,
                first.rankingStatus,
            )
            assertTrue(
                ScoreProvisionalReason.PARTIAL_DIMENSION_COVERAGE in
                    first.provisionalReasons,
            )
            assertEquals(SCORING_VERSION, first.sourceVersions.scoringVersion)
            assertEquals(
                INTEGRITY_RULES_VERSION,
                first.integrityAudit.integrityVersion,
            )
        }
    }

    @Test
    fun `complete supported opportunity set produces a full rankable score`() {
        val audit = score(multiControlFixture())

        assertEquals(TripIntegrityState.VERIFIED, audit.integrityAudit.state)
        assertEquals(TripScoreState.FULL, audit.state)
        assertEquals(ScoreRankingStatus.ELIGIBLE, audit.rankingStatus)
        assertNotNull(audit.overallDisplayScore)
        assertEquals(SCORABLE_SCORE_DIMENSIONS, audit.availableOverallDimensions)
        assertTrue(
            SCORABLE_SCORE_DIMENSIONS.all {
                audit.dimension(it).state == ScoreDimensionState.FULL
            },
        )
        assertEquals(
            ScoreDimensionState.UNAVAILABLE,
            audit.dimension(ScoringDimension.CONSISTENCY).state,
        )
    }

    @Test
    fun `abrupt evidence produces exact deterministic contribution audit`() {
        val audit = score(abruptBrakingFixture())
        val braking = audit.dimension(ScoringDimension.BRAKING_CONTROL)
        val contribution =
            braking.contributions.single {
                it.rule == ScoreContributionRule.BRAKING_ABRUPT_TRANSITION
            }

        assertEquals(ScoreContributionKind.PENALTY, contribution.kind)
        assertEquals(12, contribution.basePoints)
        assertEquals(SCORE_FULL_WEIGHT_PERMILLE, contribution.confidenceWeightPermille)
        assertTrue(contribution.severityMultiplierPermille in 1_000..2_000)
        assertEquals(
            contribution.basePoints.toLong() * contribution.severityMultiplierPermille,
            contribution.rawPointsMilli,
        )
        assertEquals(contribution.rawPointsMilli, contribution.appliedPointsMilli)
        assertEquals(1, contribution.supportingEventIds.size)
        assertTrue(contribution.contributionId.startsWith("score_v1_SC_BRAKE_"))
        assertTrue(requireNotNull(braking.scoreMilliPoints) < scorePointsToMilli(100))
    }

    @Test
    fun `only strong events after the first receive repeated maneuver penalty`() {
        val braking =
            score(repeatedStrongBrakingFixture())
                .dimension(ScoringDimension.BRAKING_CONTROL)
        val repeated =
            braking.contributions.single {
                it.rule == ScoreContributionRule.BRAKING_REPEATED_STRONG_EVENT
            }

        assertEquals(4, repeated.basePoints)
        assertEquals(1, repeated.supportingEventIds.size)
        assertTrue(repeated.appliedPointsMilli > 0L)
    }

    @Test
    fun `limited evidence halves contribution impact and makes scores provisional`() {
        val supportedFixture = abruptBrakingFixture()
        val supported = score(supportedFixture)
        val limited = score(degradedAccelerometerFixture(supportedFixture))
        val supportedContribution =
            supported.dimension(ScoringDimension.BRAKING_CONTROL).contributions.single {
                it.rule == ScoreContributionRule.BRAKING_ABRUPT_TRANSITION
            }
        val limitedBraking = limited.dimension(ScoringDimension.BRAKING_CONTROL)
        val limitedContribution =
            limitedBraking.contributions.single {
                it.rule == ScoreContributionRule.BRAKING_ABRUPT_TRANSITION
            }

        assertEquals(supportedContribution.rawPointsMilli, limitedContribution.rawPointsMilli)
        assertEquals(500, limitedContribution.confidenceWeightPermille)
        assertEquals(
            roundedPositiveDivide(limitedContribution.rawPointsMilli * 500L, 1_000L),
            limitedContribution.appliedPointsMilli,
        )
        assertEquals(ScoreDimensionState.PROVISIONAL, limitedBraking.state)
        assertTrue(
            ScoreProvisionalReason.LIMITED_TELEMETRY_EVIDENCE in
                limitedBraking.provisionalReasons,
        )
        assertTrue(
            ScoreProvisionalReason.LIMITED_EVENT_EVIDENCE in
                limitedBraking.provisionalReasons,
        )
        assertEquals(TripIntegrityState.LIMITED_CONFIDENCE, limited.integrityAudit.state)
        assertEquals(ScoreRankingStatus.INELIGIBLE_PROVISIONAL_SCORE, limited.rankingStatus)
    }

    @Test
    fun `questionable and unranked integrity govern score and ranking state`() {
        val questionable =
            score(
                impossibleJumpFixture(
                    TelemetryRegressionScenario.SMOOTH_ACCELERATION,
                    setOf(7_000_000_000L),
                ),
            )
        assertEquals(TripIntegrityState.QUESTIONABLE, questionable.integrityAudit.state)
        assertEquals(
            "questionable dimensions=${questionable.dimensions}",
            TripScoreState.PROVISIONAL,
            questionable.state,
        )
        assertNotNull(questionable.overallDisplayScore)
        assertEquals(ScoreRankingStatus.REVIEW_REQUIRED_INTEGRITY, questionable.rankingStatus)
        assertTrue(
            ScoreProvisionalReason.QUESTIONABLE_INTEGRITY in
                questionable.provisionalReasons,
        )

        val unranked =
            score(
                impossibleJumpFixture(
                    TelemetryRegressionScenario.SMOOTH_ACCELERATION,
                    setOf(7_000_000_000L, 8_000_000_000L),
                ),
            )
        assertEquals(TripIntegrityState.UNRANKED, unranked.integrityAudit.state)
        assertEquals(TripScoreState.UNRANKED, unranked.state)
        assertNull(unranked.overallDisplayScore)
        assertEquals(ScoreRankingStatus.INELIGIBLE_INTEGRITY, unranked.rankingStatus)
        assertTrue(ScoreUnavailableReason.INTEGRITY_UNRANKED in unranked.unavailableReasons)
        assertTrue(
            ScoreProvisionalReason.UNRANKED_INTEGRITY in
                unranked.dimension(ScoringDimension.ACCELERATION_CONTROL).provisionalReasons,
        )
    }

    @Test
    fun `overall synthesis applies low dimension guardrail before display rounding`() {
        val defaults = ScoringConfig()
        val penalties =
            defaults.contributionBasePenaltyPoints.toMutableMap().apply {
                this[ScoreContributionRule.SMOOTHNESS_ABRUPT_LONGITUDINAL_TRANSITION] = 1
                this[ScoreContributionRule.ACCELERATION_ABRUPT_TRANSITION] = 50
            }
        val audit =
            score(
                pulse(PulseAxis.DEVICE_Y, firstDelta = 4.0f, secondDelta = 0.0f),
                defaults.copy(contributionBasePenaltyPoints = penalties),
            )
        val acceleration =
            requireNotNull(
                audit.dimension(ScoringDimension.ACCELERATION_CONTROL).scoreMilliPoints,
            )
        val guardrail =
            acceleration + scorePointsToMilli(defaults.overallRiskGuardrailMarginPoints)

        assertTrue(audit.riskGuardrailApplied)
        assertEquals(guardrail, audit.overallScoreMilliPoints)
    }

    @Test
    fun `explicit loss and phone movement never become full rankable scores`() {
        listOf(
            TelemetryRegressionScenario.GNSS_LOSS,
            TelemetryRegressionScenario.PHONE_MOVE,
        ).forEach { scenario ->
            val audit = score(scenario)
            assertEquals(TripIntegrityState.LIMITED_CONFIDENCE, audit.integrityAudit.state)
            assertFalse(audit.state == TripScoreState.FULL)
            assertFalse(audit.rankingStatus == ScoreRankingStatus.ELIGIBLE)
        }
    }

    private fun TripScoreAudit.dimension(dimension: ScoringDimension): DimensionScore =
        dimensions.getValue(dimension)

    private fun score(scenario: TelemetryRegressionScenario): TripScoreAudit =
        score(TelemetryRegressionFixtureCorpus.generate(scenario))

    private fun score(
        fixture: TelemetryRegressionFixture,
        config: ScoringConfig = ScoringConfig(),
    ): TripScoreAudit =
        ScoringPipeline.score(
            EventMergePipeline.build(
                EventTaxonomyPipeline.build(confidenceTimelineFor(fixture)),
            ),
            config,
        )

    private fun abruptBrakingFixture(): TelemetryRegressionFixture =
        pulse(PulseAxis.DEVICE_Y, firstDelta = -4.0f, secondDelta = 0.0f)

    private fun multiControlFixture(): TelemetryRegressionFixture {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        return source.copy(
            records =
                source.records.map { record ->
                    if (
                        record !is TelemetrySampleRecord.Imu ||
                        record.sample.sensorType != ImuSensorType.ACCELEROMETER
                    ) {
                        return@map record
                    }
                    when (record.tripElapsedNanos) {
                        in 6_000_000_000L until 7_000_000_000L ->
                            record.copy(sample = record.sample.copy(y = record.sample.y + 1.0f))
                        in 7_000_000_000L until 8_000_000_000L ->
                            record.copy(sample = record.sample.copy(y = record.sample.y - 1.0f))
                        in 8_000_000_000L until 9_000_000_000L ->
                            record.copy(sample = record.sample.copy(x = record.sample.x - 1.0f))
                        else -> record
                    }
                },
        )
    }

    private fun repeatedStrongBrakingFixture(): TelemetryRegressionFixture {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        return source.copy(
            records =
                source.records.map { record ->
                    if (
                        record is TelemetrySampleRecord.Imu &&
                        record.sample.sensorType == ImuSensorType.ACCELEROMETER &&
                        (
                            record.tripElapsedNanos in
                                6_000_000_000L until 7_000_000_000L ||
                                record.tripElapsedNanos in
                                8_000_000_000L until 9_000_000_000L
                        )
                    ) {
                        record.copy(sample = record.sample.copy(y = record.sample.y - 3.0f))
                    } else {
                        record
                    }
                },
        )
    }

    private fun degradedAccelerometerFixture(
        source: TelemetryRegressionFixture,
    ): TelemetryRegressionFixture {
        return source.copy(
            records =
                source.records.map { record ->
                    if (
                        record is TelemetrySampleRecord.Imu &&
                        record.sample.sensorType == ImuSensorType.ACCELEROMETER
                    ) {
                        record.copy(
                            sample =
                                record.sample.copy(
                                    accuracyStatus = 0,
                                    qualityFlags = setOf(ImuQualityFlag.SENSOR_UNRELIABLE),
                                ),
                        )
                    } else {
                        record
                    }
                },
        )
    }

    private fun pulse(
        axis: PulseAxis,
        firstDelta: Float,
        secondDelta: Float,
    ): TelemetryRegressionFixture {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        return source.copy(
            records =
                source.records.map { record ->
                    if (
                        record !is TelemetrySampleRecord.Imu ||
                        record.sample.sensorType != ImuSensorType.ACCELEROMETER
                    ) {
                        return@map record
                    }
                    val delta =
                        when (record.tripElapsedNanos) {
                            in PULSE_START_NANOS until PULSE_MIDDLE_NANOS -> firstDelta
                            in PULSE_MIDDLE_NANOS until PULSE_END_NANOS -> secondDelta
                            else -> 0.0f
                        }
                    record.copy(
                        sample =
                            when (axis) {
                                PulseAxis.DEVICE_X -> record.sample.copy(x = record.sample.x + delta)
                                PulseAxis.DEVICE_Y -> record.sample.copy(y = record.sample.y + delta)
                            },
                    )
                },
        )
    }

    private fun impossibleJumpFixture(
        scenario: TelemetryRegressionScenario,
        times: Set<Long>,
    ): TelemetryRegressionFixture {
        val source = TelemetryRegressionFixtureCorpus.generate(scenario)
        return source.copy(
            records =
                source.records.map { record ->
                    if (record is TelemetrySampleRecord.Gnss && record.tripElapsedNanos in times) {
                        record.copy(
                            sample =
                                record.sample.copy(
                                    latitudeDegrees = record.sample.latitudeDegrees + 1.0,
                                ),
                        )
                    } else {
                        record
                    }
                },
        )
    }

    private enum class PulseAxis {
        DEVICE_X,
        DEVICE_Y,
    }

    private companion object {
        const val PULSE_START_NANOS = 7_000_000_000L
        const val PULSE_MIDDLE_NANOS = 8_000_000_000L
        const val PULSE_END_NANOS = 9_000_000_000L
    }
}
