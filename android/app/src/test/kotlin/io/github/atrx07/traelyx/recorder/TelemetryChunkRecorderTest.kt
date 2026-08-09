package io.github.atrx07.traelyx.recorder

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TelemetryChunkRecorderTest {
    @Test
    fun `bounded writer flushes ordered chunks and resumes without overwriting`() {
        val store = MemoryChunkStore()
        val first = recorder(store, maxChunkSamples = 3, maxChunkSpanNanos = 1_000)
        assertTrue(first.start().started)
        assertTrue(first.accept(testImuSample(tripElapsedNanos = 100L, sourceTimestampNanos = 1_100L)))
        assertTrue(
            first.accept(
                testImuSample(
                    sensorType = ImuSensorType.GYROSCOPE,
                    tripElapsedNanos = 200L,
                    sourceTimestampNanos = 1_200L,
                ),
            ),
        )
        assertTrue(first.accept(testGnssSample(tripElapsedNanos = 300L, sourceTimestampNanos = 1_300L)))
        assertTrue(first.accept(testImuSample(tripElapsedNanos = 400L, sourceTimestampNanos = 1_400L)))
        assertTrue(first.stop())

        val firstCatalog = store.scan(TEST_TRIP_ID)
        assertEquals(listOf(0L, 1L), firstCatalog.validChunks.map { it.metadata.sequence })
        assertEquals(4, firstCatalog.validChunks.sumOf { it.records.size })

        val recovered = recorder(store, maxChunkSamples = 3, maxChunkSpanNanos = 1_000)
        assertTrue(recovered.start().started)
        assertEquals(2, recovered.health().recoveredValidChunkCount)
        assertTrue(recovered.accept(testImuSample(tripElapsedNanos = 500L, sourceTimestampNanos = 1_500L)))
        assertTrue(recovered.stop())

        val recoveredCatalog = store.scan(TEST_TRIP_ID)
        assertEquals(listOf(0L, 1L, 2L), recoveredCatalog.validChunks.map { it.metadata.sequence })
        assertEquals(listOf(100L, 200L, 300L, 400L, 500L), recoveredCatalog.allElapsed())
    }

    @Test
    fun `missing trip time and evidence behind committed boundary fail visibly`() {
        val invalidErrors = Collections.synchronizedList(mutableListOf<String>())
        val invalid = recorder(MemoryChunkStore(), onFatalError = invalidErrors::add)
        invalid.start()
        assertFalse(invalid.accept(testImuSample(tripElapsedNanos = null)))
        assertTrue(await { invalid.health().state == TelemetryBufferState.ERROR })
        assertEquals("chunk_trip_time_invalid", invalid.health().errorCode)
        assertEquals(1L, invalid.health().invalidTripTimeCount)
        invalid.stop()

        val lateErrors = Collections.synchronizedList(mutableListOf<String>())
        val late = recorder(MemoryChunkStore(), reorderHorizonNanos = 0, onFatalError = lateErrors::add)
        late.start()
        assertTrue(late.accept(testImuSample(tripElapsedNanos = 200L, sourceTimestampNanos = 1_200L)))
        assertTrue(await { late.health().completedChunkCount == 1L })
        assertTrue(late.accept(testImuSample(tripElapsedNanos = 100L, sourceTimestampNanos = 1_100L)))
        assertTrue(await { late.health().state == TelemetryBufferState.ERROR })
        assertEquals("chunk_late_sample", late.health().errorCode)
        assertEquals(1L, late.health().lateSampleCount)
        late.stop()
    }

    @Test
    fun `queue overflow and write failure are explicit recorder errors`() {
        val blockingStore = BlockingMemoryChunkStore()
        val overflow =
            recorder(
                blockingStore,
                queueCapacity = 1,
                reorderHorizonNanos = 0,
                maxChunkSamples = 1,
            )
        overflow.start()
        assertTrue(overflow.accept(testImuSample(tripElapsedNanos = 100L, sourceTimestampNanos = 1_100L)))
        assertTrue(blockingStore.writeEntered.await(2, TimeUnit.SECONDS))
        assertTrue(overflow.accept(testImuSample(tripElapsedNanos = 200L, sourceTimestampNanos = 1_200L)))
        assertFalse(overflow.accept(testImuSample(tripElapsedNanos = 300L, sourceTimestampNanos = 1_300L)))
        assertEquals("chunk_buffer_overflow", overflow.health().errorCode)
        assertEquals(1L, overflow.health().overflowCount)
        blockingStore.releaseWrite.countDown()
        overflow.stop()

        val failingStore = MemoryChunkStore(failWrites = true)
        val failed = recorder(failingStore, reorderHorizonNanos = 0)
        failed.start()
        assertTrue(failed.accept(testImuSample(tripElapsedNanos = 100L, sourceTimestampNanos = 1_100L)))
        assertTrue(await { failed.health().state == TelemetryBufferState.ERROR })
        assertEquals("chunk_test_write_failed", failed.health().errorCode)
        assertEquals(1L, failed.health().writeFailureCount)
        failed.stop()
    }

    @Test
    fun `non advancing timestamps cannot grow the reorder buffer without bound`() {
        val recorder =
            TelemetryChunkRecorder(
                tripId = TEST_TRIP_ID,
                store = MemoryChunkStore(),
                clockUtcEpochMillis = { 1_777_777_777_500L },
                queueCapacity = 16,
                reorderBufferCapacity = 2,
                reorderHorizonNanos = Long.MAX_VALUE,
                maxChunkSamples = 4,
                maxChunkSpanNanos = 10_000,
            )
        recorder.start()
        repeat(3) { index ->
            assertTrue(
                recorder.accept(
                    testImuSample(
                        tripElapsedNanos = 100L,
                        sourceTimestampNanos = 1_100L + index,
                    ),
                ),
            )
        }
        assertTrue(await { recorder.health().state == TelemetryBufferState.ERROR })
        assertEquals("chunk_reorder_buffer_overflow", recorder.health().errorCode)
        assertEquals(1L, recorder.health().overflowCount)
        recorder.stop()
    }

    private fun recorder(
        store: TelemetryChunkStore,
        queueCapacity: Int = 16,
        reorderBufferCapacity: Int = 16,
        reorderHorizonNanos: Long = 10_000,
        maxChunkSamples: Int = 4,
        maxChunkSpanNanos: Long = 10_000,
        onFatalError: (String) -> Unit = {},
    ): TelemetryChunkRecorder =
        TelemetryChunkRecorder(
            tripId = TEST_TRIP_ID,
            store = store,
            clockUtcEpochMillis = { 1_777_777_777_500L },
            queueCapacity = queueCapacity,
            reorderBufferCapacity = reorderBufferCapacity,
            reorderHorizonNanos = reorderHorizonNanos,
            maxChunkSamples = maxChunkSamples,
            maxChunkSpanNanos = maxChunkSpanNanos,
            onFatalError = onFatalError,
        )

    private fun await(predicate: () -> Boolean): Boolean {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
        while (!predicate() && System.nanoTime() < deadline) Thread.yield()
        return predicate()
    }
}

