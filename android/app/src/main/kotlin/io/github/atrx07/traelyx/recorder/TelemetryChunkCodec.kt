package io.github.atrx07.traelyx.recorder

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.io.IOException
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.DataFormatException
import java.util.zip.Deflater
import java.util.zip.DeflaterOutputStream
import java.util.zip.InflaterInputStream

object TelemetryChunkCodec {
    private const val ENVELOPE_MAGIC = 0x54525843
    private const val COMPLETION_MAGIC = 0x434F4D50
    private const val MAX_COMPRESSED_PAYLOAD_BYTES = 4 * 1024 * 1024
    private const val MAX_DECOMPRESSED_PAYLOAD_BYTES = 16 * 1024 * 1024
    private const val SHA256_LENGTH_BYTES = 32

    fun encode(
        tripId: String,
        sequence: Long,
        records: List<TelemetrySampleRecord>,
        createdAtUtcEpochMillis: Long,
    ): EncodedTelemetryChunk {
        require(runCatching { UUID.fromString(tripId) }.isSuccess)
        require(sequence >= 0)
        require(records.isNotEmpty())
        require(records.size <= TELEMETRY_CHUNK_MAX_SAMPLES)
        require(createdAtUtcEpochMillis > 0)

        val ordered = records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR)
        require(ordered == records)
        require(
            ordered.last().tripElapsedNanos - ordered.first().tripElapsedNanos <=
                TELEMETRY_CHUNK_MAX_SPAN_NANOS,
        )
        val rawPayload = encodeRecords(ordered)
        val storedPayload = deflate(rawPayload)
        require(storedPayload.size <= MAX_COMPRESSED_PAYLOAD_BYTES)
        val checksum = sha256(storedPayload)
        val checksumHex = checksum.toHex()
        val counts = ordered.groupingBy { it.channel }.eachCount()

