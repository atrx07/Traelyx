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
    private val newId: () -> String = { UUID.randomUUID().toString() },
    private val newCredential: () -> String = {
        ByteArray(32).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it.toInt() and 255) }
    },
) {
    private var owner: String? = null
    private var bound = false
    private var proposal: GuardianActivationProposal? = null

    @Synchronized fun bindOwner(nextOwner: String?) {
        nextOwner?.let(::guardianUuid)
        if (!bound || owner != nextOwner) proposal = null
        // Clear in-memory authority before any fallible persistence operation.
        owner = null
        bound = false
        if (nextOwner == null) outbox.revoke() else outbox.recover(nextOwner, clock())
        owner = nextOwner
        bound = true
    }

    @Synchronized fun begin(expectedOwner: String, forwardAxis: String, rigidMountConfirmed: Boolean): GuardianActivationProposal {
        require(bound && owner == expectedOwner && rigidMountConfirmed)
        require(forwardAxis in setOf("+x", "-x", "+y", "-y", "+z", "-z"))
        val now = clock()
        proposal?.let { if (!fresh(it.created, now)) proposal = null }
        check(proposal == null) { "Activation review already pending" }
        val activation = newId().also(::guardianUuid)
        val credential = newCredential().also { require(it.matches(Regex("[a-f0-9]{64}"))) }
        // Starting replacement disables the old local lease; failure cannot leave it dispatching.
        eraseAuthority(expectedOwner)
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
        outbox.activate(lease, now)
        return lease
    }

    /** A late failed request must not cancel a newer proposal or another account's lease. */
    @Synchronized fun abort(expectedOwner: String, activationId: String) {
        if (bound && owner == expectedOwner && proposal?.activationId == activationId) proposal = null
    }

    @Synchronized fun disable(expectedOwner: String) {
        require(bound && owner == expectedOwner)
        proposal = null
        eraseAuthority(expectedOwner)
    }

    private fun eraseAuthority(restoreOwner: String) {
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
        return outbox.recover(expectedOwner, clock())
    }

    companion object { const val REVIEW_TTL_MILLIS = 120_000L }
}
