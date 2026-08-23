package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
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

class ExplanationPipelineTest {
    @Test
    fun `explanation schema and typed parameter contract are stable and versioned`() {
        val config = ExplanationConfig()

        assertEquals(1, EXPLANATION_VERSION)
        assertEquals(1, EXPLANATION_MESSAGE_CATALOG_VERSION)
        assertEquals(1, config.explanationVersion)
        assertEquals(1, config.messageCatalogVersion)
        assertEquals(
            listOf(
                "MEASUREMENT",
                "DETECTED_EVENT",
                "CONFIDENCE",
                "SCORING_CONSEQUENCE",
                "INTEGRITY",
                "BASELINE",
            ),
            ExplanationLayer.entries.map { it.name },
        )
        assertThrows(IllegalArgumentException::class.java) {
            ExplanationConfig(explanationVersion = 2)
        }
        assertThrows(IllegalArgumentException::class.java) {
            ExplanationArgument.MachineCode("bad-key", "VALID_CODE")
        }
        assertThrows(IllegalArgumentException::class.java) {
            ExplanationArgument.MachineCode("reason", "user prose is not a machine code")
        }
        assertThrows(IllegalArgumentException::class.java) {
            ExplanationArgument.DecimalValue(
                "value",
                Double.NaN,
                ExplanationValueUnit.METRES_PER_SECOND_SQUARED,
            )
        }
    }

    @Test
    fun `governed fixtures provide a complete reason path for every event machine type`() {
        val fixtures =
            listOf(
                fixture(TelemetryRegressionScenario.SMOOTH_ACCELERATION),
                fixture(TelemetryRegressionScenario.BRAKING),
                fixture(TelemetryRegressionScenario.LEFT_CORNER),
                fixture(TelemetryRegressionScenario.RIGHT_CORNER),
                fixture(TelemetryRegressionScenario.POTHOLE),
                fixture(TelemetryRegressionScenario.PHONE_MOVE),
                pulse(PulseAxis.DEVICE_Y, 4.0f, 0.0f),
                pulse(PulseAxis.DEVICE_Y, -4.0f, 0.0f),
                pulse(PulseAxis.DEVICE_X, -4.0f, 0.0f),
            )
        val bundles = fixtures.map(::build)
        val paths = bundles.flatMap { it.explanation.eventPaths }
        val sourceEvents =
            bundles
                .flatMap { it.timeline.events().toList() }
                .associateBy { it.eventId }

        assertEquals(
            DrivingEventType.entries.mapTo(linkedSetOf()) { it.machineId },
            paths.mapTo(linkedSetOf()) { it.subjectMachineId },
        )
        paths.forEach { path ->
            val sourceEvent = sourceEvents.getValue(path.subjectId)
            assertEquals(ExplanationSubjectKind.DRIVING_EVENT, path.subjectKind)
            assertTrue(path.headlineMessageKey.startsWith("explanation.event."))
            assertTrue(path.steps.any { it.layer == ExplanationLayer.MEASUREMENT })
            assertTrue(path.steps.any { it.layer == ExplanationLayer.DETECTED_EVENT })
            assertTrue(path.steps.any { it.layer == ExplanationLayer.CONFIDENCE })
            assertTrue(path.steps.any { it.layer == ExplanationLayer.SCORING_CONSEQUENCE })
            sourceEvent.sourceSummary.metricEvidence.forEach { (metric, evidence) ->
                val step =
                    path.steps.single {
                        it.messageKey ==
                            "explanation.event.confidence.metric.${metric.name.lowercase()}"
                    }
                assertEquals(
                    evidence.observedEligibility.map { it.name }.sorted(),
                    step.machineCodesArgument("observed_eligibility").values,
                )
                assertEquals(
                    evidence.reasons.map { it.name }.sorted(),
                    step.machineCodesArgument("eligibility_reasons").values,
                )
            }
            sourceEvent.sourceSummary.componentEvidence.forEach { (component, evidence) ->
                val step =
                    path.steps.single {
                        it.messageKey ==
                            "explanation.event.confidence.component.${component.name.lowercase()}"
                    }
                assertEquals(
                    evidence.observedStates.map { it.name }.sorted(),
                    step.machineCodesArgument("observed_states").values,
                )
                assertEquals(
                    evidence.reasons.map { it.name }.sorted(),
                    step.machineCodesArgument("reasons").values,
                )
            }
        }
    }

