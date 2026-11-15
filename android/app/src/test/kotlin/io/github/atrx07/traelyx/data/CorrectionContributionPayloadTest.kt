package io.github.atrx07.traelyx.data

import org.junit.Assert.*
import org.junit.Test

class CorrectionContributionPayloadTest {
    private fun payload(): Map<String, Any> = mapOf(
        "format" to "traelyx_event_corrections", "formatVersion" to 1, "consentVersion" to 1,
        "consentPurpose" to "detection_research", "consentDeclared" to true,
        "labelProvenance" to "user_report_unverified", "trainingUse" to "quarantine_only",
        "containsPreciseLocation" to false, "containsRawTelemetry" to false,
        "labels" to listOf(mapOf("detectedEvent" to "EVT_BRAKE_STRONG", "reportedLabel" to "unsure", "eventEngineVersion" to 1, "telemetrySchemaVersion" to 1)),
    )

    @Test fun categoricalReportEncodesWithoutIdentityTimeOrTelemetry() {
        val encoded = requireNotNull(CorrectionContributionPayload.fromMap(payload())).encode().toString(Charsets.UTF_8)
        assertTrue(encoded.contains("\"trainingUse\":\"quarantine_only\""))
        assertTrue(encoded.contains("\"consentDeclared\":true"))
        for (key in listOf("tripId", "eventId", "userId", "timestamp", "latitude", "measurements")) assertFalse(encoded.contains(key))
        assertTrue(encoded.toByteArray().size < 65_536)
    }

    @Test fun privacyExpansionsAndUnsupportedConsentAreRejected() {
        for (key in listOf("tripId", "eventId", "userId", "timestamp", "route", "rawTelemetry", "features")) {
            assertNull(CorrectionContributionPayload.fromMap(payload() + (key to "private")))
            val label = (payload()["labels"] as List<*>).single() as Map<*, *>
            assertNull(CorrectionContributionPayload.fromMap(payload() + ("labels" to listOf(label + (key to "private")))))
        }
        for ((key, value) in listOf("consentDeclared" to false, "consentVersion" to 2, "formatVersion" to true,
            "trainingUse" to "eligible", "containsRawTelemetry" to true, "containsPreciseLocation" to true)) {
            assertNull(CorrectionContributionPayload.fromMap(payload() + (key to value)))
        }
    }

    @Test fun sizeKindsCountsAndUnknownLabelsFailClosed() {
        assertNull(CorrectionContributionPayload.fromMap(null))
        assertNull(CorrectionContributionPayload.fromMap(payload() + ("labels" to emptyList<Any>())))
        val label = (payload()["labels"] as List<*>).single() as Map<*, *>
        assertNull(CorrectionContributionPayload.fromMap(payload() + ("labels" to List(129) { label })))
        for ((key, value) in listOf("eventEngineVersion" to true, "telemetrySchemaVersion" to 2, "reportedLabel" to "crash_confirmed", "detectedEvent" to "unknown")) {
            assertNull(CorrectionContributionPayload.fromMap(payload() + ("labels" to listOf(label + (key to value)))))
        }
    }

    @Test fun onlyKnownCompletelyIdleRecorderCanExport() {
        val idle = mapOf("contractVersion" to 1, "state" to "idle", "active" to false, "tripId" to null, "errorCode" to null)
        assertTrue(correctionRecorderIdle(mapOf("lifecycle" to idle)))
        assertFalse(correctionRecorderIdle(null))
        for ((key, value) in listOf("state" to "recording", "state" to "error", "active" to true, "contractVersion" to 2, "tripId" to "active", "errorCode" to "unknown")) {
            assertFalse(correctionRecorderIdle(mapOf("lifecycle" to (idle + (key to value)))))
        }
        assertFalse(correctionRecorderIdle(mapOf("lifecycle" to (idle - "tripId"))))
    }
}
