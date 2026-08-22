package io.github.atrx07.traelyx.intelligence

import java.math.BigInteger
import java.util.Collections
import kotlin.math.abs

const val DRIVE_DNA_VERSION = 1
const val DEFAULT_DRIVE_DNA_MINIMUM_ELIGIBLE_OBSERVATION_COUNT = 5
const val DEFAULT_DRIVE_DNA_MINIMUM_CONSISTENCY_DIMENSION_COUNT = 3
const val DEFAULT_DRIVE_DNA_CONSISTENCY_PENALTY_PERMILLE_PER_DEVIATION_POINT = 2_000

val DRIVE_DNA_DIRECT_DIMENSIONS: List<ScoringDimension> =
    listOf(
        ScoringDimension.SMOOTHNESS,
        ScoringDimension.BRAKING_CONTROL,
        ScoringDimension.ACCELERATION_CONTROL,
        ScoringDimension.CORNERING_CONTROL,
    )

/** Synthetic-fixture-reviewed M4.5 aggregation policy. New semantics require a new version. */
data class DriveDnaConfig(
    val driveDnaVersion: Int = DRIVE_DNA_VERSION,
    val requiredScoringVersion: Int = SCORING_VERSION,
    val minimumEligibleObservationCount: Int =
        DEFAULT_DRIVE_DNA_MINIMUM_ELIGIBLE_OBSERVATION_COUNT,
    val minimumConsistencyDimensionCount: Int =
        DEFAULT_DRIVE_DNA_MINIMUM_CONSISTENCY_DIMENSION_COUNT,
    val consistencyPenaltyPermillePerDeviationPoint: Int =
        DEFAULT_DRIVE_DNA_CONSISTENCY_PENALTY_PERMILLE_PER_DEVIATION_POINT,
) {
    init {
        require(driveDnaVersion == DRIVE_DNA_VERSION)
        require(requiredScoringVersion == SCORING_VERSION)
        require(minimumEligibleObservationCount > 1)
        require(minimumConsistencyDimensionCount in 1..DRIVE_DNA_DIRECT_DIMENSIONS.size)
        require(consistencyPenaltyPermillePerDeviationPoint > 0)
    }
}

enum class DriveDnaDimensionState {
    AVAILABLE,
    UNAVAILABLE,
}

enum class DriveDnaProfileState {
    COMPLETE,
    PARTIAL,
    UNAVAILABLE,
}

enum class DriveDnaUnavailableReason {
    NO_TRIP_OBSERVATIONS,
    INSUFFICIENT_FULL_ELIGIBLE_OBSERVATIONS,
    INSUFFICIENT_COMPARABLE_DIMENSIONS,
}

data class DriveDnaTripDimensionObservation(
    val dimension: ScoringDimension,
    val scoreState: ScoreDimensionState,
    val scoreMilliPoints: Long?,
    val displayScore: Int?,
) {
    init {
        require((scoreMilliPoints == null) == (displayScore == null))
        require((scoreState == ScoreDimensionState.UNAVAILABLE) == (scoreMilliPoints == null))
        scoreMilliPoints?.let { value ->
            require(
                value in
                    scorePointsToMilli(SCORE_MINIMUM_POINTS)..
                    scorePointsToMilli(SCORE_MAXIMUM_POINTS),
            )
            require(displayScore == milliPointsToDisplayScore(value))
        }
    }
}

/** Compact, immutable source summary extracted from one versioned trip score audit. */
data class DriveDnaTripObservation(
    val tripId: String,
    val scoringVersion: Int,
    val tripScoreState: TripScoreState,
    val integrityVersion: Int,
    val integrityState: TripIntegrityState,
    val dimensions: Map<ScoringDimension, DriveDnaTripDimensionObservation>,
    val scoringSourceVersions: ScoringSourceVersions,
) {
    init {
        require(tripId.isNotBlank())
        require(scoringVersion == SCORING_VERSION)
        require(integrityVersion == INTEGRITY_RULES_VERSION)
        require(scoringSourceVersions.scoringVersion == scoringVersion)
        require(dimensions.keys == ScoringDimension.entries.toSet())
        require(dimensions.all { (dimension, observation) -> dimension == observation.dimension })
        require(
            dimensions.getValue(ScoringDimension.CONSISTENCY).scoreState ==
                ScoreDimensionState.UNAVAILABLE,
        )
        if (integrityState != TripIntegrityState.VERIFIED) {
            require(
                DRIVE_DNA_DIRECT_DIMENSIONS.none {
                    dimensions.getValue(it).scoreState == ScoreDimensionState.FULL
                },
            )
        }
        if (tripScoreState == TripScoreState.FULL) {
            require(integrityState == TripIntegrityState.VERIFIED)
            require(
                DRIVE_DNA_DIRECT_DIMENSIONS.all {
                    dimensions.getValue(it).scoreState == ScoreDimensionState.FULL
                },
            )
        }
        require(
            (tripScoreState == TripScoreState.UNRANKED) ==
                (integrityState == TripIntegrityState.UNRANKED),
        )
    }

    companion object {
        fun from(scoreAudit: TripScoreAudit): DriveDnaTripObservation =
            DriveDnaTripObservation(
                tripId = scoreAudit.tripId,
                scoringVersion = scoreAudit.scoringVersion,
                tripScoreState = scoreAudit.state,
                integrityVersion = scoreAudit.integrityAudit.integrityVersion,
                integrityState = scoreAudit.integrityAudit.state,
                dimensions =
                    Collections.unmodifiableMap(
                        ScoringDimension.entries.associateWith { dimension ->
                            val score = scoreAudit.dimensions.getValue(dimension)
                            DriveDnaTripDimensionObservation(
                                dimension = dimension,
                                scoreState = score.state,
                                scoreMilliPoints = score.scoreMilliPoints,
                                displayScore = score.displayScore,
                            )
                        },
                    ),
                scoringSourceVersions = scoreAudit.sourceVersions,
            )
    }
}

