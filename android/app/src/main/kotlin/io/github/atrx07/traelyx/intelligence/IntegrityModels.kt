package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.DERIVED_TELEMETRY_VERSION
import io.github.atrx07.traelyx.telemetry.GNSS_PROCESSING_VERSION
import io.github.atrx07.traelyx.telemetry.RAW_TELEMETRY_TRIP_DECODER_VERSION
import io.github.atrx07.traelyx.telemetry.TELEMETRY_CONFIDENCE_VERSION
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceReason

const val INTEGRITY_RULES_VERSION = 1
const val DEFAULT_REPEATED_IMPOSSIBLE_JUMP_UNRANKED_COUNT = 2
const val DEFAULT_QUESTIONABLE_SOURCE_CONFLICT_DURATION_NANOS = 1_000_000_000L
const val DEFAULT_QUESTIONABLE_MOTION_WITHOUT_IMU_DURATION_NANOS = 2_000_000_000L
const val TELEMETRY_INCONSISTENCY_EVENT_MACHINE_ID = "EVT_TELEMETRY_INCONSISTENCY"

/** Synthetic-fixture-reviewed M4.3 policy. It classifies evidence, never intent. */
data class IntegrityRulesConfig(
    val integrityVersion: Int = INTEGRITY_RULES_VERSION,
    val repeatedImpossibleJumpUnrankedCount: Int =
        DEFAULT_REPEATED_IMPOSSIBLE_JUMP_UNRANKED_COUNT,
    val questionableSourceConflictDurationNanos: Long =
        DEFAULT_QUESTIONABLE_SOURCE_CONFLICT_DURATION_NANOS,
    val questionableMotionWithoutImuDurationNanos: Long =
        DEFAULT_QUESTIONABLE_MOTION_WITHOUT_IMU_DURATION_NANOS,
) {
    init {
        require(integrityVersion == INTEGRITY_RULES_VERSION)
        require(repeatedImpossibleJumpUnrankedCount > 1)
        require(questionableSourceConflictDurationNanos > 0L)
        require(questionableMotionWithoutImuDurationNanos > 0L)
    }
}

enum class TripIntegrityState(val severityRank: Int) {
    VERIFIED(0),
    LIMITED_CONFIDENCE(1),
    QUESTIONABLE(2),
    UNRANKED(3),
}

enum class RankEligibility {
    ELIGIBLE,
    ELIGIBLE_WITH_LIMITATIONS,
    REVIEW_REQUIRED,
    INELIGIBLE,
}

enum class IntegrityDimension {
    SOURCE_INTEGRITY,
    GNSS_CONSISTENCY,
    IMU_CONSISTENCY,
    CROSS_SENSOR_AGREEMENT,
    TEMPORAL_INTEGRITY,
}

enum class IntegrityFindingKind {
    QUALITY_LIMITATION,
    PLATFORM_SIGNAL,
    INCONSISTENCY,
    DATA_CORRUPTION,
}

enum class IntegrityRuleId(val machineId: String) {
    RAW_TRIP_INVALID("INT_RAW_TRIP_INVALID"),
    PLATFORM_MOCK_LOCATION_SIGNAL("INT_GNSS_MOCK_SIGNAL"),
    IMPOSSIBLE_GNSS_JUMP("INT_GNSS_IMPOSSIBLE_JUMP"),
    IMPLAUSIBLE_GNSS_SOURCE_SPEED("INT_GNSS_SOURCE_SPEED_IMPLAUSIBLE"),
    GNSS_SOURCE_GAP("INT_GNSS_SOURCE_GAP"),
    CLOCK_DISCONTINUITY("INT_CLOCK_DISCONTINUITY"),
    IMU_SOURCE_DROPOUT("INT_IMU_SOURCE_DROPOUT"),
    IMU_SENSOR_UNRELIABLE("INT_IMU_SENSOR_UNRELIABLE"),
    CROSS_SENSOR_DISAGREEMENT("INT_CROSS_SENSOR_DISAGREEMENT"),
    PHONE_MOVEMENT_INVALIDATION("INT_PHONE_MOVEMENT_INVALIDATION"),
    MOTION_WITHOUT_INERTIAL_CORROBORATION("INT_MOTION_WITHOUT_IMU"),
}

enum class IntegrityEvidenceReason {
    RAW_TRIP_DECODER_REJECTED,
    PLATFORM_MOCK_LOCATION_FLAG,
    GNSS_PROCESSING_MOCK_SIGNAL,
    GNSS_IMPOSSIBLE_JUMP_DECISION,
    GNSS_SOURCE_SPEED_IMPLAUSIBLE,
    GNSS_PROCESSING_GAP_RESET,
    GNSS_CLOCK_DISCONTINUITY_FLAG,
    ACCELEROMETER_CLOCK_DISCONTINUITY_FLAG,
    GYROSCOPE_CLOCK_DISCONTINUITY_FLAG,
    ACCELEROMETER_DROPOUT_FLAG,
    GYROSCOPE_DROPOUT_FLAG,
    ACCELEROMETER_UNRELIABLE_FLAG,
    GYROSCOPE_UNRELIABLE_FLAG,
    SOURCE_AGREEMENT_INVALIDATED,
    ACCEPTED_PHONE_MOVEMENT_EVENT,
    MOVING_WITH_ACCELEROMETER_UNAVAILABLE,
    MOVING_WITH_GYROSCOPE_UNAVAILABLE,
}

