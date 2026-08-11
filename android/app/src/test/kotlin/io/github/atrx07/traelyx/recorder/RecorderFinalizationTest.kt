package io.github.atrx07.traelyx.recorder

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RecorderFinalizationTest {
    @Test
    fun `pending finalization codec is versioned deterministic and fail closed`() {
        val record = pendingRecord(recoveryCount = 2, recorderErrorCode = "chunk_flush_failed")
        val first = ByteArrayOutputStream().also { RecorderFinalizationCodec.encode(record, it) }
        val second = ByteArrayOutputStream().also { RecorderFinalizationCodec.encode(record, it) }

        assertTrue(first.toByteArray().contentEquals(second.toByteArray()))
        assertEquals(
            record,
            RecorderFinalizationCodec.decode(ByteArrayInputStream(first.toByteArray())),
        )
        assertNull(
            RecorderFinalizationCodec.decode(
                ByteArrayInputStream(first.toByteArray().copyOf(first.size() - 2)),
            ),
        )
        assertNull(
            RecorderFinalizationCodec.decode(
                ByteArrayInputStream(first.toByteArray() + byteArrayOf(0x00)),
            ),
        )
    }

    @Test
    fun `verified catalog becomes a complete privacy bounded finalization`() {
        val snapshot =
            RecorderFinalizationEvaluator.evaluate(
                pendingRecord(),
                catalog(sequence = 4, tripElapsedNanos = 200_000_000L),
            )
        val map = snapshot.toMap()
        val chunks = map.getValue("chunks") as List<*>
        val chunk = chunks.single() as Map<*, *>

        assertEquals("completed", snapshot.completionState)
        assertEquals("not_needed", snapshot.recoveryState)
        assertEquals("unassessed", snapshot.integrityStatus)
        assertEquals(START_ELAPSED_NANOS + 200_000_000L, snapshot.endElapsedRealtimeNanos)
        assertEquals(200L, snapshot.durationMillis)
        assertEquals(
            "recorder/trips/$TEST_TRIP_ID/chunks/0000000004.tlxc",
            chunk["storageReference"],
        )
        assertFalse(map.keys.any { it.contains("coordinate", ignoreCase = true) })
        assertFalse(chunk.keys.any { it.toString().contains("absolute", ignoreCase = true) })
    }

    @Test
    fun `recovery corruption and recorder errors cannot masquerade as complete`() {
        val valid = catalog(sequence = 0, tripElapsedNanos = 100L)
        val damaged =
            valid.copy(
                corruptChunkCount = 1,
                orphanedWriteCount = 1,
                orderingViolationCount = 1,
            )
        val snapshot =
            RecorderFinalizationEvaluator.evaluate(
                pendingRecord(recoveryCount = 1, recorderErrorCode = "chunk_write_failed"),
                damaged,
            )

        assertEquals("incomplete", snapshot.completionState)
        assertEquals("recovered", snapshot.recoveryState)
        assertEquals("review_required", snapshot.integrityStatus)
        assertEquals(
            setOf(
                "corrupt_chunks_isolated",
                "orphaned_writes_isolated",
                "chunk_ordering_violation",
                "recorder_recovered",
                "recorder_error",
            ),
            snapshot.qualityFlags.toSet(),
        )
    }

    @Test
    fun `missing valid evidence finalizes explicitly incomplete`() {
        val snapshot =
            RecorderFinalizationEvaluator.evaluate(
                pendingRecord(),
                TelemetryChunkCatalogSnapshot(emptyList(), 0, 0, 0, null),
            )

        assertEquals("incomplete", snapshot.completionState)
        assertEquals(listOf("no_valid_chunks"), snapshot.qualityFlags)
        assertNull(snapshot.endElapsedRealtimeNanos)
        assertNull(snapshot.durationMillis)
    }

    @Test
    fun `wall clock regression is clamped only with explicit incomplete evidence`() {
        val record = pendingRecord().copy(stoppedAtUtcEpochMillis = START_WALL_MILLIS - 1)
        val snapshot =
            RecorderFinalizationEvaluator.evaluate(
                record,
                catalog(sequence = 0, tripElapsedNanos = 100L),
            )

        assertEquals("incomplete", snapshot.completionState)
        assertEquals(START_WALL_MILLIS, snapshot.stoppedAtUtcEpochMillis)
        assertTrue("wall_clock_regression" in snapshot.qualityFlags)
    }

    private fun pendingRecord(
        recoveryCount: Int = 0,
        recorderErrorCode: String? = null,
    ): PendingTripFinalizationRecord =
        PendingTripFinalizationRecord(
            tripId = TEST_TRIP_ID,
            startedAtUtcEpochMillis = START_WALL_MILLIS,
            startedAtElapsedRealtimeNanos = START_ELAPSED_NANOS,
            stoppedAtUtcEpochMillis = START_WALL_MILLIS + 5_000,
            recoveryCount = recoveryCount,
            recorderErrorCode = recorderErrorCode,
        )

    private fun catalog(
        sequence: Long,
        tripElapsedNanos: Long,
    ): TelemetryChunkCatalogSnapshot {
        val encoded =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = sequence,
                records =
                    listOf(
                        TelemetrySampleRecord.Gnss(
                            testGnssSample(tripElapsedNanos = tripElapsedNanos),
                        ),
                    ),
                createdAtUtcEpochMillis = START_WALL_MILLIS + 1_000,
            )
        val decoded =
            (TelemetryChunkCodec.decode(encoded.bytes) as TelemetryChunkDecodeResult.Success).chunk
        return TelemetryChunkCatalogSnapshot(listOf(decoded), 0, 0, 0, sequence)
    }

    companion object {
        private const val START_WALL_MILLIS = 1_786_200_000_000L
        private const val START_ELAPSED_NANOS = 987_654_321L
    }
}
