package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.GnssDecision
import io.github.atrx07.traelyx.telemetry.GnssProcessingEvidence
import io.github.atrx07.traelyx.telemetry.MovementState
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecodeResult
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceReason
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceState
import java.util.EnumMap

object IntegrityPipeline {
    fun audit(
        sourceTimeline: MergedEventTimeline,
        config: IntegrityRulesConfig = IntegrityRulesConfig(),
    ): TripIntegrityAudit = CompleteTripIntegrityAuditor(sourceTimeline, config).audit()

    fun audit(
        invalidRawTrip: RawTelemetryTripDecodeResult.Invalid,
        config: IntegrityRulesConfig = IntegrityRulesConfig(),
    ): TripIntegrityAudit {
        val failure =
            RawTripIntegrityFailure(
                errorCode = invalidRawTrip.errorCode,
                inputIndex = invalidRawTrip.inputIndex,
                sequence = invalidRawTrip.sequence,
            )
        val finding =
            IntegrityFinding(
                integrityVersion = config.integrityVersion,
                eventMachineId = null,
                ruleId = IntegrityRuleId.RAW_TRIP_INVALID,
                kind = IntegrityFindingKind.DATA_CORRUPTION,
                state = TripIntegrityState.UNRANKED,
                dimensions = setOf(IntegrityDimension.SOURCE_INTEGRITY),
                occurrenceCount = 1L,
                firstTripElapsedNanos = null,
                lastTripElapsedNanos = null,
                maximumContinuousDurationNanos = null,
                evidenceReasons = setOf(IntegrityEvidenceReason.RAW_TRIP_DECODER_REJECTED),
                confidenceReasons = emptySet(),
                representativeMergedEventId = null,
                rawTripFailure = failure,
            )
        return buildAudit(
            tripId = null,
            findings = listOf(finding),
            sourceVersions = null,
            config = config,
        )
    }
}

