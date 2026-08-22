package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DriveDnaPipelineTest {
    @Test
    fun `drive DNA policy and dimension machine IDs are stable and versioned`() {
        val config = DriveDnaConfig()

        assertEquals(1, DRIVE_DNA_VERSION)
        assertEquals(5, config.minimumEligibleObservationCount)
        assertEquals(3, config.minimumConsistencyDimensionCount)
        assertEquals(2_000, config.consistencyPenaltyPermillePerDeviationPoint)
        assertEquals(
            listOf(
                "SCORE_SMOOTHNESS",
                "SCORE_BRAKING_CONTROL",
                "SCORE_ACCELERATION_CONTROL",
                "SCORE_CORNERING_CONTROL",
            ),
            DRIVE_DNA_DIRECT_DIMENSIONS.map { it.machineId },
        )
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaConfig(minimumEligibleObservationCount = 1)
        }
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaConfig(minimumConsistencyDimensionCount = 5)
        }
    }

    @Test
    fun `trip score observation preserves the governed raw to score source contract`() {
        val scoreAudit = score(multiControlFixture())
        val observation = DriveDnaPipeline.observe(scoreAudit)

        assertEquals(scoreAudit.tripId, observation.tripId)
        assertEquals(SCORING_VERSION, observation.scoringVersion)
        assertEquals(TripScoreState.FULL, observation.tripScoreState)
        assertEquals(TripIntegrityState.VERIFIED, observation.integrityState)
        DRIVE_DNA_DIRECT_DIMENSIONS.forEach { dimension ->
            val source = scoreAudit.dimensions.getValue(dimension)
            val captured = observation.dimensions.getValue(dimension)
            assertEquals(source.state, captured.scoreState)
            assertEquals(source.scoreMilliPoints, captured.scoreMilliPoints)
            assertEquals(source.displayScore, captured.displayScore)
        }
        assertEquals(
            ScoreDimensionState.UNAVAILABLE,
            observation.dimensions.getValue(ScoringDimension.CONSISTENCY).scoreState,
        )
    }

    @Test
    fun `empty and early histories remain unavailable instead of inventing a baseline`() {
        val empty = DriveDnaPipeline.build("profile-empty", emptyList())
        assertEquals(DriveDnaProfileState.UNAVAILABLE, empty.state)
        assertTrue(empty.eligibleTripIds.isEmpty())
        empty.dimensions.values.forEach { dimension ->
            assertEquals(DriveDnaDimensionState.UNAVAILABLE, dimension.state)
            assertNull(dimension.valueMilliPoints)
            assertEquals(
                setOf(DriveDnaUnavailableReason.NO_TRIP_OBSERVATIONS),
                dimension.unavailableReasons,
            )
        }

        val early =
            DriveDnaPipeline.build(
                "profile-early",
                (1..4).map { index -> observation("trip-$index", uniformScores(90)) },
            )
        assertEquals(DriveDnaProfileState.UNAVAILABLE, early.state)
        DRIVE_DNA_DIRECT_DIMENSIONS.forEach { dimension ->
            val audit = early.dimensions.getValue(dimension)
            assertEquals(4, audit.eligibleTripCount)
            assertEquals(
                setOf(DriveDnaUnavailableReason.INSUFFICIENT_FULL_ELIGIBLE_OBSERVATIONS),
                audit.unavailableReasons,
            )
        }
        assertEquals(
            setOf(DriveDnaUnavailableReason.INSUFFICIENT_COMPARABLE_DIMENSIONS),
            early.dimensions.getValue(ScoringDimension.CONSISTENCY).unavailableReasons,
        )
    }

    @Test
    fun `five comparable trips produce median dimensions and exact consistency audit`() {
        val observations =
            listOf(
                observation("trip-1", directScores(90, 80, 70, 60)),
                observation("trip-2", directScores(90, 82, 74, 66)),
                observation("trip-3", directScores(90, 78, 66, 54)),
                observation("trip-4", directScores(90, 80, 70, 60)),
                observation("trip-5", directScores(90, 80, 70, 60)),
            )

        val first = DriveDnaPipeline.build("profile-stable", observations)
        val second = DriveDnaPipeline.build("profile-stable", observations.reversed())

        assertEquals(first, second)
        assertEquals(DriveDnaProfileState.COMPLETE, first.state)
        assertEquals(scorePointsToMilli(90), first.value(ScoringDimension.SMOOTHNESS))
        assertEquals(scorePointsToMilli(80), first.value(ScoringDimension.BRAKING_CONTROL))
        assertEquals(scorePointsToMilli(70), first.value(ScoringDimension.ACCELERATION_CONTROL))
        assertEquals(scorePointsToMilli(60), first.value(ScoringDimension.CORNERING_CONTROL))
        assertEquals(
            listOf(0L, 800L, 1_600L, 2_400L),
            DRIVE_DNA_DIRECT_DIMENSIONS.map {
                first.dimensions.getValue(it).sourceMeanAbsoluteDeviationMilliPoints
            },
        )
        val consistency = first.dimensions.getValue(ScoringDimension.CONSISTENCY)
        assertEquals(1_200L, consistency.sourceMeanAbsoluteDeviationMilliPoints)
        assertEquals(97_600L, consistency.valueMilliPoints)
        assertEquals(98, consistency.displayValue)
        assertEquals(DRIVE_DNA_DIRECT_DIMENSIONS.toSet(), consistency.contributingDimensions)
        assertEquals(observations.map { it.tripId }.sorted(), consistency.sourceTripIds)
    }

    @Test
    fun `greater trip to trip dispersion reduces only the consistency dimension`() {
        val stable =
            (1..5).map { index -> observation("stable-$index", uniformScores(80)) }
        val dispersed =
            listOf(60, 70, 80, 90, 100).mapIndexed { index, value ->
                observation("dispersed-$index", uniformScores(value))
            }

        val stableProfile = DriveDnaPipeline.build("stable", stable)
        val dispersedProfile = DriveDnaPipeline.build("dispersed", dispersed)

        DRIVE_DNA_DIRECT_DIMENSIONS.forEach { dimension ->
            assertEquals(stableProfile.value(dimension), dispersedProfile.value(dimension))
        }
        assertEquals(scorePointsToMilli(100), stableProfile.value(ScoringDimension.CONSISTENCY))
        assertEquals(scorePointsToMilli(76), dispersedProfile.value(ScoringDimension.CONSISTENCY))
    }

    @Test
    fun `partial evidence cannot silently become a complete Drive DNA profile`() {
        val states =
            mapOf(
                ScoringDimension.ACCELERATION_CONTROL to ScoreDimensionState.UNAVAILABLE,
                ScoringDimension.CORNERING_CONTROL to ScoreDimensionState.UNAVAILABLE,
            )
        val observations =
            (1..5).map { index ->
                observation("partial-$index", uniformScores(85), states)
            }

        val defaultProfile = DriveDnaPipeline.build("partial-default", observations)
        assertEquals(DriveDnaProfileState.PARTIAL, defaultProfile.state)
        assertEquals(
            DriveDnaDimensionState.UNAVAILABLE,
            defaultProfile.dimensions.getValue(ScoringDimension.CONSISTENCY).state,
        )

        val twoDimensionConsistency =
            DriveDnaPipeline.build(
                profileKey = "partial-two-dimension-consistency",
                observations = observations,
                config = DriveDnaConfig(minimumConsistencyDimensionCount = 2),
            )
        assertEquals(DriveDnaProfileState.PARTIAL, twoDimensionConsistency.state)
        assertEquals(
            DriveDnaDimensionState.AVAILABLE,
            twoDimensionConsistency.dimensions.getValue(ScoringDimension.CONSISTENCY).state,
        )
        assertEquals(
            setOf(ScoringDimension.SMOOTHNESS, ScoringDimension.BRAKING_CONTROL),
            twoDimensionConsistency
                .dimensions
                .getValue(ScoringDimension.CONSISTENCY)
                .contributingDimensions,
        )
    }

    @Test
    fun `provisional and non verified trip dimensions are excluded from the baseline`() {
        val observations =
            listOf(
                observation("trip-1", uniformScores(90)),
                observation("trip-2", uniformScores(90)),
                observation("trip-3", uniformScores(90)),
                observation("trip-4", uniformScores(90)),
                observation(
                    "trip-limited",
                    uniformScores(90),
                    integrityState = TripIntegrityState.LIMITED_CONFIDENCE,
                ),
                observation(
                    "trip-provisional",
                    uniformScores(90),
                    states =
                        mapOf(
                            ScoringDimension.BRAKING_CONTROL to
                                ScoreDimensionState.PROVISIONAL,
                        ),
                ),
            )

        val profile = DriveDnaPipeline.build("profile-filtered", observations)

        assertEquals(DriveDnaProfileState.PARTIAL, profile.state)
        assertEquals(
            5,
            profile.dimensions.getValue(ScoringDimension.SMOOTHNESS).eligibleTripCount,
        )
        assertEquals(
            4,
            profile.dimensions.getValue(ScoringDimension.BRAKING_CONTROL).eligibleTripCount,
        )
        assertFalse("trip-limited" in profile.eligibleTripIds)
        assertTrue("trip-provisional" in profile.eligibleTripIds)
    }

    @Test
    fun `profile snapshots caller observations and rejects duplicate trip weighting`() {
        val mutableDimensions = LinkedHashMap(referenceObservation.dimensions)
        val mutableObservation =
            referenceObservation.copy(tripId = "trip-snapshot", dimensions = mutableDimensions)
        val profile = DriveDnaPipeline.build("profile-snapshot", listOf(mutableObservation))
        mutableDimensions[ScoringDimension.SMOOTHNESS] =
            DriveDnaTripDimensionObservation(
                dimension = ScoringDimension.SMOOTHNESS,
                scoreState = ScoreDimensionState.UNAVAILABLE,
                scoreMilliPoints = null,
                displayScore = null,
            )

        assertEquals(
            ScoreDimensionState.FULL,
            profile
                .observations
                .single()
                .dimensions
                .getValue(ScoringDimension.SMOOTHNESS)
                .scoreState,
        )
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaPipeline.build(
                "profile-duplicate",
                listOf(mutableObservation, mutableObservation),
            )
        }
    }

    @Test
    fun `compact observations reject impossible scoring and integrity combinations`() {
        assertThrows(IllegalArgumentException::class.java) {
            referenceObservation.copy(
                tripScoreState = TripScoreState.PROVISIONAL,
                integrityState = TripIntegrityState.LIMITED_CONFIDENCE,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            referenceObservation.copy(tripScoreState = TripScoreState.UNRANKED)
        }
        val dimensions = LinkedHashMap(referenceObservation.dimensions)
        dimensions[ScoringDimension.CONSISTENCY] =
            DriveDnaTripDimensionObservation(
                dimension = ScoringDimension.CONSISTENCY,
                scoreState = ScoreDimensionState.FULL,
                scoreMilliPoints = scorePointsToMilli(100),
                displayScore = 100,
            )
        assertThrows(IllegalArgumentException::class.java) {
            referenceObservation.copy(dimensions = dimensions)
        }
    }

    private fun DriveDnaProfileAudit.value(dimension: ScoringDimension): Long? =
        dimensions.getValue(dimension).valueMilliPoints

    private fun observation(
        tripId: String,
        scores: Map<ScoringDimension, Long>,
        states: Map<ScoringDimension, ScoreDimensionState> = emptyMap(),
        integrityState: TripIntegrityState = TripIntegrityState.VERIFIED,
    ): DriveDnaTripObservation {
        val dimensions = LinkedHashMap(referenceObservation.dimensions)
        DRIVE_DNA_DIRECT_DIMENSIONS.forEach { dimension ->
            val requestedState = states[dimension] ?: ScoreDimensionState.FULL
            val state =
                if (
                    integrityState == TripIntegrityState.VERIFIED ||
                    requestedState == ScoreDimensionState.UNAVAILABLE
                ) {
                    requestedState
                } else {
                    ScoreDimensionState.PROVISIONAL
                }
            val value = if (state == ScoreDimensionState.UNAVAILABLE) null else scores.getValue(dimension)
            dimensions[dimension] =
                DriveDnaTripDimensionObservation(
                    dimension = dimension,
                    scoreState = state,
                    scoreMilliPoints = value,
                    displayScore = value?.let(::milliPointsToDisplayScore),
                )
        }
        return referenceObservation.copy(
            tripId = tripId,
            tripScoreState =
                if (integrityState == TripIntegrityState.UNRANKED) {
                    TripScoreState.UNRANKED
                } else if (
                    integrityState == TripIntegrityState.VERIFIED &&
                    DRIVE_DNA_DIRECT_DIMENSIONS.all {
                        dimensions.getValue(it).scoreState == ScoreDimensionState.FULL
                    }
                ) {
                    TripScoreState.FULL
                } else {
                    TripScoreState.PROVISIONAL
                },
            integrityState = integrityState,
            dimensions = dimensions,
        )
    }

    private fun uniformScores(points: Int): Map<ScoringDimension, Long> =
        DRIVE_DNA_DIRECT_DIMENSIONS.associateWith { scorePointsToMilli(points) }

    private fun directScores(
        smoothness: Int,
        braking: Int,
        acceleration: Int,
        cornering: Int,
    ): Map<ScoringDimension, Long> =
        mapOf(
            ScoringDimension.SMOOTHNESS to scorePointsToMilli(smoothness),
            ScoringDimension.BRAKING_CONTROL to scorePointsToMilli(braking),
            ScoringDimension.ACCELERATION_CONTROL to scorePointsToMilli(acceleration),
            ScoringDimension.CORNERING_CONTROL to scorePointsToMilli(cornering),
        )

    private fun score(fixture: TelemetryRegressionFixture): TripScoreAudit =
        ScoringPipeline.score(
            EventMergePipeline.build(
                EventTaxonomyPipeline.build(confidenceTimelineFor(fixture)),
            ),
        )

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

    private val referenceObservation: DriveDnaTripObservation by lazy {
        DriveDnaPipeline.observe(score(multiControlFixture()))
    }
}
