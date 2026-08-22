package io.github.atrx07.traelyx.intelligence

import java.math.BigInteger
import java.util.Collections

const val SCORING_VERSION = 1
const val SCORE_MINIMUM_POINTS = 0
const val SCORE_MAXIMUM_POINTS = 100
const val SCORE_MILLI_POINTS_PER_POINT = 1_000L
const val SCORE_FULL_WEIGHT_PERMILLE = 1_000
const val SCORE_WEIGHT_BASIS_POINTS_TOTAL = 10_000

const val DEFAULT_MINIMUM_MOVING_DURATION_NANOS = 3_000_000_000L
const val DEFAULT_MINIMUM_CONTROL_OPPORTUNITY_DURATION_NANOS = 500_000_000L
const val DEFAULT_MINIMUM_USABLE_EVIDENCE_COVERAGE_PERMILLE = 800
const val DEFAULT_MINIMUM_FULL_EVIDENCE_COVERAGE_PERMILLE = 800
const val DEFAULT_LIMITED_EVIDENCE_WEIGHT_PERMILLE = 500
const val DEFAULT_SEVERITY_MULTIPLIER_CAP_PERMILLE = 2_000
const val DEFAULT_MINIMUM_OVERALL_DIMENSION_COUNT = 2
const val DEFAULT_OVERALL_RISK_GUARDRAIL_MARGIN_POINTS = 15
const val DEFAULT_LONGITUDINAL_CONTROL_OPPORTUNITY_METRES_PER_SECOND_SQUARED = 0.5
const val DEFAULT_CORNERING_OPPORTUNITY_METRES_PER_SECOND_SQUARED = 0.5
const val DEFAULT_CORNERING_OPPORTUNITY_RADIANS_PER_SECOND = 0.05

val SCORABLE_SCORE_DIMENSIONS: Set<ScoringDimension> =
    setOf(
        ScoringDimension.SMOOTHNESS,
        ScoringDimension.BRAKING_CONTROL,
        ScoringDimension.ACCELERATION_CONTROL,
        ScoringDimension.CORNERING_CONTROL,
    )