data class RawTripIntegrityFailure(
    val errorCode: String,
    val inputIndex: Int?,
    val sequence: Long?,
) {
    init {
        require(errorCode.isNotBlank())
        require(inputIndex == null || inputIndex >= 0)
        require(sequence == null || sequence >= 0L)
    }
}

data class IntegritySourceVersions(
    val rawDecoderVersion: Int,
    val chunkEncodingVersion: Int,
    val telemetrySchemaVersion: Int,
    val gnssProcessingVersion: Int,
    val derivedVersion: Int,
    val confidenceVersion: Int,
    val taxonomyVersion: Int,
    val mergeVersion: Int,
) {
    init {
        require(rawDecoderVersion == RAW_TELEMETRY_TRIP_DECODER_VERSION)
        require(chunkEncodingVersion > 0)
        require(telemetrySchemaVersion > 0)
        require(gnssProcessingVersion == GNSS_PROCESSING_VERSION)
        require(derivedVersion == DERIVED_TELEMETRY_VERSION)
        require(confidenceVersion == TELEMETRY_CONFIDENCE_VERSION)
        require(taxonomyVersion == EVENT_TAXONOMY_VERSION)
        require(mergeVersion == EVENT_MERGE_VERSION)
    }
}

data class IntegrityFinding(
    val integrityVersion: Int,
    val eventMachineId: String?,
    val ruleId: IntegrityRuleId,
    val kind: IntegrityFindingKind,
    val state: TripIntegrityState,
    val dimensions: Set<IntegrityDimension>,
    val occurrenceCount: Long,
    val firstTripElapsedNanos: Long?,
    val lastTripElapsedNanos: Long?,
    val maximumContinuousDurationNanos: Long?,
    val evidenceReasons: Set<IntegrityEvidenceReason>,
    val confidenceReasons: Set<TelemetryConfidenceReason>,
    val representativeMergedEventId: String?,
    val rawTripFailure: RawTripIntegrityFailure?,
) {
    init {
        require(integrityVersion == INTEGRITY_RULES_VERSION)
        require(
            (kind == IntegrityFindingKind.INCONSISTENCY) ==
                (eventMachineId == TELEMETRY_INCONSISTENCY_EVENT_MACHINE_ID),
        )
        require(state != TripIntegrityState.VERIFIED)
        require(dimensions.isNotEmpty())
        require(occurrenceCount > 0L)
        require((firstTripElapsedNanos == null) == (lastTripElapsedNanos == null))
        if (firstTripElapsedNanos != null && lastTripElapsedNanos != null) {
            require(firstTripElapsedNanos >= 0L)
            require(lastTripElapsedNanos >= firstTripElapsedNanos)
        }
        require(maximumContinuousDurationNanos == null || maximumContinuousDurationNanos > 0L)
        require(evidenceReasons.isNotEmpty())
        require(
            (ruleId == IntegrityRuleId.RAW_TRIP_INVALID) == (rawTripFailure != null),
        )
        require(
            representativeMergedEventId == null ||
                ruleId == IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION,
        )
    }
}

data class IntegrityDimensionAssessment(
    val dimension: IntegrityDimension,
    val state: TripIntegrityState,
    val contributingRules: Set<IntegrityRuleId>,
) {
    init {
        require(
            (state == TripIntegrityState.VERIFIED) == contributingRules.isEmpty(),
        )
    }
}

data class TripIntegrityAudit(
    val integrityVersion: Int,
    val tripId: String?,
    val state: TripIntegrityState,
    val rankEligibility: RankEligibility,
    val dimensions: Map<IntegrityDimension, IntegrityDimensionAssessment>,
    val findings: List<IntegrityFinding>,
    val sourceVersions: IntegritySourceVersions?,
    val configSnapshot: IntegrityRulesConfig,
) {
    init {
        require(integrityVersion == INTEGRITY_RULES_VERSION)
        require(configSnapshot.integrityVersion == integrityVersion)
        require(dimensions.keys == IntegrityDimension.entries.toSet())
        require(dimensions.all { (dimension, assessment) -> dimension == assessment.dimension })
        require(findings.zipWithNext().all { (left, right) -> left.ruleId.ordinal < right.ruleId.ordinal })
        require(state == dimensions.values.maxBy { it.state.severityRank }.state)
        require(rankEligibility == state.rankEligibility())
        require((tripId == null) == (sourceVersions == null))
        require(
            if (tripId == null) {
                findings.size == 1 && findings.single().ruleId == IntegrityRuleId.RAW_TRIP_INVALID
            } else {
                tripId.isNotBlank() && findings.none { it.ruleId == IntegrityRuleId.RAW_TRIP_INVALID }
            },
        )
    }
}

private fun TripIntegrityState.rankEligibility(): RankEligibility =
    when (this) {
        TripIntegrityState.VERIFIED -> RankEligibility.ELIGIBLE
        TripIntegrityState.LIMITED_CONFIDENCE -> RankEligibility.ELIGIBLE_WITH_LIMITATIONS
        TripIntegrityState.QUESTIONABLE -> RankEligibility.REVIEW_REQUIRED
        TripIntegrityState.UNRANKED -> RankEligibility.INELIGIBLE
    }
