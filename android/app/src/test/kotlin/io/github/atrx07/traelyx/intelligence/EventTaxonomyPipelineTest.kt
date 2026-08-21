package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceTimeline
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import io.github.atrx07.traelyx.telemetry.TelemetryMetric
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EventTaxonomyPipelineTest {
    @Test
    fun `taxonomy machine IDs and default activation gates are stable and versioned`() {
        val config = EventTaxonomyConfig()
        assertEquals(1, config.taxonomyVersion)
        assertEquals(1.5, config.strongAccelerationMetresPerSecondSquared, 0.0)
        assertEquals(2.5, config.strongBrakingMetresPerSecondSquared, 0.0)
        assertEquals(2.0, config.highLateralLoadMetresPerSecondSquared, 0.0)
        assertEquals(3.5, config.abruptLongitudinalJerkMetresPerSecondCubed, 0.0)
        assertEquals(
            0.75,
            config.abruptLongitudinalMinimumAccelerationMetresPerSecondSquared,
            0.0,
        )
        assertEquals(3.5, config.abruptLateralJerkMetresPerSecondCubed, 0.0)
        assertEquals(
            0.75,
            config.abruptCornerMinimumLateralLoadMetresPerSecondSquared,
            0.0,
        )
        assertEquals(1.0, config.roadImpactVerticalAccelerationMetresPerSecondSquared, 0.0)
        assertEquals(5.0, config.roadImpactVerticalJerkMetresPerSecondCubed, 0.0)
        assertEquals(
            setOf(
                "EVT_ACCEL_STRONG",
                "EVT_ACCEL_ABRUPT_TRANSITION",
                "EVT_BRAKE_STRONG",
                "EVT_BRAKE_ABRUPT_TRANSITION",
                "EVT_CORNER_HIGH_LOAD_LEFT",
                "EVT_CORNER_HIGH_LOAD_RIGHT",
                "EVT_CORNER_ABRUPT_ENTRY",
                "EVT_CORNER_ABRUPT_EXIT",
                "EVT_ROAD_IMPACT",
                "EVT_PHONE_MOVED",
            ),
            DrivingEventType.entries.mapTo(mutableSetOf()) { it.machineId },
        )
        assertTrue(runCatching { EventTaxonomyConfig(taxonomyVersion = 2) }.isFailure)
        assertTrue(
            runCatching {
                EventTaxonomyConfig(strongAccelerationMetresPerSecondSquared = 0.0)
            }.isFailure,
        )
    }

    @Test
    fun `governed corpus produces intended events without stationary smooth or vibration claims`() {
        val stationary = windows(TelemetryRegressionScenario.STATIONARY)
        val smooth = windows(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        val gnssLoss = windows(TelemetryRegressionScenario.GNSS_LOSS)
        val vibration = windows(TelemetryRegressionScenario.MOTORCYCLE_VIBRATION)
        assertTrue(stationary.isEmpty())
        assertTrue(smooth.isEmpty())
        assertTrue(gnssLoss.isEmpty())
        assertTrue(vibration.isEmpty())

        assertHas(TelemetryRegressionScenario.SMOOTH_ACCELERATION, DrivingEventType.STRONG_ACCELERATION)
        assertHas(TelemetryRegressionScenario.BRAKING, DrivingEventType.STRONG_BRAKING)
        assertHas(TelemetryRegressionScenario.LEFT_CORNER, DrivingEventType.HIGH_LATERAL_LOAD_LEFT)
        assertHas(TelemetryRegressionScenario.RIGHT_CORNER, DrivingEventType.HIGH_LATERAL_LOAD_RIGHT)
        assertHas(TelemetryRegressionScenario.POTHOLE, DrivingEventType.ROAD_IMPACT_OR_BUMP)
        assertHas(TelemetryRegressionScenario.PHONE_MOVE, DrivingEventType.PHONE_MOVED)
    }

    @Test
    fun `focused moving pulses cover abrupt longitudinal and corner transitions`() {
        val acceleration =
            windows(
                pulse(
                    axis = PulseAxis.DEVICE_Y,
                    firstDelta = 4.0f,
                    secondDelta = 0.0f,
                ),
            )
        assertTrue(acceleration.any { it.eventType == DrivingEventType.ABRUPT_ACCELERATION_TRANSITION })

        val braking =
            windows(
                pulse(
                    axis = PulseAxis.DEVICE_Y,
                    firstDelta = -4.0f,
                    secondDelta = 0.0f,
                ),
            )
        assertTrue(braking.any { it.eventType == DrivingEventType.ABRUPT_BRAKING_TRANSITION })

        val corner =
            windows(
                pulse(
                    axis = PulseAxis.DEVICE_X,
                    firstDelta = -4.0f,
                    secondDelta = 0.0f,
                ),
            )
        assertTrue(corner.any { it.eventType == DrivingEventType.ABRUPT_CORNER_ENTRY })
        assertTrue(corner.any { it.eventType == DrivingEventType.ABRUPT_CORNER_EXIT })
    }

    @Test
    fun `excluded movement evidence cannot become an event claim`() {
        val source = pulse(PulseAxis.DEVICE_Y, firstDelta = 4.0f, secondDelta = 0.0f)
        val withoutActionGnss =
            source.copy(
                records =
                    source.records.filterNot {
                        it is TelemetrySampleRecord.Gnss &&
                            it.tripElapsedNanos >= 5_000_000_000L
                    },
            )
        val emitted = windows(withoutActionGnss)
        assertFalse(
            emitted.any {
                it.peakTripElapsedNanos >= PULSE_START_NANOS &&
                    it.eventType != DrivingEventType.PHONE_MOVED
            },
        )
    }

    @Test
    fun `degraded but usable evidence remains explicitly limited and auditable`() {
        val source = TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.BRAKING)
        val degraded =
            source.copy(
                records =
                    source.records.map { record ->
                        if (
                            record is TelemetrySampleRecord.Imu &&
                            record.sample.sensorType == ImuSensorType.ACCELEROMETER
                        ) {
                            record.copy(
                                sample =
                                    record.sample.copy(
                                        accuracyStatus = 0,
                                        qualityFlags = setOf(ImuQualityFlag.SENSOR_UNRELIABLE),
                                    ),
                            )
                        } else {
                            record
                        }
                    },
            )
        val event = windows(degraded).first { it.eventType == DrivingEventType.STRONG_BRAKING }
        assertEquals(EventEvidenceConfidence.LIMITED, event.confidence)
        assertTrue(EventQualityFlag.LIMITED_SOURCE_EVIDENCE in event.qualityFlags)
        assertEquals(
            TelemetryEligibility.LIMITED,
            event.sourceEvidence.metricEligibility.values
                .first { it.metric == TelemetryMetric.VEHICLE_ACCELERATION }
                .eligibility,
        )
    }

    @Test
    fun `window generation is lazy repeatable ordered and retains physical provenance`() {
        val timeline =
            EventTaxonomyPipeline.build(
                confidenceTimeline(
                    TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.POTHOLE),
                ),
            )
        val first = timeline.windows().toList()
        val second = timeline.windows().toList()
        assertEquals(first, second)
        assertTrue(first.zipWithNext().all { (left, right) -> left.peakTripElapsedNanos <= right.peakTripElapsedNanos })
        val impact = first.first { it.eventType == DrivingEventType.ROAD_IMPACT_OR_BUMP }
        assertTrue(impact.primaryMeasurements.any { it.kind == EventMeasurementKind.VERTICAL_ACCELERATION })
        assertTrue(impact.primaryMeasurements.any { it.kind == EventMeasurementKind.VERTICAL_JERK })
        assertTrue(impact.sourceEvidence.metricEligibility.values.none { it.eligibility == TelemetryEligibility.EXCLUDED })
        assertEquals(EVENT_TAXONOMY_VERSION, impact.taxonomyVersion)
        assertEquals(EVENT_TAXONOMY_VERSION, impact.configSnapshot.taxonomyVersion)
    }

    private fun assertHas(
        scenario: TelemetryRegressionScenario,
        expected: DrivingEventType,
    ) {
        assertTrue(
            "$scenario should emit $expected",
            windows(scenario).any { it.eventType == expected },
        )
    }

    private fun windows(scenario: TelemetryRegressionScenario): List<EventEvidenceWindow> =
        windows(TelemetryRegressionFixtureCorpus.generate(scenario))

    private fun windows(fixture: TelemetryRegressionFixture): List<EventEvidenceWindow> =
        EventTaxonomyPipeline.build(confidenceTimeline(fixture)).windows().toList()

    private fun pulse(
        axis: PulseAxis,
        firstDelta: Float,
        secondDelta: Float,
    ): TelemetryRegressionFixture {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        return source.copy(
            records =
                source.records.map { record ->
                    if (
                        record !is TelemetrySampleRecord.Imu ||
                        record.sample.sensorType != ImuSensorType.ACCELEROMETER
                    ) {
                        return@map record
                    }
                    val delta =
                        when (record.tripElapsedNanos) {
                            in PULSE_START_NANOS until PULSE_MIDDLE_NANOS -> firstDelta
                            in PULSE_MIDDLE_NANOS until PULSE_END_NANOS -> secondDelta
                            else -> 0.0f
                        }
                    record.copy(
                        sample =
                            when (axis) {
                                PulseAxis.DEVICE_X -> record.sample.copy(x = record.sample.x + delta)
                                PulseAxis.DEVICE_Y -> record.sample.copy(y = record.sample.y + delta)
                            },
                    )
                },
        )
    }

    private fun confidenceTimeline(
        fixture: TelemetryRegressionFixture,
    ): TelemetryConfidenceTimeline = confidenceTimelineFor(fixture)

    private enum class PulseAxis {
        DEVICE_X,
        DEVICE_Y,
    }

    private companion object {
        const val PULSE_START_NANOS = 7_000_000_000L
        const val PULSE_MIDDLE_NANOS = 8_000_000_000L
        const val PULSE_END_NANOS = 9_000_000_000L
    }
}