/** Synthetic-fixture-reviewed M4.4 policy. A new meaning or weight requires a new version. */
data class ScoringConfig(
    val scoringVersion: Int = SCORING_VERSION,
    val minimumMovingDurationNanos: Long = DEFAULT_MINIMUM_MOVING_DURATION_NANOS,
    val minimumControlOpportunityDurationNanos: Long =
        DEFAULT_MINIMUM_CONTROL_OPPORTUNITY_DURATION_NANOS,
    val minimumUsableEvidenceCoveragePermille: Int =
        DEFAULT_MINIMUM_USABLE_EVIDENCE_COVERAGE_PERMILLE,
    val minimumFullEvidenceCoveragePermille: Int =
        DEFAULT_MINIMUM_FULL_EVIDENCE_COVERAGE_PERMILLE,
    val limitedEvidenceWeightPermille: Int = DEFAULT_LIMITED_EVIDENCE_WEIGHT_PERMILLE,
    val severityMultiplierCapPermille: Int = DEFAULT_SEVERITY_MULTIPLIER_CAP_PERMILLE,
    val minimumOverallDimensionCount: Int = DEFAULT_MINIMUM_OVERALL_DIMENSION_COUNT,
    val overallRiskGuardrailMarginPoints: Int =
        DEFAULT_OVERALL_RISK_GUARDRAIL_MARGIN_POINTS,
    val longitudinalControlOpportunityMetresPerSecondSquared: Double =
        DEFAULT_LONGITUDINAL_CONTROL_OPPORTUNITY_METRES_PER_SECOND_SQUARED,
    val corneringOpportunityMetresPerSecondSquared: Double =
        DEFAULT_CORNERING_OPPORTUNITY_METRES_PER_SECOND_SQUARED,
    val corneringOpportunityRadiansPerSecond: Double =
        DEFAULT_CORNERING_OPPORTUNITY_RADIANS_PER_SECOND,
    val dimensionWeightsBasisPoints: Map<ScoringDimension, Int> =
        defaultDimensionWeightsBasisPoints(),
    val contributionBasePenaltyPoints: Map<ScoreContributionRule, Int> =
        defaultContributionBasePenaltyPoints(),
) {
    init {
        require(scoringVersion == SCORING_VERSION)
        require(minimumMovingDurationNanos > 0L)
        require(minimumControlOpportunityDurationNanos > 0L)
        require(minimumUsableEvidenceCoveragePermille in 1..SCORE_FULL_WEIGHT_PERMILLE)
        require(minimumFullEvidenceCoveragePermille in 1..SCORE_FULL_WEIGHT_PERMILLE)
        require(minimumFullEvidenceCoveragePermille >= minimumUsableEvidenceCoveragePermille)
        require(limitedEvidenceWeightPermille in 1 until SCORE_FULL_WEIGHT_PERMILLE)
        require(severityMultiplierCapPermille >= SCORE_FULL_WEIGHT_PERMILLE)
        require(minimumOverallDimensionCount in 1..SCORABLE_SCORE_DIMENSIONS.size)
        require(overallRiskGuardrailMarginPoints in 0..SCORE_MAXIMUM_POINTS)
        requirePositiveFinite(longitudinalControlOpportunityMetresPerSecondSquared)
        requirePositiveFinite(corneringOpportunityMetresPerSecondSquared)
        requirePositiveFinite(corneringOpportunityRadiansPerSecond)
        require(dimensionWeightsBasisPoints.keys == ScoringDimension.entries.toSet())
        require(dimensionWeightsBasisPoints.values.all { it in 1..SCORE_WEIGHT_BASIS_POINTS_TOTAL })
        require(
            dimensionWeightsBasisPoints.values.sumOf { it.toLong() } ==
                SCORE_WEIGHT_BASIS_POINTS_TOTAL.toLong(),
        )
        require(contributionBasePenaltyPoints.keys == ScoreContributionRule.entries.toSet())
        require(contributionBasePenaltyPoints.values.all { it in 1..SCORE_MAXIMUM_POINTS })
    }
}

enum class ScoringDimension(val machineId: String) {
    SMOOTHNESS("SCORE_SMOOTHNESS"),
    BRAKING_CONTROL("SCORE_BRAKING_CONTROL"),
    ACCELERATION_CONTROL("SCORE_ACCELERATION_CONTROL"),
    CORNERING_CONTROL("SCORE_CORNERING_CONTROL"),
    CONSISTENCY("SCORE_CONSISTENCY"),
}

enum class ScoreDimensionState {
    FULL,
    PROVISIONAL,
    UNAVAILABLE,
}

enum class TripScoreState {
    FULL,
    PROVISIONAL,
    UNAVAILABLE,
    UNRANKED,
}

enum class ScoreContributionKind {
    PENALTY,
    BONUS,
}

enum class ScoreContributionRule(
    val machineId: String,
    val dimension: ScoringDimension,
) {
    SMOOTHNESS_ABRUPT_LONGITUDINAL_TRANSITION(
        "SC_SMOOTH_ABRUPT_LONGITUDINAL",
        ScoringDimension.SMOOTHNESS,
    ),
    SMOOTHNESS_ABRUPT_CORNER_TRANSITION(
        "SC_SMOOTH_ABRUPT_CORNER",
        ScoringDimension.SMOOTHNESS,
    ),
    BRAKING_ABRUPT_TRANSITION(
        "SC_BRAKE_ABRUPT_TRANSITION",
        ScoringDimension.BRAKING_CONTROL,
    ),
    BRAKING_REPEATED_STRONG_EVENT(
        "SC_BRAKE_REPEATED_STRONG",
        ScoringDimension.BRAKING_CONTROL,
    ),
    ACCELERATION_ABRUPT_TRANSITION(
        "SC_ACCEL_ABRUPT_TRANSITION",
        ScoringDimension.ACCELERATION_CONTROL,
    ),
    ACCELERATION_REPEATED_STRONG_EVENT(
        "SC_ACCEL_REPEATED_STRONG",
        ScoringDimension.ACCELERATION_CONTROL,
    ),
    CORNERING_ABRUPT_ENTRY(
        "SC_CORNER_ABRUPT_ENTRY",
        ScoringDimension.CORNERING_CONTROL,
    ),
    CORNERING_ABRUPT_EXIT(
        "SC_CORNER_ABRUPT_EXIT",
        ScoringDimension.CORNERING_CONTROL,
    ),
    CORNERING_REPEATED_HIGH_LOAD(
        "SC_CORNER_REPEATED_HIGH_LOAD",
        ScoringDimension.CORNERING_CONTROL,
    ),
}

