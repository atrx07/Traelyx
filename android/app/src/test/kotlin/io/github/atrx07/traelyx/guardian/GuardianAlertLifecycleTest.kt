package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianAlertLifecycleTest {
    private val initial = GuardianPendingAlert(
        eventId = "11111111-1111-4111-8111-111111111111",
        ownerId = "22222222-2222-4222-8222-222222222222",
        consentGeneration = "33333333-3333-4333-8333-333333333333",
        kind = GuardianAlertKind.POSSIBLE_CRASH,
        occurredAtEpochMillis = 1_800_000_000_000L,
        createdAtElapsedMillis = 1000,
        bootId = "synthetic-boot",
    )

    @Test fun `thirty second cancellation is mandatory and expiration exact`() {
        assertEquals(GuardianSendState.CANCELLABLE, advance(29_999).state)
        assertEquals(GuardianSendState.QUEUED, advance(30_000).state)
        assertEquals(GuardianSendState.EXPIRED, advance(600_000).state)
        assertFalse(initial.readyToAttempt(31_000))
        assertTrue(advance(30_000).readyToAttempt(31_000))
    }

    @Test fun `sign out account switch consent replacement and reboot never send old events`() {
        assertEquals(GuardianSendState.CONSENT_REVOKED, initial.advance(31_000,
            initial.occurredAtEpochMillis + 30_000, initial.bootId, null, initial.consentGeneration).state)
        assertEquals(GuardianSendState.CONSENT_REVOKED, initial.advance(31_000,
            initial.occurredAtEpochMillis + 30_000, initial.bootId, initial.ownerId, "changed").state)
        assertEquals(GuardianSendState.EXPIRED, initial.advance(31_000,
            initial.occurredAtEpochMillis + 30_000, "another-boot", initial.ownerId, initial.consentGeneration).state)
    }

    @Test fun `clock rollback and elapsed reset expire rather than extending alert lifetime`() {
        assertEquals(GuardianSendState.EXPIRED, initial.advance(0, initial.occurredAtEpochMillis,
            initial.bootId, initial.ownerId, initial.consentGeneration).state)
        assertEquals(GuardianSendState.EXPIRED, initial.advance(31_000, initial.occurredAtEpochMillis - 1,
            initial.bootId, initial.ownerId, initial.consentGeneration).state)
    }

    @Test fun `retry reservations survive process loss retain identity and bound exponential delay`() {
        var alert = advance(30_000)
        var time = 31_000L
        repeat(6) { index ->
            assertTrue(alert.readyToAttempt(time))
            alert = alert.reserveAttempt(time)
            assertEquals(initial.eventId, alert.eventId)
            assertEquals(index + 1, alert.attempts)
            assertFalse(alert.readyToAttempt(time))
            time = alert.nextAttemptAtElapsedMillis
            alert = alert.result(backendAccepted = false)
        }
        assertEquals(GuardianSendState.RETRIES_EXHAUSTED, alert.state)
        assertFalse(alert.readyToAttempt(time))
    }

    @Test fun `acceptance does not claim delivery and late success cannot resurrect cancellation`() {
        val pending = advance(30_000).reserveAttempt(31_000)
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, pending.result(true).state)
        assertEquals(GuardianSendState.CANCELLED, advance(30_000).cancel().result(true).state)
        assertEquals(pending, pending.cancel())
        assertEquals(GuardianSendState.CONSENT_REVOKED, pending.result(false, authorizationDenied = true).state)
    }

    @Test fun `process death after final attempt becomes exhausted at persisted deadline`() {
        var alert = advance(30_000)
        repeat(6) { alert = alert.reserveAttempt(alert.nextAttemptAtElapsedMillis) }
        val elapsed = alert.nextAttemptAtElapsedMillis
        val restored = alert.advance(elapsed, initial.occurredAtEpochMillis + elapsed - initial.createdAtElapsedMillis,
            initial.bootId, initial.ownerId, initial.consentGeneration)
        assertEquals(GuardianSendState.RETRIES_EXHAUSTED, restored.state)
    }

    @Test fun `envelope cannot leak local identity mount speed route or raw telemetry`() {
        val envelope = initial.envelope()
        assertEquals(setOf("schema_version", "event_id", "kind", "rule_version", "occurred_at_epoch_ms", "uncertainty"), envelope.keys)
        assertEquals("experimental_not_confirmed", envelope["uncertainty"])
        assertFalse(envelope.values.contains(initial.ownerId))
        assertFalse(envelope.values.contains(initial.consentGeneration))
        assertFalse(envelope.values.contains(initial.bootId))
    }

    private fun advance(delta: Long) = initial.advance(initial.createdAtElapsedMillis + delta,
        initial.occurredAtEpochMillis + delta, initial.bootId, initial.ownerId, initial.consentGeneration)
}
