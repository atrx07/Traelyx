package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.DERIVED_TELEMETRY_VERSION
import io.github.atrx07.traelyx.telemetry.DerivedChannelProvenance
import io.github.atrx07.traelyx.telemetry.TELEMETRY_CONFIDENCE_VERSION
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceAssessment
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceComponentKind
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import io.github.atrx07.traelyx.telemetry.TelemetryEligibilityAssessment
import io.github.atrx07.traelyx.telemetry.TelemetryMetric

const val EVENT_TAXONOMY_VERSION = 1

const val DEFAULT_STRONG_ACCELERATION_METRES_PER_SECOND_SQUARED = 1.5
const val DEFAULT_STRONG_BRAKING_METRES_PER_SECOND_SQUARED = 2.5
const val DEFAULT_HIGH_LATERAL_LOAD_METRES_PER_SECOND_SQUARED = 2.0
const val DEFAULT_ABRUPT_LONGITUDINAL_JERK_METRES_PER_SECOND_CUBED = 3.5
const val DEFAULT_ABRUPT_LONGITUDINAL_MINIMUM_ACCELERATION_METRES_PER_SECOND_SQUARED = 0.75
const val DEFAULT_ABRUPT_LATERAL_JERK_METRES_PER_SECOND_CUBED = 3.5
const val DEFAULT_ABRUPT_CORNER_MINIMUM_LATERAL_LOAD_METRES_PER_SECOND_SQUARED = 0.75
const val DEFAULT_ROAD_IMPACT_VERTICAL_ACCELERATION_METRES_PER_SECOND_SQUARED = 1.0
const val DEFAULT_ROAD_IMPACT_VERTICAL_JERK_METRES_PER_SECOND_CUBED = 5.0

/**
 * Synthetic-fixture-reviewed M4.1 baseline. These values are event-evidence activation gates,
 * not legal, moral, crash, or scoring thresholds.
 */
data class EventTaxonomyConfig(
    val taxonomyVersion: Int = EVENT_TAXONOMY_VERSION,
    val strongAccelerationMetresPerSecondSquared: Double =
        DEFAULT_STRONG_ACCELERATION_METRES_PER_SECOND_SQUARED,
    val strongBrakingMetresPerSecondSquared: Double =
        DEFAULT_STRONG_BRAKING_METRES_PER_SECOND_SQUARED,
    val highLateralLoadMetresPerSecondSquared: Double =
        DEFAULT_HIGH_LATERAL_LOAD_METRES_PER_SECOND_SQUARED,
    val abruptLongitudinalJerkMetresPerSecondCubed: Double =
        DEFAULT_ABRUPT_LONGITUDINAL_JERK_METRES_PER_SECOND_CUBED,
    val abruptLongitudinalMinimumAccelerationMetresPerSecondSquared: Double =
        DEFAULT_ABRUPT_LONGITUDINAL_MINIMUM_ACCELERATION_METRES_PER_SECOND_SQUARED,
    val abruptLateralJerkMetresPerSecondCubed: Double =
        DEFAULT_ABRUPT_LATERAL_JERK_METRES_PER_SECOND_CUBED,
    val abruptCornerMinimumLateralLoadMetresPerSecondSquared: Double =
        DEFAULT_ABRUPT_CORNER_MINIMUM_LATERAL_LOAD_METRES_PER_SECOND_SQUARED,
    val roadImpactVerticalAccelerationMetresPerSecondSquared: Double =
        DEFAULT_ROAD_IMPACT_VERTICAL_ACCELERATION_METRES_PER_SECOND_SQUARED,
    val roadImpactVerticalJerkMetresPerSecondCubed: Double =
        DEFAULT_ROAD_IMPACT_VERTICAL_JERK_METRES_PER_SECOND_CUBED,
) {
    init {
        require(taxonomyVersion == EVENT_TAXONOMY_VERSION)
        requirePositiveFinite(strongAccelerationMetresPerSecondSquared)
        requirePositiveFinite(strongBrakingMetresPerSecondSquared)
        requirePositiveFinite(highLateralLoadMetresPerSecondSquared)
        requirePositiveFinite(abruptLongitudinalJerkMetresPerSecondCubed)
        requirePositiveFinite(abruptLongitudinalMinimumAccelerationMetresPerSecondSquared)
        requirePositiveFinite(abruptLateralJerkMetresPerSecondCubed)
        requirePositiveFinite(abruptCornerMinimumLateralLoadMetresPerSecondSquared)
        requirePositiveFinite(roadImpactVerticalAccelerationMetresPerSecondSquared)
        requirePositiveFinite(roadImpactVerticalJerkMetresPerSecondCubed)
    }
}

enum class DrivingEventType(val machineId: String) {
    STRONG_ACCELERATION("EVT_ACCEL_STRONG"),
    ABRUPT_ACCELERATION_TRANSITION("EVT_ACCEL_ABRUPT_TRANSITION"),
    STRONG_BRAKING("EVT_BRAKE_STRONG"),
    ABRUPT_BRAKING_TRANSITION("EVT_BRAKE_ABRUPT_TRANSITION"),
    HIGH_LATERAL_LOAD_LEFT("EVT_CORNER_HIGH_LOAD_LEFT"),
    HIGH_LATERAL_LOAD_RIGHT("EVT_CORNER_HIGH_LOAD_RIGHT"),
    ABRUPT_CORNER_ENTRY("EVT_CORNER_ABRUPT_ENTRY"),
    ABRUPT_CORNER_EXIT("EVT_CORNER_ABRUPT_EXIT"),
    ROAD_IMPACT_OR_BUMP("EVT_ROAD_IMPACT"),
    PHONE_MOVED("EVT_PHONE_MOVED"),
}

enum class EventEvidenceConfidence {
    SUPPORTED,
    LIMITED,
}

