package io.github.atrx07.traelyx.recorder

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RawTelemetryDeletionTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun deletionIsScopedToOneValidatedSyntheticTrip() {
        val trips = temporaryFolder.newFolder("trips")
        val target = File(trips, TARGET_TRIP_ID).resolve("chunks").apply { mkdirs() }
        target.resolve("0000000000.tlxc").writeBytes(ByteArray(11))
        target.resolve("0000000000.tlxc.bak").writeBytes(ByteArray(7))
        val preserved = File(trips, PRESERVED_TRIP_ID).resolve("chunks").apply { mkdirs() }
        preserved.resolve("0000000000.tlxc").writeBytes(ByteArray(5))

        val result = AtomicFileTelemetryChunkStore(trips)
            .deleteTripRawTelemetry(TARGET_TRIP_ID)

        assertEquals(RawTelemetryDeletionResult.Success(18L), result)
        assertFalse(File(trips, TARGET_TRIP_ID).exists())
        assertTrue(File(trips, PRESERVED_TRIP_ID).exists())
        assertEquals(5L, preserved.resolve("0000000000.tlxc").length())
    }

    @Test
    fun deletionRejectsTraversalAndTreatsMissingTripAsSuccess() {
        val trips = temporaryFolder.newFolder("trips-safe")
        val store = AtomicFileTelemetryChunkStore(trips)

        assertEquals(
            RawTelemetryDeletionResult.Failure("raw_delete_invalid_trip_id"),
            store.deleteTripRawTelemetry("../outside"),
        )
        assertEquals(
            RawTelemetryDeletionResult.Success(0L),
            store.deleteTripRawTelemetry(TARGET_TRIP_ID),
        )
    }

    companion object {
        private const val TARGET_TRIP_ID = "00000000-0000-4000-8000-000000000001"
        private const val PRESERVED_TRIP_ID = "00000000-0000-4000-8000-000000000002"
    }
}
