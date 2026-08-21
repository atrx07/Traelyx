package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.DerivedChannelMissingReason
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceComponentKind
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceReason
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceState
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import io.github.atrx07.traelyx.telemetry.TelemetryEligibilityReason
import io.github.atrx07.traelyx.telemetry.TelemetryMetric
import java.security.MessageDigest

class MergedEventTimeline internal constructor(
    val sourceTimeline: EventEvidenceTimeline,
    val config: EventMergeConfig,
) {
    /**
     * Returns fresh, deterministic decisions in group-finalization order. Debounced groups remain
     * present here for audit and tuning; [events] exposes accepted maneuver-level records only.
     */
    fun decisions(): Sequence<EventMergeDecision> =
        mergeEventWindows(
            tripId =
                sourceTimeline.sourceTimeline.sourceTimeline.sourceTimeline.trip.tripId,
            windows = sourceTimeline.windows(),
            config = config,
        )

    fun events(): Sequence<MergedDrivingEvent> =
        decisions().mapNotNull { decision ->
            (decision as? EventMergeDecision.Accepted)?.event
        }
}

object EventMergePipeline {
    fun build(
        sourceTimeline: EventEvidenceTimeline,
        config: EventMergeConfig = EventMergeConfig(),
    ): MergedEventTimeline =
        MergedEventTimeline(
            sourceTimeline = sourceTimeline,
            config = config,
        )
}

internal fun mergeEventWindows(
    tripId: String,
    windows: Sequence<EventEvidenceWindow>,
    config: EventMergeConfig = EventMergeConfig(),
): Sequence<EventMergeDecision> = sequence {
    require(tripId.isNotBlank())
    val active = mutableMapOf<DrivingEventType, EventWindowAccumulator>()
    var previousPeakTripElapsedNanos: Long? = null

    windows.forEach { window ->
        val previousPeak = previousPeakTripElapsedNanos
        require(previousPeak == null || window.peakTripElapsedNanos >= previousPeak) {
            "M4.1 evidence windows must be ordered by peakTripElapsedNanos"
        }
        previousPeakTripElapsedNanos = window.peakTripElapsedNanos

        val expired =
            active.values
                .filter {
                    window.peakTripElapsedNanos - it.lastPeakTripElapsedNanos >
                        config.maximumMergeGapNanos
                }
                .sortedWith(
                    compareBy<EventWindowAccumulator> { it.lastPeakTripElapsedNanos }
                        .thenBy { it.eventType.ordinal },
                )
        expired.forEach { accumulator ->
            active.remove(accumulator.eventType)
            yield(accumulator.toDecision())
        }

        val accumulator = active[window.eventType]
        if (accumulator == null) {
            active[window.eventType] =
                EventWindowAccumulator(
                    tripId = tripId,
                    firstWindow = window,
                    config = config,
                )
        } else {
            accumulator.add(window)
        }
    }

    active.values
        .sortedWith(
            compareBy<EventWindowAccumulator> { it.lastPeakTripElapsedNanos }
                .thenBy { it.eventType.ordinal },
        ).forEach { yield(it.toDecision()) }
}

