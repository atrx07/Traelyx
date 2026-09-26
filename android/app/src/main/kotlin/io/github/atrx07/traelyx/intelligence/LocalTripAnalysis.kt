package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.TelemetryChunkStore
import io.github.atrx07.traelyx.telemetry.*
import java.security.MessageDigest
import java.util.UUID

/** Explicit foreground analysis only. No network, recorder mutation, or inferred mount hint. */
class LocalTripAnalysis(private val store: TelemetryChunkStore) {
    fun read(tripId: String, forwardAxis: String): Map<String, Any?> {
        require(UUID.fromString(tripId).toString() == tripId)
        val catalog = store.listSequences(tripId)
        require(catalog.orphanedWriteCount == 0 && catalog.invalidCandidateCount == 0)
        require(catalog.sequences.size in 1..20_000)
        require(catalog.sequences.withIndex().all { (i, s) -> i.toLong() == s })
        var totalBytes = 0L
        val chunks = catalog.sequences.map { sequence ->
            check(!Thread.currentThread().isInterrupted)
            val bytes = requireNotNull(store.read(tripId, sequence))
            totalBytes += bytes.size
            require(totalBytes <= 32L * 1024 * 1024) { "analysis_size_limit" }
            bytes
        }
        val result = analyze(chunks, forwardAxis)
        require(result["tripId"] == tripId)
        // Do not persist a result if a concurrent deletion changed the source catalog.
        require(store.listSequences(tripId) == catalog)
        return result
    }

    companion object {
        const val VERSION = 1
        const val CHANNEL = "io.github.atrx07.traelyx/local-analysis/v1"

        internal fun analyze(chunks: List<ByteArray>, forwardAxis: String): Map<String, Any?> {
            val forward = when (forwardAxis) {
                "top" -> FrameVector3(0.0, 1.0, 0.0)
                "bottom" -> FrameVector3(0.0, -1.0, 0.0)
                "right" -> FrameVector3(1.0, 0.0, 0.0)
                "left" -> FrameVector3(-1.0, 0.0, 0.0)
                "screen" -> FrameVector3(0.0, 0.0, 1.0)
                "back" -> FrameVector3(0.0, 0.0, -1.0)
                else -> error("analysis_mount_required")
            }
            val decoded = RawTelemetryTripDecoder.decode(chunks)
            require(decoded is RawTelemetryTripDecodeResult.Success)
            val trip = decoded.trip
            require(trip.totalSampleCount <= 1_000_000)
            val built = AnalysisTimelineResampler.build(trip)
            require(built is AnalysisTimelineBuildResult.Success)
            val analysis = built.timeline
            require(analysis.frameCount <= 720_000)
            val gnssResult = GnssSanityFilter.process(trip)
            require(gnssResult is GnssProcessingResult.Success)
            // Retrospective, explicit analysis: first and last non-overlapping 30s windows.
            // A missing/degraded comparison never becomes supported orientation evidence.
            val reference = ImuStationaryCalibrator.calibrate(
                analysis.frames().takeWhile { it.tripElapsedNanos <= 30_000_000_000L },
                analysis.config.intervalNanos,
            )
            val subsequentStart = maxOf(30_000_000_001L, trip.endElapsedNanos - 30_000_000_000L)
            val subsequent = ImuStationaryCalibrator.calibrate(
                analysis.frames().filter { it.tripElapsedNanos >= subsequentStart },
                analysis.config.intervalNanos,
            )
            val tilt = TiltOrientationResolver.resolve(reference)
            val change = if (tilt is TiltOrientationResolution.Available) {
                StationaryOrientationChangeDetector.compare(tilt.orientation, subsequent)
            } else null
            val contexts = if (tilt is TiltOrientationResolution.Available) {
                DerivedMotionContextTimeline.fixed(
                    reference,
                    VehicleMountAlignmentResolver.resolve(tilt.orientation, forward, change),
                )
            } else DerivedMotionContextTimeline(emptyList())
            val derived = DerivedTelemetryPipeline.build(analysis, gnssResult.summary, contexts)
            require(derived is DerivedTelemetryBuildResult.Success)
            val merged = EventMergePipeline.build(
                EventTaxonomyPipeline.build(TelemetryConfidencePipeline.build(derived.timeline)),
            )
            val score = ScoringPipeline.score(merged)
            val events = merged.events().take(10_001).toList()
            require(events.size <= 10_000)
            val digest = MessageDigest.getInstance("SHA-256")
            chunks.forEach { digest.update(it) }
            return mapOf(
                "analysisVersion" to VERSION,
                "versions" to mapOf("analysis" to VERSION, "raw" to trip.decoderVersion,
                    "encoding" to trip.chunkEncodingVersion, "schema" to trip.telemetrySchemaVersion,
                    "timeline" to ANALYSIS_TIMELINE_VERSION, "gnss" to GNSS_PROCESSING_VERSION,
                    "calibration" to IMU_STATIONARY_CALIBRATION_VERSION,
                    "orientation" to ORIENTATION_FRAME_TRANSFORM_VERSION,
                    "derived" to DERIVED_TELEMETRY_VERSION, "confidence" to TELEMETRY_CONFIDENCE_VERSION,
                    "taxonomy" to EVENT_TAXONOMY_VERSION, "merge" to EVENT_MERGE_VERSION,
                    "integrity" to INTEGRITY_RULES_VERSION, "scoring" to SCORING_VERSION),
                "tripId" to trip.tripId,
                "sourceDigest" to digest.digest().joinToString("") { "%02x".format(it) },
                "sourceChunkCount" to chunks.size,
                "sourceChunks" to trip.chunks.map { c -> c.metadata.let { m -> listOf(
                    m.sequence,m.startElapsedNanos,m.endElapsedNanos,m.checksumHex,m.byteLength,
                    m.gnssSampleCount,m.accelerometerSampleCount,m.gyroscopeSampleCount,m.createdAtUtcEpochMillis,
                ) } },
                "sourceSampleCount" to trip.totalSampleCount,
                "sourceStartNanos" to trip.startElapsedNanos,
                "sourceEndNanos" to trip.endElapsedNanos,
                "forwardAxis" to forwardAxis,
                "calibrationState" to reference.state.name,
                "comparisonState" to change?.state?.name,
                "subsequentCalibrationState" to subsequent.state.name,
                "calibrationEvidence" to reference.evidence.map { it.name },
                "comparisonEvidence" to subsequent.evidence.map { it.name },
                "calibrationConfig" to reference.config.toString(),
                "referenceCalibration" to reference.calibration?.toString(),
                "subsequentCalibration" to subsequent.calibration?.toString(),
                "pipelineConfigs" to listOf(analysis.config, gnssResult.summary.config,
                    derived.timeline.config, merged.sourceTimeline.sourceTimeline.config,
                    merged.sourceTimeline.config, merged.config).map { it.toString() },
                "distanceMeters" to if (gnssResult.summary.samples.size >= 2)
                    gnssResult.summary.totalDistanceMetres else null,
                "distanceDecisionCounts" to gnssResult.summary.decisionCounts.mapKeys { it.key.name },
                "score" to score.localMap(),
                "events" to events.map { it.localMap() },
            )
        }
    }
}