enum class ScoreUnavailableReason {
    INSUFFICIENT_MOVING_DURATION,
    INSUFFICIENT_USABLE_EVIDENCE,
    NO_BRAKING_OPPORTUNITY,
    NO_ACCELERATION_OPPORTUNITY,
    NO_CORNERING_OPPORTUNITY,
    CONSISTENCY_BASELINE_NOT_AVAILABLE,
    INSUFFICIENT_AVAILABLE_DIMENSIONS,
    INTEGRITY_UNRANKED,
}

enum class ScoreProvisionalReason {
    LIMITED_INTEGRITY,
    QUESTIONABLE_INTEGRITY,
    UNRANKED_INTEGRITY,
    LIMITED_TELEMETRY_EVIDENCE,
    LIMITED_EVENT_EVIDENCE,
    PARTIAL_DIMENSION_COVERAGE,
}

enum class ScoreRankingStatus {
    ELIGIBLE,
    INELIGIBLE_PROVISIONAL_SCORE,
    INELIGIBLE_INSUFFICIENT_SCORE_EVIDENCE,
    REVIEW_REQUIRED_INTEGRITY,
    INELIGIBLE_INTEGRITY,
}

data class ScoreEvidenceSummary(
    val movingDurationNanos: Long,
    val opportunityDurationNanos: Long,
    val usableDurationNanos: Long,
    val fullyEligibleDurationNanos: Long,
) {
    val usableCoveragePermille: Int
        get() = coveragePermille(usableDurationNanos, opportunityDurationNanos)

    val fullyEligibleCoveragePermille: Int
        get() = coveragePermille(fullyEligibleDurationNanos, opportunityDurationNanos)

    init {
        require(movingDurationNanos >= 0L)
        require(opportunityDurationNanos in 0L..movingDurationNanos)
        require(usableDurationNanos in 0L..opportunityDurationNanos)
        require(fullyEligibleDurationNanos in 0L..usableDurationNanos)
    }
}

data class ScoreContribution(
    val scoringVersion: Int,
    val contributionId: String,
    val rule: ScoreContributionRule,
    val kind: ScoreContributionKind,
    val basePoints: Int,
    val severityMultiplierPermille: Int,
    val confidenceWeightPermille: Int,
    val rawPointsMilli: Long,
    val appliedPointsMilli: Long,
    val supportingEventIds: Set<String>,
) {
    val appliedPoints: Double
        get() = appliedPointsMilli.toDouble() / SCORE_MILLI_POINTS_PER_POINT

    init {
        require(scoringVersion == SCORING_VERSION)
        require(contributionId.startsWith("score_v${SCORING_VERSION}_"))
        require(kind == ScoreContributionKind.PENALTY)
        require(basePoints > 0)
        require(severityMultiplierPermille >= SCORE_FULL_WEIGHT_PERMILLE)
        require(confidenceWeightPermille in 1..SCORE_FULL_WEIGHT_PERMILLE)
        require(rawPointsMilli == basePoints.toLong() * severityMultiplierPermille)
        require(
            appliedPointsMilli ==
                roundedPositiveDivide(
                    rawPointsMilli * confidenceWeightPermille,
                    SCORE_FULL_WEIGHT_PERMILLE.toLong(),
                ),
        )
        require(supportingEventIds.isNotEmpty())
        require(supportingEventIds.all { it.isNotBlank() })
    }
}