private class CompleteTripIntegrityAuditor(
    private val sourceTimeline: MergedEventTimeline,
    private val config: IntegrityRulesConfig,
) {
    private val evidenceTimeline = sourceTimeline.sourceTimeline
    private val confidenceTimeline = evidenceTimeline.sourceTimeline
    private val derivedTimeline = confidenceTimeline.sourceTimeline
    private val analysisTimeline = derivedTimeline.sourceTimeline
    private val trip = analysisTimeline.trip
    private val findings =
        EnumMap<IntegrityRuleId, IntegrityFindingAccumulator>(IntegrityRuleId::class.java)

    fun audit(): TripIntegrityAudit {
        auditGnss()
        auditRawSensorFlags()
        auditConfidenceFrames()
        auditMergedEvents()
        val frozen =
            IntegrityRuleId.entries.mapNotNull { ruleId ->
                findings[ruleId]?.freeze(config)
            }
        return buildAudit(
            tripId = trip.tripId,
            findings = frozen,
            sourceVersions =
                IntegritySourceVersions(
                    rawDecoderVersion = trip.decoderVersion,
                    chunkEncodingVersion = trip.chunkEncodingVersion,
                    telemetrySchemaVersion = trip.telemetrySchemaVersion,
                    gnssProcessingVersion = derivedTimeline.gnssSummary.processingVersion,
                    derivedVersion = derivedTimeline.config.derivedVersion,
                    confidenceVersion = confidenceTimeline.config.confidenceVersion,
                    taxonomyVersion = evidenceTimeline.config.taxonomyVersion,
                    mergeVersion = sourceTimeline.config.mergeVersion,
                ),
            config = config,
        )
    }

    private fun auditGnss() {
        derivedTimeline.gnssSummary.samples.forEach { sample ->
            val time = requireNotNull(sample.rawSample.tripElapsedNanos)
            if (
                sample.rawSample.isMockSignal ||
                GnssProcessingEvidence.RAW_MOCK_LOCATION_SIGNAL in sample.evidence
            ) {
                observe(
                    ruleId = IntegrityRuleId.PLATFORM_MOCK_LOCATION_SIGNAL,
                    startTripElapsedNanos = time,
                    endTripElapsedNanos = time,
                    evidenceReasons =
                        buildSet {
                            if (sample.rawSample.isMockSignal) {
                                add(IntegrityEvidenceReason.PLATFORM_MOCK_LOCATION_FLAG)
                            }
                            if (GnssProcessingEvidence.RAW_MOCK_LOCATION_SIGNAL in sample.evidence) {
                                add(IntegrityEvidenceReason.GNSS_PROCESSING_MOCK_SIGNAL)
                            }
                        },
                )
            }
            if (sample.decision == GnssDecision.EXCLUDED_IMPOSSIBLE_JUMP) {
                observe(
                    ruleId = IntegrityRuleId.IMPOSSIBLE_GNSS_JUMP,
                    startTripElapsedNanos = sample.previousAnchorElapsedNanos ?: time,
                    endTripElapsedNanos = time,
                    evidenceReasons = setOf(IntegrityEvidenceReason.GNSS_IMPOSSIBLE_JUMP_DECISION),
                )
            }
            if (GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE in sample.evidence) {
                observe(
                    ruleId = IntegrityRuleId.IMPLAUSIBLE_GNSS_SOURCE_SPEED,
                    startTripElapsedNanos = time,
                    endTripElapsedNanos = time,
                    evidenceReasons = setOf(IntegrityEvidenceReason.GNSS_SOURCE_SPEED_IMPLAUSIBLE),
                )
            }
            if (sample.decision == GnssDecision.RESET_AFTER_GAP) {
                observe(
                    ruleId = IntegrityRuleId.GNSS_SOURCE_GAP,
                    startTripElapsedNanos = sample.previousAnchorElapsedNanos ?: time,
                    endTripElapsedNanos = time,
                    evidenceReasons = setOf(IntegrityEvidenceReason.GNSS_PROCESSING_GAP_RESET),
                )
            }
        }
    }

    private fun auditRawSensorFlags() {
        trip.records().forEach { record ->
            when (record) {
                is TelemetrySampleRecord.Gnss -> {
                    if (GnssQualityFlag.CLOCK_DISCONTINUITY in record.sample.qualityFlags) {
                        observe(
                            ruleId = IntegrityRuleId.CLOCK_DISCONTINUITY,
                            startTripElapsedNanos = record.tripElapsedNanos,
                            endTripElapsedNanos = record.tripElapsedNanos,
                            evidenceReasons =
                                setOf(IntegrityEvidenceReason.GNSS_CLOCK_DISCONTINUITY_FLAG),
                        )
                    }
                }

                is TelemetrySampleRecord.Imu -> auditImuFlags(record)
            }
        }
    }

    private fun auditImuFlags(record: TelemetrySampleRecord.Imu) {
        val sensorType = record.sample.sensorType
        if (ImuQualityFlag.CLOCK_DISCONTINUITY in record.sample.qualityFlags) {
            observe(
                ruleId = IntegrityRuleId.CLOCK_DISCONTINUITY,
                startTripElapsedNanos = record.tripElapsedNanos,
                endTripElapsedNanos = record.tripElapsedNanos,
                evidenceReasons =
                    setOf(
                        when (sensorType) {
                            ImuSensorType.ACCELEROMETER ->
                                IntegrityEvidenceReason.ACCELEROMETER_CLOCK_DISCONTINUITY_FLAG
                            ImuSensorType.GYROSCOPE ->
                                IntegrityEvidenceReason.GYROSCOPE_CLOCK_DISCONTINUITY_FLAG
                        },
                    ),
            )
        }
        if (ImuQualityFlag.IMU_DROPOUT in record.sample.qualityFlags) {
            observe(
                ruleId = IntegrityRuleId.IMU_SOURCE_DROPOUT,
                startTripElapsedNanos = record.tripElapsedNanos,
                endTripElapsedNanos = record.tripElapsedNanos,
                evidenceReasons =
                    setOf(
                        when (sensorType) {
                            ImuSensorType.ACCELEROMETER ->
                                IntegrityEvidenceReason.ACCELEROMETER_DROPOUT_FLAG
                            ImuSensorType.GYROSCOPE ->
                                IntegrityEvidenceReason.GYROSCOPE_DROPOUT_FLAG
                        },
                    ),
            )
        }
        if (ImuQualityFlag.SENSOR_UNRELIABLE in record.sample.qualityFlags) {
            observe(
                ruleId = IntegrityRuleId.IMU_SENSOR_UNRELIABLE,
                startTripElapsedNanos = record.tripElapsedNanos,
                endTripElapsedNanos = record.tripElapsedNanos,
                evidenceReasons =
                    setOf(
                        when (sensorType) {
                            ImuSensorType.ACCELEROMETER ->
                                IntegrityEvidenceReason.ACCELEROMETER_UNRELIABLE_FLAG
                            ImuSensorType.GYROSCOPE ->
                                IntegrityEvidenceReason.GYROSCOPE_UNRELIABLE_FLAG
                        },
                    ),
            )
        }
    }

    private fun auditConfidenceFrames() {
        confidenceTimeline.synchronizedFrames().forEach { pair ->
            val derived = pair.derived
            val confidence = pair.confidence
            val time = derived.tripElapsedNanos
            val agreement = confidence.components.sourceAgreement.assessment
            if (
                agreement.state == TelemetryConfidenceState.INVALIDATED &&
                TelemetryConfidenceReason.SOURCE_AGREEMENT_CONFLICTING in agreement.reasons
            ) {
                observe(
                    ruleId = IntegrityRuleId.CROSS_SENSOR_DISAGREEMENT,
                    startTripElapsedNanos = time,
                    endTripElapsedNanos = time,
                    evidenceReasons = setOf(IntegrityEvidenceReason.SOURCE_AGREEMENT_INVALIDATED),
                    confidenceReasons = agreement.reasons,
                )
            }

            if (derived.movementState.state != MovementState.MOVING) return@forEach
            val accelerometer = confidence.components.accelerometer.assessment
            val gyroscope = confidence.components.gyroscope.assessment
            val missingAccelerometer = accelerometer.state.isUnavailableForCorroboration()
            val missingGyroscope = gyroscope.state.isUnavailableForCorroboration()
            if (missingAccelerometer || missingGyroscope) {
                observe(
                    ruleId = IntegrityRuleId.MOTION_WITHOUT_INERTIAL_CORROBORATION,
                    startTripElapsedNanos = time,
                    endTripElapsedNanos = time,
                    evidenceReasons =
                        buildSet {
                            if (missingAccelerometer) {
                                add(
                                    IntegrityEvidenceReason.MOVING_WITH_ACCELEROMETER_UNAVAILABLE,
                                )
                            }
                            if (missingGyroscope) {
                                add(IntegrityEvidenceReason.MOVING_WITH_GYROSCOPE_UNAVAILABLE)
                            }
                        },
                    confidenceReasons =
                        buildSet {
                            if (missingAccelerometer) addAll(accelerometer.reasons)
                            if (missingGyroscope) addAll(gyroscope.reasons)
                        },
                )
            }
        }
    }

    private fun auditMergedEvents() {
        sourceTimeline.events()
            .filter { it.eventType == DrivingEventType.PHONE_MOVED }
            .forEach { event ->
                observe(
                    ruleId = IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION,
                    startTripElapsedNanos = event.startTripElapsedNanos,
                    endTripElapsedNanos = event.endTripElapsedNanos,
                    evidenceReasons = setOf(IntegrityEvidenceReason.ACCEPTED_PHONE_MOVEMENT_EVENT),
                    representativeMergedEventId = event.eventId,
                )
            }
    }

    private fun observe(
        ruleId: IntegrityRuleId,
        startTripElapsedNanos: Long,
        endTripElapsedNanos: Long,
        evidenceReasons: Set<IntegrityEvidenceReason>,
        confidenceReasons: Set<TelemetryConfidenceReason> = emptySet(),
        representativeMergedEventId: String? = null,
    ) {
        findings.getOrPut(ruleId) {
            IntegrityFindingAccumulator(
                ruleId = ruleId,
                observationIntervalNanos = analysisTimeline.config.intervalNanos,
            )
        }.observe(
            startTripElapsedNanos = startTripElapsedNanos,
            endTripElapsedNanos = endTripElapsedNanos,
            evidenceReasons = evidenceReasons,
            confidenceReasons = confidenceReasons,
            representativeMergedEventId = representativeMergedEventId,
        )
    }
}

