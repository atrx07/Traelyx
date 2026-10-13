package io.github.atrx07.traelyx.guardian

import org.junit.Assert.*
import org.junit.Test

class GuardianActivationBridgeTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val other = "22222222-2222-4222-8222-222222222222"
    private val activation = "33333333-3333-4333-8333-333333333333"
    private class MemoryVault : GuardianVault {
        var value = GuardianVaultSnapshot()
        override fun read() = value
        override fun write(snapshot: GuardianVaultSnapshot) { value = snapshot }
        override fun erase() { value = GuardianVaultSnapshot() }
    }
    private class Fixture {
        val owner = "11111111-1111-4111-8111-111111111111"
        val activation = "33333333-3333-4333-8333-333333333333"
        val credential = "a".repeat(64)
        var now = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
        val vault = MemoryVault()
        val coordinator = GuardianActivationCoordinator(
            GuardianOutbox(vault), { now }, TestDriverRevokeJournal(), { activation }, { credential },
        )
        var observation = GuardianRecordingObservation()
        var observationReads = 0
        val bridge = GuardianActivationBridge(coordinator) { observationReads++; observation }
        fun bind(value: String?) = bridge.dispatch(GuardianActivationBridge.BIND_OWNER, mapOf("ownerId" to value))
        fun begin() = bridge.dispatch(GuardianActivationBridge.BEGIN,
            mapOf("ownerId" to owner, "forwardAxis" to "+y", "rigidMountConfirmed" to true)) as Map<*, *>
    }

    private fun rejected(action: () -> Any?) {
        try { action(); fail("Expected rejection") }
        catch (_: IllegalArgumentException) { }
        catch (_: IllegalStateException) { }
    }

    @Test fun `foreground bridge has no authority until owner binding and explicit mount consent`() {
        val f = Fixture()
        rejected { f.begin() }
        f.bind(owner)
        rejected { f.bridge.dispatch(GuardianActivationBridge.BEGIN,
            mapOf("ownerId" to owner, "forwardAxis" to "+y", "rigidMountConfirmed" to false)) }
        rejected { f.bridge.dispatch(GuardianActivationBridge.BEGIN,
            mapOf("ownerId" to other, "forwardAxis" to "+y", "rigidMountConfirmed" to true)) }
        assertNull(f.vault.value.lease)
    }

    @Test fun `proposal is the sole credential-bearing reply and status stays redacted`() {
        val f = Fixture(); f.bind(owner)
        val proposal = f.begin()
        assertEquals(f.credential, proposal["credential"])
        assertNull(f.vault.value.lease)
        val before = f.bridge.dispatch(GuardianActivationBridge.SNAPSHOT, mapOf("ownerId" to owner)) as Map<*, *>
        assertEquals(mapOf("localLeasePresent" to false, "expiresEpochMillis" to null), before)
        f.now = f.now.copy(epochMillis = f.now.epochMillis + 1_000, elapsedMillis = f.now.elapsedMillis + 1_000)
        val committed = f.bridge.dispatch(GuardianActivationBridge.COMMIT,
            mapOf("ownerId" to owner, "activationId" to activation,
                "serverExpiresEpochMillis" to f.now.epochMillis + 28_799_000)) as Map<*, *>
        assertEquals(true, committed["localLeasePresent"])
        assertFalse(committed.toString().contains(f.credential))
        val after = f.bridge.dispatch(GuardianActivationBridge.SNAPSHOT, mapOf("ownerId" to owner)) as Map<*, *>
        assertFalse(after.toString().contains(f.credential))
        f.bind(null)
        assertNull(f.vault.value.lease)
    }

    @Test fun `bridge rejects unexpected fields and stale owner before vault activation`() {
        val f = Fixture(); f.bind(owner)
        rejected { f.bridge.dispatch(GuardianActivationBridge.BEGIN,
            mapOf("ownerId" to owner, "forwardAxis" to "+y", "rigidMountConfirmed" to true,
                "extra" to "ignored")) }
        rejected { f.bridge.dispatch(GuardianActivationBridge.COMMIT,
            mapOf("ownerId" to owner, "activationId" to activation,
                "serverExpiresEpochMillis" to "1800000000000")) }
        val proposal = f.begin()
        f.bind(other)
        rejected { f.bridge.dispatch(GuardianActivationBridge.COMMIT,
            mapOf("ownerId" to owner, "activationId" to proposal["activationId"],
                "serverExpiresEpochMillis" to f.now.epochMillis + 1_000)) }
        assertNull(f.vault.value.lease)
    }

    private fun status(f: Fixture) = f.bridge.dispatch(GuardianActivationBridge.DRIVER_STATUS,
        mapOf("ownerId" to owner)) as Map<*, *>
    private fun commit(f: Fixture) {
        f.begin()
        f.bridge.dispatch(GuardianActivationBridge.COMMIT, mapOf("ownerId" to owner,
            "activationId" to activation, "serverExpiresEpochMillis" to f.now.epochMillis + 60_000L))
    }

    @Test fun `driver state rejects wrong owner and extras before observing recorder`() {
        val f = Fixture()
        rejected { status(f) }
        f.bind(owner)
        rejected { f.bridge.dispatch(GuardianActivationBridge.DRIVER_STATUS, mapOf("ownerId" to other)) }
        rejected { f.bridge.dispatch(GuardianActivationBridge.DRIVER_STATUS,
            mapOf("ownerId" to owner, "extra" to true)) }
        assertEquals(0, f.observationReads)
    }

    @Test fun `consent alone never reports live evaluation and status contains no capability`() {
        val f = Fixture(); f.bind(owner)
        assertEquals(mapOf("state" to "disabled", "expiresEpochMillis" to null), status(f))
        commit(f)
        assertEquals("waiting_for_trip", status(f)["state"])
        f.observation = GuardianRecordingObservation(true, GuardianEvaluationAvailability.CALIBRATING)
        assertEquals("calibrating", status(f)["state"])
        f.observation = f.observation.copy(availability = GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL)
        val monitoring = status(f)
        assertEquals("monitoring_experimental", monitoring["state"])
        assertEquals(setOf("state", "expiresEpochMillis"), monitoring.keys)
        assertFalse(monitoring.toString().contains(f.credential))
        assertFalse(monitoring.toString().contains(activation))
        assertFalse(monitoring.toString().contains(owner))
        f.observation = f.observation.copy(availability = GuardianEvaluationAvailability.DISABLED)
        assertEquals("evidence_unavailable", status(f)["state"])
        f.observation = f.observation.copy(availability = GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE)
        assertEquals("evidence_unavailable", status(f)["state"])
    }

    @Test fun `restored lease requires a new review even if an observer claims monitoring`() {
        val f = Fixture(); f.bind(owner); commit(f)
        val restarted = GuardianActivationCoordinator(GuardianOutbox(f.vault), { f.now }, TestDriverRevokeJournal())
        restarted.bindOwner(owner)
        val bridge = GuardianActivationBridge(restarted) {
            GuardianRecordingObservation(true, GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL)
        }
        val status = bridge.dispatch(GuardianActivationBridge.DRIVER_STATUS, mapOf("ownerId" to owner)) as Map<*, *>
        assertEquals("reactivation_required", status["state"])
    }

    @Test fun `expired lease denies monitoring even before sidecar refresh`() {
        val f = Fixture(); f.bind(owner); commit(f)
        f.observation = GuardianRecordingObservation(true, GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL)
        f.now = f.now.copy(epochMillis = f.now.epochMillis + 60_000, elapsedMillis = f.now.elapsedMillis + 60_000)
        assertEquals(mapOf("state" to "disabled", "expiresEpochMillis" to null), status(f))
    }

    @Test fun `stop returns only exact revoke identity after erasing local authority`() {
        val f = Fixture(); f.bind(owner); commit(f)
        rejected { f.bridge.dispatch(GuardianActivationBridge.STOP, mapOf("ownerId" to other)) }
        rejected { f.bridge.dispatch(GuardianActivationBridge.STOP, mapOf("ownerId" to owner, "extra" to true)) }
        assertNotNull(f.vault.value.lease)
        val stopped = f.bridge.dispatch(GuardianActivationBridge.STOP, mapOf("ownerId" to owner)) as Map<*, *>
        assertEquals(mapOf("activationId" to activation), stopped)
        assertFalse(stopped.toString().contains(f.credential))
        assertNull(f.vault.value.lease)
        assertEquals(mapOf("activationId" to null),
            f.bridge.dispatch(GuardianActivationBridge.STOP, mapOf("ownerId" to owner)))
        assertEquals(listOf(mapOf("activationId" to activation)),
            f.bridge.dispatch(GuardianActivationBridge.PENDING_REVOKES, mapOf("ownerId" to owner)))
        rejected { f.bridge.dispatch(GuardianActivationBridge.CONFIRM_REVOKE,
            mapOf("ownerId" to other, "activationId" to activation)) }
        rejected { f.bridge.dispatch(GuardianActivationBridge.PENDING_REVOKES,
            mapOf("ownerId" to owner, "extra" to true)) }
        f.bridge.dispatch(GuardianActivationBridge.CONFIRM_REVOKE,
            mapOf("ownerId" to owner, "activationId" to activation))
        assertEquals(emptyList<Any>(),
            f.bridge.dispatch(GuardianActivationBridge.PENDING_REVOKES, mapOf("ownerId" to owner)))
    }
}