    @Test
    fun `phone movement stays measurement limited and has no invented score consequence`() {
        val bundle = build(fixture(TelemetryRegressionScenario.PHONE_MOVE))
        val path =
            bundle.explanation.eventPaths.single {
                it.subjectMachineId == DrivingEventType.PHONE_MOVED.machineId
            }

        assertTrue(
            path.steps.any {
                it.messageKey ==
                    "explanation.event.measurement_unavailable_phone_movement" &&
                    it.role == ExplanationReasonRole.LIMITING
            },
        )
        assertTrue(
            path.steps.any {
                it.messageKey == "explanation.event.score.no_direct_v1_consequence"
            },
        )
        assertFalse(
            path.steps.any { step ->
                step.arguments.any {
                    it is ExplanationArgument.DecimalValue
                }
            },
        )
        assertEquals(TripIntegrityState.LIMITED_CONFIDENCE, bundle.score.integrityAudit.state)
    }

    @Test
    fun `score penalties link exact event contribution amount and confidence factor`() {
        val bundle = build(pulse(PulseAxis.DEVICE_Y, -4.0f, 0.0f))
        val contribution =
            bundle.score.dimensions
                .getValue(ScoringDimension.BRAKING_CONTROL)
                .contributions
                .single { it.rule == ScoreContributionRule.BRAKING_ABRUPT_TRANSITION }
        val dimensionPath =
            bundle.explanation.scoreDimensionPaths.getValue(ScoringDimension.BRAKING_CONTROL)
        val contributionStep =
            dimensionPath.steps.single {
                it.messageKey ==
                    "explanation.score.contribution.sc_brake_abrupt_transition"
            }

        assertEquals(
            contribution.appliedPointsMilli,
            contributionStep.integerArgument("applied_penalty").value,
        )
        assertEquals(
            contribution.confidenceWeightPermille.toLong(),
            contributionStep.integerArgument("confidence_weight").value,
        )
        assertEquals(
            contribution.rawPointsMilli,
            contributionStep.integerArgument("raw_penalty").value,
        )
        assertEquals(
            contribution.supportingEventIds.sorted(),
            contributionStep.idArgument("supporting_event_ids").values,
        )
        contribution.supportingEventIds.forEach { eventId ->
            val eventPath = bundle.explanation.eventPaths.single { it.subjectId == eventId }
            assertTrue(
                eventPath.steps.any {
                    it.sourceReferences.any { source ->
                        source.kind == ExplanationSourceKind.SCORE_CONTRIBUTION &&
                            source.id == contribution.contributionId
                    }
                },
            )
        }
    }

    @Test
    fun `unavailable and provisional score states expose every governed reason`() {
        val stationary = build(fixture(TelemetryRegressionScenario.STATIONARY))
        assertEquals(TripScoreState.UNAVAILABLE, stationary.score.state)
        assertTrue(stationary.explanation.eventPaths.isEmpty())
        stationary.score.dimensions.forEach { (dimension, score) ->
            val path = stationary.explanation.scoreDimensionPaths.getValue(dimension)
            score.unavailableReasons.forEach { reason ->
                assertTrue(
                    path.steps.any {
                        it.messageKey ==
                            "explanation.score.unavailable.${reason.name.lowercase()}"
                    },
                )
            }
        }

        val abrupt = pulse(PulseAxis.DEVICE_Y, -4.0f, 0.0f)
        val limited = build(degradedAccelerometerFixture(abrupt))
        assertEquals(TripScoreState.PROVISIONAL, limited.score.state)
        limited.score.provisionalReasons.forEach { reason ->
            assertTrue(
                limited.explanation.overallScorePath.steps.any {
                    it.messageKey ==
                        "explanation.score.provisional.${reason.name.lowercase()}"
                },
            )
        }
        assertTrue(
            limited.explanation.eventPaths.any { path ->
                path.steps.any {
                    it.messageKey == "explanation.event.confidence.limited" &&
                        it.role == ExplanationReasonRole.LIMITING
                }
            },
        )
    }

    @Test
    fun `overall explanation exposes composition guardrail integrity and ranking`() {
        val defaults = ScoringConfig()
        val penalties =
            defaults.contributionBasePenaltyPoints.toMutableMap().apply {
                this[ScoreContributionRule.SMOOTHNESS_ABRUPT_LONGITUDINAL_TRANSITION] = 1
                this[ScoreContributionRule.ACCELERATION_ABRUPT_TRANSITION] = 50
            }
        val bundle =
            build(
                fixture = pulse(PulseAxis.DEVICE_Y, 4.0f, 0.0f),
                scoringConfig = defaults.copy(contributionBasePenaltyPoints = penalties),
            )
        val path = bundle.explanation.overallScorePath

        assertTrue(bundle.score.riskGuardrailApplied)
        assertEquals(
            bundle.score.availableOverallDimensions.size,
            path.steps.count {
                it.messageKey == "explanation.score.overall.dimension_component"
            },
        )
        assertTrue(
            path.steps.any {
                it.messageKey == "explanation.score.overall.guardrail.applied"
            },
        )
        assertTrue(
            path.steps.any {
                it.messageKey ==
                    "explanation.score.ranking.${bundle.score.rankingStatus.name.lowercase()}"
            },
        )
    }