private class IntegrityFindingAccumulator(
    private val ruleId: IntegrityRuleId,
    private val observationIntervalNanos: Long,
) {
    private var occurrenceCount = 0L
    private var firstTripElapsedNanos: Long? = null
    private var lastTripElapsedNanos: Long? = null
    private var currentRunStartTripElapsedNanos: Long? = null
    private var maximumContinuousDurationNanos = 0L
    private val evidenceReasons = linkedSetOf<IntegrityEvidenceReason>()
    private val confidenceReasons = linkedSetOf<TelemetryConfidenceReason>()
    private var representativeMergedEventId: String? = null

    init {
        require(observationIntervalNanos > 0L)
    }

    fun observe(
        startTripElapsedNanos: Long,
        endTripElapsedNanos: Long,
        evidenceReasons: Set<IntegrityEvidenceReason>,
        confidenceReasons: Set<TelemetryConfidenceReason>,
        representativeMergedEventId: String?,
    ) {
        require(startTripElapsedNanos >= 0L)
        require(endTripElapsedNanos >= startTripElapsedNanos)
        require(evidenceReasons.isNotEmpty())
        val previousEnd = lastTripElapsedNanos
        require(previousEnd == null || endTripElapsedNanos >= previousEnd)
        val contiguous =
            previousEnd != null &&
                startTripElapsedNanos - previousEnd <= observationIntervalNanos
        if (!contiguous) currentRunStartTripElapsedNanos = startTripElapsedNanos
        val runStart = requireNotNull(currentRunStartTripElapsedNanos)
        maximumContinuousDurationNanos =
            maxOf(
                maximumContinuousDurationNanos,
                endTripElapsedNanos - runStart + observationIntervalNanos,
            )
        occurrenceCount += 1L
        firstTripElapsedNanos = firstTripElapsedNanos ?: startTripElapsedNanos
        lastTripElapsedNanos = endTripElapsedNanos
        this.evidenceReasons += evidenceReasons
        this.confidenceReasons += confidenceReasons
        if (this.representativeMergedEventId == null) {
            this.representativeMergedEventId = representativeMergedEventId
        }
    }

    fun freeze(config: IntegrityRulesConfig): IntegrityFinding =
        IntegrityFinding(
            integrityVersion = config.integrityVersion,
            eventMachineId =
                if (ruleId.findingKind() == IntegrityFindingKind.INCONSISTENCY) {
                    TELEMETRY_INCONSISTENCY_EVENT_MACHINE_ID
                } else {
                    null
                },
            ruleId = ruleId,
            kind = ruleId.findingKind(),
            state = ruleId.state(occurrenceCount, maximumContinuousDurationNanos, config),
            dimensions = ruleId.dimensions(),
            occurrenceCount = occurrenceCount,
            firstTripElapsedNanos = firstTripElapsedNanos,
            lastTripElapsedNanos = lastTripElapsedNanos,
            maximumContinuousDurationNanos = maximumContinuousDurationNanos,
            evidenceReasons = evidenceReasons.toSet(),
            confidenceReasons = confidenceReasons.toSet(),
            representativeMergedEventId = representativeMergedEventId,
            rawTripFailure = null,
        )
}