data class DimensionScore(
    val scoringVersion: Int,
    val dimension: ScoringDimension,
    val state: ScoreDimensionState,
    val scoreMilliPoints: Long?,
    val displayScore: Int?,
    val weightBasisPoints: Int,
    val evidence: ScoreEvidenceSummary,
    val contributions: List<ScoreContribution>,
    val provisionalReasons: Set<ScoreProvisionalReason>,
    val unavailableReasons: Set<ScoreUnavailableReason>,
) {
    init {
        require(scoringVersion == SCORING_VERSION)
        require(weightBasisPoints > 0)
        require(contributions.all { it.rule.dimension == dimension })
        require(contributions.zipWithNext().all { (left, right) -> left.contributionId < right.contributionId })
        require((scoreMilliPoints == null) == (displayScore == null))
        if (scoreMilliPoints != null && displayScore != null) {
            require(
                scoreMilliPoints in
                    scorePointsToMilli(SCORE_MINIMUM_POINTS)..scorePointsToMilli(SCORE_MAXIMUM_POINTS),
            )
            require(displayScore == milliPointsToDisplayScore(scoreMilliPoints))
        }
        when (state) {
            ScoreDimensionState.FULL -> {
                require(scoreMilliPoints != null)
                require(provisionalReasons.isEmpty())
                require(unavailableReasons.isEmpty())
            }
            ScoreDimensionState.PROVISIONAL -> {
                require(scoreMilliPoints != null)
                require(provisionalReasons.isNotEmpty())
                require(unavailableReasons.isEmpty())
            }
            ScoreDimensionState.UNAVAILABLE -> {
                require(scoreMilliPoints == null)
                require(provisionalReasons.isEmpty())
                require(unavailableReasons.isNotEmpty())
            }
        }
    }
}

data class ScoringSourceVersions(
    val scoringVersion: Int,
    val integritySourceVersions: IntegritySourceVersions,
) {
    init {
        require(scoringVersion == SCORING_VERSION)
    }
}