        val envelope = ByteArrayOutputStream()
        DataOutputStream(envelope).use { data ->
            data.writeInt(ENVELOPE_MAGIC)
            data.writeInt(TELEMETRY_CHUNK_ENCODING_VERSION)
            data.writeInt(RAW_GNSS_SCHEMA_VERSION)
            data.writeUTF(tripId)
            data.writeLong(sequence)
            data.writeLong(ordered.first().tripElapsedNanos)
            data.writeLong(ordered.last().tripElapsedNanos)
            data.writeInt(counts[TelemetryChannel.GNSS] ?: 0)
            data.writeInt(counts[TelemetryChannel.ACCELEROMETER] ?: 0)
            data.writeInt(counts[TelemetryChannel.GYROSCOPE] ?: 0)
            data.writeUTF(TELEMETRY_CHUNK_COMPRESSION)
            data.writeUTF(TELEMETRY_CHUNK_CHECKSUM_ALGORITHM)
            data.writeLong(createdAtUtcEpochMillis)
            data.writeInt(storedPayload.size)
            data.write(storedPayload)
            data.writeInt(checksum.size)
            data.write(checksum)
            data.writeInt(COMPLETION_MAGIC)
            data.flush()
        }
        val bytes = envelope.toByteArray()
        val metadata =
            TelemetryChunkMetadata(
                tripId = tripId,
                sequence = sequence,
                startElapsedNanos = ordered.first().tripElapsedNanos,
                endElapsedNanos = ordered.last().tripElapsedNanos,
                gnssSampleCount = counts[TelemetryChannel.GNSS] ?: 0,
                accelerometerSampleCount = counts[TelemetryChannel.ACCELEROMETER] ?: 0,
                gyroscopeSampleCount = counts[TelemetryChannel.GYROSCOPE] ?: 0,
                checksumHex = checksumHex,
                byteLength = bytes.size,
                createdAtUtcEpochMillis = createdAtUtcEpochMillis,
            )
        return EncodedTelemetryChunk(metadata = metadata, bytes = bytes)
    }

    fun decode(bytes: ByteArray): TelemetryChunkDecodeResult =
        try {
            val input = ByteArrayInputStream(bytes)
            val data = DataInputStream(input)
            if (data.readInt() != ENVELOPE_MAGIC) return invalid("chunk_invalid_magic")
            val encodingVersion = data.readInt()
            val telemetrySchemaVersion = data.readInt()
            if (
                encodingVersion != TELEMETRY_CHUNK_ENCODING_VERSION ||
                telemetrySchemaVersion != RAW_GNSS_SCHEMA_VERSION
            ) {
                return invalid("chunk_unknown_version")
            }
            val tripId = data.readUTF()
            if (runCatching { UUID.fromString(tripId) }.isFailure) {
                return invalid("chunk_invalid_trip_id")
            }
            val sequence = data.readLong()
            val startElapsedNanos = data.readLong()
            val endElapsedNanos = data.readLong()
            val gnssCount = data.readInt()
            val accelerometerCount = data.readInt()
            val gyroscopeCount = data.readInt()
            val compression = data.readUTF()
            val checksumAlgorithm = data.readUTF()
            val createdAtUtcEpochMillis = data.readLong()
            if (
                sequence < 0 || startElapsedNanos < 0 || endElapsedNanos < startElapsedNanos ||
                gnssCount < 0 || accelerometerCount < 0 || gyroscopeCount < 0 ||
                gnssCount + accelerometerCount + gyroscopeCount !in
                1..TELEMETRY_CHUNK_MAX_SAMPLES ||
                compression != TELEMETRY_CHUNK_COMPRESSION ||
                checksumAlgorithm != TELEMETRY_CHUNK_CHECKSUM_ALGORITHM ||
                createdAtUtcEpochMillis <= 0
            ) {
                return invalid("chunk_invalid_metadata")
            }
            val storedPayloadLength = data.readInt()
            if (storedPayloadLength !in 1..MAX_COMPRESSED_PAYLOAD_BYTES) {
                return invalid("chunk_invalid_payload_length")
            }
            val storedPayload = ByteArray(storedPayloadLength)
            data.readFully(storedPayload)
            val checksumLength = data.readInt()
            if (checksumLength != SHA256_LENGTH_BYTES) {
                return invalid("chunk_invalid_checksum")
            }
            val expectedChecksum = ByteArray(checksumLength)
            data.readFully(expectedChecksum)
            if (!MessageDigest.isEqual(expectedChecksum, sha256(storedPayload))) {
                return invalid("chunk_checksum_mismatch")
            }
            if (data.readInt() != COMPLETION_MAGIC) return invalid("chunk_incomplete")
            if (data.read() != -1) return invalid("chunk_trailing_bytes")

            val records = decodeRecords(inflate(storedPayload))
            if (records.size != gnssCount + accelerometerCount + gyroscopeCount) {
                return invalid("chunk_count_mismatch")
            }
            if (records != records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR)) {
                return invalid("chunk_record_order_invalid")
            }
            if (
                records.first().tripElapsedNanos != startElapsedNanos ||
                records.last().tripElapsedNanos != endElapsedNanos ||
                records.count { it.channel == TelemetryChannel.GNSS } != gnssCount ||
                records.count { it.channel == TelemetryChannel.ACCELEROMETER } !=
                accelerometerCount ||
                records.count { it.channel == TelemetryChannel.GYROSCOPE } != gyroscopeCount
            ) {
                return invalid("chunk_metadata_mismatch")
            }
            val metadata =
                TelemetryChunkMetadata(
                    encodingVersion = encodingVersion,
                    telemetrySchemaVersion = telemetrySchemaVersion,
                    tripId = tripId,
                    sequence = sequence,
                    startElapsedNanos = startElapsedNanos,
                    endElapsedNanos = endElapsedNanos,
                    gnssSampleCount = gnssCount,
                    accelerometerSampleCount = accelerometerCount,
                    gyroscopeSampleCount = gyroscopeCount,
                    compression = compression,
                    checksumAlgorithm = checksumAlgorithm,
                    checksumHex = expectedChecksum.toHex(),
                    byteLength = bytes.size,
                    createdAtUtcEpochMillis = createdAtUtcEpochMillis,
                )
            TelemetryChunkDecodeResult.Success(
                DecodedTelemetryChunk(metadata = metadata, records = records),
            )
        } catch (_: EOFException) {
            invalid("chunk_truncated")
        } catch (_: DataFormatException) {
            invalid("chunk_decompression_failed")
        } catch (_: IOException) {
            invalid("chunk_io_invalid")
        } catch (_: IllegalArgumentException) {
            invalid("chunk_invalid")
        } catch (_: RuntimeException) {
            invalid("chunk_invalid")
        }

    /**
     * Verifies the complete chunk contract while retaining only GNSS records.
     * IMU fields are parsed and validated in-place without allocating samples.
     */
    fun decodeGnss(bytes: ByteArray): TelemetryChunkGnssDecodeResult =
        try {
            val input = ByteArrayInputStream(bytes)
            val data = DataInputStream(input)
            if (data.readInt() != ENVELOPE_MAGIC) return invalidGnss("chunk_invalid_magic")
            val encodingVersion = data.readInt()
            val telemetrySchemaVersion = data.readInt()
            if (
                encodingVersion != TELEMETRY_CHUNK_ENCODING_VERSION ||
                telemetrySchemaVersion != RAW_GNSS_SCHEMA_VERSION
            ) {
                return invalidGnss("chunk_unknown_version")
            }
            val tripId = data.readUTF()
            if (runCatching { UUID.fromString(tripId) }.isFailure) {
                return invalidGnss("chunk_invalid_trip_id")
            }
            val sequence = data.readLong()
            val startElapsedNanos = data.readLong()
            val endElapsedNanos = data.readLong()
            val gnssCount = data.readInt()
            val accelerometerCount = data.readInt()
            val gyroscopeCount = data.readInt()
            val compression = data.readUTF()
            val checksumAlgorithm = data.readUTF()
            val createdAtUtcEpochMillis = data.readLong()
            if (
                sequence < 0 || startElapsedNanos < 0 || endElapsedNanos < startElapsedNanos ||
                gnssCount < 0 || accelerometerCount < 0 || gyroscopeCount < 0 ||
                gnssCount + accelerometerCount + gyroscopeCount !in
                1..TELEMETRY_CHUNK_MAX_SAMPLES ||
                compression != TELEMETRY_CHUNK_COMPRESSION ||
                checksumAlgorithm != TELEMETRY_CHUNK_CHECKSUM_ALGORITHM ||
                createdAtUtcEpochMillis <= 0
            ) {
                return invalidGnss("chunk_invalid_metadata")
            }
            val storedPayloadLength = data.readInt()
            if (storedPayloadLength !in 1..MAX_COMPRESSED_PAYLOAD_BYTES) {
                return invalidGnss("chunk_invalid_payload_length")
            }
            val storedPayload = ByteArray(storedPayloadLength)
            data.readFully(storedPayload)
            val checksumLength = data.readInt()
            if (checksumLength != SHA256_LENGTH_BYTES) {
                return invalidGnss("chunk_invalid_checksum")
            }
            val expectedChecksum = ByteArray(checksumLength)
            data.readFully(expectedChecksum)
            if (!MessageDigest.isEqual(expectedChecksum, sha256(storedPayload))) {
                return invalidGnss("chunk_checksum_mismatch")
            }
            if (data.readInt() != COMPLETION_MAGIC) return invalidGnss("chunk_incomplete")
            if (data.read() != -1) return invalidGnss("chunk_trailing_bytes")

            val decoded = decodeGnssRecords(inflate(storedPayload))
            if (
                decoded.totalCount != gnssCount + accelerometerCount + gyroscopeCount ||
                decoded.gnssCount != gnssCount ||
                decoded.accelerometerCount != accelerometerCount ||
                decoded.gyroscopeCount != gyroscopeCount
            ) {
                return invalidGnss("chunk_count_mismatch")
            }
            if (
                decoded.firstElapsedNanos != startElapsedNanos ||
                decoded.lastElapsedNanos != endElapsedNanos
            ) {
                return invalidGnss("chunk_metadata_mismatch")
            }
            val metadata =
                TelemetryChunkMetadata(
                    encodingVersion = encodingVersion,
                    telemetrySchemaVersion = telemetrySchemaVersion,
                    tripId = tripId,
                    sequence = sequence,
                    startElapsedNanos = startElapsedNanos,
                    endElapsedNanos = endElapsedNanos,
                    gnssSampleCount = gnssCount,
                    accelerometerSampleCount = accelerometerCount,
                    gyroscopeSampleCount = gyroscopeCount,
                    compression = compression,
                    checksumAlgorithm = checksumAlgorithm,
                    checksumHex = expectedChecksum.toHex(),
                    byteLength = bytes.size,
                    createdAtUtcEpochMillis = createdAtUtcEpochMillis,
                )
            TelemetryChunkGnssDecodeResult.Success(
                DecodedGnssTelemetryChunk(
                    metadata = metadata,
                    samples = decoded.samples,
                    channelElapsedRanges = decoded.channelElapsedRanges,
                ),
            )
        } catch (_: EOFException) {
            invalidGnss("chunk_truncated")
        } catch (_: DataFormatException) {
            invalidGnss("chunk_decompression_failed")
        } catch (_: IOException) {
            invalidGnss("chunk_io_invalid")
        } catch (_: IllegalArgumentException) {
            invalidGnss("chunk_invalid")
        } catch (_: RuntimeException) {
            invalidGnss("chunk_invalid")
        }

    private fun encodeRecords(records: List<TelemetrySampleRecord>): ByteArray {
        val output = ByteArrayOutputStream()
        DataOutputStream(output).use { data ->
            data.writeInt(records.size)
            for (record in records) {
                data.writeByte(record.channel.wireId)
                data.writeLong(record.tripElapsedNanos)
                data.writeLong(record.sourceTimestampNanos)
                when (record) {
                    is TelemetrySampleRecord.Gnss -> data.writeGnss(record.sample)
                    is TelemetrySampleRecord.Imu -> data.writeImu(record.sample)
                }
            }
            data.flush()
        }
        return output.toByteArray()
    }

    private fun decodeRecords(bytes: ByteArray): List<TelemetrySampleRecord> {
        val input = ByteArrayInputStream(bytes)
        val data = DataInputStream(input)
        val count = data.readInt()
        require(count in 1..TELEMETRY_CHUNK_MAX_SAMPLES)
        val records = ArrayList<TelemetrySampleRecord>(count)
        repeat(count) {
            val channel =
                TelemetryChannel.fromWireId(data.readUnsignedByte())
                    ?: throw IllegalArgumentException("Unknown telemetry channel")
            val tripElapsedNanos = data.readLong()
            val sourceTimestampNanos = data.readLong()
            require(tripElapsedNanos >= 0 && sourceTimestampNanos >= 0)
            records +=
                when (channel) {
                    TelemetryChannel.GNSS ->
                        TelemetrySampleRecord.Gnss(
                            data.readGnss(tripElapsedNanos, sourceTimestampNanos),
                        )

                    TelemetryChannel.ACCELEROMETER,
                    TelemetryChannel.GYROSCOPE,
                    ->
                        TelemetrySampleRecord.Imu(
                            data.readImu(channel, tripElapsedNanos, sourceTimestampNanos),
                        )
                }
        }
        require(data.read() == -1)
        return records
    }

    private fun decodeGnssRecords(bytes: ByteArray): GnssOnlyRecordSummary {
        val data = DataInputStream(ByteArrayInputStream(bytes))
        val count = data.readInt()
        require(count in 1..TELEMETRY_CHUNK_MAX_SAMPLES)
        val samples = mutableListOf<RawGnssSample>()
        var gnssCount = 0
        var accelerometerCount = 0
        var gyroscopeCount = 0
        var firstElapsedNanos: Long? = null
        var lastElapsedNanos: Long? = null
        var previousElapsedNanos: Long? = null
        var previousChannelWireId: Int? = null
        var previousSourceTimestampNanos: Long? = null
        val firstChannelElapsedNanos = mutableMapOf<TelemetryChannel, Long>()
        val lastChannelElapsedNanos = mutableMapOf<TelemetryChannel, Long>()
        repeat(count) {
            val channel =
                TelemetryChannel.fromWireId(data.readUnsignedByte())
                    ?: throw IllegalArgumentException("Unknown telemetry channel")
            val tripElapsedNanos = data.readLong()
            val sourceTimestampNanos = data.readLong()
            require(tripElapsedNanos >= 0 && sourceTimestampNanos >= 0)
            val lastChannelElapsed = lastChannelElapsedNanos[channel]
            require(lastChannelElapsed == null || tripElapsedNanos > lastChannelElapsed)
            firstChannelElapsedNanos.putIfAbsent(channel, tripElapsedNanos)
            lastChannelElapsedNanos[channel] = tripElapsedNanos
            val priorElapsed = previousElapsedNanos
            if (priorElapsed != null) {
                require(
                    tripElapsedNanos > priorElapsed ||
                        tripElapsedNanos == priorElapsed &&
                        (
                            channel.wireId > requireNotNull(previousChannelWireId) ||
                                channel.wireId == previousChannelWireId &&
                                sourceTimestampNanos >= requireNotNull(previousSourceTimestampNanos)
                        ),
                )
            }
            firstElapsedNanos = firstElapsedNanos ?: tripElapsedNanos
            lastElapsedNanos = tripElapsedNanos
            previousElapsedNanos = tripElapsedNanos
            previousChannelWireId = channel.wireId
            previousSourceTimestampNanos = sourceTimestampNanos
            when (channel) {
                TelemetryChannel.GNSS -> {
                    samples += data.readGnss(tripElapsedNanos, sourceTimestampNanos)
                    gnssCount += 1
                }

                TelemetryChannel.ACCELEROMETER -> {
                    data.validateAndSkipImu()
                    accelerometerCount += 1
                }

                TelemetryChannel.GYROSCOPE -> {
                    data.validateAndSkipImu()
                    gyroscopeCount += 1
                }
            }
        }
        require(data.read() == -1)
        return GnssOnlyRecordSummary(
            samples = samples,
            totalCount = count,
            gnssCount = gnssCount,
            accelerometerCount = accelerometerCount,
            gyroscopeCount = gyroscopeCount,
            firstElapsedNanos = requireNotNull(firstElapsedNanos),
            lastElapsedNanos = requireNotNull(lastElapsedNanos),
            channelElapsedRanges =
                firstChannelElapsedNanos.mapValues { (channel, first) ->
                    first..requireNotNull(lastChannelElapsedNanos[channel])
                },
        )
    }

    private fun DataInputStream.validateAndSkipImu() {
        require(readInt() == RAW_IMU_SCHEMA_VERSION)
        val x = readFloat()
        val y = readFloat()
        val z = readFloat()
        val accuracyStatus = readInt()
        val flags = decodeImuFlags(readInt())
        require(x.isFinite() && y.isFinite() && z.isFinite())
        require(
            accuracyStatus in
                RawImuSample.MIN_SENSOR_ACCURACY_STATUS..RawImuSample.MAX_SENSOR_ACCURACY_STATUS,
        )
        require(
            (ImuQualityFlag.SENSOR_UNRELIABLE in flags) ==
                (accuracyStatus <= RawImuSample.SENSOR_STATUS_UNRELIABLE),
        )
    }

    private fun DataOutputStream.writeGnss(sample: RawGnssSample) {
        writeInt(sample.schemaVersion)
        writeOptionalLong(sample.sourceWallTimeUtcEpochMillis)
        writeDouble(sample.latitudeDegrees)
        writeDouble(sample.longitudeDegrees)
        writeFloat(sample.horizontalAccuracyMetres)
        writeOptionalDouble(sample.altitudeMetres)
        writeOptionalFloat(sample.verticalAccuracyMetres)
        writeOptionalFloat(sample.speedMetresPerSecond)
        writeOptionalFloat(sample.speedAccuracyMetresPerSecond)
        writeOptionalFloat(sample.bearingDegrees)
        writeOptionalFloat(sample.bearingAccuracyDegrees)
        writeUTF(sample.provider)
        writeBoolean(sample.isMockSignal)
        writeInt(encodeGnssFlags(sample.qualityFlags))
    }

    private fun DataInputStream.readGnss(
        tripElapsedNanos: Long,
        sourceTimestampNanos: Long,
    ): RawGnssSample {
        val schemaVersion = readInt()
        require(schemaVersion == RAW_GNSS_SCHEMA_VERSION)
        return RawGnssSample(
            schemaVersion = schemaVersion,
            tripElapsedNanos = tripElapsedNanos,
            sourceTimestampNanos = sourceTimestampNanos,
            sourceWallTimeUtcEpochMillis = readOptionalLong(),
            latitudeDegrees = readDouble(),
            longitudeDegrees = readDouble(),
            horizontalAccuracyMetres = readFloat(),
            altitudeMetres = readOptionalDouble(),
            verticalAccuracyMetres = readOptionalFloat(),
            speedMetresPerSecond = readOptionalFloat(),
            speedAccuracyMetresPerSecond = readOptionalFloat(),
            bearingDegrees = readOptionalFloat(),
            bearingAccuracyDegrees = readOptionalFloat(),
            provider = readUTF(),
            isMockSignal = readBoolean(),
            qualityFlags = decodeGnssFlags(readInt()),
        )
    }

    private fun DataOutputStream.writeImu(sample: RawImuSample) {
        writeInt(sample.schemaVersion)
        writeFloat(sample.x)
        writeFloat(sample.y)
        writeFloat(sample.z)
        writeInt(sample.accuracyStatus)
        writeInt(encodeImuFlags(sample.qualityFlags))
    }

    private fun DataInputStream.readImu(
        channel: TelemetryChannel,
        tripElapsedNanos: Long,
        sourceTimestampNanos: Long,
    ): RawImuSample {
        val schemaVersion = readInt()
        require(schemaVersion == RAW_IMU_SCHEMA_VERSION)
        return RawImuSample(
            schemaVersion = schemaVersion,
            sensorType =
                when (channel) {
                    TelemetryChannel.ACCELEROMETER -> ImuSensorType.ACCELEROMETER
                    TelemetryChannel.GYROSCOPE -> ImuSensorType.GYROSCOPE
                    TelemetryChannel.GNSS -> throw IllegalArgumentException("GNSS is not IMU")
                },
            tripElapsedNanos = tripElapsedNanos,
            sourceTimestampNanos = sourceTimestampNanos,
            x = readFloat(),
            y = readFloat(),
            z = readFloat(),
            accuracyStatus = readInt(),
            qualityFlags = decodeImuFlags(readInt()),
        )
    }

    private fun DataOutputStream.writeOptionalLong(value: Long?) {
        writeBoolean(value != null)
        if (value != null) writeLong(value)
    }

    private fun DataInputStream.readOptionalLong(): Long? =
        if (readBoolean()) readLong() else null

    private fun DataOutputStream.writeOptionalDouble(value: Double?) {
        writeBoolean(value != null)
        if (value != null) writeDouble(value)
    }

    private fun DataInputStream.readOptionalDouble(): Double? =
        if (readBoolean()) readDouble() else null

    private fun DataOutputStream.writeOptionalFloat(value: Float?) {
        writeBoolean(value != null)
        if (value != null) writeFloat(value)
    }

    private fun DataInputStream.readOptionalFloat(): Float? =
        if (readBoolean()) readFloat() else null

    private fun encodeGnssFlags(flags: Set<GnssQualityFlag>): Int =
        flags.fold(0) { bits, flag ->
            bits or
                when (flag) {
                    GnssQualityFlag.GNSS_LOW_ACCURACY -> 1
                    GnssQualityFlag.CLOCK_DISCONTINUITY -> 1 shl 1
                    GnssQualityFlag.MOCK_LOCATION_SIGNAL -> 1 shl 2
                }
        }

    private fun decodeGnssFlags(bits: Int): Set<GnssQualityFlag> {
        require(bits and GNSS_FLAG_MASK.inv() == 0)
        return buildSet {
            if (bits and 1 != 0) add(GnssQualityFlag.GNSS_LOW_ACCURACY)
            if (bits and (1 shl 1) != 0) add(GnssQualityFlag.CLOCK_DISCONTINUITY)
            if (bits and (1 shl 2) != 0) add(GnssQualityFlag.MOCK_LOCATION_SIGNAL)
        }
    }

    private fun encodeImuFlags(flags: Set<ImuQualityFlag>): Int =
        flags.fold(0) { bits, flag ->
            bits or
                when (flag) {
                    ImuQualityFlag.CLOCK_DISCONTINUITY -> 1
                    ImuQualityFlag.IMU_DROPOUT -> 1 shl 1
                    ImuQualityFlag.SENSOR_UNRELIABLE -> 1 shl 2
                }
        }

    private fun decodeImuFlags(bits: Int): Set<ImuQualityFlag> {
        require(bits and IMU_FLAG_MASK.inv() == 0)
        return buildSet {
            if (bits and 1 != 0) add(ImuQualityFlag.CLOCK_DISCONTINUITY)
            if (bits and (1 shl 1) != 0) add(ImuQualityFlag.IMU_DROPOUT)
            if (bits and (1 shl 2) != 0) add(ImuQualityFlag.SENSOR_UNRELIABLE)
        }
    }

    private fun deflate(bytes: ByteArray): ByteArray {
        val output = ByteArrayOutputStream()
        val deflater = Deflater(Deflater.BEST_SPEED)
        try {
            DeflaterOutputStream(output, deflater, 8_192, true).use { it.write(bytes) }
        } finally {
            deflater.end()
        }
        return output.toByteArray()
    }

    @Throws(IOException::class, DataFormatException::class)
    private fun inflate(bytes: ByteArray): ByteArray {
        val output = ByteArrayOutputStream()
        InflaterInputStream(ByteArrayInputStream(bytes)).use { input ->
            val buffer = ByteArray(8_192)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                if (total > MAX_DECOMPRESSED_PAYLOAD_BYTES) {
                    throw DataFormatException("Decompressed payload exceeds limit")
                }
                output.write(buffer, 0, read)
            }
        }
        return output.toByteArray()
    }

    private fun sha256(bytes: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(bytes)

    private fun ByteArray.toHex(): String = joinToString(separator = "") { "%02x".format(it) }

    private fun invalid(errorCode: String): TelemetryChunkDecodeResult =
        TelemetryChunkDecodeResult.Invalid(errorCode)

    private fun invalidGnss(errorCode: String): TelemetryChunkGnssDecodeResult =
        TelemetryChunkGnssDecodeResult.Invalid(errorCode)

    private data class GnssOnlyRecordSummary(
        val samples: List<RawGnssSample>,
        val totalCount: Int,
        val gnssCount: Int,
        val accelerometerCount: Int,
        val gyroscopeCount: Int,
        val firstElapsedNanos: Long,
        val lastElapsedNanos: Long,
        val channelElapsedRanges: Map<TelemetryChannel, LongRange>,
    )

    private const val GNSS_FLAG_MASK = 0b111
    private const val IMU_FLAG_MASK = 0b111
}