private fun buildAudit(
    tripId: String?,
    findings: List<IntegrityFinding>,
    sourceVersions: IntegritySourceVersions?,
    config: IntegrityRulesConfig,
): TripIntegrityAudit {
    val dimensions =
        IntegrityDimension.entries.associateWith { dimension ->
            val contributors = findings.filter { dimension in it.dimensions }
            IntegrityDimensionAssessment(
                dimension = dimension,
                state =
                    contributors.maxByOrNull { it.state.severityRank }?.state
                        ?: TripIntegrityState.VERIFIED,
                contributingRules = contributors.mapTo(linkedSetOf()) { it.ruleId },
            )
        }
    val state = dimensions.values.maxBy { it.state.severityRank }.state
    return TripIntegrityAudit(
        integrityVersion = config.integrityVersion,
        tripId = tripId,
        state = state,
        rankEligibility =
            when (state) {
                TripIntegrityState.VERIFIED -> RankEligibility.ELIGIBLE
                TripIntegrityState.LIMITED_CONFIDENCE ->
                    RankEligibility.ELIGIBLE_WITH_LIMITATIONS
                TripIntegrityState.QUESTIONABLE -> RankEligibility.REVIEW_REQUIRED
                TripIntegrityState.UNRANKED -> RankEligibility.INELIGIBLE
            },
        dimensions = dimensions,
        findings = findings,
        sourceVersions = sourceVersions,
        configSnapshot = config,
    )
}

