package io.github.atrx07.traelyx.intelligence

import java.util.Collections

const val DRIVE_DNA_LIFECYCLE_VERSION = 1
const val DEFAULT_DRIVE_DNA_MINIMUM_EMERGING_OBSERVATION_COUNT = 1
const val DEFAULT_DRIVE_DNA_MINIMUM_ESTABLISHED_OBSERVATION_COUNT = 10
const val DEFAULT_DRIVE_DNA_MAXIMUM_BASELINE_OBSERVATION_COUNT = 30
const val DEFAULT_DRIVE_DNA_LONG_GAP_MICROS = 90L * 24L * 60L * 60L * 1_000_000L

/** Synthetic-fixture-reviewed M4.6 lifecycle policy. New semantics require a new version. */
data class DriveDnaLifecycleConfig(
    val lifecycleVersion: Int = DRIVE_DNA_LIFECYCLE_VERSION,
    val driveDnaConfig: DriveDnaConfig = DriveDnaConfig(),
    val minimumEmergingObservationCount: Int =
        DEFAULT_DRIVE_DNA_MINIMUM_EMERGING_OBSERVATION_COUNT,
    val minimumEstablishedObservationCount: Int =
        DEFAULT_DRIVE_DNA_MINIMUM_ESTABLISHED_OBSERVATION_COUNT,
    val maximumBaselineObservationCount: Int =
        DEFAULT_DRIVE_DNA_MAXIMUM_BASELINE_OBSERVATION_COUNT,
    val longGapMicros: Long = DEFAULT_DRIVE_DNA_LONG_GAP_MICROS,
) {
    init {
        require(lifecycleVersion == DRIVE_DNA_LIFECYCLE_VERSION)
        require(minimumEmergingObservationCount > 0)
        require(
            minimumEstablishedObservationCount >=
                driveDnaConfig.minimumEligibleObservationCount,
        )
        require(minimumEstablishedObservationCount >= minimumEmergingObservationCount)
        require(maximumBaselineObservationCount >= minimumEstablishedObservationCount)
        require(longGapMicros > 0L)
    }
}

enum class DriveDnaPersonalLifecycleState {
    UNCALIBRATED,
    EMERGING,
    ESTABLISHED,
    RECALIBRATING,
}

enum class DriveDnaRecalibrationReason {
    VEHICLE_PROFILE_CHANGED,
    VEHICLE_CLASS_CHANGED,
    MOUNT_CONTEXT_CHANGED,
    SENSOR_CONTEXT_CHANGED,
    LONG_INACTIVITY_GAP,
}

enum class DriveDnaCohortExclusionReason {
    PERSONAL_SCOPE_MISMATCH,
    VEHICLE_PROFILE_MISMATCH,
    VEHICLE_CLASS_MISMATCH,
    MOUNT_CONTEXT_MISMATCH,
    SENSOR_CONTEXT_MISMATCH,
    NO_FULL_VERIFIED_DIMENSION_EVIDENCE,
    BEFORE_CURRENT_RECALIBRATION_EPOCH,
    OUTSIDE_ROLLING_WINDOW,
}

/** Explicit local partition labels. The personal key must not be a device fingerprint. */
data class DriveDnaBaselineScope(
    val personalScopeKey: String,
    val vehicleProfileId: String,
    val vehicleClassKey: String,
) {
    init {
        require(personalScopeKey.isNotBlank())
        require(vehicleProfileId.isNotBlank())
        require(vehicleClassKey.isNotBlank())
    }
}

/** Opaque local context keys. They must never be hardware serials or advertising identifiers. */
data class DriveDnaSensorContext(
    val mountContextKey: String,
    val sensorContextKey: String,
) {
    init {
        require(mountContextKey.isNotBlank())
        require(sensorContextKey.isNotBlank())
    }
}

data class DriveDnaLifecycleObservation(
    val completedAtUtcEpochMicros: Long,
    val scope: DriveDnaBaselineScope,
    val sensorContext: DriveDnaSensorContext,
    val tripObservation: DriveDnaTripObservation,
) {
    init {
        require(completedAtUtcEpochMicros >= 0L)
    }
}

data class DriveDnaCohortDecision(
    val tripId: String,
    val completedAtUtcEpochMicros: Long,
    val included: Boolean,
    val exclusionReasons: Set<DriveDnaCohortExclusionReason>,
) {
    init {
        require(tripId.isNotBlank())
        require(completedAtUtcEpochMicros >= 0L)
        require(included == exclusionReasons.isEmpty())
    }
}

