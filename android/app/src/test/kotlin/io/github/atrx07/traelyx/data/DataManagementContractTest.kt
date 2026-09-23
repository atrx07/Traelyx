package io.github.atrx07.traelyx.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DataManagementContractTest {
    @Test
    fun redactedSummaryIsDeterministicAndContainsNoSensitiveFields() {
        val payload = requireNotNull(RedactedTripSummaryPayload.fromMap(validPayload()))
        val encoded = payload.encode().decodeToString()

        assertTrue(encoded.contains("\"format\": \"traelyx.redacted_trip_summary\""))
        assertTrue(encoded.contains("\"privacy_class\": \"redacted_summary\""))
        assertTrue(encoded.contains("\"contains_precise_location\": false"))
        assertTrue(encoded.contains("\"duration_millis\": 90000"))
        assertTrue(encoded.endsWith("}\n"))
        assertFalse(encoded.contains("tripId", ignoreCase = true))
        assertFalse(encoded.contains("vehicle", ignoreCase = true))
        assertFalse(encoded.contains("latitude", ignoreCase = true))
        assertFalse(encoded.contains("longitude", ignoreCase = true))
        assertFalse(encoded.contains("wall_time", ignoreCase = true))
    }

    @Test
    fun redactedSummaryRejectsUnknownOrInconsistentInputs() {
        assertNull(RedactedTripSummaryPayload.fromMap(validPayload() + ("tripId" to "private")))
        assertNull(RedactedTripSummaryPayload.fromMap(validPayload() + ("distanceMeters" to -1.0)))
        assertNull(RedactedTripSummaryPayload.fromMap(validPayload() + ("completionState" to "perfect")))
        assertNull(RedactedTripSummaryPayload.fromMap(validPayload() + ("scoreEligibility" to 1)))
        assertNull(RedactedTripSummaryPayload.fromMap(validPayload() + ("scoringVersion" to true)))
        assertNull(
            RedactedTripSummaryPayload.fromMap(
                validPayload() + mapOf("overallScore" to 88.0, "scoreEligibility" to null),
            ),
        )
    }

    @Test
    fun bridgeMapsKeepDeletionAndExportStatesExplicit() {
        val deletion = rawTelemetryDeletionMap(
            "00000000-0000-4000-8000-000000000001",
            true,
            42L,
            null,
        )
        assertEquals(1, deletion["contractVersion"])
        assertEquals(true, deletion["deleted"])
        assertEquals(42L, deletion["bytesDeleted"])

        val export = redactedSummaryExportMap(false, 512L, "export_cancelled")
        assertEquals(false, export["exported"])
        assertEquals(false, export["containsPreciseLocation"])
        assertEquals(false, export["containsRawTelemetry"])
        assertEquals("redacted_summary", export["privacyClass"])
        assertEquals("export_cancelled", export["errorCode"])
    }

    private fun validPayload(): Map<String, Any?> = mapOf(
        "durationMillis" to 90_000L,
        "distanceMeters" to 1_234.5678,
        "completionState" to "verified",
        "recoveryState" to "verified",
        "integrityState" to "not_assessed",
        "telemetrySchemaVersion" to 1,
        "eventCount" to 2,
        "overallScore" to 88.5,
        "scoreEligibility" to "verified",
        "scoringVersion" to "score-v1",
    )
}