private fun IntegrityRuleId.dimensions(): Set<IntegrityDimension> =
    when (this) {
        IntegrityRuleId.RAW_TRIP_INVALID -> setOf(IntegrityDimension.SOURCE_INTEGRITY)
        IntegrityRuleId.PLATFORM_MOCK_LOCATION_SIGNAL ->
            setOf(
                IntegrityDimension.SOURCE_INTEGRITY,
                IntegrityDimension.GNSS_CONSISTENCY,
            )
        IntegrityRuleId.IMPOSSIBLE_GNSS_JUMP,
        IntegrityRuleId.IMPLAUSIBLE_GNSS_SOURCE_SPEED,
        IntegrityRuleId.GNSS_SOURCE_GAP,
        -> setOf(IntegrityDimension.GNSS_CONSISTENCY)
        IntegrityRuleId.CLOCK_DISCONTINUITY ->
            setOf(IntegrityDimension.TEMPORAL_INTEGRITY)
        IntegrityRuleId.IMU_SOURCE_DROPOUT,
        IntegrityRuleId.IMU_SENSOR_UNRELIABLE,
        -> setOf(IntegrityDimension.IMU_CONSISTENCY)
        IntegrityRuleId.CROSS_SENSOR_DISAGREEMENT ->
            setOf(IntegrityDimension.CROSS_SENSOR_AGREEMENT)
        IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION ->
            setOf(
                IntegrityDimension.SOURCE_INTEGRITY,
                IntegrityDimension.IMU_CONSISTENCY,
            )
        IntegrityRuleId.MOTION_WITHOUT_INERTIAL_CORROBORATION ->
            setOf(
                IntegrityDimension.IMU_CONSISTENCY,
                IntegrityDimension.CROSS_SENSOR_AGREEMENT,
            )
    }

private fun IntegrityRuleId.findingKind(): IntegrityFindingKind =
    when (this) {
        IntegrityRuleId.RAW_TRIP_INVALID -> IntegrityFindingKind.DATA_CORRUPTION
        IntegrityRuleId.PLATFORM_MOCK_LOCATION_SIGNAL -> IntegrityFindingKind.PLATFORM_SIGNAL
        IntegrityRuleId.GNSS_SOURCE_GAP,
        IntegrityRuleId.IMU_SOURCE_DROPOUT,
        IntegrityRuleId.IMU_SENSOR_UNRELIABLE,
        IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION,
        -> IntegrityFindingKind.QUALITY_LIMITATION
        IntegrityRuleId.IMPOSSIBLE_GNSS_JUMP,
        IntegrityRuleId.IMPLAUSIBLE_GNSS_SOURCE_SPEED,
        IntegrityRuleId.CLOCK_DISCONTINUITY,
        IntegrityRuleId.CROSS_SENSOR_DISAGREEMENT,
        IntegrityRuleId.MOTION_WITHOUT_INERTIAL_CORROBORATION,
        -> IntegrityFindingKind.INCONSISTENCY
    }

private fun IntegrityRuleId.state(
    occurrenceCount: Long,
    maximumContinuousDurationNanos: Long,
    config: IntegrityRulesConfig,
): TripIntegrityState =
    when (this) {
        IntegrityRuleId.RAW_TRIP_INVALID -> TripIntegrityState.UNRANKED
        IntegrityRuleId.PLATFORM_MOCK_LOCATION_SIGNAL,
        IntegrityRuleId.IMPLAUSIBLE_GNSS_SOURCE_SPEED,
        IntegrityRuleId.CLOCK_DISCONTINUITY,
        -> TripIntegrityState.QUESTIONABLE
        IntegrityRuleId.IMPOSSIBLE_GNSS_JUMP ->
            if (occurrenceCount >= config.repeatedImpossibleJumpUnrankedCount) {
                TripIntegrityState.UNRANKED
            } else {
                TripIntegrityState.QUESTIONABLE
            }
        IntegrityRuleId.CROSS_SENSOR_DISAGREEMENT ->
            if (maximumContinuousDurationNanos >= config.questionableSourceConflictDurationNanos) {
                TripIntegrityState.QUESTIONABLE
            } else {
                TripIntegrityState.LIMITED_CONFIDENCE
            }
        IntegrityRuleId.MOTION_WITHOUT_INERTIAL_CORROBORATION ->
            if (
                maximumContinuousDurationNanos >=
                config.questionableMotionWithoutImuDurationNanos
            ) {
                TripIntegrityState.QUESTIONABLE
            } else {
                TripIntegrityState.LIMITED_CONFIDENCE
            }
        IntegrityRuleId.GNSS_SOURCE_GAP,
        IntegrityRuleId.IMU_SOURCE_DROPOUT,
        IntegrityRuleId.IMU_SENSOR_UNRELIABLE,
        IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION,
        -> TripIntegrityState.LIMITED_CONFIDENCE
    }

private fun TelemetryConfidenceState.isUnavailableForCorroboration(): Boolean =
    this == TelemetryConfidenceState.UNAVAILABLE || this == TelemetryConfidenceState.INVALIDATED
