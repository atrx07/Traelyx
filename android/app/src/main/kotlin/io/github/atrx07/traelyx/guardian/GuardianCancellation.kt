package io.github.atrx07.traelyx.guardian

data class GuardianEventReference(val ownerId: String, val activationId: String, val eventId: String) {
    init { guardianUuid(ownerId); guardianUuid(activationId); guardianUuid(eventId) }
    override fun toString() = "GuardianEventReference(redacted)"
}

interface GuardianCancellationNotice {
    fun available(): Boolean
    /** True only when the exact notification is observable as active, not merely submitted. */
    fun show(reference: GuardianEventReference, expiresAfterMillis: Long): Boolean
    fun present(reference: GuardianEventReference): Boolean
    fun remove(reference: GuardianEventReference)
}

/** Control-worker only. Proof is deliberately not restored across process death. No network IO. */
class GuardianCancellationControls(
    private val outbox: GuardianOutbox,
    private val authority: () -> GuardianVaultSnapshot?,
    private val clock: () -> GuardianClock,
    private val notices: GuardianCancellationNotice,
) {
    private data class Offer(val lease: GuardianDriverLease, val alert: GuardianPendingAlert,
        val at: GuardianClock, var matured: Boolean = false)
    private val offers = mutableMapOf<String, Offer>()
    private val posted = mutableSetOf<GuardianEventReference>()
    private val submittedAt = mutableMapOf<GuardianEventReference, GuardianClock>()
    private val withdrawn = mutableSetOf<GuardianEventReference>()
    private var failed = false

    /** Invalidate before owner/Stop/replacement. Never removes recipient notices. */
    fun invalidate() {
        offers.clear()
        withdrawn.clear()
        submittedAt.clear()
        val old = posted.toList()
        posted.clear()
        old.forEach { runCatching { notices.remove(it) } }
        failed = false
    }

    /** Called on the control worker after enqueue and by the one-shot alert scheduler. */
    fun refresh() {
        if (failed) return
        try {
            val now = clock()
            val snapshot = current(now)
            val lease = snapshot?.lease
            val live = snapshot?.alerts.orEmpty().filter { active(it, now) }
            val references = live.filter { it.attempts == 0 }.map(::reference).toSet()
            withdrawn.retainAll(references)
            submittedAt.keys.retainAll(references)
            posted.filter { it !in references }.toList().forEach { notices.remove(it); posted.remove(it) }
            offers.entries.removeAll { (_, offer) ->
                offer.lease != lease || live.none { sameEvent(it, offer.alert) } ||
                    (!offer.matured && live.any { sameEvent(it, offer.alert) && it.attempts > 0 })
            }
            offers.values.toList().forEach { check(ordered(it.at, now)); observe(it, now) }
            if (lease == null) return
            for (alert in live.filter { it.attempts == 0 }) {
                if (offers.containsKey(alert.eventId) || reference(alert) in withdrawn || !notices.available()) continue
                val ref = reference(alert)
                submittedAt.putIfAbsent(ref, now)
                posted.add(ref) // Also clean a submission that throws or is not observable yet.
                val lifetime = minOf(GuardianPendingAlert.TTL_MILLIS - (now.elapsedMillis - alert.createdAtElapsedMillis),
                    GuardianPendingAlert.TTL_MILLIS - (now.epochMillis - alert.occurredAtEpochMillis),
                    lease.expiresEpochMillis - now.epochMillis,
                    lease.expiresEpochMillis - lease.startedEpochMillis - (now.elapsedMillis - lease.startedElapsedMillis))
                if (!notices.show(ref, lifetime)) continue
                val after = clock()
                check(ordered(now, after))
                if (current(after)?.lease != lease || !active(alert, after)) {
                    notices.remove(ref); posted.remove(ref)
                    continue
                }
                check(offers.size < GuardianVaultSnapshot.MAX_ALERTS)
                offers[alert.eventId] = Offer(lease, alert, after)
            }
        } catch (_: Exception) { failClosed() }
    }

    /** Independent of recorder lifetime. No UI metadata is used to authorize scheduling. */
    internal fun nextRefreshAt(): Long? {
        if (failed) return null
        return try {
            val now = clock()
            val snapshot = current(now) ?: return null
            val lease = snapshot.lease ?: return null
            snapshot.alerts.filter { active(it, now) }.minOfOrNull { alert ->
                var delay = minOf(
                    GuardianPendingAlert.TTL_MILLIS - (now.elapsedMillis - alert.createdAtElapsedMillis),
                    GuardianPendingAlert.TTL_MILLIS - (now.epochMillis - alert.occurredAtEpochMillis),
                    lease.expiresEpochMillis - now.epochMillis,
                    lease.expiresEpochMillis - lease.startedEpochMillis - (now.elapsedMillis - lease.startedElapsedMillis))
                val offer = offers[alert.eventId]
                if (offer != null && !offer.matured) {
                    check(ordered(offer.at, now))
                    delay = minOf(delay, maxOf(1L, remaining(offer, now)), 1_000L)
                } else if (offer == null && reference(alert) !in withdrawn) {
                    submittedAt[reference(alert)]?.let { submitted ->
                        check(ordered(submitted, now))
                        // Android notification submission is asynchronous. Bound automatic
                        // confirmation checks; a later explicit refresh can retry observation.
                        val left = 3_000L - (now.elapsedMillis - submitted.elapsedMillis)
                        if (left > 0) delay = minOf(delay, left, 1_000L)
                    }
                }
                Math.addExact(now.elapsedMillis, maxOf(1L, delay))
            }
        } catch (_: Exception) { failClosed(); null }
    }

    /** Future dispatch gate; checking this never posts a notification or reserves an attempt. */
    fun allows(alert: GuardianPendingAlert): Boolean {
        if (failed) return false
        return try {
            val now = clock()
            val snapshot = current(now) ?: return false
            val offer = offers[alert.eventId] ?: return false
            check(ordered(offer.at, now))
            offer.lease == snapshot.lease && sameEvent(alert, offer.alert) &&
                snapshot.alerts.any { it == alert } && active(alert, now) &&
                (offer.matured || (alert.attempts == 0 && observe(offer, now))) && notices.available()
        } catch (_: Exception) { failClosed(); false }
    }

    fun views(owner: String): List<Map<String, Any?>> {
        guardianUuid(owner)
        check(!failed) { "Guardian cancellation unavailable" }
        try {
            val now = clock()
            val snapshot = current(now) ?: return emptyList()
            require(snapshot.lease?.ownerId == owner)
            return snapshot.alerts.map { alert ->
                val advanced = alert.advance(now.elapsedMillis, now.epochMillis, now.bootId,
                    owner, snapshot.lease.activationId)
                val offer = offers[alert.eventId]?.takeIf { it.lease == snapshot.lease && sameEvent(it.alert, alert) }
                offer?.let { check(ordered(it.at, now)) }
                mapOf("activationId" to alert.consentGeneration, "eventId" to alert.eventId,
                    "kind" to alert.kind.wireName, "state" to advanced.state.name.lowercase(),
                    "canCancel" to (active(advanced, now) && advanced.attempts == 0),
                    "cancellationReadyInMillis" to offer?.let { remaining(it, now) })
            }
        } catch (failure: Exception) { failClosed(); throw failure }
    }

    fun cancel(ref: GuardianEventReference): Boolean {
        if (failed) return false
        return try {
            val now = clock()
            val snapshot = current(now) ?: return false
            val lease = snapshot.lease ?: return false
            if (lease.ownerId != ref.ownerId || lease.activationId != ref.activationId) return false
            val alert = snapshot.alerts.find { it.eventId == ref.eventId } ?: return false
            if (!active(alert, now) || alert.attempts != 0) return false
            if (!outbox.cancel(ref.ownerId, ref.eventId, now)) return false
            offers.remove(ref.eventId)
            posted.remove(ref)
            runCatching { notices.remove(ref) } // Durable cancellation already succeeded.
            true
        } catch (_: Exception) { failClosed(); false }
    }

    private fun current(now: GuardianClock): GuardianVaultSnapshot? = authority()?.takeIf {
        it.lease?.valid(now, it.lease.ownerId) == true
    }
    private fun active(alert: GuardianPendingAlert, now: GuardianClock): Boolean =
        alert.advance(now.elapsedMillis, now.epochMillis, now.bootId,
            alert.ownerId, alert.consentGeneration).state in setOf(GuardianSendState.CANCELLABLE, GuardianSendState.QUEUED)
    private fun reference(alert: GuardianPendingAlert) = GuardianEventReference(alert.ownerId, alert.consentGeneration, alert.eventId)
    private fun sameEvent(a: GuardianPendingAlert, b: GuardianPendingAlert) =
        a.copy(state = b.state, attempts = b.attempts, nextAttemptAtElapsedMillis = b.nextAttemptAtElapsedMillis) == b
    private fun ordered(before: GuardianClock, after: GuardianClock) = before.bootId == after.bootId &&
        after.epochMillis >= before.epochMillis && after.elapsedMillis >= before.elapsedMillis
    private fun remaining(offer: Offer, now: GuardianClock) = maxOf(0,
        GuardianPendingAlert.CANCEL_WINDOW_MILLIS - (now.elapsedMillis - offer.at.elapsedMillis),
        GuardianPendingAlert.CANCEL_WINDOW_MILLIS - (now.epochMillis - offer.at.epochMillis))
    private fun observe(offer: Offer, now: GuardianClock): Boolean {
        if (offer.matured) return true
        val ref = reference(offer.alert)
        if (!notices.available() || !notices.present(ref)) {
            offers.remove(offer.alert.eventId)
            withdrawn.add(ref) // No repeated posting after dismissal during the window.
            return false
        }
        if (remaining(offer, now) == 0L) offer.matured = true
        return offer.matured
    }
    private fun failClosed() { invalidate(); failed = true }
}
