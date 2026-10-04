package io.github.atrx07.traelyx.guardian

/** Local preflight only. A current server permission check is still required before display. */
internal class GuardianPushPreflight(
    private val vault: GuardianRecipientVault,
    private val marker: GuardianProviderMarker,
    private val epochMillis: () -> Long,
) {
    fun check(data: Map<String, String>, hasNotificationPayload: Boolean): GuardianPushReceiptRequest? {
        val envelope = GuardianPushEnvelope.parse(data, hasNotificationPayload) ?: return null
        return try {
            if (!marker.present()) return null
            val device = vault.readStored() ?: return null
            if (!device.validFor(device.ownerId, envelope.deviceGeneration, epochMillis())) return null
            GuardianPushReceiptRequest(envelope.deliveryId, device.deviceId, device.credential)
        } catch (_: Exception) {
            // A missing key, corrupt vault, or uncertain marker cannot authorize a receipt.
            null
        }
    }
}

/** Transient receipt capability. Never log or persist this value. */
internal class GuardianPushReceiptRequest(
    val deliveryId: String,
    val deviceId: String,
    val credential: String,
) {
    override fun toString() = "GuardianPushReceiptRequest(redacted)"
}
