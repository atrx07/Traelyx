package io.github.atrx07.traelyx.data

import java.nio.charset.StandardCharsets
import java.util.Locale

object DataManagementContract {
    const val CONTRACT_VERSION = 1
    const val REDACTED_SUMMARY_FORMAT_VERSION = 1
    const val CHANNEL_NAME = "io.github.atrx07.traelyx/data_management/v1"
    const val DELETE_RAW_TELEMETRY = "deleteRawTelemetry"
    const val EXPORT_REDACTED_SUMMARY = "exportRedactedTripSummary"
}

data class RedactedTripSummaryPayload(
    val durationMillis: Long?,
    val distanceMeters: Double?,
    val completionState: String,
    val recoveryState: String,
    val integrityState: String,
    val telemetrySchemaVersion: Int,
    val eventCount: Int,
    val overallScore: Double?,
    val scoreEligibility: String?,
    val scoringVersion: String?,
) {
    fun encode(): ByteArray {
        val lines = listOf(
            "{",
            "  \"format\": \"traelyx.redacted_trip_summary\",",
            "  \"format_version\": ${DataManagementContract.REDACTED_SUMMARY_FORMAT_VERSION},",
            "  \"privacy_class\": \"redacted_summary\",",
            "  \"contains_precise_location\": false,",
            "  \"contains_raw_telemetry\": false,",
            "  \"duration_millis\": ${durationMillis.jsonNumber()},",
            "  \"distance_meters\": ${distanceMeters.jsonNumber()},",
            "  \"completion_state\": \"$completionState\",",
            "  \"recovery_state\": \"$recoveryState\",",
            "  \"integrity_state\": \"$integrityState\",",
            "  \"telemetry_schema_version\": $telemetrySchemaVersion,",
            "  \"event_count\": $eventCount,",
            "  \"overall_score\": ${overallScore.jsonNumber()},",
            "  \"score_eligibility\": ${scoreEligibility.jsonString()},",
            "  \"scoring_version\": ${scoringVersion.jsonString()}",
            "}",
            "",
        )
        return lines.joinToString("\n").toByteArray(StandardCharsets.UTF_8)
    }

    companion object {
        private val allowedKeys = setOf(
            "durationMillis",
            "distanceMeters",
            "completionState",
            "recoveryState",
            "integrityState",
            "telemetrySchemaVersion",
            "eventCount",
            "overallScore",
            "scoreEligibility",
            "scoringVersion",
        )
        private val evidenceStates = setOf(
            "verified",
            "limited",
            "review_required",
            "unavailable",
            "not_assessed",
        )
        private val versionPattern = Regex("^[A-Za-z0-9._-]{1,64}$")

        fun fromMap(value: Map<String, Any?>?): RedactedTripSummaryPayload? {
            if (value == null || value.keys != allowedKeys) return null
            val duration = value["durationMillis"].optionalLong() ?: if (value["durationMillis"] == null) null else return null
            val distance = value["distanceMeters"].optionalDouble() ?: if (value["distanceMeters"] == null) null else return null
            val completion = value["completionState"] as? String ?: return null
            val recovery = value["recoveryState"] as? String ?: return null
            val integrity = value["integrityState"] as? String ?: return null
            val schemaVersion = value["telemetrySchemaVersion"].requiredInt() ?: return null
            val eventCount = value["eventCount"].requiredInt() ?: return null
            val overallScore = value["overallScore"].optionalDouble() ?: if (value["overallScore"] == null) null else return null
            val scoreEligibility = value["scoreEligibility"] as? String
                ?: if (value["scoreEligibility"] == null) null else return null
            val scoringVersion = value["scoringVersion"] as? String
                ?: if (value["scoringVersion"] == null) null else return null
            if (duration != null && duration < 0L) return null
            if (distance != null && (!distance.isFinite() || distance < 0.0)) return null
            if (completion !in evidenceStates || recovery !in evidenceStates || integrity !in evidenceStates) return null
            if (schemaVersion <= 0 || eventCount < 0) return null
            if (overallScore != null && (!overallScore.isFinite() || overallScore !in 0.0..100.0)) return null
            val scoreFields = listOf(overallScore, scoreEligibility, scoringVersion)
            if (scoreFields.any { it != null } && scoreFields.any { it == null }) return null
            if (scoreEligibility != null && scoreEligibility !in evidenceStates) return null
            if (scoringVersion != null && !versionPattern.matches(scoringVersion)) return null
            return RedactedTripSummaryPayload(
                durationMillis = duration,
                distanceMeters = distance,
                completionState = completion,
                recoveryState = recovery,
                integrityState = integrity,
                telemetrySchemaVersion = schemaVersion,
                eventCount = eventCount,
                overallScore = overallScore,
                scoreEligibility = scoreEligibility,
                scoringVersion = scoringVersion,
            )
        }
    }
}

fun rawTelemetryDeletionMap(
    tripId: String?,
    deleted: Boolean,
    bytesDeleted: Long,
    errorCode: String?,
): Map<String, Any?> = mapOf(
    "contractVersion" to DataManagementContract.CONTRACT_VERSION,
    "tripId" to tripId,
    "deleted" to deleted,
    "bytesDeleted" to bytesDeleted,
    "errorCode" to errorCode,
)

fun redactedSummaryExportMap(
    exported: Boolean,
    byteLength: Long,
    errorCode: String?,
): Map<String, Any?> = mapOf(
    "contractVersion" to DataManagementContract.CONTRACT_VERSION,
    "formatVersion" to DataManagementContract.REDACTED_SUMMARY_FORMAT_VERSION,
    "exported" to exported,
    "containsPreciseLocation" to false,
    "containsRawTelemetry" to false,
    "privacyClass" to "redacted_summary",
    "byteLength" to byteLength,
    "errorCode" to errorCode,
)

private fun Any?.requiredInt(): Int? = when (this) {
    is Int -> this
    is Long -> if (this in Int.MIN_VALUE..Int.MAX_VALUE) toInt() else null
    else -> null
}

private fun Any?.optionalLong(): Long? = when (this) {
    null -> null
    is Int -> toLong()
    is Long -> this
    else -> null
}

private fun Any?.optionalDouble(): Double? = when (this) {
    null -> null
    is Double -> this
    is Float -> toDouble()
    is Int -> toDouble()
    is Long -> toDouble()
    else -> null
}

private fun Long?.jsonNumber(): String = this?.toString() ?: "null"

private fun Double?.jsonNumber(): String = this?.let { String.format(Locale.ROOT, "%.3f", it) } ?: "null"

private fun String?.jsonString(): String = this?.let { "\"$it\"" } ?: "null"