enum class EventMeasurementKind {
    LONGITUDINAL_ACCELERATION,
    LATERAL_ACCELERATION,
    VERTICAL_ACCELERATION,
    LONGITUDINAL_JERK,
    LATERAL_JERK,
    VERTICAL_JERK,
}

enum class EventMeasurementUnit {
    METRES_PER_SECOND_SQUARED,
    METRES_PER_SECOND_CUBED,
}

data class EventPrimaryMeasurement(
    val kind: EventMeasurementKind,
    val unit: EventMeasurementUnit,
    val signedValue: Double,
    val sourceProvenance: DerivedChannelProvenance,
) {
    init {
        require(signedValue.isFinite())
        require(
            when (kind) {
                EventMeasurementKind.LONGITUDINAL_ACCELERATION,
                EventMeasurementKind.LATERAL_ACCELERATION,
                EventMeasurementKind.VERTICAL_ACCELERATION,
                -> unit == EventMeasurementUnit.METRES_PER_SECOND_SQUARED

                EventMeasurementKind.LONGITUDINAL_JERK,
                EventMeasurementKind.LATERAL_JERK,
                EventMeasurementKind.VERTICAL_JERK,
                -> unit == EventMeasurementUnit.METRES_PER_SECOND_CUBED
            },
        )
    }
}

enum class EventRuleEvidence {
    MOVEMENT_CONFIRMED,
    LONGITUDINAL_ACCELERATION_THRESHOLD,
    LONGITUDINAL_BRAKING_THRESHOLD,
    LONGITUDINAL_POSITIVE_JERK_THRESHOLD,
    LONGITUDINAL_NEGATIVE_JERK_THRESHOLD,
    LATERAL_LEFT_LOAD_THRESHOLD,
    LATERAL_RIGHT_LOAD_THRESHOLD,
    LATERAL_JERK_THRESHOLD,
    LATERAL_LOAD_INCREASING,
    LATERAL_LOAD_DECREASING,
    VERTICAL_ACCELERATION_THRESHOLD,
    VERTICAL_JERK_THRESHOLD,
    EXPLICIT_DEVICE_MOVEMENT_INVALIDATION,
}

enum class EventQualityFlag {
    LIMITED_SOURCE_EVIDENCE,
    PHONE_ORIENTATION_INVALIDATED,
}

sealed interface EventSeverityEvidence {
    data class Measured(
        val physicalMagnitude: Double,
        val activationThreshold: Double,
    ) : EventSeverityEvidence {
        val activationRatio: Double
            get() = physicalMagnitude / activationThreshold

        init {
            require(physicalMagnitude.isFinite() && physicalMagnitude >= 0.0)
            require(activationThreshold.isFinite() && activationThreshold > 0.0)
            require(physicalMagnitude >= activationThreshold)
        }
    }

    data object UnavailableForPhoneMovement : EventSeverityEvidence
}

data class EventSourceEvidence(
    val derivedVersion: Int,
    val confidenceVersion: Int,
    val metricEligibility: Map<TelemetryMetric, TelemetryEligibilityAssessment>,
    val componentConfidence:
        Map<TelemetryConfidenceComponentKind, TelemetryConfidenceAssessment>,
) {
    init {
        require(derivedVersion == DERIVED_TELEMETRY_VERSION)
        require(confidenceVersion == TELEMETRY_CONFIDENCE_VERSION)
        require(metricEligibility.all { (metric, assessment) -> metric == assessment.metric })
        require(
            metricEligibility.values.none {
                it.eligibility == TelemetryEligibility.EXCLUDED
            },
        )
        require(componentConfidence.isNotEmpty())
    }
}

/**
 * A single M4.1 analysis-window classification. M4.2 is responsible for merging adjacent windows
 * into maneuver-level events and assigning final event identifiers/start/peak/end bounds.
 */
data class EventEvidenceWindow(
    val taxonomyVersion: Int = EVENT_TAXONOMY_VERSION,
    val eventType: DrivingEventType,
    val windowStartTripElapsedNanos: Long,
    val peakTripElapsedNanos: Long,
    val windowEndTripElapsedNanos: Long,
    val severity: EventSeverityEvidence,
    val confidence: EventEvidenceConfidence,
    val qualityFlags: Set<EventQualityFlag>,
    val primaryMeasurements: List<EventPrimaryMeasurement>,
    val ruleEvidence: Set<EventRuleEvidence>,
    val sourceEvidence: EventSourceEvidence,
    val configSnapshot: EventTaxonomyConfig,
) {
    init {
        require(taxonomyVersion == EVENT_TAXONOMY_VERSION)
        require(configSnapshot.taxonomyVersion == taxonomyVersion)
        require(windowStartTripElapsedNanos >= 0L)
        require(peakTripElapsedNanos in windowStartTripElapsedNanos..windowEndTripElapsedNanos)
        require(ruleEvidence.isNotEmpty())
        require(
            (confidence == EventEvidenceConfidence.LIMITED) ==
                (EventQualityFlag.LIMITED_SOURCE_EVIDENCE in qualityFlags),
        )
        require(
            if (eventType == DrivingEventType.PHONE_MOVED) {
                primaryMeasurements.isEmpty() &&
                    severity is EventSeverityEvidence.UnavailableForPhoneMovement &&
                    EventRuleEvidence.EXPLICIT_DEVICE_MOVEMENT_INVALIDATION in ruleEvidence &&
                    EventQualityFlag.PHONE_ORIENTATION_INVALIDATED in qualityFlags
            } else {
                primaryMeasurements.isNotEmpty() && severity is EventSeverityEvidence.Measured
            },
        )
    }
}

private fun requirePositiveFinite(value: Double) {
    require(value.isFinite() && value > 0.0)
}