    @Test
    fun `integrity explanation distinguishes no findings from typed quality evidence`() {
        val verified = build(multiControlFixture())
        assertEquals(TripIntegrityState.VERIFIED, verified.score.integrityAudit.state)
        assertTrue(
            verified.explanation.integrityPath.steps.any {
                it.messageKey == "explanation.integrity.no_v1_findings"
            },
        )

        val phoneMove = build(fixture(TelemetryRegressionScenario.PHONE_MOVE))
        val finding =
            phoneMove.score.integrityAudit.findings.single {
                it.ruleId == IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION
            }
        val step =
            phoneMove.explanation.integrityPath.steps.single {
                it.messageKey ==
                    "explanation.integrity.finding.${finding.ruleId.machineId.lowercase()}"
            }
        assertEquals(
            finding.kind.name,
            step.machineCodeArgument("kind").value,
        )
        assertEquals(ExplanationReasonRole.LIMITING, step.role)
        assertTrue(
            step.sourceReferences.any {
                it.kind == ExplanationSourceKind.MERGED_EVENT &&
                    it.id == finding.representativeMergedEventId
            },
        )
        assertFalse(
            phoneMove.explanation.integrityPath.steps.any {
                "cheater" in it.messageKey || "intent" in it.messageKey
            },
        )
    }

    @Test
    fun `Drive DNA explanation covers every profile dimension and lifecycle source trip`() {
        val observations = lifecycleObservations(10, "established")
        val lifecycle = evaluateLifecycle(observations)
        val first = ExplanationPipeline.explainDriveDna(lifecycle)
        val second = ExplanationPipeline.explainDriveDna(lifecycle)

        assertEquals(first, second)
        assertEquals(DriveDnaPersonalLifecycleState.ESTABLISHED.name, first.lifecyclePath.stateMachineCode)
        assertEquals(ScoringDimension.entries.toSet(), first.profileDimensionPaths.keys)
        assertEquals(
            observations.map { it.tripObservation.tripId },
            first.sourceCandidateTripIds,
        )
        first.profileDimensionPaths.values.forEach { path ->
            assertTrue(path.steps.any { it.layer == ExplanationLayer.BASELINE })
        }
        assertEquals(
            lifecycle.candidateSourceVersions,
            first.sourceVersions.candidateSourceVersions,
        )
    }

    @Test
    fun `recalibration explanation preserves context trigger and excluded cohort evidence`() {
        val oldHistory = lifecycleObservations(10, "old", sensorContext = CONTEXT_A)
        val newHistory =
            lifecycleObservations(
                count = 5,
                prefix = "new",
                sensorContext = CONTEXT_B,
                startMicros = BASE_MICROS + 20L * DAY_MICROS,
            )
        val lifecycle = evaluateLifecycle(oldHistory + newHistory, sensorContext = CONTEXT_B)
        val explanation = ExplanationPipeline.explainDriveDna(lifecycle)

        assertEquals(DriveDnaPersonalLifecycleState.RECALIBRATING.name, explanation.lifecyclePath.stateMachineCode)
        listOf(
            DriveDnaRecalibrationReason.MOUNT_CONTEXT_CHANGED,
            DriveDnaRecalibrationReason.SENSOR_CONTEXT_CHANGED,
        ).forEach { reason ->
            assertTrue(
                explanation.lifecyclePath.steps.any {
                    it.messageKey ==
                        "explanation.drive_dna.recalibration.${reason.name.lowercase()}"
                },
            )
        }
        assertTrue(
            explanation.lifecyclePath.steps.any {
                it.messageKey ==
                    "explanation.drive_dna.cohort_exclusion.mount_context_mismatch"
            },
        )
        assertEquals(
            (oldHistory + newHistory).map { it.tripObservation.tripId }.toSet(),
            explanation.lifecyclePath.steps
                .flatMap { it.sourceReferences }
                .filter { it.kind == ExplanationSourceKind.DRIVE_DNA_TRIP }
                .mapTo(linkedSetOf()) { it.id },
        )
    }

    @Test
    fun `trip explanation is repeatable immutable and rejects a mismatched score audit`() {
        val timeline = timeline(multiControlFixture())
        val score = ScoringPipeline.score(timeline)
        val first = ExplanationPipeline.explainTrip(timeline, score)
        val second = ExplanationPipeline.explainTrip(timeline, score)

        assertEquals(first, second)
        assertEquals(ScoringDimension.entries.toSet(), first.scoreDimensionPaths.keys)
        assertEquals(score.sourceVersions, first.sourceVersions.scoringSourceVersions)
        assertThrows(UnsupportedOperationException::class.java) {
            @Suppress("UNCHECKED_CAST")
            (first.eventPaths as MutableList<ExplanationPath>).clear()
        }
        assertThrows(UnsupportedOperationException::class.java) {
            @Suppress("UNCHECKED_CAST")
            (first.eventPaths.first().steps.first().machineCodesArgument("rule_evidence").values
                as MutableList<String>).clear()
        }
        val mismatchedTripId = "mismatched-trip"
        val mismatchedScore =
            score.copy(
                tripId = mismatchedTripId,
                integrityAudit = score.integrityAudit.copy(tripId = mismatchedTripId),
            )
        assertThrows(IllegalArgumentException::class.java) {
            ExplanationPipeline.explainTrip(timeline, mismatchedScore)
        }
    }