data class DriveDnaDimensionAudit(
    val driveDnaVersion: Int,
    val dimension: ScoringDimension,
    val state: DriveDnaDimensionState,
    val valueMilliPoints: Long?,
    val displayValue: Int?,
    val candidateTripCount: Int,
    val eligibleTripCount: Int,
    val sourceTripIds: List<String>,
    val sourceMeanAbsoluteDeviationMilliPoints: Long?,
    val contributingDimensions: Set<ScoringDimension>,
    val unavailableReasons: Set<DriveDnaUnavailableReason>,
) {
    init {
        require(driveDnaVersion == DRIVE_DNA_VERSION)
        require(candidateTripCount >= 0)
        require(eligibleTripCount in 0..candidateTripCount)
        require(sourceTripIds.size == eligibleTripCount)
        require(sourceTripIds.distinct().size == sourceTripIds.size)
        require(sourceTripIds == sourceTripIds.sorted())
        require((sourceMeanAbsoluteDeviationMilliPoints == null) == sourceTripIds.isEmpty())
        require(
            sourceMeanAbsoluteDeviationMilliPoints == null ||
                sourceMeanAbsoluteDeviationMilliPoints >= 0L,
        )
        require((valueMilliPoints == null) == (displayValue == null))
        valueMilliPoints?.let { value ->
            require(
                value in
                    scorePointsToMilli(SCORE_MINIMUM_POINTS)..
                    scorePointsToMilli(SCORE_MAXIMUM_POINTS),
            )
            require(displayValue == milliPointsToDisplayScore(value))
        }
        when (state) {
            DriveDnaDimensionState.AVAILABLE -> {
                require(valueMilliPoints != null)
                require(unavailableReasons.isEmpty())
            }
            DriveDnaDimensionState.UNAVAILABLE -> {
                require(valueMilliPoints == null)
                require(unavailableReasons.isNotEmpty())
            }
        }
        if (dimension == ScoringDimension.CONSISTENCY) {
            require(contributingDimensions.all { it in DRIVE_DNA_DIRECT_DIMENSIONS })
        } else {
            require(dimension in DRIVE_DNA_DIRECT_DIMENSIONS)
            require(contributingDimensions.isEmpty())
        }
    }
}

data class DriveDnaSourceVersions(
    val driveDnaVersion: Int,
    val scoringVersions: Set<Int>,
    val integrityVersions: Set<Int>,
    val rawDecoderVersions: Set<Int>,
    val chunkEncodingVersions: Set<Int>,
    val telemetrySchemaVersions: Set<Int>,
    val gnssProcessingVersions: Set<Int>,
    val derivedVersions: Set<Int>,
    val confidenceVersions: Set<Int>,
    val taxonomyVersions: Set<Int>,
    val mergeVersions: Set<Int>,
) {
    init {
        require(driveDnaVersion == DRIVE_DNA_VERSION)
        require(scoringVersions.all { it == SCORING_VERSION })
        require(integrityVersions.all { it == INTEGRITY_RULES_VERSION })
        require(rawDecoderVersions.all { it > 0 })
        require(chunkEncodingVersions.all { it > 0 })
        require(telemetrySchemaVersions.all { it > 0 })
        require(gnssProcessingVersions.all { it > 0 })
        require(derivedVersions.all { it > 0 })
        require(confidenceVersions.all { it > 0 })
        require(taxonomyVersions.all { it == EVENT_TAXONOMY_VERSION })
        require(mergeVersions.all { it == EVENT_MERGE_VERSION })
    }
}

