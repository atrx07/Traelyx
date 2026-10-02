package io.github.atrx07.traelyx.guardian

/** Parses the fixed, data-only FCM contract before any local authority is consulted. */
internal class GuardianPushEnvelope private constructor(
    val deliveryId: String,
    val deviceGeneration: String,
) {
    override fun toString() = "GuardianPushEnvelope(redacted)"

    companion object {
        private val fields = setOf("schema_version", "delivery_id", "device_generation")
        private val uuid = Regex("^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$")

        fun parse(data: Map<String, String>, hasNotificationPayload: Boolean): GuardianPushEnvelope? {
            if (hasNotificationPayload || data.keys != fields || data["schema_version"] != "1") return null
            val delivery = data["delivery_id"] ?: return null
            val generation = data["device_generation"] ?: return null
            if (!uuid.matches(delivery) || !uuid.matches(generation)) return null
            return GuardianPushEnvelope(delivery, generation)
        }
    }
}
