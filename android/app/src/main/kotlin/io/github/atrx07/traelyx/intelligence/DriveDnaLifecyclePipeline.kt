package io.github.atrx07.traelyx.intelligence

import java.util.Collections

object DriveDnaLifecyclePipeline {
    fun evaluate(
        baselineKey: String,
        asOfUtcEpochMicros: Long,
        scope: DriveDnaBaselineScope,
        sensorContext: DriveDnaSensorContext,
        observations: List<DriveDnaLifecycleObservation>,
        previousActiveScope: DriveDnaBaselineScope? = null,
        config: DriveDnaLifecycleConfig = DriveDnaLifecycleConfig(),
    ): DriveDnaLifecycleAudit {
        val configSnapshot = config.immutableSnapshot()
        require(
            previousActiveScope == null ||
                previousActiveScope.personalScopeKey == scope.personalScopeKey,
        )
        val candidates =
            observations
                .map { it.immutableSnapshot() }
                .sortedWith(
                    compareBy<DriveDnaLifecycleObservation> { it.completedAtUtcEpochMicros }
                        .thenBy { it.tripObservation.tripId },
                )
        require(candidates.map { it.tripObservation.tripId }.distinct().size == candidates.size) {
            "Drive DNA lifecycle observations must contain unique trip IDs"
        }
        require(candidates.all { it.completedAtUtcEpochMicros <= asOfUtcEpochMicros }) {
            "Drive DNA lifecycle observations cannot be in the future"
        }

        val exclusionReasons =
            candidates.associate {
                it.tripObservation.tripId to
                    linkedSetOf<DriveDnaCohortExclusionReason>()
            }
        val recalibrationTriggers = linkedSetOf<DriveDnaRecalibrationReason>()
        addPreviousScopeTriggers(previousActiveScope, scope, recalibrationTriggers)

        candidates.forEach { candidate ->
            val reasons = exclusionReasons.getValue(candidate.tripObservation.tripId)
            when {
                candidate.scope.personalScopeKey != scope.personalScopeKey ->
                    reasons += DriveDnaCohortExclusionReason.PERSONAL_SCOPE_MISMATCH
                candidate.scope.vehicleProfileId != scope.vehicleProfileId ->
                    reasons += DriveDnaCohortExclusionReason.VEHICLE_PROFILE_MISMATCH
                candidate.scope.vehicleClassKey != scope.vehicleClassKey -> {
                    reasons += DriveDnaCohortExclusionReason.VEHICLE_CLASS_MISMATCH
                    recalibrationTriggers += DriveDnaRecalibrationReason.VEHICLE_CLASS_CHANGED
                }
                else -> {
                    if (candidate.sensorContext.mountContextKey != sensorContext.mountContextKey) {
                        reasons += DriveDnaCohortExclusionReason.MOUNT_CONTEXT_MISMATCH
                        recalibrationTriggers += DriveDnaRecalibrationReason.MOUNT_CONTEXT_CHANGED
                    }
                    if (candidate.sensorContext.sensorContextKey != sensorContext.sensorContextKey) {
                        reasons += DriveDnaCohortExclusionReason.SENSOR_CONTEXT_MISMATCH
                        recalibrationTriggers += DriveDnaRecalibrationReason.SENSOR_CONTEXT_CHANGED
                    }
                    if (
                        reasons.isEmpty() &&
                        !candidate.tripObservation.hasDriveDnaLifecycleEvidence(configSnapshot)
                    ) {
                        reasons +=
                            DriveDnaCohortExclusionReason.NO_FULL_VERIFIED_DIMENSION_EVIDENCE
                    }
                }
            }
        }

        val currentContextEligible =
            candidates.filter { exclusionReasons.getValue(it.tripObservation.tripId).isEmpty() }
        val currentEpoch =
            selectCurrentEpoch(
                candidates = currentContextEligible,
                asOfUtcEpochMicros = asOfUtcEpochMicros,
                longGapMicros = configSnapshot.longGapMicros,
                recalibrationTriggers = recalibrationTriggers,
                exclusionReasons = exclusionReasons,
            )
        val selected = currentEpoch.takeLast(configSnapshot.maximumBaselineObservationCount)
        val selectedIds = selected.map { it.tripObservation.tripId }.toSet()
        currentEpoch
            .filterNot { it.tripObservation.tripId in selectedIds }
            .forEach {
                exclusionReasons.getValue(it.tripObservation.tripId) +=
                    DriveDnaCohortExclusionReason.OUTSIDE_ROLLING_WINDOW
            }

        val profile =
            DriveDnaPipeline.build(
                profileKey = baselineKey,
                observations = selected.map { it.tripObservation },
                config = configSnapshot.driveDnaConfig,
            )
        val established =
            selected.size >= configSnapshot.minimumEstablishedObservationCount &&
                profile.state == DriveDnaProfileState.COMPLETE
        val activeRecalibrationReasons =
            if (established) emptySet() else recalibrationTriggers
        val state =
            when {
                established -> DriveDnaPersonalLifecycleState.ESTABLISHED
                activeRecalibrationReasons.isNotEmpty() ->
                    DriveDnaPersonalLifecycleState.RECALIBRATING
                selected.size >= configSnapshot.minimumEmergingObservationCount ->
                    DriveDnaPersonalLifecycleState.EMERGING
                else -> DriveDnaPersonalLifecycleState.UNCALIBRATED
            }
        val decisions =
            candidates.map { candidate ->
                val reasons = exclusionReasons.getValue(candidate.tripObservation.tripId)
                DriveDnaCohortDecision(
                    tripId = candidate.tripObservation.tripId,
                    completedAtUtcEpochMicros = candidate.completedAtUtcEpochMicros,
                    included = reasons.isEmpty(),
                    exclusionReasons = Collections.unmodifiableSet(LinkedHashSet(reasons)),
                )
            }
        return DriveDnaLifecycleAudit(
            lifecycleVersion = configSnapshot.lifecycleVersion,
            baselineKey = baselineKey,
            asOfUtcEpochMicros = asOfUtcEpochMicros,
            scope = scope,
            sensorContext = sensorContext,
            previousActiveScope = previousActiveScope,
            state = state,
            profile = profile,
            candidateObservations = Collections.unmodifiableList(candidates),
            cohortDecisions = Collections.unmodifiableList(decisions),
            selectedTripIds =
                Collections.unmodifiableList(
                    selected.map { it.tripObservation.tripId },
                ),
            currentEpochEligibleTripCount = currentEpoch.size,
            windowStartUtcEpochMicros = selected.firstOrNull()?.completedAtUtcEpochMicros,
            windowEndUtcEpochMicros = selected.lastOrNull()?.completedAtUtcEpochMicros,
            activeRecalibrationReasons = activeRecalibrationReasons.immutableSnapshot(),
            candidateSourceVersions =
                candidates.map { it.tripObservation }.toDriveDnaSourceVersions(),
            configSnapshot = configSnapshot,
        )
    }

