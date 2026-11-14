package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceState
import io.github.atrx07.traelyx.telemetry.TelemetryEligibility
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.Collections
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs

const val HYBRID_EVENT_EVIDENCE_VERSION = 1

enum class EventModelArtifactStatus { GENERATED_FIXTURE, EXPERIMENT, REJECTED }

/** Data-only identity; there is deliberately no production-approved status in version 1. */
class EventModelManifest(
    val modelVersion: String,
    val modelSha256: String,
    val featureSchema: String,
    val featureCount: Int,
    val labelSchema: String,
    classLabels: List<String>,
    val calibrationVersion: String,
    val calibrationSha256: String,
    val status: EventModelArtifactStatus,
) {
    val classLabels: List<String> = Collections.unmodifiableList(ArrayList(classLabels.also {
        require(it.size in 2..16)
    }))

    init {
        listOf(modelVersion, featureSchema, labelSchema, calibrationVersion).forEach { requireToken(it) }
        requireDigest(modelSha256)
        requireDigest(calibrationSha256)
        require(featureCount in 1..4096)
        require(this.classLabels.size in 2..16 && this.classLabels.toSet().size == this.classLabels.size)
        this.classLabels.forEach { requireToken(it) }
    }
}

/** Generated harness only. No adapter from recorded telemetry/source-space M7.2 inputs exists. */
class GeneratedEventFeatureWindow(
    val featureSchema: String,
    val startTripElapsedNanos: Long,
    val endTripElapsedNanos: Long,
    features: FloatArray,
) {
    private val values = features.also { require(it.size in 1..4096) }.copyOf()
    val featureCount: Int get() = values.size
    val inputSha256: String

    init {
        requireToken(featureSchema)
        require(startTripElapsedNanos >= 0 && endTripElapsedNanos >= startTripElapsedNanos)
        require(values.size in 1..4096 && values.all { it.isFinite() && abs(it) <= 1e9f })
        val digest = MessageDigest.getInstance("SHA-256")
        digest.update("generated-event-input-v1\n$featureSchema\n".toByteArray(Charsets.UTF_8))
        val buffer = ByteBuffer.allocate(20 + values.size * 4).order(ByteOrder.LITTLE_ENDIAN)
        buffer.putLong(startTripElapsedNanos).putLong(endTripElapsedNanos).putInt(values.size)
        values.forEach { buffer.putFloat(it) }
        inputSha256 = digest.digest(buffer.array()).joinToString("") { "%02x".format(it) }
    }

    fun copyFeatures(): FloatArray = values.copyOf()
}

interface GeneratedEventEvidenceProvider {
    val modelSha256: String
    /** Probabilities in manifest label order; no normalization of malformed outputs. */
    fun probabilities(features: FloatArray): DoubleArray
}

enum class HybridEventEvidenceStatus {
    DISABLED_MODEL_ACCEPTANCE_DEFERRED,
    ARTIFACT_REJECTED,
    MODEL_NOT_ACCEPTED,
    QUALITY_EXCLUDED,
    QUALITY_LIMITED,
    PROVIDER_UNAVAILABLE,
    ATTEMPT_BUDGET_EXHAUSTED,
    INVALID_INPUT,
    FEATURE_OR_WINDOW_MISMATCH,
    PROVIDER_MODEL_MISMATCH,
    PROVIDER_FAILURE,
    INVALID_PROBABILITIES,
    GENERATED_EVIDENCE_ONLY,
}

class HybridEventEvidenceAudit internal constructor(
    val status: HybridEventEvidenceStatus,
    manifest: EventModelManifest?,
    window: GeneratedEventFeatureWindow?,
    rule: EventEvidenceWindow?,
    probabilities: Map<String, Double>?,
) {
    // Snapshot nested rule collections as well as provider output before returning.
    private val model = manifest?.let { mapOf(
        "version" to it.modelVersion, "sha256" to it.modelSha256,
        "featureSchema" to it.featureSchema, "featureCount" to it.featureCount,
        "labelSchema" to it.labelSchema, "labels" to it.classLabels,
        "calibrationVersion" to it.calibrationVersion, "calibrationSha256" to it.calibrationSha256,
        "artifactStatus" to it.status.name,
    ) }
    private val input = window?.let { mapOf(
        "sha256" to it.inputSha256, "startNanos" to it.startTripElapsedNanos,
        "endNanos" to it.endTripElapsedNanos, "origin" to "generated_fixture",
    ) }
    private val ruleSummary = rule?.let { mapOf(
        "taxonomyVersion" to it.taxonomyVersion, "type" to it.eventType.machineId,
        "startNanos" to it.windowStartTripElapsedNanos, "peakNanos" to it.peakTripElapsedNanos,
        "endNanos" to it.windowEndTripElapsedNanos, "confidence" to it.confidence.name,
        "rules" to it.ruleEvidence.map { value -> value.name }.sorted(),
        "qualityFlags" to it.qualityFlags.map { value -> value.name }.sorted(),
        "eligibility" to it.sourceEvidence.metricEligibility.entries.sortedBy { value -> value.key.name }
            .associate { value -> value.key.name to value.value.eligibility.name },
        "components" to it.sourceEvidence.componentConfidence.entries.sortedBy { value -> value.key.name }
            .associate { value -> value.key.name to mapOf(
                "state" to value.value.state.name, "reasons" to value.value.reasons.map { reason -> reason.name }.sorted(),
            ) },
    ) }
    private val prediction = probabilities?.toMap()

    /** Fresh deep copy prevents callers mutating this audit through a serialization map. */
    fun localMap(): Map<String, Any?> = deepCopy(mapOf(
        "boundaryVersion" to HYBRID_EVENT_EVIDENCE_VERSION,
        "policy" to "rules_authoritative_no_ml_effect",
        "status" to status.name.lowercase(),
        "model" to model, "input" to input, "rule" to ruleSummary,
        "probabilities" to prediction,
    ))
}

