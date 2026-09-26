package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import org.junit.Assert.*
import org.junit.Test

class LocalTripAnalysisTest {
    @Test
    fun `complete production pipeline supports a governed full-evidence synthetic trip`() {
        val base = TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.STATIONARY)
        val accelerometer = base.records.filterIsInstance<TelemetrySampleRecord.Imu>()
            .first { it.sample.sensorType == ImuSensorType.ACCELEROMETER }.sample
        val gyroscope = base.records.filterIsInstance<TelemetrySampleRecord.Imu>()
            .first { it.sample.sensorType == ImuSensorType.GYROSCOPE }.sample
        val gnss = base.records.filterIsInstance<TelemetrySampleRecord.Gnss>().first().sample
        // 80s, synthetic equatorial origin, stationary endpoints and three modest control
        // opportunities. No private recording, phone correction or threshold override.
        val records = buildList {
            var distance = 0.0
            for (millis in 0L..80_000L step 10L) {
                val nanos = millis * 1_000_000
                val longitudinal = when (millis) { in 20_000..20_999 -> 1f; in 40_000..40_999 -> -1f; else -> 0f }
                val lateral = if (millis in 60_000..60_999) -1f else 0f
                add(TelemetrySampleRecord.Imu(accelerometer.copy(tripElapsedNanos=nanos,
                    sourceTimestampNanos=accelerometer.sourceTimestampNanos+nanos,
                    x=accelerometer.x+lateral,y=accelerometer.y+longitudinal)))
                add(TelemetrySampleRecord.Imu(gyroscope.copy(tripElapsedNanos=nanos,
                    sourceTimestampNanos=gyroscope.sourceTimestampNanos+nanos)))
                if (millis % 100L == 0L) {
                    val speed = if (millis in 5_000L until 75_000L) 10f else 0f
                    distance += speed * 0.1
                    add(TelemetrySampleRecord.Gnss(gnss.copy(tripElapsedNanos=nanos,
                        sourceTimestampNanos=requireNotNull(gnss.sourceTimestampNanos)+nanos,
                        sourceWallTimeUtcEpochMillis=requireNotNull(gnss.sourceWallTimeUtcEpochMillis)+millis,
                        latitudeDegrees=Math.toDegrees(distance/6_371_008.8),
                        speedMetresPerSecond=speed)))
                }
            }
        }.sortedWith(TELEMETRY_SAMPLE_COMPARATOR)
        val chunks = base.copy(records=records).encodedChunks()
        val result = LocalTripAnalysis.analyze(chunks, "top")
        val score = result["score"] as Map<*, *>
        assertEquals("CONSISTENT", result["comparisonState"])
        assertEquals("CALIBRATED", result["calibrationState"])
        assertEquals("full", score["state"])
        assertEquals("ELIGIBLE", score["rankingStatus"])
        val dimensions = score["dimensions"] as Map<*, *>
        val smoothness = dimensions["SCORE_SMOOTHNESS"] as Map<*, *>
        assertTrue((smoothness["movingNanos"] as Long) >= 60_000_000_000L)
        assertEquals("verified", (score["integrity"] as Map<*, *>)["state"])
        // Optional, synthetic-only export for physical bridge QA; absent in ordinary tests.
        System.getenv("TRAELYX_ANALYSIS_FIXTURE_OUTPUT")?.let { path ->
            val directory = java.io.File(path)
            require(directory.isAbsolute)
            directory.mkdirs()
            chunks.forEachIndexed { index, bytes ->
                java.io.File(directory, "%010d.tlxc".format(index)).writeBytes(bytes)
            }
        }
    }
    @Test
    fun `production adapter preserves conservative evidence and deterministic audit`() {
        val fixture = TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.SMOOTH_STRAIGHT)
        val chunks = fixture.encodedChunks()
        val first = LocalTripAnalysis.analyze(chunks, "top")
        assertEquals(first, LocalTripAnalysis.analyze(chunks, "top"))
        assertEquals(1, first["analysisVersion"])
        assertEquals(64, (first["sourceDigest"] as String).length)
        val score = first["score"] as Map<*, *>
        // This 12s fixture has no later 30s comparison window: never invent full eligibility.
        assertNotEquals("ELIGIBLE", score["rankingStatus"])
        assertNotEquals("full", score["state"])
        assertTrue(first.containsKey("referenceCalibration"))
        assertFalse(first.containsKey("latitude"))
    }

    @Test
    fun `invalid mount or corrupt source cannot yield an analysis`() {
        val chunks = TelemetryRegressionFixtureCorpus.generate(TelemetryRegressionScenario.STATIONARY).encodedChunks()
        assertThrows(IllegalStateException::class.java) { LocalTripAnalysis.analyze(chunks, "assumed") }
        val corrupt = chunks.map { it.copyOf() }
        corrupt.first()[0] = 0
        assertThrows(IllegalArgumentException::class.java) { LocalTripAnalysis.analyze(corrupt, "top") }
    }
}