    private fun addPreviousScopeTriggers(
        previousActiveScope: DriveDnaBaselineScope?,
        scope: DriveDnaBaselineScope,
        triggers: MutableSet<DriveDnaRecalibrationReason>,
    ) {
        if (previousActiveScope == null) return
        if (previousActiveScope.vehicleProfileId != scope.vehicleProfileId) {
            triggers += DriveDnaRecalibrationReason.VEHICLE_PROFILE_CHANGED
        } else if (previousActiveScope.vehicleClassKey != scope.vehicleClassKey) {
            triggers += DriveDnaRecalibrationReason.VEHICLE_CLASS_CHANGED
        }
    }

    private fun selectCurrentEpoch(
        candidates: List<DriveDnaLifecycleObservation>,
        asOfUtcEpochMicros: Long,
        longGapMicros: Long,
        recalibrationTriggers: MutableSet<DriveDnaRecalibrationReason>,
        exclusionReasons: Map<String, MutableSet<DriveDnaCohortExclusionReason>>,
    ): List<DriveDnaLifecycleObservation> {
        if (candidates.isEmpty()) return emptyList()
        if (asOfUtcEpochMicros - candidates.last().completedAtUtcEpochMicros > longGapMicros) {
            recalibrationTriggers += DriveDnaRecalibrationReason.LONG_INACTIVITY_GAP
            candidates.forEach {
                exclusionReasons.getValue(it.tripObservation.tripId) +=
                    DriveDnaCohortExclusionReason.BEFORE_CURRENT_RECALIBRATION_EPOCH
            }
            return emptyList()
        }

        var epochStartIndex = 0
        candidates.zipWithNext().forEachIndexed { index, (earlier, later) ->
            if (
                later.completedAtUtcEpochMicros - earlier.completedAtUtcEpochMicros >
                    longGapMicros
            ) {
                epochStartIndex = index + 1
            }
        }
        if (epochStartIndex > 0) {
            recalibrationTriggers += DriveDnaRecalibrationReason.LONG_INACTIVITY_GAP
            candidates.take(epochStartIndex).forEach {
                exclusionReasons.getValue(it.tripObservation.tripId) +=
                    DriveDnaCohortExclusionReason.BEFORE_CURRENT_RECALIBRATION_EPOCH
            }
        }
        return candidates.drop(epochStartIndex)
    }
}

private fun DriveDnaTripObservation.hasDriveDnaLifecycleEvidence(
    config: DriveDnaLifecycleConfig,
): Boolean =
    DRIVE_DNA_DIRECT_DIMENSIONS.any {
        isEligibleForDriveDna(it, config.driveDnaConfig)
    }
