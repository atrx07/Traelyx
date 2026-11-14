package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.*
import java.util.concurrent.CancellationException
import org.junit.Assert.*
import org.junit.Test

class HybridEventEvidenceTest {
    private val modelHash = "a".repeat(64)
    private fun manifest(status: EventModelArtifactStatus = EventModelArtifactStatus.GENERATED_FIXTURE,
        labels: List<String> = listOf("fixture-a", "fixture-b")) = EventModelManifest(
        "fixture-model-v1", modelHash, "generated-features-v1", 2, "generated-labels-v1", labels,
        "generated-calibration-v1", "b".repeat(64), status,
    )
    private fun rules(scenario: TelemetryRegressionScenario = TelemetryRegressionScenario.SMOOTH_ACCELERATION) =
        EventTaxonomyPipeline.build(confidenceTimelineFor(TelemetryRegressionFixtureCorpus.generate(scenario)))
    private fun rule() = rules().windows().first { it.confidence == EventEvidenceConfidence.SUPPORTED }
    private fun window(rule: EventEvidenceWindow, features: FloatArray = floatArrayOf(1f, 2f)) =
        GeneratedEventFeatureWindow("generated-features-v1", rule.windowStartTripElapsedNanos, rule.windowEndTripElapsedNanos, features)
    private fun provider(values: DoubleArray = doubleArrayOf(.2, .8), hash: String = modelHash) =
        object : GeneratedEventEvidenceProvider {
            override val modelSha256 = hash
            override fun probabilities(features: FloatArray) = values
        }

    @Test fun `production audit contains no model input prediction or generated provider mode`() {
        val audit = HybridEventEvidenceBoundary.productionAudit().localMap()
        assertEquals("disabled_model_acceptance_deferred", audit["status"])
        for (field in listOf("model", "input", "probabilities", "rule")) assertNull(audit[field])
        assertEquals(1, audit["boundaryVersion"])
        assertEquals("rules_authoritative_no_ml_effect", audit["policy"])
    }

    @Test fun `rejected and experimental artifacts never construct features or providers`() {
        val rule = rule()
        for ((status, expected) in listOf(EventModelArtifactStatus.REJECTED to HybridEventEvidenceStatus.ARTIFACT_REJECTED,
            EventModelArtifactStatus.EXPERIMENT to HybridEventEvidenceStatus.MODEL_NOT_ACCEPTED)) {
            val decision = GeneratedEventEvidenceSession().evaluate(rule, manifest(status), { error("must not build features") }, { error("must not initialize runtime") })
            assertSame(rule, decision.ruleWindow)
            assertEquals(expected, decision.audit.status)
        }
    }

    @Test fun `limited quality and invalidated movement never call model or feature adapter`() {
        val base = rule()
        val limited = base.copy(confidence = EventEvidenceConfidence.LIMITED, qualityFlags = setOf(EventQualityFlag.LIMITED_SOURCE_EVIDENCE))
        val moved = rules(TelemetryRegressionScenario.PHONE_MOVE).windows().first { it.eventType == DrivingEventType.PHONE_MOVED }
        for ((value, expected) in listOf(limited to HybridEventEvidenceStatus.QUALITY_LIMITED, moved to HybridEventEvidenceStatus.QUALITY_EXCLUDED)) {
            assertEquals(expected, GeneratedEventEvidenceSession().evaluate(value, manifest(), { error("features") }, { error("runtime") }).audit.status)
        }
    }

    @Test fun `generated inference preserves rule and freezes probabilities and provenance`() {
        val base = rule()
        val features = floatArrayOf(1f, 2f)
        val input = window(base, features)
        val labels = mutableListOf("fixture-a", "fixture-b")
        val descriptor = manifest(labels = labels)
        labels[0] = "modified"
        val output = doubleArrayOf(.2, .8)
        val decision = GeneratedEventEvidenceSession().evaluate(base, descriptor, { input }, { provider(output) })
        features[0] = 999f
        output[0] = 999.0
        input.copyFeatures()[0] = 999f
        assertSame(base, decision.ruleWindow)
        assertEquals(HybridEventEvidenceStatus.GENERATED_EVIDENCE_ONLY, decision.audit.status)
        val audit = decision.audit.localMap()
        assertEquals(mapOf("fixture-a" to .2, "fixture-b" to .8), audit["probabilities"])
        assertEquals(modelHash, (audit["model"] as Map<*, *>)["sha256"])
        assertEquals(input.inputSha256, (audit["input"] as Map<*, *>)["sha256"])
        assertEquals(base.eventType.machineId, (audit["rule"] as Map<*, *>)["type"])
        @Suppress("UNCHECKED_CAST")
        (audit["probabilities"] as MutableMap<String, Double>)["fixture-a"] = 999.0
        assertEquals(.2, (decision.audit.localMap()["probabilities"] as Map<*, *>)["fixture-a"])
        @Suppress("UNCHECKED_CAST")
        ((audit["model"] as Map<*, *>)["labels"] as MutableList<String>)[0] = "changed"
        assertEquals(listOf("fixture-a", "fixture-b"), (decision.audit.localMap()["model"] as Map<*, *>)["labels"])
        assertFalse((audit["input"] as Map<*, *>).containsKey("features"))
        assertFalse(audit.toString().contains("features="))
        assertNotEquals(input.inputSha256, window(base, floatArrayOf(3f, 2f)).inputSha256)
        assertNotEquals(input.inputSha256, GeneratedEventFeatureWindow("generated-features-v1", base.windowStartTripElapsedNanos, base.windowEndTripElapsedNanos + 1, floatArrayOf(1f, 2f)).inputSha256)
    }