object TelemetryChunkCatalog {
    fun inspect(candidates: List<TelemetryChunkCandidate>): TelemetryChunkCatalogSnapshot {
        val maxObservedSequence = candidates.maxOfOrNull { it.observedSequence }
        var corruptCount = 0
        var orphanedCount = 0
        var orderingViolationCount = 0
        val decodedBySequence = linkedMapOf<Long, DecodedTelemetryChunk>()

        for (candidate in candidates.sortedBy { it.observedSequence }) {
            if (candidate.orphanedIncompleteWrite || candidate.bytes == null) {
                orphanedCount += 1
                continue
            }
            when (val result = TelemetryChunkCodec.decode(candidate.bytes)) {
                is TelemetryChunkDecodeResult.Invalid -> corruptCount += 1
                is TelemetryChunkDecodeResult.Success -> {
                    if (result.chunk.metadata.sequence != candidate.observedSequence) {
                        corruptCount += 1
                    } else if (decodedBySequence.putIfAbsent(candidate.observedSequence, result.chunk) != null) {
                        corruptCount += 1
                    }
                }
            }
        }

        val valid = mutableListOf<DecodedTelemetryChunk>()
        var lastEnd: Long? = null
        for (chunk in decodedBySequence.values.sortedBy { it.metadata.sequence }) {
            if (lastEnd != null && chunk.metadata.startElapsedNanos < lastEnd) {
                orderingViolationCount += 1
                continue
            }
            valid += chunk
            lastEnd = chunk.metadata.endElapsedNanos
        }
        return TelemetryChunkCatalogSnapshot(
            validChunks = valid,
            corruptChunkCount = corruptCount,
            orphanedWriteCount = orphanedCount,
            orderingViolationCount = orderingViolationCount,
            maxObservedSequence = maxObservedSequence,
        )
    }
}