internal fun TripScoreAudit.localMap(): Map<String, Any?> = mapOf(
    "scoringVersion" to scoringVersion,
    "state" to state.name.lowercase(),
    "overallMilliPoints" to overallScoreMilliPoints,
    "rankingStatus" to rankingStatus.name,
    "riskGuardrailApplied" to riskGuardrailApplied,
    "configSnapshot" to configSnapshot.toString(),
    "sourceVersions" to sourceVersions.toString(),
    "provisionalReasons" to provisionalReasons.map { it.name },
    "unavailableReasons" to unavailableReasons.map { it.name },
    "integrity" to mapOf(
        "version" to integrityAudit.integrityVersion,
        "state" to integrityAudit.state.name.lowercase(),
        "configSnapshot" to integrityAudit.configSnapshot.toString(),
        "findings" to integrityAudit.findings.map { finding -> mapOf(
            "rule" to finding.ruleId.machineId,
            "state" to finding.state.name.lowercase(),
            "count" to finding.occurrenceCount,
            "firstNanos" to finding.firstTripElapsedNanos,
            "lastNanos" to finding.lastTripElapsedNanos,
            "maximumContinuousNanos" to finding.maximumContinuousDurationNanos,
            "reasons" to finding.evidenceReasons.map { it.name },
            "confidenceReasons" to finding.confidenceReasons.map { it.name },
        ) },
    ),
    "dimensions" to dimensions.mapKeys { it.key.machineId }.mapValues { (_, d) -> mapOf(
        "state" to d.state.name.lowercase(),
        "scoreMilliPoints" to d.scoreMilliPoints,
        "weightBasisPoints" to d.weightBasisPoints,
        "movingNanos" to d.evidence.movingDurationNanos,
        "opportunityNanos" to d.evidence.opportunityDurationNanos,
        "usableNanos" to d.evidence.usableDurationNanos,
        "fullyEligibleNanos" to d.evidence.fullyEligibleDurationNanos,
        "provisionalReasons" to d.provisionalReasons.map { it.name },
        "unavailableReasons" to d.unavailableReasons.map { it.name },
        "contributions" to d.contributions.map { c -> mapOf(
            "id" to c.contributionId, "rule" to c.rule.machineId,
            "basePoints" to c.basePoints, "severityPermille" to c.severityMultiplierPermille,
            "confidencePermille" to c.confidenceWeightPermille,
            "appliedMilliPoints" to c.appliedPointsMilli,
            "eventIds" to c.supportingEventIds.toList(),
        ) },
    ) },
)

private fun MergedDrivingEvent.localMap(): Map<String, Any?> = mapOf(
    "id" to eventId, "type" to eventType.machineId,
    "startNanos" to startTripElapsedNanos, "peakNanos" to peakTripElapsedNanos,
    "endNanos" to endTripElapsedNanos,
    "activationRatio" to (severity as? EventSeverityEvidence.Measured)?.activationRatio,
    "confidence" to confidence.name,
    "qualityFlags" to qualityFlags.map { it.name },
    "measurements" to primaryMeasurements.map { mapOf(
        "kind" to it.kind.name, "unit" to it.unit.name, "value" to it.signedValue,
        "provenance" to it.sourceProvenance.toString(),
    ) },
    "rules" to ruleEvidence.map { it.name },
    "sourceSummary" to sourceSummary.toString(),
)
