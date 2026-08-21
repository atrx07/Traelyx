package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.ConfidenceTelemetryFramePair
import io.github.atrx07.traelyx.telemetry.DerivedTelemetryFrame
import io.github.atrx07.traelyx.telemetry.DerivedVectorValue
import io.github.atrx07.traelyx.telemetry.DeviceMovementTelemetryConfidence
import io.github.atrx07.traelyx.telemetry.MovementState
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceAssessment
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceComponentKind
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceFrame
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceReason
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceState
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceTimeline
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import io.github.atrx07.traelyx.telemetry.TelemetryEligibilityAssessment
import io.github.atrx07.traelyx.telemetry.TelemetryMetric
import io.github.atrx07.traelyx.telemetry.VehicleMountAlignmentUnavailableReason
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class EventEvidenceTimeline internal constructor(
    val sourceTimeline: TelemetryConfidenceTimeline,
    val config: EventTaxonomyConfig,
) {
    /** Returns a fresh bounded-memory M4.1 classifier on each call. */
    fun windows(): Sequence<EventEvidenceWindow> = sequence {
        val analysisIntervalNanos =
            sourceTimeline.sourceTimeline.sourceTimeline.config.intervalNanos
        val classifier = EventTaxonomyFrameClassifier(config, analysisIntervalNanos)
        sourceTimeline.synchronizedFrames().forEach { frame ->
            yieldAll(classifier.classify(frame))
        }
    }
}

object EventTaxonomyPipeline {
    fun build(
        sourceTimeline: TelemetryConfidenceTimeline,
        config: EventTaxonomyConfig = EventTaxonomyConfig(),
    ): EventEvidenceTimeline =
        EventEvidenceTimeline(
            sourceTimeline = sourceTimeline,
            config = config,
        )
}

