package io.github.atrx07.traelyx.guardian

/** No credential leaves this status. Presence alone does not mean push delivery is enabled. */
data class GuardianRecipientStatus(val deviceId: String, val generation: String, val expiresAtEpochMillis: Long) {
    override fun toString() = "GuardianRecipientStatus(redacted)"
}

/** Serial, account-bound local receipt authority. Server confirmation is a separate foreground gate. */
class GuardianRecipientCoordinator(
    private val vault: GuardianRecipientVault,
    private val epochMillis: () -> Long,
) {
    private var owner: String? = null
    private var bound = false

    @Synchronized fun bindOwner(nextOwner: String?) {
        // Refuse all operations while cleanup is uncertain.
        owner = null
        bound = false
        try { nextOwner?.let(::guardianUuid) } catch (error: IllegalArgumentException) {
            vault.erase()
            throw error
        }
        if (nextOwner == null) {
            vault.erase()
        } else {
            val stored = try { vault.readStored() } catch (_: GuardianVaultUnavailable) {
                vault.erase()
                null
            }
            if (stored != null && !stored.validFor(nextOwner, stored.generation, epochMillis())) vault.erase()
        }
        owner = nextOwner
        bound = true
    }

    /** Called only after a guarded signed-in server registration has completed. */
    @Synchronized fun commit(expectedOwner: String, device: GuardianRecipientDevice): GuardianRecipientStatus {
        require(bound && owner == expectedOwner && device.ownerId == expectedOwner)
        val now = epochMillis()
        require(now >= device.registeredAtEpochMillis &&
            now - device.registeredAtEpochMillis < REVIEW_TTL_MILLIS &&
            device.expiresAtEpochMillis > now &&
            device.expiresAtEpochMillis - device.registeredAtEpochMillis <= LOCAL_MAX_LIFETIME_MILLIS)
        vault.write(device)
        return GuardianRecipientStatus(device.deviceId, device.generation, device.expiresAtEpochMillis)
    }

    @Synchronized fun snapshot(expectedOwner: String): GuardianRecipientStatus? {
        require(bound && owner == expectedOwner)
        val stored = vault.readStored() ?: return null
        if (!stored.validFor(expectedOwner, stored.generation, epochMillis())) {
            vault.erase()
            return null
        }
        return GuardianRecipientStatus(stored.deviceId, stored.generation, stored.expiresAtEpochMillis)
    }

    @Synchronized fun disable(expectedOwner: String) {
        require(bound && owner == expectedOwner)
        vault.erase()
    }

    companion object {
        const val REVIEW_TTL_MILLIS = 120_000L
        const val LOCAL_MAX_LIFETIME_MILLIS = 29L * 24 * 60 * 60 * 1000
    }
}
