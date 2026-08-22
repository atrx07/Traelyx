package io.github.atrx07.traelyx.intelligence

import java.util.Collections

object DriveDnaPipeline {
    fun observe(scoreAudit: TripScoreAudit): DriveDnaTripObservation =
        DriveDnaTripObservation.from(scoreAudit)

    fun build(
        profileKey: String,
        observations: List<DriveDnaTripObservation>,
        config: DriveDnaConfig = DriveDnaConfig(),
    ): DriveDnaProfileAudit {
        val configSnapshot = config.copy()
        val observationSnapshot =
            observations
                .map { it.immutableSnapshot() }
                .sortedBy { it.tripId }
        require(observationSnapshot.map { it.tripId }.distinct().size == observationSnapshot.size) {
            "Drive DNA observations must contain unique trip IDs"
        }

        val dimensions = linkedMapOf<ScoringDimension, DriveDnaDimensionAudit>()
        DRIVE_DNA_DIRECT_DIMENSIONS.forEach { dimension ->
            dimensions[dimension] =
                buildDirectDimension(
                    dimension = dimension,
                    observations = observationSnapshot,
                    config = configSnapshot,
                )
        }
        dimensions[ScoringDimension.CONSISTENCY] =
            buildConsistencyDimension(
                observations = observationSnapshot,
                directDimensions = dimensions,
                config = configSnapshot,
            )

        val immutableDimensions = Collections.unmodifiableMap(dimensions)
        val sourceTripIds = observationSnapshot.map { it.tripId }
        val eligibleTripIds =
            DRIVE_DNA_DIRECT_DIMENSIONS
                .flatMap { immutableDimensions.getValue(it).sourceTripIds }
                .distinct()
                .sorted()
        val availableCount =
            immutableDimensions.values.count { it.state == DriveDnaDimensionState.AVAILABLE }
        val state =
            when {
                availableCount == ScoringDimension.entries.size -> DriveDnaProfileState.COMPLETE
                availableCount > 0 -> DriveDnaProfileState.PARTIAL
                else -> DriveDnaProfileState.UNAVAILABLE
            }
        return DriveDnaProfileAudit(
            driveDnaVersion = configSnapshot.driveDnaVersion,
            profileKey = profileKey,
            state = state,
            dimensions = immutableDimensions,
            observations = Collections.unmodifiableList(observationSnapshot),
            sourceTripIds = Collections.unmodifiableList(sourceTripIds),
            eligibleTripIds = Collections.unmodifiableList(eligibleTripIds),
            sourceVersions = observationSnapshot.toDriveDnaSourceVersions(),
            configSnapshot = configSnapshot,
        )
    }

    private fun buildDirectDimension(
        dimension: ScoringDimension,
        observations: List<DriveDnaTripObservation>,
        config: DriveDnaConfig,
    ): DriveDnaDimensionAudit {
        val eligible = observations.filter { it.isEligibleForDriveDna(dimension, config) }
        val values =
            eligible.map {
                requireNotNull(it.dimensions.getValue(dimension).scoreMilliPoints)
            }
        val available = eligible.size >= config.minimumEligibleObservationCount
        val median = values.medianMilliPoints()
        return DriveDnaDimensionAudit(
            driveDnaVersion = config.driveDnaVersion,
            dimension = dimension,
            state =
                if (available) {
                    DriveDnaDimensionState.AVAILABLE
                } else {
                    DriveDnaDimensionState.UNAVAILABLE
                },
            valueMilliPoints = if (available) median else null,
            displayValue =
                if (available) {
                    median?.let(::milliPointsToDisplayScore)
                } else {
                    null
                },
            candidateTripCount = observations.size,
            eligibleTripCount = eligible.size,
            sourceTripIds = Collections.unmodifiableList(eligible.map { it.tripId }),
            sourceMeanAbsoluteDeviationMilliPoints =
                values.meanAbsoluteDeviationFromMedianMilliPoints(),
            contributingDimensions = emptySet(),
            unavailableReasons =
                if (available) {
                    emptySet()
                } else if (observations.isEmpty()) {
                    setOf(DriveDnaUnavailableReason.NO_TRIP_OBSERVATIONS)
                } else {
                    setOf(
                        DriveDnaUnavailableReason.INSUFFICIENT_FULL_ELIGIBLE_OBSERVATIONS,
                    )
                },
        )
    }

    private fun buildConsistencyDimension(
        observations: List<DriveDnaTripObservation>,
        directDimensions: Map<ScoringDimension, DriveDnaDimensionAudit>,
        config: DriveDnaConfig,
    ): DriveDnaDimensionAudit {
        val contributing =
            DRIVE_DNA_DIRECT_DIMENSIONS.filterTo(linkedSetOf()) {
                directDimensions.getValue(it).state == DriveDnaDimensionState.AVAILABLE
            }
        val sourceTripIds =
            contributing
                .flatMap { directDimensions.getValue(it).sourceTripIds }
                .distinct()
                .sorted()
        val meanDeviation =
            contributing.map {
                requireNotNull(
                    directDimensions.getValue(it).sourceMeanAbsoluteDeviationMilliPoints,
                )
            }.roundedMean()
        val available = contributing.size >= config.minimumConsistencyDimensionCount
        val value =
            if (available) {
                val penalty =
                    scaleDriveDnaDeviation(
                        requireNotNull(meanDeviation),
                        config.consistencyPenaltyPermillePerDeviationPoint,
                    )
                (scorePointsToMilli(SCORE_MAXIMUM_POINTS) - penalty)
                    .coerceAtLeast(scorePointsToMilli(SCORE_MINIMUM_POINTS))
            } else {
                null
            }
        return DriveDnaDimensionAudit(
            driveDnaVersion = config.driveDnaVersion,
            dimension = ScoringDimension.CONSISTENCY,
            state =
                if (available) {
                    DriveDnaDimensionState.AVAILABLE
                } else {
                    DriveDnaDimensionState.UNAVAILABLE
                },
            valueMilliPoints = value,
            displayValue = value?.let(::milliPointsToDisplayScore),
            candidateTripCount = observations.size,
            eligibleTripCount = sourceTripIds.size,
            sourceTripIds = Collections.unmodifiableList(sourceTripIds),
            sourceMeanAbsoluteDeviationMilliPoints = meanDeviation,
            contributingDimensions = Collections.unmodifiableSet(contributing),
            unavailableReasons =
                if (available) {
                    emptySet()
                } else if (observations.isEmpty()) {
                    setOf(DriveDnaUnavailableReason.NO_TRIP_OBSERVATIONS)
                } else {
                    setOf(DriveDnaUnavailableReason.INSUFFICIENT_COMPARABLE_DIMENSIONS)
                },
        )
    }
}
