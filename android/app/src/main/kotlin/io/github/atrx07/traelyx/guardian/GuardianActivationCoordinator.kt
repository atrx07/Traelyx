package io.github.atrx07.traelyx.guardian

import java.security.SecureRandom
import java.util.UUID

/** Short-lived proposal, returned only to the account-bound foreground cloud coordinator. */
class GuardianActivationProposal internal constructor(
    val ownerId: String,
    val activationId: String,
    val credential: String,
    val forwardAxis: String,
    internal val created: GuardianClock,
) {
    override fun toString() = "GuardianActivationProposal(redacted)"
}

/**
 * Two-phase local activation. Call on a worker thread, once per app process.
 * This class never authenticates a user, registers FCM, evaluates samples or sends an alert.
 * The foreground Auth owner must be bound before beginning, then checked again before commit.
 */
class GuardianActivationCoordinator(
    private val outbox: GuardianOutbox,
    private val clock: () -> GuardianClock,
    private val revokeJournal: GuardianDriverRevokeJournal,
    private val newId: () -> String = { UUID.randomUUID().toString() },
    private val newCredential: () -> String = {
        ByteArray(32).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it.toInt() and 255) }
    },
) {
    private var owner: String? = null
    private var bound = false
    private var proposal: GuardianActivationProposal? = null
    private var recordingActivationId: String? = null

    @Synchronized fun bindOwner(nextOwner: String?) {
        nextOwner?.let(::guardianUuid)
        if (!bound || owner != nextOwner) {
            proposal = null
            recordingActivationId = null
        }
        // Clear in-memory authority before any fallible persistence operation.
        owner = null
        bound = false
        if (nextOwner == null) outbox.revoke(revokeJournal::record)
        else outbox.recover(nextOwner, clock(), revokeJournal::record)
        owner = nextOwner
        bound = true
    }

    @Synchronized fun begin(expectedOwner: String, forwardAxis: String, rigidMountConfirmed: Boolean): GuardianActivationProposal {
        require(bound && owner == expectedOwner && rigidMountConfirmed)
        require(forwardAxis in setOf("+x", "-x", "+y", "-y", "+z", "-z"))
        check(proposal == null) { "Activation review already pending" }
        // Replacement must first settle its old exact identity. Never overwrite it.
        stop(expectedOwner)
        val stops = revokeJournal.pending()
        check(stops.size < GuardianDriverRevokeJournalCodec.MAX_TICKETS &&
            stops.none { it.ownerId == expectedOwner }) { "Driver stop confirmation pending" }
        val now = clock()
        val activation = newId().also(::guardianUuid)
        val credential = newCredential().also { require(it.matches(Regex("[a-f0-9]{64}"))) }
        // A lost bridge reply or process death must leave exact server cleanup possible.
        revokeJournal.record(GuardianDriverRevokeTicket(expectedOwner, activation))
        return GuardianActivationProposal(expectedOwner, activation, credential, forwardAxis, now).also { proposal = it }
    }

    @Synchronized fun commit(expectedOwner: String, activationId: String, serverExpiresEpochMillis: Long): GuardianDriverLease {
        require(bound && owner == expectedOwner)
        val pending = requireNotNull(proposal)
        require(pending.ownerId == expectedOwner && pending.activationId == activationId)
        proposal = null // Single-use even if verification or disk commit fails.
        val now = clock()
        val start = pending.created
        require(fresh(start, now))
        require(start.epochMillis <= Long.MAX_VALUE - GuardianDriverLease.MAX_DURATION_MILLIS)
        val expiry = minOf(serverExpiresEpochMillis, start.epochMillis + GuardianDriverLease.MAX_DURATION_MILLIS)
        require(expiry > now.epochMillis)
        val lease = GuardianDriverLease(expectedOwner, activationId, pending.credential,
            start.epochMillis, start.elapsedMillis, expiry, start.bootId, pending.forwardAxis)
        val ticket = GuardianDriverRevokeTicket(expectedOwner, activationId)
        check(ticket in revokeJournal.pending()) { "Activation reservation unavailable" }
        try {
            outbox.activate(lease, now)
            revokeJournal.confirm(ticket)
        } catch (failure: Exception) {
            eraseAuthority(expectedOwner)
            throw failure
        }
        recordingActivationId = lease.activationId
        return lease
    }

    /** A late failed request must not cancel a newer proposal or another account's lease. */
    @Synchronized fun abort(expectedOwner: String, activationId: String) {
        guardianUuid(expectedOwner); guardianUuid(activationId)
        if (!bound || owner != expectedOwner) return
        if (proposal?.activationId == activationId) proposal = null
        val current = try { outbox.activationToRevoke(expectedOwner) } catch (failure: Exception) {
            eraseAuthority(expectedOwner)
            throw failure
        }
        if (current == activationId) stop(expectedOwner)
    }

    /** Erase first, then return only the activation ID needed for a guarded server revoke. */
    @Synchronized fun stop(expectedOwner: String): String? {
        require(bound && owner == expectedOwner)
        proposal = null
        try {
            val activation = outbox.activationToRevoke(expectedOwner)
            activation?.let { revokeJournal.record(GuardianDriverRevokeTicket(expectedOwner, it)) }
            return activation
        } finally {
            eraseAuthority(expectedOwner)
        }
    }

    @Synchronized fun pendingRevokes(expectedOwner: String): List<GuardianDriverRevokeTicket> {
        require(bound && owner == expectedOwner)
        return revokeJournal.pending().filter { it.ownerId == expectedOwner }
    }

    @Synchronized fun confirmRevoke(expectedOwner: String, activation: String) {
        require(bound && owner == expectedOwner)
        check(proposal?.activationId != activation && outbox.activationToRevoke(expectedOwner) != activation) {
            "Stop local activation before confirming revoke"
        }
        revokeJournal.confirm(GuardianDriverRevokeTicket(expectedOwner, activation))
    }

    @Synchronized fun disable(expectedOwner: String) {
        stop(expectedOwner)
    }

    private fun eraseAuthority(restoreOwner: String) {
        recordingActivationId = null
        owner = null
        bound = false
        outbox.revoke()
        owner = restoreOwner
        bound = true
    }

    private fun fresh(start: GuardianClock, now: GuardianClock) =
        now.bootId == start.bootId && now.epochMillis >= start.epochMillis && now.elapsedMillis >= start.elapsedMillis &&
            now.epochMillis - start.epochMillis < REVIEW_TTL_MILLIS && now.elapsedMillis - start.elapsedMillis < REVIEW_TTL_MILLIS

    /** Read-only local lease status; presence does not imply that monitoring/delivery is running. */
    @Synchronized fun snapshot(expectedOwner: String): GuardianVaultSnapshot {
        require(bound && owner == expectedOwner)
        return outbox.recover(expectedOwner, clock(), revokeJournal::record)
    }

    /** A restored lease is status/outbox evidence, not permission to restart live evaluation. */
    @Synchronized fun recordingSnapshot(): GuardianVaultSnapshot? {
        val current = owner
        if (!bound || current == null || recordingActivationId == null) return null
        val snapshot = outbox.recover(current, clock(), revokeJournal::record)
        return snapshot.takeIf { it.lease?.activationId == recordingActivationId }
    }

    companion object { const val REVIEW_TTL_MILLIS = 120_000L }
}