private class EventWindowAccumulator(
    private val tripId: String,
    firstWindow: EventEvidenceWindow,
    private val config: EventMergeConfig,
) {
    val eventType: DrivingEventType = firstWindow.eventType
    val mergePolicy: EventMergePolicy = eventType.mergePolicy()
    var lastPeakTripElapsedNanos: Long = firstWindow.peakTripElapsedNanos
        private set

    private val taxonomyVersion = firstWindow.taxonomyVersion
    private val taxonomyConfig = firstWindow.configSnapshot
    private var startTripElapsedNanos = firstWindow.windowStartTripElapsedNanos
    private var endTripElapsedNanos = firstWindow.windowEndTripElapsedNanos
    private var peakWindow = firstWindow
    private var sourceWindowCount = 0
    private var supportedWindowCount = 0
    private var limitedWindowCount = 0
    private val qualityFlags = linkedSetOf<EventQualityFlag>()
    private val ruleEvidence = linkedSetOf<EventRuleEvidence>()
    private val metricEvidence = mutableMapOf<TelemetryMetric, MutableMetricEvidence>()
    private val componentEvidence =
        mutableMapOf<TelemetryConfidenceComponentKind, MutableComponentEvidence>()

    init {
        add(firstWindow)
    }

    fun add(window: EventEvidenceWindow) {
        require(window.eventType == eventType)
        require(window.taxonomyVersion == taxonomyVersion)
        require(window.configSnapshot == taxonomyConfig)
        require(window.peakTripElapsedNanos >= lastPeakTripElapsedNanos)
        require(
            sourceWindowCount == 0 ||
                window.peakTripElapsedNanos - lastPeakTripElapsedNanos <=
                config.maximumMergeGapNanos,
        )

        startTripElapsedNanos =
            minOf(startTripElapsedNanos, window.windowStartTripElapsedNanos)
        endTripElapsedNanos = maxOf(endTripElapsedNanos, window.windowEndTripElapsedNanos)
        lastPeakTripElapsedNanos = window.peakTripElapsedNanos
        sourceWindowCount += 1
        when (window.confidence) {
            EventEvidenceConfidence.SUPPORTED -> supportedWindowCount += 1
            EventEvidenceConfidence.LIMITED -> limitedWindowCount += 1
        }
        qualityFlags += window.qualityFlags
        ruleEvidence += window.ruleEvidence
        if (window.hasStrongerPeakThan(peakWindow)) peakWindow = window

        window.sourceEvidence.metricEligibility.forEach { (metric, assessment) ->
            val merged = metricEvidence.getOrPut(metric) { MutableMetricEvidence() }
            merged.observedEligibility += assessment.eligibility
            merged.reasons += assessment.reasons
            merged.requiredComponents += assessment.requiredComponents
            merged.limitingComponents += assessment.limitingComponents
            assessment.sourceMissingReason?.let(merged.sourceMissingReasons::add)
        }
        window.sourceEvidence.componentConfidence.forEach { (component, assessment) ->
            val merged = componentEvidence.getOrPut(component) { MutableComponentEvidence() }
            merged.observedStates += assessment.state
            merged.reasons += assessment.reasons
        }
    }

    fun toDecision(): EventMergeDecision {
        val summary = toSummary()
        val minimumRequiredWindowCount =
            when (mergePolicy) {
                EventMergePolicy.SUSTAINED -> config.minimumSustainedWindowCount
                EventMergePolicy.TRANSIENT -> 1
            }
        if (sourceWindowCount < minimumRequiredWindowCount) {
            return EventMergeDecision.Debounced(
                sourceSummary = summary,
                reason = EventDebounceReason.INSUFFICIENT_SOURCE_WINDOWS,
                minimumRequiredWindowCount = minimumRequiredWindowCount,
            )
        }
        return EventMergeDecision.Accepted(summary.toEvent())
    }

    private fun toSummary(): EventWindowGroupSummary {
        val confidence =
            if (limitedWindowCount > 0) {
                EventEvidenceConfidence.LIMITED
            } else {
                EventEvidenceConfidence.SUPPORTED
            }
        return EventWindowGroupSummary(
            taxonomyVersion = taxonomyVersion,
            mergeVersion = config.mergeVersion,
            tripId = tripId,
            eventType = eventType,
            mergePolicy = mergePolicy,
            startTripElapsedNanos = startTripElapsedNanos,
            peakTripElapsedNanos = peakWindow.peakTripElapsedNanos,
            endTripElapsedNanos = endTripElapsedNanos,
            sourceWindowCount = sourceWindowCount,
            supportedWindowCount = supportedWindowCount,
            limitedWindowCount = limitedWindowCount,
            peakWindow = peakWindow,
            confidence = confidence,
            qualityFlags = qualityFlags.toSet(),
            ruleEvidence = ruleEvidence.toSet(),
            metricEvidence =
                metricEvidence.mapValues { (metric, evidence) -> evidence.freeze(metric) },
            componentEvidence =
                componentEvidence.mapValues { (component, evidence) ->
                    evidence.freeze(component)
                },
            taxonomyConfigSnapshot = taxonomyConfig,
            mergeConfigSnapshot = config,
        )
    }
}

