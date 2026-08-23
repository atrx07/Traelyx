package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DriveDnaLifecyclePipelineTest {
    @Test
    fun `lifecycle policy defaults and machine states are stable and versioned`() {
        val config = DriveDnaLifecycleConfig()

        assertEquals(1, DRIVE_DNA_LIFECYCLE_VERSION)
        assertEquals(1, config.minimumEmergingObservationCount)
        assertEquals(10, config.minimumEstablishedObservationCount)
        assertEquals(30, config.maximumBaselineObservationCount)
        assertEquals(90L * DAY_MICROS, config.longGapMicros)
        assertEquals(
            listOf("UNCALIBRATED", "EMERGING", "ESTABLISHED", "RECALIBRATING"),
            DriveDnaPersonalLifecycleState.entries.map { it.name },
        )
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaLifecycleConfig(lifecycleVersion = 2)
        }
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaLifecycleConfig(minimumEstablishedObservationCount = 4)
        }
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaLifecycleConfig(maximumBaselineObservationCount = 9)
        }
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaBaselineScope("", "vehicle-a", "car")
        }
        assertThrows(IllegalArgumentException::class.java) {
            DriveDnaSensorContext("mount-a", "")
        }
    }

    @Test
    fun `empty emerging and established histories expose distinct audited states`() {
        val empty = evaluate(emptyList())
        assertEquals(DriveDnaPersonalLifecycleState.UNCALIBRATED, empty.state)
        assertEquals(DriveDnaProfileState.UNAVAILABLE, empty.profile.state)
        assertTrue(empty.selectedTripIds.isEmpty())

        val emergingObservations = observations(9, "emerging")
        val emerging = evaluate(emergingObservations)
        assertEquals(DriveDnaPersonalLifecycleState.EMERGING, emerging.state)
        assertEquals(DriveDnaProfileState.COMPLETE, emerging.profile.state)
        assertEquals(9, emerging.currentEpochEligibleTripCount)
        assertTrue(emerging.activeRecalibrationReasons.isEmpty())

        val establishedObservations = observations(10, "established")
        val first = evaluate(establishedObservations)
        val second = evaluate(establishedObservations.reversed())
        assertEquals(first, second)
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED, first.state)
        assertEquals(DriveDnaProfileState.COMPLETE, first.profile.state)
        assertEquals(establishedObservations.map { it.tripObservation.tripId }, first.selectedTripIds)
        assertTrue(first.activeRecalibrationReasons.isEmpty())
    }

    @Test
    fun `vehicle profiles never silently share a personal baseline`() {
        val vehicleAHistory = observations(10, "vehicle-a", scope = SCOPE_A)

        val changedVehicle =
            evaluate(
                observations = vehicleAHistory,
                scope = SCOPE_B,
                previousActiveScope = SCOPE_A,
            )
        assertEquals(DriveDnaPersonalLifecycleState.RECALIBRATING, changedVehicle.state)
        assertEquals(
            setOf(DriveDnaRecalibrationReason.VEHICLE_PROFILE_CHANGED),
            changedVehicle.activeRecalibrationReasons,
        )
        assertTrue(changedVehicle.selectedTripIds.isEmpty())
        assertTrue(
            changedVehicle.cohortDecisions.all {
                it.exclusionReasons ==
                    setOf(DriveDnaCohortExclusionReason.VEHICLE_PROFILE_MISMATCH)
            },
        )

        val vehicleBHistory =
            observations(
                count = 10,
                prefix = "vehicle-b",
                scope = SCOPE_B,
                startMicros = BASE_MICROS + 20L * DAY_MICROS,
            )
        val establishedB =
            evaluate(
                observations = vehicleAHistory + vehicleBHistory,
                scope = SCOPE_B,
                previousActiveScope = SCOPE_A,
            )
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED, establishedB.state)
        assertEquals(
            vehicleBHistory.map { it.tripObservation.tripId },
            establishedB.selectedTripIds,
        )
        assertTrue(establishedB.activeRecalibrationReasons.isEmpty())

        val establishedA =
            evaluate(
                observations = vehicleAHistory + vehicleBHistory,
                scope = SCOPE_A,
                previousActiveScope = SCOPE_B,
            )
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED, establishedA.state)
        assertEquals(
            vehicleAHistory.map { it.tripObservation.tripId },
            establishedA.selectedTripIds,
        )
    }

    @Test
    fun `mount and sensor changes form a fresh recalibration cohort`() {
        val oldContextHistory = observations(10, "old-context", sensorContext = CONTEXT_A)
        val newContextHistory =
            observations(
                count = 5,
                prefix = "new-context",
                sensorContext = CONTEXT_B,
                startMicros = BASE_MICROS + 20L * DAY_MICROS,
            )

        val recalibrating = evaluate(oldContextHistory + newContextHistory, sensorContext = CONTEXT_B)
        assertEquals(DriveDnaPersonalLifecycleState.RECALIBRATING, recalibrating.state)
        assertEquals(
            setOf(
                DriveDnaRecalibrationReason.MOUNT_CONTEXT_CHANGED,
                DriveDnaRecalibrationReason.SENSOR_CONTEXT_CHANGED,
            ),
            recalibrating.activeRecalibrationReasons,
        )
        assertEquals(
            newContextHistory.map { it.tripObservation.tripId },
            recalibrating.selectedTripIds,
        )

        val completeNewContext =
            observations(
                count = 10,
                prefix = "new-context",
                sensorContext = CONTEXT_B,
                startMicros = BASE_MICROS + 20L * DAY_MICROS,
            )
        val established = evaluate(oldContextHistory + completeNewContext, sensorContext = CONTEXT_B)
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED, established.state)
        assertTrue(established.activeRecalibrationReasons.isEmpty())
        assertEquals(
            completeNewContext.map { it.tripObservation.tripId },
            established.selectedTripIds,
        )
    }

    @Test
    fun `long inactivity starts a new epoch until enough current evidence exists`() {
        val oldHistory = observations(10, "old")
        val oldEnd = oldHistory.last().completedAtUtcEpochMicros

        val inactive = evaluate(oldHistory, asOfMicros = oldEnd + 91L * DAY_MICROS)
        assertEquals(DriveDnaPersonalLifecycleState.RECALIBRATING, inactive.state)
        assertEquals(
            setOf(DriveDnaRecalibrationReason.LONG_INACTIVITY_GAP),
            inactive.activeRecalibrationReasons,
        )
        assertTrue(inactive.selectedTripIds.isEmpty())
        assertTrue(
            inactive.cohortDecisions.all {
                DriveDnaCohortExclusionReason.BEFORE_CURRENT_RECALIBRATION_EPOCH in
                    it.exclusionReasons
            },
        )

        val newStart = oldEnd + 91L * DAY_MICROS
        val firstCurrent = observations(1, "current", startMicros = newStart)
        val early = evaluate(oldHistory + firstCurrent, asOfMicros = newStart + DAY_MICROS)
        assertEquals(DriveDnaPersonalLifecycleState.RECALIBRATING, early.state)
        assertEquals(listOf("current-01"), early.selectedTripIds)

        val currentHistory = observations(10, "current", startMicros = newStart)
        val established =
            evaluate(
                oldHistory + currentHistory,
                asOfMicros = currentHistory.last().completedAtUtcEpochMicros + DAY_MICROS,
            )
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED, established.state)
        assertEquals(currentHistory.map { it.tripObservation.tripId }, established.selectedTripIds)
        assertTrue(established.activeRecalibrationReasons.isEmpty())
    }

    @Test
    fun `rolling cohort keeps the latest thirty valid trips deterministically`() {
        val history = observations(35, "rolling")

        val first = evaluate(history)
        val second = evaluate(history.reversed())

        assertEquals(first, second)
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED, first.state)
        assertEquals(35, first.currentEpochEligibleTripCount)
        assertEquals(
            history.takeLast(30).map { it.tripObservation.tripId },
            first.selectedTripIds,
        )
        assertEquals(
            5,
            first.cohortDecisions.count {
                it.exclusionReasons ==
                    setOf(DriveDnaCohortExclusionReason.OUTSIDE_ROLLING_WINDOW)
            },
        )
        assertEquals(history[5].completedAtUtcEpochMicros, first.windowStartUtcEpochMicros)
        assertEquals(history.last().completedAtUtcEpochMicros, first.windowEndUtcEpochMicros)
    }

    @Test
    fun `only full verified dimension evidence can enter the lifecycle cohort`() {
        val partialStates =
            DRIVE_DNA_DIRECT_DIMENSIONS.drop(1).associateWith {
                ScoreDimensionState.UNAVAILABLE
            }
        val candidates =
            listOf(
                lifecycleObservation("partial", BASE_MICROS, states = partialStates),
                lifecycleObservation(
                    tripId = "provisional",
                    completedAtMicros = BASE_MICROS + DAY_MICROS,
                    states =
                        DRIVE_DNA_DIRECT_DIMENSIONS.associateWith {
                            ScoreDimensionState.PROVISIONAL
                        },
                ),
                lifecycleObservation(
                    tripId = "limited",
                    completedAtMicros = BASE_MICROS + 2L * DAY_MICROS,
                    integrityState = TripIntegrityState.LIMITED_CONFIDENCE,
                ),
                lifecycleObservation(
                    tripId = "other-person",
                    completedAtMicros = BASE_MICROS + 3L * DAY_MICROS,
                    scope = SCOPE_OTHER_PERSON,
                ),
            )

        val audit = evaluate(candidates)

        assertEquals(DriveDnaPersonalLifecycleState.EMERGING, audit.state)
        assertEquals(listOf("partial"), audit.selectedTripIds)
        assertEquals(
            setOf(DriveDnaCohortExclusionReason.NO_FULL_VERIFIED_DIMENSION_EVIDENCE),
            audit.decision("provisional").exclusionReasons,
        )
        assertEquals(
            setOf(DriveDnaCohortExclusionReason.NO_FULL_VERIFIED_DIMENSION_EVIDENCE),
            audit.decision("limited").exclusionReasons,
        )
        assertEquals(
            setOf(DriveDnaCohortExclusionReason.PERSONAL_SCOPE_MISMATCH),
            audit.decision("other-person").exclusionReasons,
        )
    }

    @Test
    fun `vehicle class changes are explicit and do not contaminate the target class`() {
        val priorClass = SCOPE_A.copy(vehicleClassKey = "motorcycle")
        val oldClassHistory = observations(10, "motorcycle", scope = priorClass)
        val currentClassHistory =
            observations(
                count = 5,
                prefix = "car",
                scope = SCOPE_A,
                startMicros = BASE_MICROS + 20L * DAY_MICROS,
            )

        val audit = evaluate(oldClassHistory + currentClassHistory, previousActiveScope = priorClass)

        assertEquals(DriveDnaPersonalLifecycleState.RECALIBRATING, audit.state)
        assertEquals(
            setOf(DriveDnaRecalibrationReason.VEHICLE_CLASS_CHANGED),
            audit.activeRecalibrationReasons,
        )
        assertEquals(currentClassHistory.map { it.tripObservation.tripId }, audit.selectedTripIds)
        assertTrue(
            oldClassHistory.all {
                audit.decision(it.tripObservation.tripId).exclusionReasons ==
                    setOf(DriveDnaCohortExclusionReason.VEHICLE_CLASS_MISMATCH)
            },
        )
    }

    @Test
    fun `invalid timelines and ambiguous identity inputs fail closed`() {
        val observation = observations(1, "trip").single()

        assertThrows(IllegalArgumentException::class.java) {
            evaluate(listOf(observation, observation))
        }
        assertThrows(IllegalArgumentException::class.java) {
            evaluate(
                observations = listOf(observation),
                asOfMicros = observation.completedAtUtcEpochMicros - 1L,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            evaluate(
                observations = listOf(observation),
                previousActiveScope = SCOPE_OTHER_PERSON,
            )
        }
    }

    @Test
    fun `audit snapshots caller history and retains all source versions`() {
        val mutableDimensions = LinkedHashMap(referenceObservation.dimensions)
        val sourceTrip = referenceObservation.copy(tripId = "snapshot", dimensions = mutableDimensions)
        val mutableHistory =
            mutableListOf(
                DriveDnaLifecycleObservation(
                    completedAtUtcEpochMicros = BASE_MICROS,
                    scope = SCOPE_A,
                    sensorContext = CONTEXT_A,
                    tripObservation = sourceTrip,
                ),
            )

        val audit = evaluate(mutableHistory)
        mutableHistory.clear()
        mutableDimensions[ScoringDimension.SMOOTHNESS] =
            DriveDnaTripDimensionObservation(
                dimension = ScoringDimension.SMOOTHNESS,
                scoreState = ScoreDimensionState.UNAVAILABLE,
                scoreMilliPoints = null,
                displayScore = null,
            )

        assertEquals(listOf("snapshot"), audit.selectedTripIds)
        assertEquals(
            ScoreDimensionState.FULL,
            audit.candidateObservations
                .single()
                .tripObservation
                .dimensions
                .getValue(ScoringDimension.SMOOTHNESS)
                .scoreState,
        )
        assertEquals(setOf(SCORING_VERSION), audit.candidateSourceVersions.scoringVersions)
        assertEquals(
            setOf(INTEGRITY_RULES_VERSION),
            audit.candidateSourceVersions.integrityVersions,
        )
        assertFalse(audit.candidateSourceVersions.rawDecoderVersions.isEmpty())
        assertThrows(UnsupportedOperationException::class.java) {
            @Suppress("UNCHECKED_CAST")
            (audit.selectedTripIds as MutableList<String>).add("mutated")
        }
    }

    private fun evaluate(
        observations: List<DriveDnaLifecycleObservation>,
        scope: DriveDnaBaselineScope = SCOPE_A,
        sensorContext: DriveDnaSensorContext = CONTEXT_A,
        previousActiveScope: DriveDnaBaselineScope? = null,
        asOfMicros: Long =
            (observations.maxOfOrNull { it.completedAtUtcEpochMicros } ?: BASE_MICROS) +
                DAY_MICROS,
    ): DriveDnaLifecycleAudit =
        DriveDnaLifecyclePipeline.evaluate(
            baselineKey = "${scope.personalScopeKey}:${scope.vehicleProfileId}",
            asOfUtcEpochMicros = asOfMicros,
            scope = scope,
            sensorContext = sensorContext,
            observations = observations,
            previousActiveScope = previousActiveScope,
        )

    private fun observations(
        count: Int,
        prefix: String,
        scope: DriveDnaBaselineScope = SCOPE_A,
        sensorContext: DriveDnaSensorContext = CONTEXT_A,
        startMicros: Long = BASE_MICROS,
    ): List<DriveDnaLifecycleObservation> =
        (1..count).map { index ->
            lifecycleObservation(
                tripId = "$prefix-${index.toString().padStart(2, '0')}",
                completedAtMicros = startMicros + (index - 1L) * DAY_MICROS,
                scope = scope,
                sensorContext = sensorContext,
            )
        }

    private fun lifecycleObservation(
        tripId: String,
        completedAtMicros: Long,
        scope: DriveDnaBaselineScope = SCOPE_A,
        sensorContext: DriveDnaSensorContext = CONTEXT_A,
        states: Map<ScoringDimension, ScoreDimensionState> = emptyMap(),
        integrityState: TripIntegrityState = TripIntegrityState.VERIFIED,
    ): DriveDnaLifecycleObservation =
        DriveDnaLifecycleObservation(
            completedAtUtcEpochMicros = completedAtMicros,
            scope = scope,
            sensorContext = sensorContext,
            tripObservation = tripObservation(tripId, states, integrityState),
        )

    private fun tripObservation(
        tripId: String,
        states: Map<ScoringDimension, ScoreDimensionState>,
        integrityState: TripIntegrityState,
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
            val value =
                if (state == ScoreDimensionState.UNAVAILABLE) {
                    null
                } else {
                    scorePointsToMilli(80)
                }
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
                if (
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

    private fun DriveDnaLifecycleAudit.decision(tripId: String): DriveDnaCohortDecision =
        cohortDecisions.single { it.tripId == tripId }

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

    private companion object {
        const val DAY_MICROS = 24L * 60L * 60L * 1_000_000L
        const val BASE_MICROS = 2_000_000_000_000_000L

        val SCOPE_A = DriveDnaBaselineScope("local-person", "vehicle-a", "passenger-car")
        val SCOPE_B = DriveDnaBaselineScope("local-person", "vehicle-b", "passenger-car")
        val SCOPE_OTHER_PERSON =
            DriveDnaBaselineScope("other-person", "vehicle-a", "passenger-car")
        val CONTEXT_A = DriveDnaSensorContext("mount-a", "sensor-class-a")
        val CONTEXT_B = DriveDnaSensorContext("mount-b", "sensor-class-b")
    }
}