private class EventTaxonomyFrameClassifier(
    private val config: EventTaxonomyConfig,
    private val analysisIntervalNanos: Long,
) {
    init {
        require(analysisIntervalNanos > 0L)
    }

    fun classify(pair: ConfidenceTelemetryFramePair): List<EventEvidenceWindow> = buildList {
        val derived = pair.derived
        val confidence = pair.confidence
        phoneMovement(derived, confidence)?.let(::add)

        if (!hasMovingEvidence(derived, confidence)) return@buildList

        val acceleration =
            (derived.vehicleAccelerationMetresPerSecondSquared as? DerivedVectorValue.Available)
        val jerk = (derived.vehicleJerkMetresPerSecondCubed as? DerivedVectorValue.Available)
        val accelerationEligibility = confidence.eligibility.vehicleAcceleration
        val jerkEligibility = confidence.eligibility.vehicleJerk
        val movementEligibility = confidence.eligibility.movementState

        if (acceleration != null && accelerationEligibility.isUsable()) {
            val vector = acceleration.value
            if (vector.x >= config.strongAccelerationMetresPerSecondSquared) {
                add(
                    measuredEvent(
                        type = DrivingEventType.STRONG_ACCELERATION,
                        derived = derived,
                        confidence = confidence,
                        measurements = listOf(acceleration.measurement(EventMeasurementKind.LONGITUDINAL_ACCELERATION, vector.x)),
                        primaryMagnitude = vector.x,
                        activationThreshold = config.strongAccelerationMetresPerSecondSquared,
                        eligibility = listOf(accelerationEligibility, movementEligibility),
                        rules =
                            setOf(
                                EventRuleEvidence.MOVEMENT_CONFIRMED,
                                EventRuleEvidence.LONGITUDINAL_ACCELERATION_THRESHOLD,
                            ),
                    ),
                )
            }
            if (vector.x <= -config.strongBrakingMetresPerSecondSquared) {
                add(
                    measuredEvent(
                        type = DrivingEventType.STRONG_BRAKING,
                        derived = derived,
                        confidence = confidence,
                        measurements = listOf(acceleration.measurement(EventMeasurementKind.LONGITUDINAL_ACCELERATION, vector.x)),
                        primaryMagnitude = abs(vector.x),
                        activationThreshold = config.strongBrakingMetresPerSecondSquared,
                        eligibility = listOf(accelerationEligibility, movementEligibility),
                        rules =
                            setOf(
                                EventRuleEvidence.MOVEMENT_CONFIRMED,
                                EventRuleEvidence.LONGITUDINAL_BRAKING_THRESHOLD,
                            ),
                    ),
                )
            }
            if (vector.y >= config.highLateralLoadMetresPerSecondSquared) {
                add(
                    measuredEvent(
                        type = DrivingEventType.HIGH_LATERAL_LOAD_LEFT,
                        derived = derived,
                        confidence = confidence,
                        measurements = listOf(acceleration.measurement(EventMeasurementKind.LATERAL_ACCELERATION, vector.y)),
                        primaryMagnitude = vector.y,
                        activationThreshold = config.highLateralLoadMetresPerSecondSquared,
                        eligibility = listOf(accelerationEligibility, movementEligibility),
                        rules =
                            setOf(
                                EventRuleEvidence.MOVEMENT_CONFIRMED,
                                EventRuleEvidence.LATERAL_LEFT_LOAD_THRESHOLD,
                            ),
                    ),
                )
            }
            if (vector.y <= -config.highLateralLoadMetresPerSecondSquared) {
                add(
                    measuredEvent(
                        type = DrivingEventType.HIGH_LATERAL_LOAD_RIGHT,
                        derived = derived,
                        confidence = confidence,
                        measurements = listOf(acceleration.measurement(EventMeasurementKind.LATERAL_ACCELERATION, vector.y)),
                        primaryMagnitude = abs(vector.y),
                        activationThreshold = config.highLateralLoadMetresPerSecondSquared,
                        eligibility = listOf(accelerationEligibility, movementEligibility),
                        rules =
                            setOf(
                                EventRuleEvidence.MOVEMENT_CONFIRMED,
                                EventRuleEvidence.LATERAL_RIGHT_LOAD_THRESHOLD,
                            ),
                    ),
                )
            }
        }

        if (
            acceleration != null &&
            jerk != null &&
            accelerationEligibility.isUsable() &&
            jerkEligibility.isUsable()
        ) {
            classifyTransitions(
                derived = derived,
                confidence = confidence,
                acceleration = acceleration,
                jerk = jerk,
                eligibility = listOf(accelerationEligibility, jerkEligibility, movementEligibility),
            ).forEach(::add)
            roadImpact(
                derived = derived,
                confidence = confidence,
                acceleration = acceleration,
                jerk = jerk,
                eligibility = listOf(accelerationEligibility, jerkEligibility, movementEligibility),
            )?.let(::add)
        }
    }

    private fun classifyTransitions(
        derived: DerivedTelemetryFrame,
        confidence: TelemetryConfidenceFrame,
        acceleration: DerivedVectorValue.Available,
        jerk: DerivedVectorValue.Available,
        eligibility: List<TelemetryEligibilityAssessment>,
    ): List<EventEvidenceWindow> = buildList {
        val accelerationVector = acceleration.value
        val jerkVector = jerk.value
        val longitudinalMeasurements =
            listOf(
                jerk.measurement(EventMeasurementKind.LONGITUDINAL_JERK, jerkVector.x),
                acceleration.measurement(
                    EventMeasurementKind.LONGITUDINAL_ACCELERATION,
                    accelerationVector.x,
                ),
            )
        if (
            jerkVector.x >= config.abruptLongitudinalJerkMetresPerSecondCubed &&
            accelerationVector.x >=
            config.abruptLongitudinalMinimumAccelerationMetresPerSecondSquared
        ) {
            add(
                measuredEvent(
                    type = DrivingEventType.ABRUPT_ACCELERATION_TRANSITION,
                    derived = derived,
                    confidence = confidence,
                    measurements = longitudinalMeasurements,
                    primaryMagnitude = jerkVector.x,
                    activationThreshold = config.abruptLongitudinalJerkMetresPerSecondCubed,
                    eligibility = eligibility,
                    rules =
                        setOf(
                            EventRuleEvidence.MOVEMENT_CONFIRMED,
                            EventRuleEvidence.LONGITUDINAL_POSITIVE_JERK_THRESHOLD,
                            EventRuleEvidence.LONGITUDINAL_ACCELERATION_THRESHOLD,
                        ),
                ),
            )
        }
        if (
            jerkVector.x <= -config.abruptLongitudinalJerkMetresPerSecondCubed &&
            accelerationVector.x <=
            -config.abruptLongitudinalMinimumAccelerationMetresPerSecondSquared
        ) {
            add(
                measuredEvent(
                    type = DrivingEventType.ABRUPT_BRAKING_TRANSITION,
                    derived = derived,
                    confidence = confidence,
                    measurements = longitudinalMeasurements,
                    primaryMagnitude = abs(jerkVector.x),
                    activationThreshold = config.abruptLongitudinalJerkMetresPerSecondCubed,
                    eligibility = eligibility,
                    rules =
                        setOf(
                            EventRuleEvidence.MOVEMENT_CONFIRMED,
                            EventRuleEvidence.LONGITUDINAL_NEGATIVE_JERK_THRESHOLD,
                            EventRuleEvidence.LONGITUDINAL_BRAKING_THRESHOLD,
                        ),
                ),
            )
        }

        val lateralLoad = accelerationVector.y
        val lateralJerk = jerkVector.y
        if (
            abs(lateralJerk) >= config.abruptLateralJerkMetresPerSecondCubed &&
            abs(lateralLoad) >=
            config.abruptCornerMinimumLateralLoadMetresPerSecondSquared
        ) {
            val increasing = lateralLoad * lateralJerk > 0.0
            add(
                measuredEvent(
                    type =
                        if (increasing) {
                            DrivingEventType.ABRUPT_CORNER_ENTRY
                        } else {
                            DrivingEventType.ABRUPT_CORNER_EXIT
                        },
                    derived = derived,
                    confidence = confidence,
                    measurements =
                        listOf(
                            jerk.measurement(EventMeasurementKind.LATERAL_JERK, lateralJerk),
                            acceleration.measurement(
                                EventMeasurementKind.LATERAL_ACCELERATION,
                                lateralLoad,
                            ),
                        ),
                    primaryMagnitude = abs(lateralJerk),
                    activationThreshold = config.abruptLateralJerkMetresPerSecondCubed,
                    eligibility = eligibility,
                    rules =
                        setOf(
                            EventRuleEvidence.MOVEMENT_CONFIRMED,
                            EventRuleEvidence.LATERAL_JERK_THRESHOLD,
                            if (increasing) {
                                EventRuleEvidence.LATERAL_LOAD_INCREASING
                            } else {
                                EventRuleEvidence.LATERAL_LOAD_DECREASING
                            },
                        ),
                ),
            )
        }
    }

    private fun roadImpact(
        derived: DerivedTelemetryFrame,
        confidence: TelemetryConfidenceFrame,
        acceleration: DerivedVectorValue.Available,
        jerk: DerivedVectorValue.Available,
        eligibility: List<TelemetryEligibilityAssessment>,
    ): EventEvidenceWindow? {
        val verticalAcceleration = acceleration.value.z
        val verticalJerk = jerk.value.z
        if (
            abs(verticalAcceleration) <
            config.roadImpactVerticalAccelerationMetresPerSecondSquared ||
            abs(verticalJerk) < config.roadImpactVerticalJerkMetresPerSecondCubed
        ) {
            return null
        }
        return measuredEvent(
            type = DrivingEventType.ROAD_IMPACT_OR_BUMP,
            derived = derived,
            confidence = confidence,
            measurements =
                listOf(
                    acceleration.measurement(
                        EventMeasurementKind.VERTICAL_ACCELERATION,
                        verticalAcceleration,
                    ),
                    jerk.measurement(EventMeasurementKind.VERTICAL_JERK, verticalJerk),
                ),
            primaryMagnitude = abs(verticalAcceleration),
            activationThreshold = config.roadImpactVerticalAccelerationMetresPerSecondSquared,
            eligibility = eligibility,
            rules =
                setOf(
                    EventRuleEvidence.MOVEMENT_CONFIRMED,
                    EventRuleEvidence.VERTICAL_ACCELERATION_THRESHOLD,
                    EventRuleEvidence.VERTICAL_JERK_THRESHOLD,
                ),
        )
    }

    private fun phoneMovement(
        derived: DerivedTelemetryFrame,
        confidence: TelemetryConfidenceFrame,
    ): EventEvidenceWindow? {
        val movement = confidence.components.deviceMovement
        if (!movement.isExplicitPhoneMovement()) return null
        val target = derived.tripElapsedNanos
        return EventEvidenceWindow(
            eventType = DrivingEventType.PHONE_MOVED,
            windowStartTripElapsedNanos = (target - analysisIntervalNanos).coerceAtLeast(0L),
            peakTripElapsedNanos = target,
            windowEndTripElapsedNanos = target,
            severity = EventSeverityEvidence.UnavailableForPhoneMovement,
            confidence = EventEvidenceConfidence.SUPPORTED,
            qualityFlags = setOf(EventQualityFlag.PHONE_ORIENTATION_INVALIDATED),
            primaryMeasurements = emptyList(),
            ruleEvidence = setOf(EventRuleEvidence.EXPLICIT_DEVICE_MOVEMENT_INVALIDATION),
            sourceEvidence =
                EventSourceEvidence(
                    derivedVersion = derived.derivedVersion,
                    confidenceVersion = confidence.confidenceVersion,
                    metricEligibility = emptyMap(),
                    componentConfidence =
                        mapOf(
                            TelemetryConfidenceComponentKind.DEVICE_MOVEMENT to
                                movement.assessment,
                            TelemetryConfidenceComponentKind.ORIENTATION to
                                confidence.components.orientation.assessment,
                        ),
                ),
            configSnapshot = config,
        )
    }

    private fun measuredEvent(
        type: DrivingEventType,
        derived: DerivedTelemetryFrame,
        confidence: TelemetryConfidenceFrame,
        measurements: List<EventPrimaryMeasurement>,
        primaryMagnitude: Double,
        activationThreshold: Double,
        eligibility: List<TelemetryEligibilityAssessment>,
        rules: Set<EventRuleEvidence>,
    ): EventEvidenceWindow {
        val eligibilityMap = eligibility.associateBy { it.metric }
        require(eligibilityMap.values.none { it.eligibility == TelemetryEligibility.EXCLUDED })
        val limited = eligibilityMap.values.any { it.eligibility == TelemetryEligibility.LIMITED }
        val target = derived.tripElapsedNanos
        val start =
            min(
                target,
                measurements.minOf { it.sourceProvenance.sourceStartTripElapsedNanos },
            )
        val end =
            max(
                target,
                measurements.maxOf { it.sourceProvenance.sourceEndTripElapsedNanos },
            )
        val requiredComponents =
            eligibilityMap.values.flatMapTo(mutableSetOf()) { it.requiredComponents }
        return EventEvidenceWindow(
            eventType = type,
            windowStartTripElapsedNanos = start,
            peakTripElapsedNanos = target,
            windowEndTripElapsedNanos = end,
            severity =
                EventSeverityEvidence.Measured(
                    physicalMagnitude = primaryMagnitude,
                    activationThreshold = activationThreshold,
                ),
            confidence =
                if (limited) {
                    EventEvidenceConfidence.LIMITED
                } else {
                    EventEvidenceConfidence.SUPPORTED
                },
            qualityFlags =
                if (limited) {
                    setOf(EventQualityFlag.LIMITED_SOURCE_EVIDENCE)
                } else {
                    emptySet()
                },
            primaryMeasurements = measurements,
            ruleEvidence = rules,
            sourceEvidence =
                EventSourceEvidence(
                    derivedVersion = derived.derivedVersion,
                    confidenceVersion = confidence.confidenceVersion,
                    metricEligibility = eligibilityMap,
                    componentConfidence =
                        requiredComponents.associateWith { confidence.assessment(it) },
                ),
            configSnapshot = config,
        )
    }

    private fun hasMovingEvidence(
        derived: DerivedTelemetryFrame,
        confidence: TelemetryConfidenceFrame,
    ): Boolean =
        derived.movementState.state == MovementState.MOVING &&
            confidence.eligibility.movementState.isUsable()
}

