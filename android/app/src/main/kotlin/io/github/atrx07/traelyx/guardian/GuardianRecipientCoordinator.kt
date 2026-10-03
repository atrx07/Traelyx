package io.github.atrx07.traelyx.guardian

/** No credential leaves this status. Presence alone does not mean push delivery is enabled. */
data class GuardianRecipientStatus(val deviceId: String, val generation: String, val expiresAtEpochMillis: Long) {
    override fun toString() = "GuardianRecipientStatus(redacted)"
}

/** Serial, account-bound local receipt authority. Server confirmation is a separate foreground gate. */
class GuardianRecipientCoordinator(
    private val vault: GuardianRecipientVault,
    private val revokeJournal: GuardianRecipientRevokeJournal,
    private val epochMillis: () -> Long,
) {
    private var owner: String? = null
    private var bound = false

    @Synchronized fun bindOwner(nextOwner: String?) {
        // Refuse all operations while cleanup is uncertain.
        owner = null
        bound = false
        try { nextOwner?.let(::guardianUuid) } catch (error: IllegalArgumentException) {
            dropStored()
            throw error
        }
        if (nextOwner == null) {
            dropStored()
        } else {
            val stored = try { vault.readStored() } catch (_: GuardianVaultUnavailable) {
                vault.erase()
                null
            }
            if (stored != null && !stored.validFor(nextOwner, stored.generation, epochMillis())) {
                recordBeforeErase(stored)
                vault.erase()
            }
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
        vault.readStored()?.takeIf { it != device }?.let(::recordBeforeErase)
        vault.write(device)
        return GuardianRecipientStatus(device.deviceId, device.generation, device.expiresAtEpochMillis)
    }

    @Synchronized fun snapshot(expectedOwner: String): GuardianRecipientStatus? {
        require(bound && owner == expectedOwner)
        val stored = vault.readStored() ?: return null
        if (!stored.validFor(expectedOwner, stored.generation, epochMillis())) {
            recordBeforeErase(stored)
            vault.erase()
            return null
        }
        return GuardianRecipientStatus(stored.deviceId, stored.generation, stored.expiresAtEpochMillis)
    }

    @Synchronized fun disable(expectedOwner: String) {
        require(bound && owner == expectedOwner)
        dropStored()
    }

    /** Expose only bound-owner IDs; Flutter separately checks signed-in Auth before server use. */
    @Synchronized fun pendingRevokes(expectedOwner: String): List<GuardianRecipientRevokeTicket> {
        require(bound && owner == expectedOwner)
        return revokeJournal.pending().filter { it.ownerId == expectedOwner }
    }

    /** Called after the server confirms this exact row is revoked. */
    @Synchronized fun confirmPendingRevoke(ticket: GuardianRecipientRevokeTicket) {
        require(bound && owner == ticket.ownerId)
        revokeJournal.confirm(ticket)
    }

    /** Explicit sign-out has already revoked this exact local row on the server. */
    @Synchronized fun disableConfirmed(expectedOwner: String, deviceId: String, generation: String) {
        require(bound && owner == expectedOwner)
        guardianUuid(deviceId); guardianUuid(generation)
        val stored = vault.readStored() ?: return
        require(stored.ownerId == expectedOwner && stored.deviceId == deviceId && stored.generation == generation)
        revokeJournal.confirm(GuardianRecipientRevokeTicket(expectedOwner, deviceId, generation))
        vault.erase()
    }

    private fun dropStored() {
        val stored = try { vault.readStored() } catch (_: GuardianVaultUnavailable) {
            vault.erase()
            return
        }
        if (stored != null) recordBeforeErase(stored)
        vault.erase()
    }

    private fun recordBeforeErase(stored: GuardianRecipientDevice) {
        revokeJournal.record(GuardianRecipientRevokeTicket(stored.ownerId, stored.deviceId, stored.generation))
    }

    companion object {
        const val REVIEW_TTL_MILLIS = 120_000L
        const val LOCAL_MAX_LIFETIME_MILLIS = 29L * 24 * 60 * 60 * 1000
    }
}