data class TripScoreAudit(
    val scoringVersion: Int,
    val tripId: String,
    val state: TripScoreState,
    val overallScoreMilliPoints: Long?,
    val overallDisplayScore: Int?,
    val rankingStatus: ScoreRankingStatus,
    val dimensions: Map<ScoringDimension, DimensionScore>,
    val availableOverallDimensions: Set<ScoringDimension>,
    val availableOverallWeightBasisPoints: Int,
    val riskGuardrailApplied: Boolean,
    val provisionalReasons: Set<ScoreProvisionalReason>,
    val unavailableReasons: Set<ScoreUnavailableReason>,
    val integrityAudit: TripIntegrityAudit,
    val sourceVersions: ScoringSourceVersions,
    val configSnapshot: ScoringConfig,
) {
    init {
        require(scoringVersion == SCORING_VERSION)
        require(configSnapshot.scoringVersion == scoringVersion)
        require(tripId.isNotBlank())
        require(tripId == integrityAudit.tripId)
        require(sourceVersions.integritySourceVersions == integrityAudit.sourceVersions)
        require(dimensions.keys == ScoringDimension.entries.toSet())
        require(dimensions.all { (dimension, score) -> dimension == score.dimension })
        dimensions.forEach { (dimension, score) ->
            require(score.weightBasisPoints == configSnapshot.dimensionWeightsBasisPoints.getValue(dimension))
            score.contributions.forEach { contribution ->
                require(
                    contribution.basePoints ==
                        configSnapshot.contributionBasePenaltyPoints.getValue(contribution.rule),
                )
                require(
                    contribution.severityMultiplierPermille <=
                        configSnapshot.severityMultiplierCapPermille,
                )
                require(
                    contribution.confidenceWeightPermille == SCORE_FULL_WEIGHT_PERMILLE ||
                        contribution.confidenceWeightPermille ==
                        configSnapshot.limitedEvidenceWeightPermille,
                )
            }
            score.scoreMilliPoints?.let { scoreMilliPoints ->
                val expected =
                    (scorePointsToMilli(SCORE_MAXIMUM_POINTS) -
                        score.contributions.sumOf { it.appliedPointsMilli })
                        .coerceIn(
                            scorePointsToMilli(SCORE_MINIMUM_POINTS),
                            scorePointsToMilli(SCORE_MAXIMUM_POINTS),
                        )
                require(scoreMilliPoints == expected)
            }
        }
        val consistency = dimensions.getValue(ScoringDimension.CONSISTENCY)
        require(consistency.state == ScoreDimensionState.UNAVAILABLE)
        require(
            ScoreUnavailableReason.CONSISTENCY_BASELINE_NOT_AVAILABLE in
                consistency.unavailableReasons,
        )
        val scoredDimensions =
            dimensions.filterValues { it.scoreMilliPoints != null }.keys.intersect(
                SCORABLE_SCORE_DIMENSIONS,
            )
        require(availableOverallDimensions == scoredDimensions)
        require(
            availableOverallWeightBasisPoints ==
                availableOverallDimensions.sumOf {
                    configSnapshot.dimensionWeightsBasisPoints.getValue(it)
                },
        )
        require((overallScoreMilliPoints == null) == (overallDisplayScore == null))
        if (overallScoreMilliPoints != null && overallDisplayScore != null) {
            require(
                overallScoreMilliPoints in
                    scorePointsToMilli(SCORE_MINIMUM_POINTS)..scorePointsToMilli(SCORE_MAXIMUM_POINTS),
            )
            require(overallDisplayScore == milliPointsToDisplayScore(overallScoreMilliPoints))
            val weightedNumerator =
                availableOverallDimensions.sumOf { dimension ->
                    requireNotNull(dimensions.getValue(dimension).scoreMilliPoints) *
                        configSnapshot.dimensionWeightsBasisPoints.getValue(dimension)
                }
            val weighted =
                roundedPositiveDivide(
                    weightedNumerator,
                    availableOverallWeightBasisPoints.toLong(),
                )
            val lowest =
                availableOverallDimensions.minOf {
                    requireNotNull(dimensions.getValue(it).scoreMilliPoints)
                }
            val guardrail =
                (lowest +
                    scorePointsToMilli(configSnapshot.overallRiskGuardrailMarginPoints))
                    .coerceAtMost(scorePointsToMilli(SCORE_MAXIMUM_POINTS))
            require(overallScoreMilliPoints == minOf(weighted, guardrail))
            require(riskGuardrailApplied == (weighted > guardrail))
        } else {
            require(!riskGuardrailApplied)
        }
        require(
            (state == TripScoreState.UNRANKED) ==
                (integrityAudit.state == TripIntegrityState.UNRANKED),
        )
        when (state) {
            TripScoreState.FULL -> {
                require(overallScoreMilliPoints != null)
                require(availableOverallDimensions == SCORABLE_SCORE_DIMENSIONS)
                require(availableOverallDimensions.all { dimensions.getValue(it).state == ScoreDimensionState.FULL })
                require(integrityAudit.state == TripIntegrityState.VERIFIED)
                require(provisionalReasons.isEmpty())
                require(unavailableReasons.isEmpty())
            }
            TripScoreState.PROVISIONAL -> {
                require(overallScoreMilliPoints != null)
                require(
                    availableOverallDimensions.size >=
                        configSnapshot.minimumOverallDimensionCount,
                )
                require(provisionalReasons.isNotEmpty())
                require(unavailableReasons.isEmpty())
            }
            TripScoreState.UNAVAILABLE -> {
                require(overallScoreMilliPoints == null)
                require(
                    availableOverallDimensions.size <
                        configSnapshot.minimumOverallDimensionCount,
                )
                require(provisionalReasons.isEmpty())
                require(unavailableReasons.isNotEmpty())
            }
            TripScoreState.UNRANKED -> {
                require(overallScoreMilliPoints == null)
                require(provisionalReasons.isEmpty())
                require(integrityAudit.state == TripIntegrityState.UNRANKED)
                require(ScoreUnavailableReason.INTEGRITY_UNRANKED in unavailableReasons)
            }
        }
        require(rankingStatus == expectedRankingStatus(state, integrityAudit.state))
    }
}

internal fun scorePointsToMilli(points: Int): Long =
    points.toLong() * SCORE_MILLI_POINTS_PER_POINT

