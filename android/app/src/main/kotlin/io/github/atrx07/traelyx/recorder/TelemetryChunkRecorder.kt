package io.github.atrx07.traelyx.recorder

import java.util.PriorityQueue
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class TelemetryChunkRecorder(
    private val tripId: String,
    private val store: TelemetryChunkStore,
    private val clockUtcEpochMillis: () -> Long = System::currentTimeMillis,
    private val queueCapacity: Int = TELEMETRY_CHUNK_INGRESS_CAPACITY,
    private val reorderBufferCapacity: Int = TELEMETRY_CHUNK_REORDER_BUFFER_CAPACITY,
    private val reorderHorizonNanos: Long = TELEMETRY_CHUNK_REORDER_HORIZON_NANOS,
    private val maxChunkSamples: Int = TELEMETRY_CHUNK_MAX_SAMPLES,
    private val maxChunkSpanNanos: Long = TELEMETRY_CHUNK_MAX_SPAN_NANOS,
    private val publishHealth: (TelemetryBufferHealthSnapshot) -> Unit = {},
    private val onFatalError: (String) -> Unit = {},
) {
    private sealed interface WriterCommand {
        data class Sample(val record: TelemetrySampleRecord) : WriterCommand

        data object Stop : WriterCommand
    }

    private val queue = ArrayBlockingQueue<WriterCommand>(queueCapacity)
    private val pending = PriorityQueue(TELEMETRY_SAMPLE_COMPARATOR)
    private val staged = ArrayList<TelemetrySampleRecord>(maxChunkSamples)
    private val accepting = AtomicBoolean(false)
    private val fatalSignalled = AtomicBoolean(false)
    private val lifecycleLock = Any()
    private val healthLock = Any()
    private var worker: Thread? = null
    private var nextSequence = 0L
    private var committedEndElapsedNanos: Long? = null
    private var highestObservedElapsedNanos: Long? = null
    private var health =
        TelemetryBufferHealthSnapshot.idle().copy(
            queueCapacity = queueCapacity,
            reorderBufferCapacity = reorderBufferCapacity,
        )

    init {
        require(runCatching { UUID.fromString(tripId) }.isSuccess)
        require(queueCapacity > 0)
        require(reorderBufferCapacity > 0)
        require(reorderHorizonNanos >= 0)
        require(maxChunkSamples in 1..TELEMETRY_CHUNK_MAX_SAMPLES)
        require(maxChunkSpanNanos in 1..TELEMETRY_CHUNK_MAX_SPAN_NANOS)
    }

    fun start(): TelemetryChunkRecorderStartResult =
        synchronized(lifecycleLock) {
            if (accepting.get()) return TelemetryChunkRecorderStartResult(started = true)
            updateHealth { it.copy(state = TelemetryBufferState.STARTING, errorCode = null) }
            val catalog =
                runCatching { store.scan(tripId) }.getOrElse {
                    return failStart("chunk_scan_failed")
                }
            if (catalog.maxObservedSequence == Long.MAX_VALUE) {
                return failStart("chunk_sequence_exhausted")
            }
            nextSequence = (catalog.maxObservedSequence ?: -1L) + 1L
            committedEndElapsedNanos = catalog.lastVerifiedEndElapsedNanos
            highestObservedElapsedNanos = committedEndElapsedNanos
            updateHealth {
                it.copy(
                    state = TelemetryBufferState.ACTIVE,
                    completedChunkCount = catalog.validChunks.size.toLong(),
                    persistedGnssSampleCount =
                        catalog.validChunks.sumOf { chunk ->
                            chunk.metadata.gnssSampleCount.toLong()
                        },
                    persistedAccelerometerSampleCount =
                        catalog.validChunks.sumOf { chunk ->
                            chunk.metadata.accelerometerSampleCount.toLong()
                        },
                    persistedGyroscopeSampleCount =
                        catalog.validChunks.sumOf { chunk ->
                            chunk.metadata.gyroscopeSampleCount.toLong()
                        },
                    persistedByteCount =
                        catalog.validChunks.sumOf { chunk -> chunk.metadata.byteLength.toLong() },
                    recoveredValidChunkCount = catalog.validChunks.size,
                    corruptChunkCount = catalog.corruptChunkCount,
                    orphanedWriteCount = catalog.orphanedWriteCount,
                    orderingViolationCount = catalog.orderingViolationCount,
                    lastCompletedSequence = catalog.validChunks.lastOrNull()?.metadata?.sequence,
                    hasCommittedElapsedBoundary = catalog.lastVerifiedEndElapsedNanos != null,
                    errorCode = null,
                )
            }
            accepting.set(true)
            val thread = Thread(::runWriter, "traelyx-telemetry-writer").apply { isDaemon = true }
            worker = thread
            thread.start()
            TelemetryChunkRecorderStartResult(started = true)
        }

    fun accept(sample: RawGnssSample): Boolean =
        TelemetrySampleRecord.from(sample)?.let(::enqueue)
            ?: rejectInvalidTripTime()

    fun accept(sample: RawImuSample): Boolean =
        TelemetrySampleRecord.from(sample)?.let(::enqueue)
            ?: rejectInvalidTripTime()

    fun stop(timeoutMillis: Long = STOP_TIMEOUT_MILLIS): Boolean =
        synchronized(lifecycleLock) {
            accepting.set(false)
            if (currentHealth().state != TelemetryBufferState.ERROR) {
                updateHealth { it.copy(state = TelemetryBufferState.STOPPING) }
            }
            val activeWorker = worker
            if (activeWorker != null && activeWorker.isAlive) {
                val stopQueued =
                    runCatching {
                        queue.offer(WriterCommand.Stop, timeoutMillis, TimeUnit.MILLISECONDS)
                    }.getOrDefault(false)
                if (!stopQueued) {
                    signalFatal("chunk_stop_timeout")
                    activeWorker.interrupt()
                }
                runCatching { activeWorker.join(timeoutMillis) }
                if (activeWorker.isAlive) {
                    signalFatal("chunk_stop_timeout")
                    activeWorker.interrupt()
                }
            }
            worker = null
            val succeeded = currentHealth().errorCode == null
            if (succeeded) {
                updateHealth {
                    it.copy(
                        state = TelemetryBufferState.STOPPED,
                        queueDepth = queue.size,
                        bufferedSampleCount = pending.size,
                    )
                }
            }
            succeeded
        }

    fun health(): TelemetryBufferHealthSnapshot = synchronized(healthLock) { health }

    private fun enqueue(record: TelemetrySampleRecord): Boolean {
        if (!accepting.get()) return false
        if (!queue.offer(WriterCommand.Sample(record))) {
            updateHealth { it.copy(overflowCount = it.overflowCount + 1) }
            signalFatal("chunk_buffer_overflow")
            return false
        }
        updateHealth {
            it.copy(
                queueDepth = queue.size.coerceAtMost(queueCapacity),
            )
        }
        return true
    }

    private fun rejectInvalidTripTime(): Boolean {
        updateHealth { it.copy(invalidTripTimeCount = it.invalidTripTimeCount + 1) }
        signalFatal("chunk_trip_time_invalid")
        return false
    }

    private fun runWriter() {
        try {
            while (true) {
                when (val command = queue.take()) {
                    is WriterCommand.Sample -> {
                        if (!process(command.record)) break
                    }

                    WriterCommand.Stop -> {
                        if (!flushAll()) return
                        return
                    }
                }
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            signalFatal("chunk_writer_interrupted")
        } catch (_: RuntimeException) {
            signalFatal("chunk_writer_failed")
        }
    }

    private fun process(record: TelemetrySampleRecord): Boolean {
        val safeEnd = staged.lastOrNull()?.tripElapsedNanos ?: committedEndElapsedNanos
        if (safeEnd != null && record.tripElapsedNanos < safeEnd) {
            updateHealth { it.copy(lateSampleCount = it.lateSampleCount + 1) }
            signalFatal("chunk_late_sample")
            return false
        }
        if (pending.size >= reorderBufferCapacity) {
            updateHealth { it.copy(overflowCount = it.overflowCount + 1) }
            signalFatal("chunk_reorder_buffer_overflow")
            return false
        }
        pending += record
        highestObservedElapsedNanos =
            maxOf(highestObservedElapsedNanos ?: record.tripElapsedNanos, record.tripElapsedNanos)
        updateDepths()
        val cutoff = (highestObservedElapsedNanos ?: return true) - reorderHorizonNanos
        return flushThrough(cutoff)
    }

    private fun flushThrough(cutoffElapsedNanos: Long): Boolean {
        while (pending.peek()?.tripElapsedNanos?.let { it <= cutoffElapsedNanos } == true) {
            val next = requireNotNull(pending.remove())
            val first = staged.firstOrNull()
            if (first != null && next.tripElapsedNanos - first.tripElapsedNanos > maxChunkSpanNanos) {
                if (!writeStaged()) return false
            }
            staged += next
            if (staged.size == maxChunkSamples && !writeStaged()) return false
        }
        updateDepths()
        return true
    }

    private fun flushAll(): Boolean {
        if (!flushThrough(Long.MAX_VALUE)) return false
        return staged.isEmpty() || writeStaged()
    }

    private fun writeStaged(): Boolean {
        check(staged.isNotEmpty())
        val records = staged.toList()
        if (!writeBatch(records)) return false
        staged.clear()
        updateDepths()
        return true
    }

    private fun writeBatch(records: List<TelemetrySampleRecord>): Boolean {
        val encoded =
            runCatching {
                TelemetryChunkCodec.encode(
                    tripId = tripId,
                    sequence = nextSequence,
                    records = records,
                    createdAtUtcEpochMillis = clockUtcEpochMillis(),
                )
            }.getOrElse {
                updateHealth { health ->
                    health.copy(writeFailureCount = health.writeFailureCount + 1)
                }
                signalFatal("chunk_encode_failed")
                return false
            }
        when (val result = store.write(encoded)) {
            is TelemetryChunkWriteResult.Failure -> {
                updateHealth { it.copy(writeFailureCount = it.writeFailureCount + 1) }
                signalFatal(result.errorCode)
                return false
            }

            TelemetryChunkWriteResult.Success -> Unit
        }
        committedEndElapsedNanos = encoded.metadata.endElapsedNanos
        nextSequence += 1
        updateHealth {
            it.copy(
                completedChunkCount = it.completedChunkCount + 1,
                persistedGnssSampleCount =
                    it.persistedGnssSampleCount + encoded.metadata.gnssSampleCount,
                persistedAccelerometerSampleCount =
                    it.persistedAccelerometerSampleCount +
                        encoded.metadata.accelerometerSampleCount,
                persistedGyroscopeSampleCount =
                    it.persistedGyroscopeSampleCount + encoded.metadata.gyroscopeSampleCount,
                persistedByteCount = it.persistedByteCount + encoded.metadata.byteLength,
                lastCompletedSequence = encoded.metadata.sequence,
                hasCommittedElapsedBoundary = true,
                queueDepth = queue.size.coerceAtMost(queueCapacity),
            )
        }
        return true
    }

    private fun updateDepths() {
        updateHealth {
            it.copy(
                queueDepth = queue.size.coerceAtMost(queueCapacity),
                bufferedSampleCount = staged.size + pending.size + queue.size,
            )
        }
    }

    private fun failStart(errorCode: String): TelemetryChunkRecorderStartResult {
        signalFatal(errorCode)
        return TelemetryChunkRecorderStartResult(started = false, errorCode = errorCode)
    }

    private fun signalFatal(errorCode: String) {
        accepting.set(false)
        updateHealth { it.copy(state = TelemetryBufferState.ERROR, errorCode = errorCode) }
        if (fatalSignalled.compareAndSet(false, true)) onFatalError(errorCode)
    }

    private fun currentHealth(): TelemetryBufferHealthSnapshot = synchronized(healthLock) { health }

    private fun updateHealth(transform: (TelemetryBufferHealthSnapshot) -> TelemetryBufferHealthSnapshot) {
        val latest = synchronized(healthLock) {
            health = transform(health)
            health
        }
        publishHealth(latest)
    }

    companion object {
        private const val STOP_TIMEOUT_MILLIS = 10_000L
    }
}
