package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.DerivedScalarValue
import io.github.atrx07.traelyx.telemetry.DerivedVectorValue
import io.github.atrx07.traelyx.telemetry.MovementState
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import kotlin.math.abs
import kotlin.math.roundToInt

object ScoringPipeline {
    fun score(
        sourceTimeline: MergedEventTimeline,
        config: ScoringConfig = ScoringConfig(),
    ): TripScoreAudit {
        val configSnapshot = config.immutableSnapshot()
        return CompleteTripScorer(
            sourceTimeline = sourceTimeline,
            integrityAudit = IntegrityPipeline.audit(sourceTimeline),
            config = configSnapshot,
        ).score()
    }
}

private class CompleteTripScorer(
    private val sourceTimeline: MergedEventTimeline,
    private val integrityAudit: TripIntegrityAudit,
    private val config: ScoringConfig,
) {
    private val evidenceTimeline = sourceTimeline.sourceTimeline
    private val confidenceTimeline = evidenceTimeline.sourceTimeline
    private val derivedTimeline = confidenceTimeline.sourceTimeline
    private val trip = derivedTimeline.sourceTimeline.trip
    private val analysisIntervalNanos = derivedTimeline.sourceTimeline.config.intervalNanos

    fun score(): TripScoreAudit {
        check(integrityAudit.tripId == trip.tripId)
        val evidence = collectDimensionEvidence()
        val contributions = collectContributions()
        val dimensions =
            ScoringDimension.entries.associateWith { dimension ->
                buildDimensionScore(
                    dimension = dimension,
                    evidence = evidence.getValue(dimension),
                    contributions = contributions.getValue(dimension),
                )
            }
        return synthesizeTripScore(dimensions)
    }

    private fun collectDimensionEvidence(): Map<ScoringDimension, ScoreEvidenceSummary> {
        var movingDurationNanos = 0L
        val evidence =
            SCORABLE_SCORE_DIMENSIONS.associateWith { MutableScoreEvidence() }.toMutableMap()
        confidenceTimeline.synchronizedFrames().forEach { pair ->
            val derived = pair.derived
            if (derived.movementState.state != MovementState.MOVING) return@forEach
            movingDurationNanos = safeDurationAdd(movingDurationNanos, analysisIntervalNanos)

            val acceleration =
                derived.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available
            val jerk = derived.vehicleJerkMetresPerSecondCubed as? DerivedVectorValue.Available
            val yawRate = derived.yawRateRadiansPerSecond as? DerivedScalarValue.Available
            val accelerationEligibility = pair.confidence.eligibility.vehicleAcceleration.eligibility
            val jerkEligibility = pair.confidence.eligibility.vehicleJerk.eligibility
            val yawEligibility = pair.confidence.eligibility.yawRate.eligibility

            evidence.getValue(ScoringDimension.SMOOTHNESS).observe(
                durationNanos = analysisIntervalNanos,
                usable = jerk != null && jerkEligibility.isUsable(),
                fullyEligible = jerk != null && jerkEligibility == TelemetryEligibility.ELIGIBLE,
            )

            val longitudinal = acceleration?.value?.x
            if (
                longitudinal != null &&
                longitudinal >= config.longitudinalControlOpportunityMetresPerSecondSquared
            ) {
                evidence.getValue(ScoringDimension.ACCELERATION_CONTROL).observe(
                    durationNanos = analysisIntervalNanos,
                    usable = accelerationEligibility.isUsable(),
                    fullyEligible = accelerationEligibility == TelemetryEligibility.ELIGIBLE,
                )
            }
            if (
                longitudinal != null &&
                longitudinal <= -config.longitudinalControlOpportunityMetresPerSecondSquared
            ) {
                evidence.getValue(ScoringDimension.BRAKING_CONTROL).observe(
                    durationNanos = analysisIntervalNanos,
                    usable = accelerationEligibility.isUsable(),
                    fullyEligible = accelerationEligibility == TelemetryEligibility.ELIGIBLE,
                )
            }

            val lateralOpportunity =
                acceleration != null &&
                    abs(acceleration.value.y) >=
                    config.corneringOpportunityMetresPerSecondSquared
            val yawOpportunity =
                yawRate != null &&
                    abs(yawRate.value) >= config.corneringOpportunityRadiansPerSecond
            if (lateralOpportunity || yawOpportunity) {
                val usable =
                    acceleration != null &&
                        yawRate != null &&
                        accelerationEligibility.isUsable() &&
                        yawEligibility.isUsable()
                val fullyEligible =
                    acceleration != null &&
                        yawRate != null &&
                        accelerationEligibility == TelemetryEligibility.ELIGIBLE &&
                        yawEligibility == TelemetryEligibility.ELIGIBLE
                evidence.getValue(ScoringDimension.CORNERING_CONTROL).observe(
                    durationNanos = analysisIntervalNanos,
                    usable = usable,
                    fullyEligible = fullyEligible,
                )
            }
        }

        return ScoringDimension.entries.associateWith { dimension ->
            if (dimension == ScoringDimension.CONSISTENCY) {
                ScoreEvidenceSummary(
                    movingDurationNanos = movingDurationNanos,
                    opportunityDurationNanos = 0L,
                    usableDurationNanos = 0L,
                    fullyEligibleDurationNanos = 0L,
                )
            } else {
                evidence.getValue(dimension).freeze(movingDurationNanos)
            }
        }
    }

    private fun collectContributions(): Map<ScoringDimension, List<ScoreContribution>> {
        val events =
            sourceTimeline.events().sortedWith(
                compareBy<MergedDrivingEvent> { it.startTripElapsedNanos }
                    .thenBy { it.eventType.ordinal }
                    .thenBy { it.eventId },
            ).toList()
        val contributions =
            ScoringDimension.entries.associateWith { mutableListOf<ScoreContribution>() }

        events.forEach { event ->
            when (event.eventType) {
                DrivingEventType.ABRUPT_ACCELERATION_TRANSITION -> {
                    contributions.getValue(ScoringDimension.SMOOTHNESS) +=
                        event.toContribution(
                            ScoreContributionRule.SMOOTHNESS_ABRUPT_LONGITUDINAL_TRANSITION,
                        )
                    contributions.getValue(ScoringDimension.ACCELERATION_CONTROL) +=
                        event.toContribution(
                            ScoreContributionRule.ACCELERATION_ABRUPT_TRANSITION,
                        )
                }
                DrivingEventType.ABRUPT_BRAKING_TRANSITION -> {
                    contributions.getValue(ScoringDimension.SMOOTHNESS) +=
                        event.toContribution(
                            ScoreContributionRule.SMOOTHNESS_ABRUPT_LONGITUDINAL_TRANSITION,
                        )
                    contributions.getValue(ScoringDimension.BRAKING_CONTROL) +=
                        event.toContribution(ScoreContributionRule.BRAKING_ABRUPT_TRANSITION)
                }
                DrivingEventType.ABRUPT_CORNER_ENTRY -> {
                    contributions.getValue(ScoringDimension.SMOOTHNESS) +=
                        event.toContribution(
                            ScoreContributionRule.SMOOTHNESS_ABRUPT_CORNER_TRANSITION,
                        )
                    contributions.getValue(ScoringDimension.CORNERING_CONTROL) +=
                        event.toContribution(ScoreContributionRule.CORNERING_ABRUPT_ENTRY)
                }
                DrivingEventType.ABRUPT_CORNER_EXIT -> {
                    contributions.getValue(ScoringDimension.SMOOTHNESS) +=
                        event.toContribution(
                            ScoreContributionRule.SMOOTHNESS_ABRUPT_CORNER_TRANSITION,
                        )
                    contributions.getValue(ScoringDimension.CORNERING_CONTROL) +=
                        event.toContribution(ScoreContributionRule.CORNERING_ABRUPT_EXIT)
                }
                else -> Unit
            }
        }

        events.filter { it.eventType == DrivingEventType.STRONG_BRAKING }
            .drop(1)
            .forEach { event ->
                contributions.getValue(ScoringDimension.BRAKING_CONTROL) +=
                    event.toContribution(ScoreContributionRule.BRAKING_REPEATED_STRONG_EVENT)
            }
        events.filter { it.eventType == DrivingEventType.STRONG_ACCELERATION }
            .drop(1)
            .forEach { event ->
                contributions.getValue(ScoringDimension.ACCELERATION_CONTROL) +=
                    event.toContribution(
                        ScoreContributionRule.ACCELERATION_REPEATED_STRONG_EVENT,
                    )
            }
        events.filter {
            it.eventType == DrivingEventType.HIGH_LATERAL_LOAD_LEFT ||
                it.eventType == DrivingEventType.HIGH_LATERAL_LOAD_RIGHT
        }.drop(1)
            .forEach { event ->
                contributions.getValue(ScoringDimension.CORNERING_CONTROL) +=
                    event.toContribution(ScoreContributionRule.CORNERING_REPEATED_HIGH_LOAD)
            }

        return contributions.mapValues { (_, values) ->
            values.sortedBy { it.contributionId }
        }
    }

    private fun MergedDrivingEvent.toContribution(rule: ScoreContributionRule): ScoreContribution {
        val severity = severity as EventSeverityEvidence.Measured
        val severityMultiplierPermille =
            (severity.activationRatio * SCORE_FULL_WEIGHT_PERMILLE)
                .roundToInt()
                .coerceIn(
                    SCORE_FULL_WEIGHT_PERMILLE,
                    config.severityMultiplierCapPermille,
                )
        val confidenceWeightPermille =
            when (confidence) {
                EventEvidenceConfidence.SUPPORTED -> SCORE_FULL_WEIGHT_PERMILLE
                EventEvidenceConfidence.LIMITED -> config.limitedEvidenceWeightPermille
            }
        val basePoints = config.contributionBasePenaltyPoints.getValue(rule)
        val rawPointsMilli = basePoints.toLong() * severityMultiplierPermille
        val appliedPointsMilli =
            roundedPositiveDivide(
                rawPointsMilli * confidenceWeightPermille,
                SCORE_FULL_WEIGHT_PERMILLE.toLong(),
            )
        return ScoreContribution(
            scoringVersion = config.scoringVersion,
            contributionId = "score_v${config.scoringVersion}_${rule.machineId}_$eventId",
            rule = rule,
            kind = ScoreContributionKind.PENALTY,
            basePoints = basePoints,
            severityMultiplierPermille = severityMultiplierPermille,
            confidenceWeightPermille = confidenceWeightPermille,
            rawPointsMilli = rawPointsMilli,
            appliedPointsMilli = appliedPointsMilli,
            supportingEventIds = setOf(eventId),
        )
    }

    private fun buildDimensionScore(
        dimension: ScoringDimension,
        evidence: ScoreEvidenceSummary,
        contributions: List<ScoreContribution>,
    ): DimensionScore {
        val unavailableReasons = linkedSetOf<ScoreUnavailableReason>()
        when (dimension) {
            ScoringDimension.SMOOTHNESS -> {
                if (evidence.movingDurationNanos < config.minimumMovingDurationNanos) {
                    unavailableReasons += ScoreUnavailableReason.INSUFFICIENT_MOVING_DURATION
                }
            }
            ScoringDimension.BRAKING_CONTROL -> {
                if (
                    evidence.opportunityDurationNanos <
                    config.minimumControlOpportunityDurationNanos
                ) {
                    unavailableReasons += ScoreUnavailableReason.NO_BRAKING_OPPORTUNITY
                }
            }
            ScoringDimension.ACCELERATION_CONTROL -> {
                if (
                    evidence.opportunityDurationNanos <
                    config.minimumControlOpportunityDurationNanos
                ) {
                    unavailableReasons += ScoreUnavailableReason.NO_ACCELERATION_OPPORTUNITY
                }
            }
            ScoringDimension.CORNERING_CONTROL -> {
                if (
                    evidence.opportunityDurationNanos <
                    config.minimumControlOpportunityDurationNanos
                ) {
                    unavailableReasons += ScoreUnavailableReason.NO_CORNERING_OPPORTUNITY
                }
            }
            ScoringDimension.CONSISTENCY -> {
                unavailableReasons +=
                    ScoreUnavailableReason.CONSISTENCY_BASELINE_NOT_AVAILABLE
            }
        }
        if (
            dimension != ScoringDimension.CONSISTENCY &&
            evidence.opportunityDurationNanos > 0L &&
            evidence.usableCoveragePermille < config.minimumUsableEvidenceCoveragePermille
        ) {
            unavailableReasons += ScoreUnavailableReason.INSUFFICIENT_USABLE_EVIDENCE
        }

        val weight = config.dimensionWeightsBasisPoints.getValue(dimension)
        if (unavailableReasons.isNotEmpty()) {
            return DimensionScore(
                scoringVersion = config.scoringVersion,
                dimension = dimension,
                state = ScoreDimensionState.UNAVAILABLE,
                scoreMilliPoints = null,
                displayScore = null,
                weightBasisPoints = weight,
                evidence = evidence,
                contributions = contributions,
                provisionalReasons = emptySet(),
                unavailableReasons = unavailableReasons,
            )
        }

        val scoreMilliPoints =
            (scorePointsToMilli(SCORE_MAXIMUM_POINTS) -
                contributions.sumOf { it.appliedPointsMilli })
                .coerceIn(
                    scorePointsToMilli(SCORE_MINIMUM_POINTS),
                    scorePointsToMilli(SCORE_MAXIMUM_POINTS),
                )
        val provisionalReasons = linkedSetOf<ScoreProvisionalReason>()
        if (
            evidence.fullyEligibleCoveragePermille <
            config.minimumFullEvidenceCoveragePermille
        ) {
            provisionalReasons += ScoreProvisionalReason.LIMITED_TELEMETRY_EVIDENCE
        }
        if (contributions.any { it.confidenceWeightPermille < SCORE_FULL_WEIGHT_PERMILLE }) {
            provisionalReasons += ScoreProvisionalReason.LIMITED_EVENT_EVIDENCE
        }
        when (integrityAudit.state) {
            TripIntegrityState.VERIFIED -> Unit
            TripIntegrityState.LIMITED_CONFIDENCE ->
                provisionalReasons += ScoreProvisionalReason.LIMITED_INTEGRITY
            TripIntegrityState.QUESTIONABLE ->
                provisionalReasons += ScoreProvisionalReason.QUESTIONABLE_INTEGRITY
            TripIntegrityState.UNRANKED ->
                provisionalReasons += ScoreProvisionalReason.UNRANKED_INTEGRITY
        }
        return DimensionScore(
            scoringVersion = config.scoringVersion,
            dimension = dimension,
            state =
                if (provisionalReasons.isEmpty()) {
                    ScoreDimensionState.FULL
                } else {
                    ScoreDimensionState.PROVISIONAL
                },
            scoreMilliPoints = scoreMilliPoints,
            displayScore = milliPointsToDisplayScore(scoreMilliPoints),
            weightBasisPoints = weight,
            evidence = evidence,
            contributions = contributions,
            provisionalReasons = provisionalReasons,
            unavailableReasons = emptySet(),
        )
    }

    private fun synthesizeTripScore(
        dimensions: Map<ScoringDimension, DimensionScore>,
    ): TripScoreAudit {
        val available =
            SCORABLE_SCORE_DIMENSIONS.filterTo(linkedSetOf()) {
                dimensions.getValue(it).scoreMilliPoints != null
            }
        val availableWeight =
            available.sumOf { config.dimensionWeightsBasisPoints.getValue(it) }
        var overallScoreMilliPoints: Long? = null
        var riskGuardrailApplied = false
        val provisionalReasons = linkedSetOf<ScoreProvisionalReason>()
        val unavailableReasons = linkedSetOf<ScoreUnavailableReason>()
        val state =
            when {
                integrityAudit.state == TripIntegrityState.UNRANKED -> {
                    unavailableReasons += ScoreUnavailableReason.INTEGRITY_UNRANKED
                    TripScoreState.UNRANKED
                }
                available.size < config.minimumOverallDimensionCount -> {
                    unavailableReasons += ScoreUnavailableReason.INSUFFICIENT_AVAILABLE_DIMENSIONS
                    TripScoreState.UNAVAILABLE
                }
                else -> {
                    val weightedNumerator =
                        available.sumOf { dimension ->
                            requireNotNull(dimensions.getValue(dimension).scoreMilliPoints) *
                                config.dimensionWeightsBasisPoints.getValue(dimension)
                        }
                    val weighted =
                        roundedPositiveDivide(weightedNumerator, availableWeight.toLong())
                    val lowest =
                        available.minOf {
                            requireNotNull(dimensions.getValue(it).scoreMilliPoints)
                        }
                    val guardrail =
                        (lowest + scorePointsToMilli(config.overallRiskGuardrailMarginPoints))
                            .coerceAtMost(scorePointsToMilli(SCORE_MAXIMUM_POINTS))
                    overallScoreMilliPoints = minOf(weighted, guardrail)
                    riskGuardrailApplied = weighted > guardrail
                    available.forEach { dimension ->
                        provisionalReasons += dimensions.getValue(dimension).provisionalReasons
                    }
                    if (available != SCORABLE_SCORE_DIMENSIONS) {
                        provisionalReasons += ScoreProvisionalReason.PARTIAL_DIMENSION_COVERAGE
                    }
                    val full =
                        available == SCORABLE_SCORE_DIMENSIONS &&
                            available.all {
                                dimensions.getValue(it).state == ScoreDimensionState.FULL
                            } &&
                            integrityAudit.state == TripIntegrityState.VERIFIED
                    if (full) TripScoreState.FULL else TripScoreState.PROVISIONAL
                }
            }

        val rankingStatus =
            when (integrityAudit.state) {
                TripIntegrityState.UNRANKED -> ScoreRankingStatus.INELIGIBLE_INTEGRITY
                TripIntegrityState.QUESTIONABLE ->
                    ScoreRankingStatus.REVIEW_REQUIRED_INTEGRITY
                TripIntegrityState.LIMITED_CONFIDENCE ->
                    ScoreRankingStatus.INELIGIBLE_PROVISIONAL_SCORE
                TripIntegrityState.VERIFIED ->
                    when (state) {
                        TripScoreState.FULL -> ScoreRankingStatus.ELIGIBLE
                        TripScoreState.PROVISIONAL ->
                            ScoreRankingStatus.INELIGIBLE_PROVISIONAL_SCORE
                        TripScoreState.UNAVAILABLE ->
                            ScoreRankingStatus.INELIGIBLE_INSUFFICIENT_SCORE_EVIDENCE
                        TripScoreState.UNRANKED ->
                            error("Verified integrity cannot produce unranked score")
                    }
            }
        return TripScoreAudit(
            scoringVersion = config.scoringVersion,
            tripId = trip.tripId,
            state = state,
            overallScoreMilliPoints = overallScoreMilliPoints,
            overallDisplayScore = overallScoreMilliPoints?.let(::milliPointsToDisplayScore),
            rankingStatus = rankingStatus,
            dimensions = dimensions,
            availableOverallDimensions = available,
            availableOverallWeightBasisPoints = availableWeight,
            riskGuardrailApplied = riskGuardrailApplied,
            provisionalReasons = provisionalReasons,
            unavailableReasons = unavailableReasons,
            integrityAudit = integrityAudit,
            sourceVersions =
                ScoringSourceVersions(
                    scoringVersion = config.scoringVersion,
                    integritySourceVersions = requireNotNull(integrityAudit.sourceVersions),
                ),
            configSnapshot = config,
        )
    }
}

