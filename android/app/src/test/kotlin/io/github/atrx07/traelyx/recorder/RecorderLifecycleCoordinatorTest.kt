package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RecorderLifecycleCoordinatorTest {
    @Test
    fun startIsPersistentAndDuplicateStartIsIdempotent() {
        val store = InMemoryRecorderRecoveryStore()
        val coordinator = RecorderLifecycleCoordinator(store)

        val started = coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)
        val duplicate = coordinator.beginStart(OTHER_TRIP_ID, WALL_TIME_MILLIS + 1, ELAPSED_NANOS + 1)

        assertEquals(RecorderLifecycleOutcomeKind.APPLIED, started.kind)
        assertEquals(RecorderLifecycleState.STARTING, started.snapshot.lifecycleState)
        assertEquals(TRIP_ID, started.snapshot.tripId)
        assertEquals(RecorderLifecycleOutcomeKind.NO_OP, duplicate.kind)
        assertEquals(TRIP_ID, duplicate.snapshot.tripId)
        assertEquals(1, store.saveCount)
    }

    @Test
    fun recordingRecoveryAndStopFollowTheExplicitStateMachine() {
        val store = InMemoryRecorderRecoveryStore()
        val coordinator = RecorderLifecycleCoordinator(store)

        coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)
        val recording = coordinator.markRecording(TRIP_ID)
        val recovered = coordinator.recover()
        val repeatedRecovery = coordinator.recover()
        val stopping = coordinator.beginStop()
        val idle = coordinator.completeStop()

        assertEquals(RecorderLifecycleState.RECORDING, recording.snapshot.lifecycleState)
        assertEquals(RecorderLifecycleState.RECOVERED, recovered.snapshot.lifecycleState)
        assertEquals(1, recovered.snapshot.recoveryCount)
        assertEquals(RecorderLifecycleOutcomeKind.NO_OP, repeatedRecovery.kind)
        assertEquals(1, repeatedRecovery.snapshot.recoveryCount)
        assertEquals(RecorderLifecycleState.STOPPING, stopping.snapshot.lifecycleState)
        assertEquals(RecorderLifecycleState.IDLE, idle.snapshot.lifecycleState)
        assertFalse(idle.snapshot.isActive)
        assertNull(store.record)
    }

    @Test
    fun restartWhileStoppingCompletesTheInterruptedStop() {
        val store = InMemoryRecorderRecoveryStore()
        val coordinator = RecorderLifecycleCoordinator(store)
        coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)
        coordinator.markRecording(TRIP_ID)
        coordinator.beginStop()

        val recovered = coordinator.recover()

        assertEquals(RecorderLifecycleOutcomeKind.APPLIED, recovered.kind)
        assertEquals(RecorderLifecycleState.IDLE, recovered.snapshot.lifecycleState)
        assertNull(store.record)
    }

    @Test
    fun invalidRecoveryMetadataFailsClosedUntilExplicitStopClearsIt() {
        val store = InMemoryRecorderRecoveryStore(readOverride = RecorderRecoveryRead.Invalid())
        val coordinator = RecorderLifecycleCoordinator(store)

        val query = coordinator.query()
        val start = coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)
        val stop = coordinator.beginStop()

        assertEquals(RecorderLifecycleState.ERROR, query.lifecycleState)
        assertEquals("invalid_recovery_metadata", query.errorCode)
        assertEquals(RecorderLifecycleOutcomeKind.REJECTED, start.kind)
        assertEquals(RecorderLifecycleOutcomeKind.APPLIED, stop.kind)
        assertTrue(store.clearCount > 0)
    }

    @Test
    fun persistenceFailureNeverReportsAnActiveTrip() {
        val store = InMemoryRecorderRecoveryStore(saveSucceeds = false)
        val coordinator = RecorderLifecycleCoordinator(store)

        val outcome = coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)

        assertEquals(RecorderLifecycleOutcomeKind.REJECTED, outcome.kind)
        assertEquals(RecorderLifecycleState.ERROR, outcome.snapshot.lifecycleState)
        assertEquals("recovery_persistence_failed", outcome.snapshot.errorCode)
        assertFalse(outcome.snapshot.isActive)
        assertNull(store.record)
    }

    @Test
    fun mismatchedTripCannotAdvanceAnotherTripsLifecycle() {
        val store = InMemoryRecorderRecoveryStore()
        val coordinator = RecorderLifecycleCoordinator(store)
        coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)

        val outcome = coordinator.markRecording(OTHER_TRIP_ID)

        assertEquals(RecorderLifecycleOutcomeKind.REJECTED, outcome.kind)
        assertEquals("active_trip_mismatch", outcome.snapshot.errorCode)
        assertEquals(RecorderLifecycleState.STARTING, store.record?.lifecycleState)
    }

    @Test
    fun lifecycleFailureIsPersistedWithoutRawExceptionDetails() {
        val store = InMemoryRecorderRecoveryStore()
        val coordinator = RecorderLifecycleCoordinator(store)
        coordinator.beginStart(TRIP_ID, WALL_TIME_MILLIS, ELAPSED_NANOS)

        val outcome = coordinator.markError("foreground_promotion_failed")

        assertEquals(RecorderLifecycleState.ERROR, outcome.snapshot.lifecycleState)
        assertEquals("foreground_promotion_failed", outcome.snapshot.errorCode)
        assertFalse(outcome.snapshot.isActive)
        assertEquals("foreground_promotion_failed", store.record?.errorCode)
    }

    private class InMemoryRecorderRecoveryStore(
        private var readOverride: RecorderRecoveryRead? = null,
        private val saveSucceeds: Boolean = true,
        private val clearSucceeds: Boolean = true,
    ) : RecorderRecoveryStore {
        var record: ActiveTripRecoveryRecord? = null
        var saveCount = 0
        var clearCount = 0

        override fun load(): RecorderRecoveryRead =
            readOverride ?: record?.let(RecorderRecoveryRead::Available) ?: RecorderRecoveryRead.Empty

        override fun save(record: ActiveTripRecoveryRecord): Boolean {
            saveCount += 1
            if (saveSucceeds) {
                this.record = record
            }
            return saveSucceeds
        }

        override fun clear(): Boolean {
            clearCount += 1
            if (clearSucceeds) {
                record = null
                readOverride = null
            }
            return clearSucceeds
        }
    }

    companion object {
        private const val TRIP_ID = "d181f268-f3ef-4a43-a142-8bf0671dcd49"
        private const val OTHER_TRIP_ID = "d67df78c-11f2-451d-bd03-af2f011ae983"
        private const val WALL_TIME_MILLIS = 1_786_200_000_000L
        private const val ELAPSED_NANOS = 987_654_321L
    }
}