private open class MemoryChunkStore(
    private val failWrites: Boolean = false,
) : TelemetryChunkStore {
    protected val stored = Collections.synchronizedList(mutableListOf<EncodedTelemetryChunk>())

    override fun scan(tripId: String): TelemetryChunkCatalogSnapshot =
        TelemetryChunkCatalog.inspect(
            synchronized(stored) {
                stored.map { TelemetryChunkCandidate(it.metadata.sequence, it.bytes) }
            },
        )

    override fun write(chunk: EncodedTelemetryChunk): TelemetryChunkWriteResult {
        if (failWrites) return TelemetryChunkWriteResult.Failure("chunk_test_write_failed")
        stored += chunk
        return TelemetryChunkWriteResult.Success
    }
}

private class BlockingMemoryChunkStore : MemoryChunkStore() {
    val writeEntered = CountDownLatch(1)
    val releaseWrite = CountDownLatch(1)

    override fun write(chunk: EncodedTelemetryChunk): TelemetryChunkWriteResult {
        writeEntered.countDown()
        check(releaseWrite.await(2, TimeUnit.SECONDS))
        return super.write(chunk)
    }
}

private fun TelemetryChunkCatalogSnapshot.allElapsed(): List<Long> =
    validChunks.flatMap { it.records }.sortedWith(TELEMETRY_SAMPLE_COMPARATOR)
        .map { it.tripElapsedNanos }