data class HybridEventEvidenceDecision(
    val ruleWindow: EventEvidenceWindow,
    val audit: HybridEventEvidenceAudit,
)

object HybridEventEvidenceBoundary {
    /** Constant-size status only; no runtime, features, provider or per-frame work. */
    fun productionAudit(): HybridEventEvidenceAudit = HybridEventEvidenceAudit(
        HybridEventEvidenceStatus.DISABLED_MODEL_ACCEPTANCE_DEFERRED, null, null, null, null,
    )
}

/** Caller-owned bounded, synchronous generated evaluation. Never wired to production analysis. */
class GeneratedEventEvidenceSession(maximumAttempts: Int = 32) {
    private val limit = maximumAttempts.also { require(it in 1..256) }
    private val attempts = AtomicInteger(0)

    fun evaluate(
        rule: EventEvidenceWindow,
        manifest: EventModelManifest,
        createWindow: () -> GeneratedEventFeatureWindow,
        createProvider: (() -> GeneratedEventEvidenceProvider)?,
    ): HybridEventEvidenceDecision {
        var window: GeneratedEventFeatureWindow? = null
        fun result(status: HybridEventEvidenceStatus, probabilities: Map<String, Double>? = null) =
            HybridEventEvidenceDecision(rule, HybridEventEvidenceAudit(status, manifest, window, rule, probabilities))
        checkCancellation()
        when (manifest.status) {
            EventModelArtifactStatus.REJECTED -> return result(HybridEventEvidenceStatus.ARTIFACT_REJECTED)
            EventModelArtifactStatus.EXPERIMENT -> return result(HybridEventEvidenceStatus.MODEL_NOT_ACCEPTED)
            EventModelArtifactStatus.GENERATED_FIXTURE -> Unit
        }
        val source = rule.sourceEvidence
        if (source.componentConfidence.values.any { it.state == TelemetryConfidenceState.INVALIDATED ||
                it.state == TelemetryConfidenceState.UNAVAILABLE }) return result(HybridEventEvidenceStatus.QUALITY_EXCLUDED)
        if (rule.confidence != EventEvidenceConfidence.SUPPORTED || rule.qualityFlags.isNotEmpty() ||
            source.metricEligibility.values.any { it.eligibility != TelemetryEligibility.ELIGIBLE } ||
            source.componentConfidence.values.any { it.state != TelemetryConfidenceState.SUPPORTED }) {
            return result(HybridEventEvidenceStatus.QUALITY_LIMITED)
        }
        if (createProvider == null) return result(HybridEventEvidenceStatus.PROVIDER_UNAVAILABLE)
        if (attempts.getAndUpdate { if (it < limit) it + 1 else it } >= limit) {
            return result(HybridEventEvidenceStatus.ATTEMPT_BUDGET_EXHAUSTED)
        }
        window = try { createWindow() } catch (failure: Exception) {
            propagateCancellation(failure)
            return result(HybridEventEvidenceStatus.INVALID_INPUT)
        }
        val input = requireNotNull(window)
        if (input.featureSchema != manifest.featureSchema || input.featureCount != manifest.featureCount ||
            input.startTripElapsedNanos != rule.windowStartTripElapsedNanos ||
            input.endTripElapsedNanos != rule.windowEndTripElapsedNanos) {
            return result(HybridEventEvidenceStatus.FEATURE_OR_WINDOW_MISMATCH)
        }
        val output = try {
            checkCancellation()
            val provider = createProvider()
            if (provider.modelSha256 != manifest.modelSha256) return result(HybridEventEvidenceStatus.PROVIDER_MODEL_MISMATCH)
            val values = provider.probabilities(input.copyFeatures())
            checkCancellation()
            if (values.size != manifest.classLabels.size) return result(HybridEventEvidenceStatus.INVALID_PROBABILITIES)
            values.copyOf()
        } catch (failure: Exception) {
            propagateCancellation(failure)
            return result(HybridEventEvidenceStatus.PROVIDER_FAILURE)
        }
        if (output.size != manifest.classLabels.size || output.any { !it.isFinite() || it !in 0.0..1.0 } ||
            abs(output.sum() - 1.0) > 1e-6) return result(HybridEventEvidenceStatus.INVALID_PROBABILITIES)
        return result(HybridEventEvidenceStatus.GENERATED_EVIDENCE_ONLY,
            manifest.classLabels.zip(output.toList()).toMap())
    }
}

private fun requireToken(value: String) { require(value.matches(Regex("[a-z0-9][a-z0-9-]{0,63}"))) }
private fun requireDigest(value: String) { require(value.matches(Regex("[a-f0-9]{64}"))) }
private fun checkCancellation() { if (Thread.currentThread().isInterrupted) throw InterruptedException() }
private fun propagateCancellation(failure: Exception) {
    if (failure is InterruptedException) { Thread.currentThread().interrupt(); throw failure }
    if (failure is CancellationException) throw failure
    checkCancellation()
}

private fun deepCopy(value: Map<String, Any?>): Map<String, Any?> {
    fun copy(item: Any?): Any? = when (item) {
        is Map<*, *> -> item.entries.associate { (key, entry) -> key as String to copy(entry) }
        is List<*> -> item.map { copy(it) }
        else -> item
    }
    return value.mapValues { copy(it.value) }
}