private class MutableMetricEvidence {
    val observedEligibility = linkedSetOf<TelemetryEligibility>()
    val reasons = linkedSetOf<TelemetryEligibilityReason>()
    val requiredComponents = linkedSetOf<TelemetryConfidenceComponentKind>()
    val limitingComponents = linkedSetOf<TelemetryConfidenceComponentKind>()
    val sourceMissingReasons = linkedSetOf<DerivedChannelMissingReason>()

    fun freeze(metric: TelemetryMetric): MergedMetricEvidence =
        MergedMetricEvidence(
            metric = metric,
            observedEligibility = observedEligibility.toSet(),
            reasons = reasons.toSet(),
            requiredComponents = requiredComponents.toSet(),
            limitingComponents = limitingComponents.toSet(),
            sourceMissingReasons = sourceMissingReasons.toSet(),
        )
}

private class MutableComponentEvidence {
    val observedStates = linkedSetOf<TelemetryConfidenceState>()
    val reasons = linkedSetOf<TelemetryConfidenceReason>()

    fun freeze(component: TelemetryConfidenceComponentKind): MergedComponentEvidence =
        MergedComponentEvidence(
            component = component,
            observedStates = observedStates.toSet(),
            reasons = reasons.toSet(),
        )
}

private fun DrivingEventType.mergePolicy(): EventMergePolicy =
    when (this) {
        DrivingEventType.STRONG_ACCELERATION,
        DrivingEventType.STRONG_BRAKING,
        DrivingEventType.HIGH_LATERAL_LOAD_LEFT,
        DrivingEventType.HIGH_LATERAL_LOAD_RIGHT,
        -> EventMergePolicy.SUSTAINED

        DrivingEventType.ABRUPT_ACCELERATION_TRANSITION,
        DrivingEventType.ABRUPT_BRAKING_TRANSITION,
        DrivingEventType.ABRUPT_CORNER_ENTRY,
        DrivingEventType.ABRUPT_CORNER_EXIT,
        DrivingEventType.ROAD_IMPACT_OR_BUMP,
        DrivingEventType.PHONE_MOVED,
        -> EventMergePolicy.TRANSIENT
    }

private fun EventEvidenceWindow.hasStrongerPeakThan(other: EventEvidenceWindow): Boolean {
    val candidate = severity as? EventSeverityEvidence.Measured ?: return false
    val current = other.severity as? EventSeverityEvidence.Measured ?: return false
    return candidate.activationRatio > current.activationRatio
}

private fun EventWindowGroupSummary.toEvent(): MergedDrivingEvent =
    MergedDrivingEvent(
        eventId = deterministicEventId(),
        taxonomyVersion = taxonomyVersion,
        mergeVersion = mergeVersion,
        tripId = tripId,
        eventType = eventType,
        startTripElapsedNanos = startTripElapsedNanos,
        peakTripElapsedNanos = peakTripElapsedNanos,
        endTripElapsedNanos = endTripElapsedNanos,
        severity = peakWindow.severity,
        confidence = confidence,
        qualityFlags = qualityFlags,
        primaryMeasurements = peakWindow.primaryMeasurements,
        ruleEvidence = ruleEvidence,
        sourceSummary = this,
    )

private fun EventWindowGroupSummary.deterministicEventId(): String {
    val fields =
        listOf(
            tripId,
            taxonomyVersion.toString(),
            mergeVersion.toString(),
            eventType.machineId,
            startTripElapsedNanos.toString(),
            peakTripElapsedNanos.toString(),
            endTripElapsedNanos.toString(),
        )
    val canonical = fields.joinToString(separator = "") { field -> "${field.length}:$field" }
    val digest = MessageDigest.getInstance("SHA-256").digest(canonical.toByteArray(Charsets.UTF_8))
    return "evt_v${mergeVersion}_${digest.joinToString("") { byte -> "%02x".format(byte) }}"
}
