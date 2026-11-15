package io.github.atrx07.traelyx.data

private val correctionEvents = setOf(
    "EVT_ACCEL_STRONG", "EVT_ACCEL_ABRUPT_TRANSITION", "EVT_BRAKE_STRONG",
    "EVT_BRAKE_ABRUPT_TRANSITION", "EVT_CORNER_HIGH_LOAD_LEFT", "EVT_CORNER_HIGH_LOAD_RIGHT",
    "EVT_CORNER_ABRUPT_ENTRY", "EVT_CORNER_ABRUPT_EXIT", "EVT_ROAD_IMPACT", "EVT_PHONE_MOVED",
)
private val correctionChoices = setOf("correct", "not_this_event", "road_impact", "device_moved", "unsure")

class CorrectionContributionPayload private constructor(private val labels: List<Pair<String, String>>) {
    fun encode(): ByteArray = (
        "{\"format\":\"traelyx_event_corrections\",\"formatVersion\":1,\"consentVersion\":1," +
            "\"consentPurpose\":\"detection_research\",\"consentDeclared\":true," +
            "\"labelProvenance\":\"user_report_unverified\",\"trainingUse\":\"quarantine_only\"," +
            "\"containsPreciseLocation\":false,\"containsRawTelemetry\":false,\"labels\":[" +
            labels.joinToString(",") { (event, choice) ->
                "{\"detectedEvent\":\"$event\",\"reportedLabel\":\"$choice\",\"eventEngineVersion\":1,\"telemetrySchemaVersion\":1}"
            } + "]}\n"
        ).toByteArray(Charsets.UTF_8)

    companion object {
        fun fromMap(value: Map<*, *>?): CorrectionContributionPayload? {
            val header = mapOf(
                "format" to "traelyx_event_corrections", "formatVersion" to 1, "consentVersion" to 1,
                "consentPurpose" to "detection_research", "consentDeclared" to true,
                "labelProvenance" to "user_report_unverified", "trainingUse" to "quarantine_only",
                "containsPreciseLocation" to false, "containsRawTelemetry" to false,
            )
            if (value == null || value.keys != header.keys + "labels" || header.any { (key, expected) -> value[key] != expected }) return null
            val raw = value["labels"] as? List<*> ?: return null
            if (raw.size !in 1..128) return null
            val labels = mutableListOf<Pair<String, String>>()
            for (item in raw) {
                val row = item as? Map<*, *> ?: return null
                if (row.keys != setOf("detectedEvent", "reportedLabel", "eventEngineVersion", "telemetrySchemaVersion") ||
                    row["eventEngineVersion"] != 1 || row["telemetrySchemaVersion"] != 1
                ) return null
                val event = row["detectedEvent"] as? String ?: return null
                val choice = row["reportedLabel"] as? String ?: return null
                if (event !in correctionEvents || choice !in correctionChoices) return null
                labels.add(event to choice)
            }
            val result = CorrectionContributionPayload(labels.toList())
            return result.takeIf { it.encode().size <= 65_536 }
        }
    }
}

fun correctionRecorderIdle(status: Map<*, *>?): Boolean {
    val lifecycle = status?.get("lifecycle") as? Map<*, *> ?: return false
    return lifecycle["contractVersion"] == 1 && lifecycle["state"] == "idle" && lifecycle["active"] == false &&
        lifecycle.containsKey("tripId") && lifecycle["tripId"] == null && lifecycle.containsKey("errorCode") && lifecycle["errorCode"] == null
}

fun correctionExportResult(exported: Boolean, bytes: Int, error: String?): Map<String, Any?> = mapOf(
    "contractVersion" to 1, "exported" to exported, "byteLength" to bytes, "errorCode" to error,
)