data class DriveDnaLifecycleAudit(
    val lifecycleVersion: Int,
    val baselineKey: String,
    val asOfUtcEpochMicros: Long,
    val scope: DriveDnaBaselineScope,
    val sensorContext: DriveDnaSensorContext,
    val previousActiveScope: DriveDnaBaselineScope?,
    val state: DriveDnaPersonalLifecycleState,
    val profile: DriveDnaProfileAudit,
    val candidateObservations: List<DriveDnaLifecycleObservation>,
    val cohortDecisions: List<DriveDnaCohortDecision>,
    val selectedTripIds: List<String>,
    val currentEpochEligibleTripCount: Int,
    val windowStartUtcEpochMicros: Long?,
    val windowEndUtcEpochMicros: Long?,
    val activeRecalibrationReasons: Set<DriveDnaRecalibrationReason>,
    val candidateSourceVersions: DriveDnaSourceVersions,
    val configSnapshot: DriveDnaLifecycleConfig,
) {
    init {
        require(lifecycleVersion == DRIVE_DNA_LIFECYCLE_VERSION)
        require(configSnapshot.lifecycleVersion == lifecycleVersion)
        require(baselineKey.isNotBlank())
        require(asOfUtcEpochMicros >= 0L)
        require(
            previousActiveScope == null ||
                previousActiveScope.personalScopeKey == scope.personalScopeKey,
        )
        require(
            candidateObservations ==
                candidateObservations.sortedWith(
                    compareBy<DriveDnaLifecycleObservation> { it.completedAtUtcEpochMicros }
                        .thenBy { it.tripObservation.tripId },
                ),
        )
        require(
            candidateObservations.map { it.tripObservation.tripId }.distinct().size ==
                candidateObservations.size,
        )
        require(candidateObservations.all { it.completedAtUtcEpochMicros <= asOfUtcEpochMicros })
        require(cohortDecisions.size == candidateObservations.size)
        candidateObservations.zip(cohortDecisions).forEach { (observation, decision) ->
            require(decision.tripId == observation.tripObservation.tripId)
            require(decision.completedAtUtcEpochMicros == observation.completedAtUtcEpochMicros)
        }
        require(selectedTripIds == cohortDecisions.filter { it.included }.map { it.tripId })
        require(selectedTripIds.distinct().size == selectedTripIds.size)
        require(selectedTripIds.size <= configSnapshot.maximumBaselineObservationCount)
        require(currentEpochEligibleTripCount >= selectedTripIds.size)
        require(profile.profileKey == baselineKey)
        require(profile.sourceTripIds.toSet() == selectedTripIds.toSet())
        require(
            profile.observations.all { selected ->
                candidateObservations.any {
                    it.tripObservation == selected &&
                        it.scope == scope &&
                        it.sensorContext == sensorContext
                }
            },
        )
        require((windowStartUtcEpochMicros == null) == selectedTripIds.isEmpty())
        require((windowEndUtcEpochMicros == null) == selectedTripIds.isEmpty())
        if (windowStartUtcEpochMicros != null && windowEndUtcEpochMicros != null) {
            require(windowStartUtcEpochMicros <= windowEndUtcEpochMicros)
            val selectedTimes =
                candidateObservations.filter {
                    it.tripObservation.tripId in selectedTripIds
                }.map { it.completedAtUtcEpochMicros }
            require(windowStartUtcEpochMicros == selectedTimes.min())
            require(windowEndUtcEpochMicros == selectedTimes.max())
        }
        when (state) {
            DriveDnaPersonalLifecycleState.UNCALIBRATED -> {
                require(selectedTripIds.size < configSnapshot.minimumEmergingObservationCount)
                require(activeRecalibrationReasons.isEmpty())
            }
            DriveDnaPersonalLifecycleState.EMERGING -> {
                require(selectedTripIds.size >= configSnapshot.minimumEmergingObservationCount)
                require(activeRecalibrationReasons.isEmpty())
                require(
                    selectedTripIds.size < configSnapshot.minimumEstablishedObservationCount ||
                        profile.state != DriveDnaProfileState.COMPLETE,
                )
            }
            DriveDnaPersonalLifecycleState.ESTABLISHED -> {
                require(selectedTripIds.size >= configSnapshot.minimumEstablishedObservationCount)
                require(profile.state == DriveDnaProfileState.COMPLETE)
                require(activeRecalibrationReasons.isEmpty())
            }
            DriveDnaPersonalLifecycleState.RECALIBRATING -> {
                require(activeRecalibrationReasons.isNotEmpty())
                require(
                    selectedTripIds.size < configSnapshot.minimumEstablishedObservationCount ||
                        profile.state != DriveDnaProfileState.COMPLETE,
                )
            }
        }
        require(
            candidateSourceVersions ==
                candidateObservations
                    .map { it.tripObservation }
                    .toDriveDnaSourceVersions(),
        )
    }
}

internal fun DriveDnaLifecycleConfig.immutableSnapshot(): DriveDnaLifecycleConfig =
    copy(driveDnaConfig = driveDnaConfig.copy())

internal fun DriveDnaLifecycleObservation.immutableSnapshot(): DriveDnaLifecycleObservation =
    copy(tripObservation = tripObservation.immutableSnapshot())

internal fun Set<DriveDnaRecalibrationReason>.immutableSnapshot(): Set<DriveDnaRecalibrationReason> =
    Collections.unmodifiableSet(LinkedHashSet(this))
