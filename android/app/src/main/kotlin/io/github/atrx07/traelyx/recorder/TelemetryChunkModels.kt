package io.github.atrx07.traelyx.recorder

import java.util.UUID

const val TELEMETRY_CHUNK_ENCODING_VERSION = 1
const val TELEMETRY_CHUNK_HEALTH_CONTRACT_VERSION = 1
const val TELEMETRY_CHUNK_MAX_SAMPLES = 256
const val TELEMETRY_CHUNK_MAX_SPAN_NANOS = 1_000_000_000L
const val TELEMETRY_CHUNK_REORDER_HORIZON_NANOS = 2_000_000_000L
const val TELEMETRY_CHUNK_INGRESS_CAPACITY = 1_024
const val TELEMETRY_CHUNK_REORDER_BUFFER_CAPACITY = 1_024
const val TELEMETRY_CHUNK_COMPRESSION = "deflate"
const val TELEMETRY_CHUNK_CHECKSUM_ALGORITHM = "sha256"
const val TELEMETRY_CHUNK_ATOMIC_WRITE_STRATEGY = "android_atomic_file"

enum class TelemetryChannel(val wireId: Int, val wireName: String) {
    GNSS(1, "gnss"),
    ACCELEROMETER(2, "accelerometer"),
    GYROSCOPE(3, "gyroscope"),
    ;

    companion object {
        fun fromWireId(value: Int): TelemetryChannel? = entries.firstOrNull { it.wireId == value }
    }
}

sealed interface TelemetrySampleRecord {
    val channel: TelemetryChannel
    val tripElapsedNanos: Long
    val sourceTimestampNanos: Long

    data class Gnss(val sample: RawGnssSample) : TelemetrySampleRecord {
        init {
            require(sample.tripElapsedNanos != null)
        }

        override val channel: TelemetryChannel = TelemetryChannel.GNSS
        override val tripElapsedNanos: Long = requireNotNull(sample.tripElapsedNanos)
        override val sourceTimestampNanos: Long = sample.sourceTimestampNanos
    }

    data class Imu(val sample: RawImuSample) : TelemetrySampleRecord {
        init {
            require(sample.tripElapsedNanos != null)
        }

        override val channel: TelemetryChannel =
            when (sample.sensorType) {
                ImuSensorType.ACCELEROMETER -> TelemetryChannel.ACCELEROMETER
                ImuSensorType.GYROSCOPE -> TelemetryChannel.GYROSCOPE
            }
        override val tripElapsedNanos: Long = requireNotNull(sample.tripElapsedNanos)
        override val sourceTimestampNanos: Long = sample.sourceTimestampNanos
    }

    companion object {
        fun from(sample: RawGnssSample): TelemetrySampleRecord? =
            sample.tripElapsedNanos?.let { Gnss(sample) }

        fun from(sample: RawImuSample): TelemetrySampleRecord? =
            sample.tripElapsedNanos?.let { Imu(sample) }
    }
}

val TELEMETRY_SAMPLE_COMPARATOR: Comparator<TelemetrySampleRecord> =
    compareBy<TelemetrySampleRecord>(
        { it.tripElapsedNanos },
        { it.channel.wireId },
        { it.sourceTimestampNanos },
    )

data class TelemetryChunkMetadata(
    val encodingVersion: Int = TELEMETRY_CHUNK_ENCODING_VERSION,
    val telemetrySchemaVersion: Int = RAW_GNSS_SCHEMA_VERSION,
    val tripId: String,
    val sequence: Long,
    val startElapsedNanos: Long,
    val endElapsedNanos: Long,
    val gnssSampleCount: Int,
    val accelerometerSampleCount: Int,
    val gyroscopeSampleCount: Int,
    val compression: String = TELEMETRY_CHUNK_COMPRESSION,
    val checksumAlgorithm: String = TELEMETRY_CHUNK_CHECKSUM_ALGORITHM,
    val checksumHex: String,
    val atomicWriteStrategy: String = TELEMETRY_CHUNK_ATOMIC_WRITE_STRATEGY,
    val byteLength: Int,
    val createdAtUtcEpochMillis: Long,
) {
    init {
        require(encodingVersion == TELEMETRY_CHUNK_ENCODING_VERSION)
        require(telemetrySchemaVersion == RAW_GNSS_SCHEMA_VERSION)
        require(RAW_GNSS_SCHEMA_VERSION == RAW_IMU_SCHEMA_VERSION)
        require(runCatching { UUID.fromString(tripId) }.isSuccess)
        require(sequence >= 0)
        require(startElapsedNanos >= 0)
        require(endElapsedNanos >= startElapsedNanos)
        require(gnssSampleCount >= 0)
        require(accelerometerSampleCount >= 0)
        require(gyroscopeSampleCount >= 0)
        require(totalSampleCount in 1..TELEMETRY_CHUNK_MAX_SAMPLES)
        require(compression == TELEMETRY_CHUNK_COMPRESSION)
        require(checksumAlgorithm == TELEMETRY_CHUNK_CHECKSUM_ALGORITHM)
        require(Regex("[0-9a-f]{64}").matches(checksumHex))
        require(atomicWriteStrategy == TELEMETRY_CHUNK_ATOMIC_WRITE_STRATEGY)
        require(byteLength > 0)
        require(createdAtUtcEpochMillis > 0)
    }

    val totalSampleCount: Int
        get() = gnssSampleCount + accelerometerSampleCount + gyroscopeSampleCount

    fun channelSampleCounts(): Map<String, Int> =
        linkedMapOf(
            TelemetryChannel.GNSS.wireName to gnssSampleCount,
            TelemetryChannel.ACCELEROMETER.wireName to accelerometerSampleCount,
            TelemetryChannel.GYROSCOPE.wireName to gyroscopeSampleCount,
        )
}

