package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecodeResult
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecoder
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceReason
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class IntegrityPipelineTest {
    @Test
    fun `integrity policy defaults and machine IDs are stable and versioned`() {
        val config = IntegrityRulesConfig()
        assertEquals(1, config.integrityVersion)
        assertEquals(2, config.repeatedImpossibleJumpUnrankedCount)
        assertEquals(1_000_000_000L, config.questionableSourceConflictDurationNanos)
        assertEquals(2_000_000_000L, config.questionableMotionWithoutImuDurationNanos)
        assertEquals(
            IntegrityRuleId.entries.size,
            IntegrityRuleId.entries.map { it.machineId }.toSet().size,
        )
        assertEquals("EVT_TELEMETRY_INCONSISTENCY", TELEMETRY_INCONSISTENCY_EVENT_MACHINE_ID)
        assertTrue(runCatching { IntegrityRulesConfig(integrityVersion = 2) }.isFailure)
        assertTrue(
            runCatching {
                IntegrityRulesConfig(repeatedImpossibleJumpUnrankedCount = 1)
            }.isFailure,
        )
        assertTrue(
            runCatching {
                IntegrityRulesConfig(questionableSourceConflictDurationNanos = 0L)
            }.isFailure,
        )
    }

    @Test
    fun `governed clean corpus remains verified while explicit loss and phone movement are limited`() {
        val verifiedScenarios =
            setOf(
                TelemetryRegressionScenario.STATIONARY,
                TelemetryRegressionScenario.SMOOTH_STRAIGHT,
                TelemetryRegressionScenario.SMOOTH_ACCELERATION,
                TelemetryRegressionScenario.BRAKING,
                TelemetryRegressionScenario.LEFT_CORNER,
                TelemetryRegressionScenario.RIGHT_CORNER,
                TelemetryRegressionScenario.POTHOLE,
                TelemetryRegressionScenario.MOTORCYCLE_VIBRATION,
            )
        verifiedScenarios.forEach { scenario ->
            val first = audit(TelemetryRegressionFixtureCorpus.generate(scenario))
            val second = audit(TelemetryRegressionFixtureCorpus.generate(scenario))
            assertEquals("$scenario should be repeatable", first, second)
            assertEquals("$scenario should remain verified", TripIntegrityState.VERIFIED, first.state)
            assertEquals(RankEligibility.ELIGIBLE, first.rankEligibility)
            assertTrue(first.findings.isEmpty())
            assertNotNull(first.sourceVersions)
        }

        val loss = audit(TelemetryRegressionScenario.GNSS_LOSS)
        assertEquals(TripIntegrityState.LIMITED_CONFIDENCE, loss.state)
        assertEquals(RankEligibility.ELIGIBLE_WITH_LIMITATIONS, loss.rankEligibility)
        assertFinding(loss, IntegrityRuleId.GNSS_SOURCE_GAP, TripIntegrityState.LIMITED_CONFIDENCE)

        val phoneMove = audit(TelemetryRegressionScenario.PHONE_MOVE)
        assertEquals(TripIntegrityState.LIMITED_CONFIDENCE, phoneMove.state)
        val phoneFinding =
            assertFinding(
                phoneMove,
                IntegrityRuleId.PHONE_MOVEMENT_INVALIDATION,
                TripIntegrityState.LIMITED_CONFIDENCE,
            )
        assertTrue(
            IntegrityEvidenceReason.ACCEPTED_PHONE_MOVEMENT_EVENT in
                phoneFinding.evidenceReasons,
        )
        assertNotNull(phoneFinding.representativeMergedEventId)
    }

    @Test
    fun `platform mock signal is questionable evidence but never sole automatic unranking`() {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        var modified = false
        val fixture =
            source.copy(
                records =
                    source.records.map { record ->
                        if (!modified && record is TelemetrySampleRecord.Gnss) {
                            modified = true
                            record.copy(
                                sample =
                                    record.sample.copy(
                                        isMockSignal = true,
                                        qualityFlags =
                                            record.sample.qualityFlags +
                                                GnssQualityFlag.MOCK_LOCATION_SIGNAL,
                                    ),
                            )
                        } else {
                            record
                        }
                    },
            )
        val audit = audit(fixture)

        assertEquals(TripIntegrityState.QUESTIONABLE, audit.state)
        assertEquals(RankEligibility.REVIEW_REQUIRED, audit.rankEligibility)
        assertFalse(audit.state == TripIntegrityState.UNRANKED)
        val finding =
            assertFinding(
                audit,
                IntegrityRuleId.PLATFORM_MOCK_LOCATION_SIGNAL,
                TripIntegrityState.QUESTIONABLE,
            )
        assertTrue(IntegrityDimension.SOURCE_INTEGRITY in finding.dimensions)
        assertTrue(IntegrityDimension.GNSS_CONSISTENCY in finding.dimensions)
        assertEquals(IntegrityFindingKind.PLATFORM_SIGNAL, finding.kind)
        assertNull(finding.eventMachineId)
    }

    @Test
    fun `implausible platform source speed is an inconsistency without altering raw evidence`() {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        var modified = false
        val fixture =
            source.copy(
                records =
                    source.records.map { record ->
                        if (
                            !modified &&
                            record is TelemetrySampleRecord.Gnss &&
                            record.tripElapsedNanos >=
                            TelemetryRegressionFixtureCorpus.ACTION_START_NANOS
                        ) {
                            modified = true
                            record.copy(sample = record.sample.copy(speedMetresPerSecond = 150.0f))
                        } else {
                            record
                        }
                    },
            )
        val audit = audit(fixture)
        val finding =
            assertFinding(
                audit,
                IntegrityRuleId.IMPLAUSIBLE_GNSS_SOURCE_SPEED,
                TripIntegrityState.QUESTIONABLE,
            )

        assertEquals(IntegrityFindingKind.INCONSISTENCY, finding.kind)
        assertEquals(TELEMETRY_INCONSISTENCY_EVENT_MACHINE_ID, finding.eventMachineId)
        assertEquals(RankEligibility.REVIEW_REQUIRED, audit.rankEligibility)
    }

    @Test
    fun `isolated impossible jump is questionable and repeated jumps are unranked`() {
        val isolated = audit(impossibleJumpFixture(setOf(7_000_000_000L)))
        val isolatedFinding =
            assertFinding(
                isolated,
                IntegrityRuleId.IMPOSSIBLE_GNSS_JUMP,
                TripIntegrityState.QUESTIONABLE,
            )
        assertEquals(1L, isolatedFinding.occurrenceCount)
        assertEquals(RankEligibility.REVIEW_REQUIRED, isolated.rankEligibility)
        assertEquals(IntegrityFindingKind.INCONSISTENCY, isolatedFinding.kind)
        assertEquals(
            TELEMETRY_INCONSISTENCY_EVENT_MACHINE_ID,
            isolatedFinding.eventMachineId,
        )

        val repeated = audit(impossibleJumpFixture(setOf(7_000_000_000L, 8_000_000_000L)))
        val repeatedFinding =
            assertFinding(
                repeated,
                IntegrityRuleId.IMPOSSIBLE_GNSS_JUMP,
                TripIntegrityState.UNRANKED,
            )
        assertEquals(2L, repeatedFinding.occurrenceCount)
        assertEquals(RankEligibility.INELIGIBLE, repeated.rankEligibility)
    }

    @Test
    fun `sustained GNSS IMU disagreement is questionable with typed M3 reasons`() {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        val fixture =
            source.copy(
                records =
                    source.records.map { record ->
                        if (
                            record is TelemetrySampleRecord.Imu &&
                            record.sample.sensorType == ImuSensorType.GYROSCOPE &&
                            record.tripElapsedNanos >=
                            TelemetryRegressionFixtureCorpus.ACTION_START_NANOS
                        ) {
                            record.copy(sample = record.sample.copy(z = record.sample.z + 1.0f))
                        } else {
                            record
                        }
                    },
            )
        val audit = audit(fixture)
        val finding =
            assertFinding(
                audit,
                IntegrityRuleId.CROSS_SENSOR_DISAGREEMENT,
                TripIntegrityState.QUESTIONABLE,
            )

        assertTrue(
            requireNotNull(finding.maximumContinuousDurationNanos) >=
                DEFAULT_QUESTIONABLE_SOURCE_CONFLICT_DURATION_NANOS,
        )
        assertTrue(
            TelemetryConfidenceReason.SOURCE_AGREEMENT_CONFLICTING in
                finding.confidenceReasons,
        )
        assertEquals(
            TripIntegrityState.QUESTIONABLE,
            audit.dimensions.getValue(IntegrityDimension.CROSS_SENSOR_AGREEMENT).state,
        )

        val limitedByPolicy =
            audit(
                fixture,
                IntegrityRulesConfig(questionableSourceConflictDurationNanos = 10_000_000_000L),
            )
        assertFinding(
            limitedByPolicy,
            IntegrityRuleId.CROSS_SENSOR_DISAGREEMENT,
            TripIntegrityState.LIMITED_CONFIDENCE,
        )
    }

    @Test
    fun `sustained motion without gyroscope corroboration is questionable not intent proof`() {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        val fixture =
            source.copy(
                records =
                    source.records.filterNot { record ->
                        record is TelemetrySampleRecord.Imu &&
                            record.sample.sensorType == ImuSensorType.GYROSCOPE &&
                            record.tripElapsedNanos in
                            6_000_000_000L until 10_000_000_000L
                    },
            )
        val audit = audit(fixture)
        val finding =
            assertFinding(
                audit,
                IntegrityRuleId.MOTION_WITHOUT_INERTIAL_CORROBORATION,
                TripIntegrityState.QUESTIONABLE,
            )

        assertTrue(
            IntegrityEvidenceReason.MOVING_WITH_GYROSCOPE_UNAVAILABLE in
                finding.evidenceReasons,
        )
        assertTrue(
            requireNotNull(finding.maximumContinuousDurationNanos) >=
                DEFAULT_QUESTIONABLE_MOTION_WITHOUT_IMU_DURATION_NANOS,
        )
        assertEquals(RankEligibility.REVIEW_REQUIRED, audit.rankEligibility)
    }

    @Test
    fun `raw sensor quality flags remain distinct limited and questionable findings`() {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        var dropoutAdded = false
        var unreliableAdded = false
        var clockAdded = false
        val fixture =
            source.copy(
                records =
                    source.records.map { record ->
                        if (record !is TelemetrySampleRecord.Imu) return@map record
                        when {
                            !dropoutAdded &&
                                record.sample.sensorType == ImuSensorType.ACCELEROMETER &&
                                record.tripElapsedNanos >=
                                TelemetryRegressionFixtureCorpus.ACTION_START_NANOS -> {
                                dropoutAdded = true
                                record.copy(
                                    sample =
                                        record.sample.copy(
                                            qualityFlags =
                                                record.sample.qualityFlags +
                                                    ImuQualityFlag.IMU_DROPOUT,
                                        ),
                                )
                            }
                            !unreliableAdded &&
                                record.sample.sensorType == ImuSensorType.GYROSCOPE &&
                                record.tripElapsedNanos >=
                                TelemetryRegressionFixtureCorpus.ACTION_START_NANOS -> {
                                unreliableAdded = true
                                record.copy(
                                    sample =
                                        record.sample.copy(
                                            accuracyStatus = 0,
                                            qualityFlags =
                                                record.sample.qualityFlags +
                                                    ImuQualityFlag.SENSOR_UNRELIABLE,
                                        ),
                                )
                            }
                            !clockAdded &&
                                record.tripElapsedNanos >
                                TelemetryRegressionFixtureCorpus.ACTION_START_NANOS -> {
                                clockAdded = true
                                record.copy(
                                    sample =
                                        record.sample.copy(
                                            qualityFlags =
                                                record.sample.qualityFlags +
                                                    ImuQualityFlag.CLOCK_DISCONTINUITY,
                                        ),
                                )
                            }
                            else -> record
                        }
                    },
            )
        val audit = audit(fixture)

        assertFinding(
            audit,
            IntegrityRuleId.IMU_SOURCE_DROPOUT,
            TripIntegrityState.LIMITED_CONFIDENCE,
        )
        assertFinding(
            audit,
            IntegrityRuleId.IMU_SENSOR_UNRELIABLE,
            TripIntegrityState.LIMITED_CONFIDENCE,
        )
        assertFinding(
            audit,
            IntegrityRuleId.CLOCK_DISCONTINUITY,
            TripIntegrityState.QUESTIONABLE,
        )
        assertEquals(TripIntegrityState.QUESTIONABLE, audit.state)
    }

    @Test
    fun `corrupted raw chunks fail closed as unranked without trusting a trip identity`() {
        val chunks =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
                .encodedChunks()
                .map(ByteArray::clone)
                .toMutableList()
        chunks[0][chunks[0].lastIndex] = (chunks[0].last().toInt() xor 0x01).toByte()
        val invalid = RawTelemetryTripDecoder.decode(chunks) as RawTelemetryTripDecodeResult.Invalid
        val audit = IntegrityPipeline.audit(invalid)

        assertEquals(TripIntegrityState.UNRANKED, audit.state)
        assertEquals(RankEligibility.INELIGIBLE, audit.rankEligibility)
        assertNull(audit.tripId)
        assertNull(audit.sourceVersions)
        val finding = audit.findings.single()
        assertEquals(IntegrityRuleId.RAW_TRIP_INVALID, finding.ruleId)
        assertEquals(IntegrityFindingKind.DATA_CORRUPTION, finding.kind)
        assertNull(finding.eventMachineId)
        assertEquals(invalid.errorCode, requireNotNull(finding.rawTripFailure).errorCode)
        assertTrue(IntegrityEvidenceReason.RAW_TRIP_DECODER_REJECTED in finding.evidenceReasons)
    }

    private fun impossibleJumpFixture(times: Set<Long>): TelemetryRegressionFixture {
        val source =
            TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        return source.copy(
            records =
                source.records.map { record ->
                    if (record is TelemetrySampleRecord.Gnss && record.tripElapsedNanos in times) {
                        record.copy(
                            sample =
                                record.sample.copy(
                                    latitudeDegrees = record.sample.latitudeDegrees + 1.0,
                                ),
                        )
                    } else {
                        record
                    }
                },
        )
    }

    private fun audit(scenario: TelemetryRegressionScenario): TripIntegrityAudit =
        audit(TelemetryRegressionFixtureCorpus.generate(scenario))

    private fun audit(fixture: TelemetryRegressionFixture): TripIntegrityAudit =
        audit(fixture, IntegrityRulesConfig())

    private fun audit(
        fixture: TelemetryRegressionFixture,
        config: IntegrityRulesConfig,
    ): TripIntegrityAudit =
        IntegrityPipeline.audit(
            EventMergePipeline.build(
                EventTaxonomyPipeline.build(confidenceTimelineFor(fixture)),
            ),
            config,
        )

    private fun assertFinding(
        audit: TripIntegrityAudit,
        ruleId: IntegrityRuleId,
        expectedState: TripIntegrityState,
    ): IntegrityFinding {
        val finding = audit.findings.single { it.ruleId == ruleId }
        assertEquals(expectedState, finding.state)
        return finding
    }
}