private fun DerivedVectorValue.Available.measurement(
    kind: EventMeasurementKind,
    value: Double,
): EventPrimaryMeasurement =
    EventPrimaryMeasurement(
        kind = kind,
        unit =
            when (kind) {
                EventMeasurementKind.LONGITUDINAL_ACCELERATION,
                EventMeasurementKind.LATERAL_ACCELERATION,
                EventMeasurementKind.VERTICAL_ACCELERATION,
                -> EventMeasurementUnit.METRES_PER_SECOND_SQUARED

                EventMeasurementKind.LONGITUDINAL_JERK,
                EventMeasurementKind.LATERAL_JERK,
                EventMeasurementKind.VERTICAL_JERK,
                -> EventMeasurementUnit.METRES_PER_SECOND_CUBED
            },
        signedValue = value,
        sourceProvenance = provenance,
    )

private fun TelemetryEligibilityAssessment.isUsable(): Boolean =
    eligibility != TelemetryEligibility.EXCLUDED

private fun DeviceMovementTelemetryConfidence.isExplicitPhoneMovement(): Boolean =
    assessment.state == TelemetryConfidenceState.INVALIDATED &&
        TelemetryConfidenceReason.DEVICE_MOVEMENT_INVALIDATED in assessment.reasons &&
        mountUnavailableReason == VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED

private fun TelemetryConfidenceFrame.assessment(
    component: TelemetryConfidenceComponentKind,
): TelemetryConfidenceAssessment =
    when (component) {
        TelemetryConfidenceComponentKind.GNSS -> components.gnss.assessment
        TelemetryConfidenceComponentKind.ACCELEROMETER -> components.accelerometer.assessment
        TelemetryConfidenceComponentKind.GYROSCOPE -> components.gyroscope.assessment
        TelemetryConfidenceComponentKind.CALIBRATION -> components.calibration.assessment
        TelemetryConfidenceComponentKind.ORIENTATION -> components.orientation.assessment
        TelemetryConfidenceComponentKind.SOURCE_AGREEMENT -> components.sourceAgreement.assessment
        TelemetryConfidenceComponentKind.DEVICE_MOVEMENT -> components.deviceMovement.assessment
        TelemetryConfidenceComponentKind.CLOCK_INTEGRITY -> components.clockIntegrity.assessment
    }