data class EncodedTelemetryChunk(
    val metadata: TelemetryChunkMetadata,
    val bytes: ByteArray,
)

data class DecodedTelemetryChunk(
    val metadata: TelemetryChunkMetadata,
    val records: List<TelemetrySampleRecord>,
)

data class DecodedGnssTelemetryChunk(
    val metadata: TelemetryChunkMetadata,
    val samples: List<RawGnssSample>,
    val channelElapsedRanges: Map<TelemetryChannel, LongRange>,
)

sealed interface TelemetryChunkDecodeResult {
    data class Success(val chunk: DecodedTelemetryChunk) : TelemetryChunkDecodeResult

    data class Invalid(val errorCode: String) : TelemetryChunkDecodeResult
}

sealed interface TelemetryChunkGnssDecodeResult {
    data class Success(val chunk: DecodedGnssTelemetryChunk) : TelemetryChunkGnssDecodeResult

    data class Invalid(val errorCode: String) : TelemetryChunkGnssDecodeResult
}

data class TelemetryChunkCandidate(
    val observedSequence: Long,
    val bytes: ByteArray?,
    val orphanedIncompleteWrite: Boolean = false,
)

data class TelemetryChunkCatalogSnapshot(
    val validChunks: List<DecodedTelemetryChunk>,
    val corruptChunkCount: Int,
    val orphanedWriteCount: Int,
    val orderingViolationCount: Int,
    val maxObservedSequence: Long?,
) {
    val lastVerifiedEndElapsedNanos: Long?
        get() = validChunks.lastOrNull()?.metadata?.endElapsedNanos
}

data class TelemetryChunkSequenceSnapshot(
    val sequences: List<Long>,
    val orphanedWriteCount: Int,
    val invalidCandidateCount: Int,
) {
    init {
        require(sequences == sequences.distinct().sorted())
        require(sequences.all { it >= 0 })
        require(orphanedWriteCount >= 0)
        require(invalidCandidateCount >= 0)
    }
}

enum class TelemetryBufferState(val wireName: String) {
    IDLE("idle"),
    STARTING("starting"),
    ACTIVE("active"),
    STOPPING("stopping"),
    STOPPED("stopped"),
    ERROR("error"),
}

data class TelemetryBufferHealthSnapshot(
    val contractVersion: Int = TELEMETRY_CHUNK_HEALTH_CONTRACT_VERSION,
    val state: TelemetryBufferState,
    val queueCapacity: Int = TELEMETRY_CHUNK_INGRESS_CAPACITY,
    val reorderBufferCapacity: Int = TELEMETRY_CHUNK_REORDER_BUFFER_CAPACITY,
    val queueDepth: Int = 0,
    val bufferedSampleCount: Int = 0,
    val completedChunkCount: Long = 0,
    val persistedGnssSampleCount: Long = 0,
    val persistedAccelerometerSampleCount: Long = 0,
    val persistedGyroscopeSampleCount: Long = 0,
    val persistedByteCount: Long = 0,
    val recoveredValidChunkCount: Int = 0,
    val corruptChunkCount: Int = 0,
    val orphanedWriteCount: Int = 0,
    val orderingViolationCount: Int = 0,
    val overflowCount: Long = 0,
    val invalidTripTimeCount: Long = 0,
    val lateSampleCount: Long = 0,
    val writeFailureCount: Long = 0,
    val lastCompletedSequence: Long? = null,
    val hasCommittedElapsedBoundary: Boolean = false,
    val errorCode: String? = null,
) {
    init {
        require(contractVersion == TELEMETRY_CHUNK_HEALTH_CONTRACT_VERSION)
        require(queueCapacity > 0)
        require(reorderBufferCapacity > 0)
        require(queueDepth in 0..queueCapacity)
        require(bufferedSampleCount >= 0)
        require(
            listOf(
                completedChunkCount,
                persistedGnssSampleCount,
                persistedAccelerometerSampleCount,
                persistedGyroscopeSampleCount,
                persistedByteCount,
                overflowCount,
                invalidTripTimeCount,
                lateSampleCount,
                writeFailureCount,
            ).all { it >= 0 },
        )
        require(
            listOf(
                recoveredValidChunkCount,
                corruptChunkCount,
                orphanedWriteCount,
                orderingViolationCount,
            ).all { it >= 0 },
        )
        require(lastCompletedSequence == null || lastCompletedSequence >= 0)
        require(errorCode == null || Regex("[a-z0-9_]{1,64}").matches(errorCode))
    }

    companion object {
        fun idle(): TelemetryBufferHealthSnapshot =
            TelemetryBufferHealthSnapshot(state = TelemetryBufferState.IDLE)
    }
}

data class TelemetryChunkRecorderStartResult(
    val started: Boolean,
    val errorCode: String? = null,
)