data class DriveDnaProfileAudit(
    val driveDnaVersion: Int,
    val profileKey: String,
    val state: DriveDnaProfileState,
    val dimensions: Map<ScoringDimension, DriveDnaDimensionAudit>,
    val observations: List<DriveDnaTripObservation>,
    val sourceTripIds: List<String>,
    val eligibleTripIds: List<String>,
    val sourceVersions: DriveDnaSourceVersions,
    val configSnapshot: DriveDnaConfig,
) {
    init {
        require(driveDnaVersion == DRIVE_DNA_VERSION)
        require(configSnapshot.driveDnaVersion == driveDnaVersion)
        require(profileKey.isNotBlank())
        require(observations.map { it.tripId } == observations.map { it.tripId }.sorted())
        require(observations.map { it.tripId }.distinct().size == observations.size)
        require(sourceTripIds == observations.map { it.tripId })
        require(dimensions.keys == ScoringDimension.entries.toSet())
        require(dimensions.all { (dimension, audit) -> dimension == audit.dimension })
        require(dimensions.values.all { it.candidateTripCount == observations.size })

        DRIVE_DNA_DIRECT_DIMENSIONS.forEach { dimension ->
            val audit = dimensions.getValue(dimension)
            val eligible = observations.filter { it.isEligibleForDriveDna(dimension, configSnapshot) }
            val eligibleValues =
                eligible.map {
                    requireNotNull(it.dimensions.getValue(dimension).scoreMilliPoints)
                }
            require(audit.sourceTripIds == eligible.map { it.tripId })
            require(audit.eligibleTripCount == eligible.size)
            require(
                audit.sourceMeanAbsoluteDeviationMilliPoints ==
                    eligibleValues.meanAbsoluteDeviationFromMedianMilliPoints(),
            )
            if (eligible.size >= configSnapshot.minimumEligibleObservationCount) {
                require(audit.state == DriveDnaDimensionState.AVAILABLE)
                require(audit.valueMilliPoints == eligibleValues.medianMilliPoints())
            } else {
                require(audit.state == DriveDnaDimensionState.UNAVAILABLE)
                require(
                    audit.unavailableReasons ==
                        expectedDirectUnavailableReasons(observations.isEmpty()),
                )
            }
        }

        val consistency = dimensions.getValue(ScoringDimension.CONSISTENCY)
        val contributing =
            DRIVE_DNA_DIRECT_DIMENSIONS.filterTo(linkedSetOf()) {
                dimensions.getValue(it).state == DriveDnaDimensionState.AVAILABLE
            }
        val consistencyTripIds =
            contributing
                .flatMap { dimensions.getValue(it).sourceTripIds }
                .distinct()
                .sorted()
        require(consistency.contributingDimensions == contributing)
        require(consistency.sourceTripIds == consistencyTripIds)
        require(consistency.eligibleTripCount == consistencyTripIds.size)
        val contributingDeviations =
            contributing.map {
                requireNotNull(
                    dimensions.getValue(it).sourceMeanAbsoluteDeviationMilliPoints,
                )
            }
        val expectedMeanDeviation = contributingDeviations.roundedMean()
        require(consistency.sourceMeanAbsoluteDeviationMilliPoints == expectedMeanDeviation)
        if (contributing.size >= configSnapshot.minimumConsistencyDimensionCount) {
            require(consistency.state == DriveDnaDimensionState.AVAILABLE)
            val penalty =
                scaleDriveDnaDeviation(
                    requireNotNull(expectedMeanDeviation),
                    configSnapshot.consistencyPenaltyPermillePerDeviationPoint,
                )
            require(
                consistency.valueMilliPoints ==
                    (scorePointsToMilli(SCORE_MAXIMUM_POINTS) - penalty)
                        .coerceAtLeast(scorePointsToMilli(SCORE_MINIMUM_POINTS)),
            )
        } else {
            require(consistency.state == DriveDnaDimensionState.UNAVAILABLE)
            require(
                consistency.unavailableReasons ==
                    expectedConsistencyUnavailableReasons(observations.isEmpty()),
            )
        }

        val expectedEligibleTripIds =
            DRIVE_DNA_DIRECT_DIMENSIONS
                .flatMap { dimensions.getValue(it).sourceTripIds }
                .distinct()
                .sorted()
        require(eligibleTripIds == expectedEligibleTripIds)
        val availableCount =
            dimensions.values.count { it.state == DriveDnaDimensionState.AVAILABLE }
        require(
            state ==
                when {
                    availableCount == ScoringDimension.entries.size ->
                        DriveDnaProfileState.COMPLETE
                    availableCount > 0 -> DriveDnaProfileState.PARTIAL
                    else -> DriveDnaProfileState.UNAVAILABLE
                },
        )
        require(sourceVersions == observations.toDriveDnaSourceVersions())
    }
}