    private fun build(
        fixture: TelemetryRegressionFixture,
        scoringConfig: ScoringConfig = ScoringConfig(),
    ): TripBundle {
        val timeline = timeline(fixture)
        val score = ScoringPipeline.score(timeline, scoringConfig)
        return TripBundle(
            timeline = timeline,
            score = score,
            explanation = ExplanationPipeline.explainTrip(timeline, score),
        )
    }

    private fun timeline(fixture: TelemetryRegressionFixture): MergedEventTimeline =
        EventMergePipeline.build(
            EventTaxonomyPipeline.build(confidenceTimelineFor(fixture)),
        )

    private fun fixture(scenario: TelemetryRegressionScenario): TelemetryRegressionFixture =
        TelemetryRegressionFixtureCorpus.generate(scenario)

    private fun pulse(
        axis: PulseAxis,
        firstDelta: Float,
        secondDelta: Float,
    ): TelemetryRegressionFixture {
        val source = fixture(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
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

    private fun degradedAccelerometerFixture(
        source: TelemetryRegressionFixture,
    ): TelemetryRegressionFixture =
        source.copy(
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

    private fun multiControlFixture(): TelemetryRegressionFixture {
        val source = fixture(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
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

    private fun lifecycleObservations(
        count: Int,
        prefix: String,
        sensorContext: DriveDnaSensorContext = CONTEXT_A,
        startMicros: Long = BASE_MICROS,
    ): List<DriveDnaLifecycleObservation> =
        (1..count).map { index ->
            DriveDnaLifecycleObservation(
                completedAtUtcEpochMicros = startMicros + (index - 1L) * DAY_MICROS,
                scope = SCOPE,
                sensorContext = sensorContext,
                tripObservation =
                    referenceObservation.copy(
                        tripId = "$prefix-${index.toString().padStart(2, '0')}",
                    ),
            )
        }

    private fun evaluateLifecycle(
        observations: List<DriveDnaLifecycleObservation>,
        sensorContext: DriveDnaSensorContext = CONTEXT_A,
    ): DriveDnaLifecycleAudit =
        DriveDnaLifecyclePipeline.evaluate(
            baselineKey = "local-person:vehicle-a",
            asOfUtcEpochMicros =
                (observations.maxOfOrNull { it.completedAtUtcEpochMicros } ?: BASE_MICROS) +
                    DAY_MICROS,
            scope = SCOPE,
            sensorContext = sensorContext,
            observations = observations,
        )

    private fun ExplanationStep.integerArgument(key: String): ExplanationArgument.IntegerValue =
        arguments.single { it.key == key } as ExplanationArgument.IntegerValue

    private fun ExplanationStep.idArgument(key: String): ExplanationArgument.IdList =
        arguments.single { it.key == key } as ExplanationArgument.IdList

    private fun ExplanationStep.machineCodeArgument(
        key: String,
    ): ExplanationArgument.MachineCode =
        arguments.single { it.key == key } as ExplanationArgument.MachineCode

    private fun ExplanationStep.machineCodesArgument(
        key: String,
    ): ExplanationArgument.MachineCodeList =
        arguments.single { it.key == key } as ExplanationArgument.MachineCodeList

    private val referenceObservation: DriveDnaTripObservation by lazy {
        DriveDnaPipeline.observe(ScoringPipeline.score(timeline(multiControlFixture())))
    }

    private data class TripBundle(
        val timeline: MergedEventTimeline,
        val score: TripScoreAudit,
        val explanation: TripExplanationAudit,
    )

    private enum class PulseAxis {
        DEVICE_X,
        DEVICE_Y,
    }

    private companion object {
        const val PULSE_START_NANOS = 7_000_000_000L
        const val PULSE_MIDDLE_NANOS = 8_000_000_000L
        const val PULSE_END_NANOS = 9_000_000_000L
        const val DAY_MICROS = 24L * 60L * 60L * 1_000_000L
        const val BASE_MICROS = 2_000_000_000_000_000L

        val SCOPE = DriveDnaBaselineScope("local-person", "vehicle-a", "passenger-car")
        val CONTEXT_A = DriveDnaSensorContext("mount-a", "sensor-a")
        val CONTEXT_B = DriveDnaSensorContext("mount-b", "sensor-b")
    }
}
