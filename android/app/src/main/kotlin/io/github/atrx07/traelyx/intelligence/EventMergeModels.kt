package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.DerivedChannelMissingReason
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceComponentKind
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceReason
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceState
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import io.github.atrx07.traelyx.telemetry.TelemetryEligibilityReason
import io.github.atrx07.traelyx.telemetry.TelemetryMetric

const val EVENT_MERGE_VERSION = 1
const val DEFAULT_MAXIMUM_EVENT_MERGE_GAP_NANOS = 250_000_000L
const val DEFAULT_MINIMUM_SUSTAINED_EVENT_WINDOW_COUNT = 3

/**
 * Synthetic-fixture-reviewed M4.2 baseline. Merge settings affect event identity and therefore
 * remain explicit, versioned evidence rather than hidden UI behavior.
 */
data class EventMergeConfig(
    val mergeVersion: Int = EVENT_MERGE_VERSION,
    val maximumMergeGapNanos: Long = DEFAULT_MAXIMUM_EVENT_MERGE_GAP_NANOS,
    val minimumSustainedWindowCount: Int = DEFAULT_MINIMUM_SUSTAINED_EVENT_WINDOW_COUNT,
) {
    init {
        require(mergeVersion == EVENT_MERGE_VERSION)
        require(maximumMergeGapNanos >= 0L)
        require(minimumSustainedWindowCount > 0)
    }
}

enum class EventMergePolicy {
    SUSTAINED,
    TRANSIENT,
}

enum class EventDebounceReason {
    INSUFFICIENT_SOURCE_WINDOWS,
}

data class MergedMetricEvidence(
    val metric: TelemetryMetric,
    val observedEligibility: Set<TelemetryEligibility>,
    val reasons: Set<TelemetryEligibilityReason>,
    val requiredComponents: Set<TelemetryConfidenceComponentKind>,
    val limitingComponents: Set<TelemetryConfidenceComponentKind>,
    val sourceMissingReasons: Set<DerivedChannelMissingReason>,
) {
    init {
        require(observedEligibility.isNotEmpty())
        require(reasons.isNotEmpty())
        require(limitingComponents.all { it in requiredComponents })
    }
}

data class MergedComponentEvidence(
    val component: TelemetryConfidenceComponentKind,
    val observedStates: Set<TelemetryConfidenceState>,
    val reasons: Set<TelemetryConfidenceReason>,
) {
    init {
        require(observedStates.isNotEmpty())
        require(reasons.isNotEmpty())
    }
}

/** Complete, bounded summary of every M4.1 window represented by one M4.2 decision. */
data class EventWindowGroupSummary(
    val taxonomyVersion: Int,
    val mergeVersion: Int,
    val tripId: String,
    val eventType: DrivingEventType,
    val mergePolicy: EventMergePolicy,
    val startTripElapsedNanos: Long,
    val peakTripElapsedNanos: Long,
    val endTripElapsedNanos: Long,
    val sourceWindowCount: Int,
    val supportedWindowCount: Int,
    val limitedWindowCount: Int,
    val peakWindow: EventEvidenceWindow,
    val confidence: EventEvidenceConfidence,
    val qualityFlags: Set<EventQualityFlag>,
    val ruleEvidence: Set<EventRuleEvidence>,
    val metricEvidence: Map<TelemetryMetric, MergedMetricEvidence>,
    val componentEvidence:
        Map<TelemetryConfidenceComponentKind, MergedComponentEvidence>,
    val taxonomyConfigSnapshot: EventTaxonomyConfig,
    val mergeConfigSnapshot: EventMergeConfig,
) {
    init {
        require(taxonomyVersion == EVENT_TAXONOMY_VERSION)
        require(mergeVersion == EVENT_MERGE_VERSION)
        require(tripId.isNotBlank())
        require(startTripElapsedNanos >= 0L)
        require(peakTripElapsedNanos in startTripElapsedNanos..endTripElapsedNanos)
        require(sourceWindowCount > 0)
        require(sourceWindowCount == supportedWindowCount + limitedWindowCount)
        require(peakWindow.eventType == eventType)
        require(peakWindow.peakTripElapsedNanos == peakTripElapsedNanos)
        require(taxonomyConfigSnapshot.taxonomyVersion == taxonomyVersion)
        require(mergeConfigSnapshot.mergeVersion == mergeVersion)
        require(ruleEvidence.isNotEmpty())
        require(componentEvidence.isNotEmpty())
        require(
            (confidence == EventEvidenceConfidence.LIMITED) ==
                (limitedWindowCount > 0),
        )
        require(
            (confidence == EventEvidenceConfidence.LIMITED) ==
                (EventQualityFlag.LIMITED_SOURCE_EVIDENCE in qualityFlags),
        )
    }
}

data class MergedDrivingEvent(
    val eventId: String,
    val taxonomyVersion: Int,
    val mergeVersion: Int,
    val tripId: String,
    val eventType: DrivingEventType,
    val startTripElapsedNanos: Long,
    val peakTripElapsedNanos: Long,
    val endTripElapsedNanos: Long,
    val severity: EventSeverityEvidence,
    val confidence: EventEvidenceConfidence,
    val qualityFlags: Set<EventQualityFlag>,
    val primaryMeasurements: List<EventPrimaryMeasurement>,
    val ruleEvidence: Set<EventRuleEvidence>,
    val sourceSummary: EventWindowGroupSummary,
) {
    init {
        require(eventId.startsWith("evt_v${EVENT_MERGE_VERSION}_"))
        require(taxonomyVersion == sourceSummary.taxonomyVersion)
        require(mergeVersion == sourceSummary.mergeVersion)
        require(tripId == sourceSummary.tripId)
        require(eventType == sourceSummary.eventType)
        require(startTripElapsedNanos == sourceSummary.startTripElapsedNanos)
        require(peakTripElapsedNanos == sourceSummary.peakTripElapsedNanos)
        require(endTripElapsedNanos == sourceSummary.endTripElapsedNanos)
        require(severity == sourceSummary.peakWindow.severity)
        require(confidence == sourceSummary.confidence)
        require(qualityFlags == sourceSummary.qualityFlags)
        require(primaryMeasurements == sourceSummary.peakWindow.primaryMeasurements)
        require(ruleEvidence == sourceSummary.ruleEvidence)
    }
}

sealed interface EventMergeDecision {
    val sourceSummary: EventWindowGroupSummary

    data class Accepted(
        val event: MergedDrivingEvent,
    ) : EventMergeDecision {
        override val sourceSummary: EventWindowGroupSummary
            get() = event.sourceSummary
    }

    data class Debounced(
        override val sourceSummary: EventWindowGroupSummary,
        val reason: EventDebounceReason,
        val minimumRequiredWindowCount: Int,
    ) : EventMergeDecision {
        init {
            require(minimumRequiredWindowCount > sourceSummary.sourceWindowCount)
        }
    }
}