    @Test fun `schema count time and artifact identity must match before inference`() {
        val base = rule()
        val mismatches = listOf(
            GeneratedEventFeatureWindow("different-schema", base.windowStartTripElapsedNanos, base.windowEndTripElapsedNanos, floatArrayOf(1f, 2f)),
            window(base, floatArrayOf(1f)),
            GeneratedEventFeatureWindow("generated-features-v1", base.windowStartTripElapsedNanos, base.windowEndTripElapsedNanos + 1, floatArrayOf(1f, 2f)),
        )
        for (input in mismatches) assertEquals(HybridEventEvidenceStatus.FEATURE_OR_WINDOW_MISMATCH,
            GeneratedEventEvidenceSession().evaluate(base, manifest(), { input }, { error("runtime") }).audit.status)
        assertEquals(HybridEventEvidenceStatus.PROVIDER_MODEL_MISMATCH,
            GeneratedEventEvidenceSession().evaluate(base, manifest(), { window(base) }, { provider(hash = "c".repeat(64)) }).audit.status)
    }

    @Test fun `invalid features and outputs or exceptions cannot manufacture evidence`() {
        val base = rule()
        for (features in listOf(floatArrayOf(Float.NaN), floatArrayOf(Float.POSITIVE_INFINITY), FloatArray(4097), floatArrayOf(1e10f))) {
            assertEquals(HybridEventEvidenceStatus.INVALID_INPUT,
                GeneratedEventEvidenceSession().evaluate(base, manifest(), { window(base, features) }, { error("runtime") }).audit.status)
        }
        for (values in listOf(doubleArrayOf(1.0), doubleArrayOf(Double.NaN, .5), doubleArrayOf(-.1, 1.1), doubleArrayOf(.1, .1))) {
            assertEquals(HybridEventEvidenceStatus.INVALID_PROBABILITIES,
                GeneratedEventEvidenceSession().evaluate(base, manifest(), { window(base) }, { provider(values) }).audit.status)
        }
        val failure = GeneratedEventEvidenceSession().evaluate(base, manifest(), { window(base) }, { error("private arbitrary exception text") })
        assertEquals(HybridEventEvidenceStatus.PROVIDER_FAILURE, failure.audit.status)
        assertFalse(failure.audit.localMap().toString().contains("private arbitrary"))
        assertEquals(HybridEventEvidenceStatus.PROVIDER_UNAVAILABLE,
            GeneratedEventEvidenceSession().evaluate(base, manifest(), { error("features") }, null).audit.status)
    }

    @Test fun `attempt budget bounds construction and cancellation propagates`() {
        val base = rule()
        val session = GeneratedEventEvidenceSession(1)
        session.evaluate(base, manifest(), { window(base) }, { provider() })
        assertEquals(HybridEventEvidenceStatus.ATTEMPT_BUDGET_EXHAUSTED,
            session.evaluate(base, manifest(), { error("features") }, { error("runtime") }).audit.status)
        assertThrows(CancellationException::class.java) {
            GeneratedEventEvidenceSession().evaluate(base, manifest(), { window(base) }, { throw CancellationException() })
        }
        try {
            assertThrows(InterruptedException::class.java) {
                GeneratedEventEvidenceSession().evaluate(base, manifest(), { throw InterruptedException() }, { provider() })
            }
            assertTrue(Thread.currentThread().isInterrupted)
        } finally { Thread.interrupted() }
    }

    @Test fun `malformed model identity calibration and feature contracts fail at admission`() {
        assertThrows(IllegalArgumentException::class.java) { manifest(labels = listOf("same", "same")) }
        assertThrows(IllegalArgumentException::class.java) { manifest(labels = List(17) { "class-$it" }) }
        assertThrows(IllegalArgumentException::class.java) {
            EventModelManifest("model", "not-a-digest", "fixture", 2, "labels", listOf("a", "b"), "calibration", "b".repeat(64), EventModelArtifactStatus.GENERATED_FIXTURE)
        }
        assertThrows(IllegalArgumentException::class.java) {
            EventModelManifest("model", modelHash, "fixture", 0, "labels", listOf("a", "b"), "", "b".repeat(64), EventModelArtifactStatus.GENERATED_FIXTURE)
        }
        assertThrows(IllegalArgumentException::class.java) { GeneratedEventEvidenceSession(257) }
        assertThrows(IllegalArgumentException::class.java) { GeneratedEventFeatureWindow("fixture", -1, 0, floatArrayOf(1f)) }
    }

    @Test fun `governed corpus rules events and scores remain authoritative for all provider outcomes`() {
        for (scenario in TelemetryRegressionScenario.entries) {
            val timeline = rules(scenario)
            val original = timeline.windows().toList()
            val merged = EventMergePipeline.build(timeline)
            val score = ScoringPipeline.score(merged)
            for (factory in listOf<() -> GeneratedEventEvidenceProvider>({ provider(doubleArrayOf(1.0, 0.0)) }, { provider(doubleArrayOf(0.0, 1.0)) }, { error("unavailable") })) {
                val session = GeneratedEventEvidenceSession(1)
                val evaluated = original.map { session.evaluate(it, manifest(), { window(it) }, factory).ruleWindow }
                assertEquals(scenario.name, original, evaluated)
                assertEquals(score, ScoringPipeline.score(merged))
            }
            assertEquals(original, timeline.windows().toList())
        }
    }
}