private class MutableScoreEvidence {
    private var opportunityDurationNanos = 0L
    private var usableDurationNanos = 0L
    private var fullyEligibleDurationNanos = 0L

    fun observe(
        durationNanos: Long,
        usable: Boolean,
        fullyEligible: Boolean,
    ) {
        require(durationNanos > 0L)
        require(!fullyEligible || usable)
        opportunityDurationNanos = safeDurationAdd(opportunityDurationNanos, durationNanos)
        if (usable) usableDurationNanos = safeDurationAdd(usableDurationNanos, durationNanos)
        if (fullyEligible) {
            fullyEligibleDurationNanos =
                safeDurationAdd(fullyEligibleDurationNanos, durationNanos)
        }
    }

    fun freeze(movingDurationNanos: Long): ScoreEvidenceSummary =
        ScoreEvidenceSummary(
            movingDurationNanos = movingDurationNanos,
            opportunityDurationNanos = opportunityDurationNanos,
            usableDurationNanos = usableDurationNanos,
            fullyEligibleDurationNanos = fullyEligibleDurationNanos,
        )
}

private fun TelemetryEligibility.isUsable(): Boolean = this != TelemetryEligibility.EXCLUDED

private fun safeDurationAdd(
    current: Long,
    addition: Long,
): Long {
    require(current >= 0L)
    require(addition >= 0L)
    require(current <= Long.MAX_VALUE - addition)
    return current + addition
}