internal fun milliPointsToDisplayScore(milliPoints: Long): Int =
    roundedPositiveDivide(milliPoints, SCORE_MILLI_POINTS_PER_POINT).toInt()

internal fun roundedPositiveDivide(
    numerator: Long,
    denominator: Long,
): Long {
    require(numerator >= 0L)
    require(denominator > 0L)
    val quotient = numerator / denominator
    val remainder = numerator % denominator
    val roundUpThreshold = denominator / 2L + denominator % 2L
    return quotient + if (remainder >= roundUpThreshold) 1L else 0L
}

internal fun ScoringConfig.immutableSnapshot(): ScoringConfig =
    copy(
        dimensionWeightsBasisPoints =
            Collections.unmodifiableMap(LinkedHashMap(dimensionWeightsBasisPoints)),
        contributionBasePenaltyPoints =
            Collections.unmodifiableMap(LinkedHashMap(contributionBasePenaltyPoints)),
    )

private fun coveragePermille(
    coveredDurationNanos: Long,
    totalDurationNanos: Long,
): Int =
    if (totalDurationNanos == 0L) {
        0
    } else {
        BigInteger.valueOf(coveredDurationNanos)
            .multiply(BigInteger.valueOf(SCORE_FULL_WEIGHT_PERMILLE.toLong()))
            .divide(BigInteger.valueOf(totalDurationNanos))
            .toInt()
    }

private fun expectedRankingStatus(
    state: TripScoreState,
    integrityState: TripIntegrityState,
): ScoreRankingStatus =
    when (integrityState) {
        TripIntegrityState.UNRANKED -> ScoreRankingStatus.INELIGIBLE_INTEGRITY
        TripIntegrityState.QUESTIONABLE -> ScoreRankingStatus.REVIEW_REQUIRED_INTEGRITY
        TripIntegrityState.LIMITED_CONFIDENCE ->
            ScoreRankingStatus.INELIGIBLE_PROVISIONAL_SCORE
        TripIntegrityState.VERIFIED ->
            when (state) {
                TripScoreState.FULL -> ScoreRankingStatus.ELIGIBLE
                TripScoreState.PROVISIONAL -> ScoreRankingStatus.INELIGIBLE_PROVISIONAL_SCORE
                TripScoreState.UNAVAILABLE ->
                    ScoreRankingStatus.INELIGIBLE_INSUFFICIENT_SCORE_EVIDENCE
                TripScoreState.UNRANKED -> error("Verified integrity cannot produce unranked score")
            }
    }

private fun defaultDimensionWeightsBasisPoints(): Map<ScoringDimension, Int> =
    linkedMapOf(
        ScoringDimension.SMOOTHNESS to 3_000,
        ScoringDimension.BRAKING_CONTROL to 2_000,
        ScoringDimension.ACCELERATION_CONTROL to 1_500,
        ScoringDimension.CORNERING_CONTROL to 2_000,
        ScoringDimension.CONSISTENCY to 1_500,
    )

private fun defaultContributionBasePenaltyPoints(): Map<ScoreContributionRule, Int> =
    linkedMapOf(
        ScoreContributionRule.SMOOTHNESS_ABRUPT_LONGITUDINAL_TRANSITION to 6,
        ScoreContributionRule.SMOOTHNESS_ABRUPT_CORNER_TRANSITION to 5,
        ScoreContributionRule.BRAKING_ABRUPT_TRANSITION to 12,
        ScoreContributionRule.BRAKING_REPEATED_STRONG_EVENT to 4,
        ScoreContributionRule.ACCELERATION_ABRUPT_TRANSITION to 10,
        ScoreContributionRule.ACCELERATION_REPEATED_STRONG_EVENT to 3,
        ScoreContributionRule.CORNERING_ABRUPT_ENTRY to 10,
        ScoreContributionRule.CORNERING_ABRUPT_EXIT to 8,
        ScoreContributionRule.CORNERING_REPEATED_HIGH_LOAD to 3,
    )

private fun requirePositiveFinite(value: Double) {
    require(value.isFinite() && value > 0.0)
}
