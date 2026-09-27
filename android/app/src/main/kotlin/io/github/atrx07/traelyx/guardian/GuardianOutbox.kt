package io.github.atrx07.traelyx.guardian

import java.util.UUID

/** Persisted attempt identity prevents late callbacks from changing a replacement lease or retry. */
class GuardianDispatchAttempt(val lease: GuardianDriverLease, val alert: GuardianPendingAlert) {
    override fun toString() = "GuardianDispatchAttempt(redacted)"
}

/** One coordinator per app process, called on a worker thread, never on acquisition callbacks. */
class GuardianOutbox(private val vault: GuardianVault) {
    @Synchronized fun activate(lease: GuardianDriverLease, now: GuardianClock) {
        require(lease.valid(now, lease.ownerId))
        val old = vault.read()
        if (old.lease?.activationId == lease.activationId) {
            require(old.lease == lease) // Idempotent retry cannot extend/replace existing authority.
            return
        }
        vault.erase() // A failed replacement can never restore the previous owner's authority.
        vault.write(GuardianVaultSnapshot(lease))
    }

    @Synchronized fun revoke() { vault.erase() }

    /** Recovery performs no IO to a server; invalid consent/boot clears the local capability. */
    @Synchronized fun recover(owner: String, now: GuardianClock): GuardianVaultSnapshot {
        guardianUuid(owner)
        val old = vault.read()
        val lease = old.lease ?: return old
        if (!lease.valid(now, owner)) {
            vault.erase()
            return GuardianVaultSnapshot()
        }
        val alerts = old.alerts.filter {
            now.elapsedMillis >= it.createdAtElapsedMillis && now.epochMillis >= it.occurredAtEpochMillis &&
                now.elapsedMillis - it.createdAtElapsedMillis < GuardianPendingAlert.TTL_MILLIS &&
                now.epochMillis - it.occurredAtEpochMillis < GuardianPendingAlert.TTL_MILLIS
        }.map { it.advance(now.elapsedMillis, now.epochMillis, now.bootId, owner, lease.activationId) }
        return old.copy(alerts = alerts).also { if (it != old) vault.write(it) }
    }

    @Synchronized fun enqueue(
        owner: String, activation: String, detection: GuardianDetection, cooldowns: GuardianSafetyCooldowns,
        now: GuardianClock, eventId: String = UUID.randomUUID().toString(),
    ): GuardianPendingAlert {
        val old = recover(owner, now)
        val lease = requireNotNull(old.lease)
        require(lease.activationId == activation && old.alerts.size < GuardianVaultSnapshot.MAX_ALERTS)
        require(now.elapsedMillis <= Long.MAX_VALUE / 1_000_000)
        val nowNanos = now.elapsedMillis * 1_000_000
        require(detection.detectedAtNanos <= nowNanos && nowNanos - detection.detectedAtNanos <= 3_000_000_000L)
        // A replayed detection cannot reset cooldowns or manufacture a second identity.
        require((cooldowns.lastSevereNanos ?: -1) >= (old.cooldowns.lastSevereNanos ?: -1))
        require((cooldowns.lastCrashNanos ?: -1) >= (old.cooldowns.lastCrashNanos ?: -1))
        if (detection.kind == GuardianAlertKind.POSSIBLE_CRASH) {
            require(cooldowns.lastCrashNanos == detection.detectedAtNanos)
            require((old.cooldowns.lastCrashNanos ?: -1) < detection.detectedAtNanos)
        } else {
            require(cooldowns.lastSevereNanos == detection.detectedAtNanos)
            require((old.cooldowns.lastSevereNanos ?: -1) < detection.detectedAtNanos)
        }
        val alert = GuardianPendingAlert(eventId, owner, activation, detection.kind, now.epochMillis,
            now.elapsedMillis, now.bootId, detection.ruleVersion)
        vault.write(old.copy(cooldowns = cooldowns, alerts = old.alerts + alert))
        return alert
    }

    @Synchronized fun cancel(owner: String, eventId: String, now: GuardianClock): Boolean {
        val old = recover(owner, now)
        val alert = old.alerts.find { it.eventId == eventId } ?: return false
        val cancelled = alert.cancel()
        if (cancelled.state != GuardianSendState.CANCELLED) return false
        if (cancelled != alert) vault.write(old.copy(alerts = old.alerts.map { if (it.eventId == eventId) cancelled else it }))
        return true
    }

    /** Returns authority only after reservation is durably committed. */
    @Synchronized fun reserveNext(owner: String, now: GuardianClock): GuardianDispatchAttempt? {
        val old = recover(owner, now)
        val lease = old.lease ?: return null
        val alert = old.alerts.firstOrNull { it.readyToAttempt(now.elapsedMillis) } ?: return null
        val reserved = alert.reserveAttempt(now.elapsedMillis)
        vault.write(old.copy(alerts = old.alerts.map { if (it.eventId == reserved.eventId) reserved else it }))
        return GuardianDispatchAttempt(lease, reserved)
    }

    @Synchronized fun complete(attempt: GuardianDispatchAttempt, accepted: Boolean, denied: Boolean, now: GuardianClock) {
        val old = vault.read()
        // A late callback must not tear down the new owner's activation.
        if (old.lease != attempt.lease) return
        val live = recover(attempt.lease.ownerId, now)
        val alert = live.alerts.find { it.eventId == attempt.alert.eventId } ?: return
        if (alert != attempt.alert) return
        val updated = alert.result(accepted, denied)
        vault.write(live.copy(alerts = live.alerts.map { if (it.eventId == alert.eventId) updated else it }))
    }
}