internal fun DriveDnaTripObservation.immutableSnapshot(): DriveDnaTripObservation =
    copy(dimensions = Collections.unmodifiableMap(LinkedHashMap(dimensions)))

internal fun List<DriveDnaTripObservation>.toDriveDnaSourceVersions(): DriveDnaSourceVersions =
    DriveDnaSourceVersions(
        driveDnaVersion = DRIVE_DNA_VERSION,
        scoringVersions = immutableSetOf(map { it.scoringVersion }),
        integrityVersions = immutableSetOf(map { it.integrityVersion }),
        rawDecoderVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.rawDecoderVersion },
            ),
        chunkEncodingVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.chunkEncodingVersion },
            ),
        telemetrySchemaVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.telemetrySchemaVersion },
            ),
        gnssProcessingVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.gnssProcessingVersion },
            ),
        derivedVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.derivedVersion },
            ),
        confidenceVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.confidenceVersion },
            ),
        taxonomyVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.taxonomyVersion },
            ),
        mergeVersions =
            immutableSetOf(
                map { it.scoringSourceVersions.integritySourceVersions.mergeVersion },
            ),
    )

internal fun DriveDnaTripObservation.isEligibleForDriveDna(
    dimension: ScoringDimension,
    config: DriveDnaConfig,
): Boolean {
    require(dimension in DRIVE_DNA_DIRECT_DIMENSIONS)
    val observation = dimensions.getValue(dimension)
    return scoringVersion == config.requiredScoringVersion &&
        integrityState == TripIntegrityState.VERIFIED &&
        observation.scoreState == ScoreDimensionState.FULL
}

internal fun List<Long>.medianMilliPoints(): Long? {
    if (isEmpty()) return null
    val sorted = sorted()
    val middle = sorted.size / 2
    return if (sorted.size % 2 == 1) {
        sorted[middle]
    } else {
        roundedPositiveDivide(sorted[middle - 1] + sorted[middle], 2L)
    }
}

internal fun List<Long>.meanAbsoluteDeviationFromMedianMilliPoints(): Long? {
    val median = medianMilliPoints() ?: return null
    return map { abs(it - median) }.roundedMean()
}

internal fun List<Long>.roundedMean(): Long? {
    if (isEmpty()) return null
    val numerator = fold(BigInteger.ZERO) { total, value ->
        require(value >= 0L)
        total.add(BigInteger.valueOf(value))
    }
    return roundedPositiveBigIntegerDivide(numerator, BigInteger.valueOf(size.toLong()))
}

internal fun scaleDriveDnaDeviation(
    deviationMilliPoints: Long,
    penaltyPermillePerDeviationPoint: Int,
): Long {
    require(deviationMilliPoints >= 0L)
    require(penaltyPermillePerDeviationPoint > 0)
    return roundedPositiveBigIntegerDivide(
        BigInteger.valueOf(deviationMilliPoints)
            .multiply(BigInteger.valueOf(penaltyPermillePerDeviationPoint.toLong())),
        BigInteger.valueOf(SCORE_FULL_WEIGHT_PERMILLE.toLong()),
    )
}

private fun roundedPositiveBigIntegerDivide(
    numerator: BigInteger,
    denominator: BigInteger,
): Long {
    require(numerator.signum() >= 0)
    require(denominator.signum() > 0)
    val quotientAndRemainder = numerator.divideAndRemainder(denominator)
    val roundUp = quotientAndRemainder[1].shiftLeft(1) >= denominator
    val result =
        if (roundUp) quotientAndRemainder[0].add(BigInteger.ONE) else quotientAndRemainder[0]
    return result.longValueExact()
}

private fun expectedDirectUnavailableReasons(
    observationsEmpty: Boolean,
): Set<DriveDnaUnavailableReason> =
    if (observationsEmpty) {
        setOf(DriveDnaUnavailableReason.NO_TRIP_OBSERVATIONS)
    } else {
        setOf(DriveDnaUnavailableReason.INSUFFICIENT_FULL_ELIGIBLE_OBSERVATIONS)
    }

private fun expectedConsistencyUnavailableReasons(
    observationsEmpty: Boolean,
): Set<DriveDnaUnavailableReason> =
    if (observationsEmpty) {
        setOf(DriveDnaUnavailableReason.NO_TRIP_OBSERVATIONS)
    } else {
        setOf(DriveDnaUnavailableReason.INSUFFICIENT_COMPARABLE_DIMENSIONS)
    }

private fun immutableSetOf(values: List<Int>): Set<Int> =
    Collections.unmodifiableSet(LinkedHashSet(values))
