package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.TelemetryMetric
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EventMergePipelineTest {
    @Test
    fun `merge policy defaults are stable validated and versioned`() {
        val config = EventMergeConfig()
        assertEquals(1, config.mergeVersion)
        assertEquals(250_000_000L, config.maximumMergeGapNanos)
        assertEquals(3, config.minimumSustainedWindowCount)
        assertTrue(runCatching { EventMergeConfig(mergeVersion = 2) }.isFailure)
        assertTrue(runCatching { EventMergeConfig(maximumMergeGapNanos = -1L) }.isFailure)
        assertTrue(runCatching { EventMergeConfig(minimumSustainedWindowCount = 0) }.isFailure)
    }

    @Test
    fun `governed corpus collapses repeated evidence without false baseline events`() {
        assertTrue(events(TelemetryRegressionScenario.STATIONARY).isEmpty())
        assertTrue(events(TelemetryRegressionScenario.SMOOTH_STRAIGHT).isEmpty())
        assertTrue(events(TelemetryRegressionScenario.GNSS_LOSS).isEmpty())
        assertTrue(events(TelemetryRegressionScenario.MOTORCYCLE_VIBRATION).isEmpty())

        assertSingleEvent(
            TelemetryRegressionScenario.SMOOTH_ACCELERATION,
            DrivingEventType.STRONG_ACCELERATION,
        )
        assertSingleEvent(TelemetryRegressionScenario.BRAKING, DrivingEventType.STRONG_BRAKING)
        assertSingleEvent(
            TelemetryRegressionScenario.LEFT_CORNER,
            DrivingEventType.HIGH_LATERAL_LOAD_LEFT,
        )
        assertSingleEvent(
            TelemetryRegressionScenario.RIGHT_CORNER,
            DrivingEventType.HIGH_LATERAL_LOAD_RIGHT,
        )
        assertSingleEvent(
            TelemetryRegressionScenario.POTHOLE,
            DrivingEventType.ROAD_IMPACT_OR_BUMP,
        )
        assertSingleEvent(TelemetryRegressionScenario.PHONE_MOVE, DrivingEventType.PHONE_MOVED)
    }

    @Test
    fun `sustained windows merge to one repeatable event retaining strongest peak and evidence`() {
        val fixture =
            TelemetryRegressionFixtureCorpus.generate(
                TelemetryRegressionScenario.SMOOTH_ACCELERATION,
            )
        val evidenceTimeline = EventTaxonomyPipeline.build(confidenceTimelineFor(fixture))
        val sourceWindows =
            evidenceTimeline.windows().filter {
                it.eventType == DrivingEventType.STRONG_ACCELERATION
            }.toList()
        val mergedTimeline = EventMergePipeline.build(evidenceTimeline)
        val first =
            mergedTimeline.events().single {
                it.eventType == DrivingEventType.STRONG_ACCELERATION
            }
        val second =
            mergedTimeline.events().single {
                it.eventType == DrivingEventType.STRONG_ACCELERATION
            }

        assertTrue(sourceWindows.size >= DEFAULT_MINIMUM_SUSTAINED_EVENT_WINDOW_COUNT)
        assertEquals(first, second)
        assertTrue(first.eventId.matches(Regex("evt_v1_[0-9a-f]{64}")))
        assertEquals(sourceWindows.size, first.sourceSummary.sourceWindowCount)
        assertEquals(sourceWindows.minOf { it.windowStartTripElapsedNanos }, first.startTripElapsedNanos)
        assertEquals(sourceWindows.maxOf { it.windowEndTripElapsedNanos }, first.endTripElapsedNanos)
        assertEquals(
            sourceWindows.maxOf { (it.severity as EventSeverityEvidence.Measured).activationRatio },
            (first.severity as EventSeverityEvidence.Measured).activationRatio,
            0.0,
        )
        assertTrue(TelemetryMetric.VEHICLE_ACCELERATION in first.sourceSummary.metricEvidence)
        assertTrue(first.sourceSummary.componentEvidence.isNotEmpty())
    }

    @Test
    fun `gap separation and sustained debounce decisions remain explicit`() {
        val source = firstWindow(DrivingEventType.STRONG_ACCELERATION)
        val limitedSource =
            source.at(1_100_000_000L).copy(
                confidence = EventEvidenceConfidence.LIMITED,
                qualityFlags =
                    source.qualityFlags + EventQualityFlag.LIMITED_SOURCE_EVIDENCE,
            )
        val windows =
            sequenceOf(
                source.at(1_000_000_000L),
                limitedSource,
                source.at(2_000_000_000L),
                source.at(2_100_000_000L),
                source.at(2_200_000_000L),
            )
        val decisions = mergeEventWindows("merge-test-trip", windows).toList()

        assertEquals(2, decisions.size)
        val debounced = decisions[0] as EventMergeDecision.Debounced
        assertEquals(EventDebounceReason.INSUFFICIENT_SOURCE_WINDOWS, debounced.reason)
        assertEquals(2, debounced.sourceSummary.sourceWindowCount)
        assertEquals(3, debounced.minimumRequiredWindowCount)
        assertEquals(EventEvidenceConfidence.LIMITED, debounced.sourceSummary.confidence)
        assertTrue(
            EventQualityFlag.LIMITED_SOURCE_EVIDENCE in debounced.sourceSummary.qualityFlags,
        )
        val accepted = decisions[1] as EventMergeDecision.Accepted
        assertEquals(3, accepted.event.sourceSummary.sourceWindowCount)
        assertEquals(2_000_000_000L, accepted.event.peakTripElapsedNanos)
        assertTrue(accepted.event.startTripElapsedNanos > debounced.sourceSummary.endTripElapsedNanos)
    }

    @Test
    fun `transient singleton is accepted while limited evidence propagates conservatively`() {
        val transient = firstWindow(DrivingEventType.ROAD_IMPACT_OR_BUMP).at(1_000_000_000L)
        val transientDecision =
            mergeEventWindows("transient-trip", sequenceOf(transient)).single()
        assertTrue(transientDecision is EventMergeDecision.Accepted)

        val sustained = firstWindow(DrivingEventType.STRONG_BRAKING)
        val limited =
            sustained.at(2_100_000_000L).copy(
                confidence = EventEvidenceConfidence.LIMITED,
                qualityFlags =
                    sustained.qualityFlags + EventQualityFlag.LIMITED_SOURCE_EVIDENCE,
            )
        val event =
            (mergeEventWindows(
                tripId = "limited-trip",
                windows =
                    sequenceOf(
                        sustained.at(2_000_000_000L),
                        limited,
                        sustained.at(2_200_000_000L),
                    ),
            ).single() as EventMergeDecision.Accepted).event
        assertEquals(EventEvidenceConfidence.LIMITED, event.confidence)
        assertEquals(1, event.sourceSummary.limitedWindowCount)
        assertEquals(2, event.sourceSummary.supportedWindowCount)
        assertTrue(EventQualityFlag.LIMITED_SOURCE_EVIDENCE in event.qualityFlags)
    }

    @Test
    fun `out of order M4_1 evidence fails closed`() {
        val source = firstWindow(DrivingEventType.STRONG_ACCELERATION)
        assertTrue(
            runCatching {
                mergeEventWindows(
                    tripId = "out-of-order-trip",
                    windows =
                        sequenceOf(
                            source.at(2_000_000_000L),
                            source.at(1_000_000_000L),
                        ),
                ).toList()
            }.isFailure,
        )
    }

    private fun assertSingleEvent(
        scenario: TelemetryRegressionScenario,
        expected: DrivingEventType,
    ) {
        val matching = events(scenario).filter { it.eventType == expected }
        assertEquals("$scenario should merge to one $expected", 1, matching.size)
    }

    private fun events(scenario: TelemetryRegressionScenario): List<MergedDrivingEvent> =
        events(TelemetryRegressionFixtureCorpus.generate(scenario))

    private fun events(fixture: TelemetryRegressionFixture): List<MergedDrivingEvent> =
        EventMergePipeline.build(
            EventTaxonomyPipeline.build(confidenceTimelineFor(fixture)),
        ).events().toList()

    private fun firstWindow(type: DrivingEventType): EventEvidenceWindow {
        val scenario =
            when (type) {
                DrivingEventType.STRONG_ACCELERATION ->
                    TelemetryRegressionScenario.SMOOTH_ACCELERATION
                DrivingEventType.STRONG_BRAKING -> TelemetryRegressionScenario.BRAKING
                DrivingEventType.ROAD_IMPACT_OR_BUMP -> TelemetryRegressionScenario.POTHOLE
                else -> error("No source fixture registered for $type")
            }
        return EventTaxonomyPipeline.build(
            confidenceTimelineFor(TelemetryRegressionFixtureCorpus.generate(scenario)),
        ).windows().first { it.eventType == type }
    }

    private fun EventEvidenceWindow.at(peakTripElapsedNanos: Long): EventEvidenceWindow =
        copy(
            windowStartTripElapsedNanos = peakTripElapsedNanos - 50_000_000L,
            peakTripElapsedNanos = peakTripElapsedNanos,
            windowEndTripElapsedNanos = peakTripElapsedNanos,
        )
}
