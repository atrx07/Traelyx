package io.github.atrx07.traelyx.recorder

import android.content.Context
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

const val TRIPDEBUG_ARCHIVE_VERSION = 1
const val TRIPDEBUG_EXPORT_CONTRACT_VERSION = 1
const val TRIPDEBUG_PRIVACY_CLASS = "precise_private"

data class TripDebugChunkDescriptor(
    val sequence: Long,
    val entryName: String,
    val byteLength: Int,
    val fileSha256: String,
)

data class TripDebugManifest(
    val archiveVersion: Int = TRIPDEBUG_ARCHIVE_VERSION,
    val privacyClass: String = TRIPDEBUG_PRIVACY_CLASS,
    val containsPreciseLocation: Boolean = true,
    val tripId: String,
    val telemetrySchemaVersion: Int,
    val chunkEncodingVersion: Int,
    val chunkCount: Int,
    val startElapsedNanos: Long,
    val endElapsedNanos: Long,
    val gnssSampleCount: Long,
    val accelerometerSampleCount: Long,
    val gyroscopeSampleCount: Long,
    val chunks: List<TripDebugChunkDescriptor>,
) {
    init {
        require(archiveVersion == TRIPDEBUG_ARCHIVE_VERSION)
        require(privacyClass == TRIPDEBUG_PRIVACY_CLASS)
        require(containsPreciseLocation)
        require(runCatching { UUID.fromString(tripId) }.isSuccess)
        require(telemetrySchemaVersion > 0)
        require(chunkEncodingVersion > 0)
        require(chunkCount in 1..MAX_TRIPDEBUG_CHUNKS)
        require(chunks.size == chunkCount)
        require(startElapsedNanos >= 0)
        require(endElapsedNanos >= startElapsedNanos)
        require(gnssSampleCount >= 0)
        require(accelerometerSampleCount >= 0)
        require(gyroscopeSampleCount >= 0)
        require(chunks.map { it.sequence } == (0L until chunkCount.toLong()).toList())
        require(chunks.map { it.entryName }.toSet().size == chunks.size)
    }
}

data class TripDebugInspection(
    val manifest: TripDebugManifest,
    val archiveByteLength: Long,
    val maxChunkGapNanos: Long,
    val maxGnssGapNanos: Long,
    val maxAccelerometerGapNanos: Long,
    val maxGyroscopeGapNanos: Long,
)

sealed interface TripDebugInspectionResult {
    data class Success(val inspection: TripDebugInspection) : TripDebugInspectionResult

    data class Invalid(val errorCode: String) : TripDebugInspectionResult
}

internal data class PreparedTripDebugChunk(
    val descriptor: TripDebugChunkDescriptor,
    val metadata: TelemetryChunkMetadata,
    val bytes: ByteArray,
)

class PreparedTripDebugExport internal constructor(
    val file: File,
    val inspection: TripDebugInspection,
) {
    val suggestedFileName: String
        get() = "traelyx-${inspection.manifest.tripId}.tripdebug"

    fun copyTo(output: OutputStream) {
        FileInputStream(file).use { input -> input.copyTo(output) }
        output.flush()
    }

    fun deleteTemporaryFile() {
        if (file.exists()) file.delete()
    }
}

sealed interface TripDebugPreparationResult {
    data class Success(val prepared: PreparedTripDebugExport) : TripDebugPreparationResult

    data class Failure(val errorCode: String) : TripDebugPreparationResult
}

class TripDebugArchiveExporter(
    private val store: TelemetryChunkStore,
    private val temporaryDirectory: File,
) {
    constructor(context: Context) : this(
        AtomicFileTelemetryChunkStore(context.applicationContext),
        File(context.applicationContext.cacheDir, "tripdebug-exports"),
    )

    fun prepare(tripId: String): TripDebugPreparationResult {
        if (runCatching { UUID.fromString(tripId) }.isFailure) {
            return TripDebugPreparationResult.Failure("export_invalid_trip_id")
        }
        val catalog = store.scan(tripId)
        if (
            catalog.corruptChunkCount != 0 ||
            catalog.orphanedWriteCount != 0 ||
            catalog.orderingViolationCount != 0
        ) {
            return TripDebugPreparationResult.Failure("export_catalog_not_verified")
        }
        if (catalog.validChunks.isEmpty()) {
            return TripDebugPreparationResult.Failure("export_trip_empty")
        }
        if (catalog.validChunks.size > MAX_TRIPDEBUG_CHUNKS) {
            return TripDebugPreparationResult.Failure("export_chunk_limit_exceeded")
        }
        if (catalog.validChunks.map { it.metadata.sequence } !=
            (0L until catalog.validChunks.size.toLong()).toList()
        ) {
            return TripDebugPreparationResult.Failure("export_sequence_gap")
        }

        val chunks = mutableListOf<PreparedTripDebugChunk>()
        for (decoded in catalog.validChunks) {
            val metadata = decoded.metadata
            val bytes = store.read(tripId, metadata.sequence)
                ?: return TripDebugPreparationResult.Failure("export_chunk_unreadable")
            val verified = TelemetryChunkCodec.decode(bytes)
            if (verified !is TelemetryChunkDecodeResult.Success) {
                return TripDebugPreparationResult.Failure("export_chunk_invalid")
            }
            if (verified.chunk.metadata != metadata) {
                return TripDebugPreparationResult.Failure("export_chunk_changed")
            }
            chunks +=
                PreparedTripDebugChunk(
                    descriptor =
                        TripDebugChunkDescriptor(
                            sequence = metadata.sequence,
                            entryName = chunkEntryName(metadata.sequence),
                            byteLength = bytes.size,
                            fileSha256 = sha256Hex(bytes),
                        ),
                    metadata = metadata,
                    bytes = bytes,
                )
        }

        val schemaVersions = chunks.map { it.metadata.telemetrySchemaVersion }.toSet()
        val encodingVersions = chunks.map { it.metadata.encodingVersion }.toSet()
        if (schemaVersions.size != 1 || encodingVersions.size != 1) {
            return TripDebugPreparationResult.Failure("export_mixed_versions")
        }
        val manifest =
            TripDebugManifest(
                tripId = tripId,
                telemetrySchemaVersion = schemaVersions.single(),
                chunkEncodingVersion = encodingVersions.single(),
                chunkCount = chunks.size,
                startElapsedNanos = chunks.first().metadata.startElapsedNanos,
                endElapsedNanos = chunks.last().metadata.endElapsedNanos,
                gnssSampleCount = chunks.sumOf { it.metadata.gnssSampleCount.toLong() },
                accelerometerSampleCount =
                    chunks.sumOf { it.metadata.accelerometerSampleCount.toLong() },
                gyroscopeSampleCount = chunks.sumOf { it.metadata.gyroscopeSampleCount.toLong() },
                chunks = chunks.map { it.descriptor },
            )
        if (!temporaryDirectory.exists() && !temporaryDirectory.mkdirs()) {
            return TripDebugPreparationResult.Failure("export_temporary_directory_failed")
        }
        temporaryDirectory.listFiles()
            ?.filter { STALE_EXPORT_PATTERN.matches(it.name) }
            ?.forEach { it.delete() }
        val target = File(temporaryDirectory, "$tripId.tmp")
        if (target.exists() && !target.delete()) {
            return TripDebugPreparationResult.Failure("export_temporary_cleanup_failed")
        }
        return try {
            FileOutputStream(target).use { output ->
                TripDebugArchiveCodec.write(manifest, chunks, output)
            }
            val inspection =
                FileInputStream(target).use { input ->
                    TripDebugArchiveCodec.inspect(input, target.length())
                }
            if (inspection is TripDebugInspectionResult.Success) {
                TripDebugPreparationResult.Success(
                    PreparedTripDebugExport(target, inspection.inspection),
                )
            } else {
                target.delete()
                TripDebugPreparationResult.Failure("export_self_inspection_failed")
            }
        } catch (_: Exception) {
            target.delete()
            TripDebugPreparationResult.Failure("export_archive_write_failed")
        }
    }
}

object TripDebugArchiveCodec {
    private const val MANIFEST_ENTRY_NAME = "manifest.txt"

    internal fun write(
        manifest: TripDebugManifest,
        chunks: List<PreparedTripDebugChunk>,
        output: OutputStream,
    ) {
        require(chunks.map { it.descriptor } == manifest.chunks)
        ZipOutputStream(BufferedOutputStream(output)).use { zip ->
            writeStoredEntry(zip, MANIFEST_ENTRY_NAME, encodeManifest(manifest))
            chunks.forEach { chunk ->
                writeStoredEntry(zip, chunk.descriptor.entryName, chunk.bytes)
            }
        }
    }

    fun inspect(
        input: InputStream,
        archiveByteLength: Long,
    ): TripDebugInspectionResult =
        try {
            require(archiveByteLength in 1..MAX_TRIPDEBUG_ARCHIVE_BYTES)
            ZipInputStream(BufferedInputStream(input)).use { zip ->
                val manifestEntry = zip.nextEntry ?: return invalid("tripdebug_manifest_missing")
                if (
                    manifestEntry.isDirectory ||
                    manifestEntry.name != MANIFEST_ENTRY_NAME ||
                    manifestEntry.method != ZipEntry.STORED
                ) {
                    return invalid("tripdebug_manifest_not_first")
                }
                val manifest = decodeManifest(readBounded(zip, MAX_TRIPDEBUG_MANIFEST_BYTES))
                    ?: return invalid("tripdebug_manifest_invalid")
                zip.closeEntry()

                var firstChunkStart: Long? = null
                var previousChunkEnd: Long? = null
                var maxChunkGap = 0L
                val firstByChannel = mutableMapOf<TelemetryChannel, Long>()
                val lastByChannel = mutableMapOf<TelemetryChannel, Long>()
                val maxGapByChannel = mutableMapOf<TelemetryChannel, Long>()
                var gnssCount = 0L
                var accelerometerCount = 0L
                var gyroscopeCount = 0L

                for (descriptor in manifest.chunks) {
                    val entry = zip.nextEntry ?: return invalid("tripdebug_chunk_missing")
                    if (
                        entry.isDirectory ||
                        entry.name != descriptor.entryName ||
                        entry.method != ZipEntry.STORED
                    ) {
                        return invalid("tripdebug_entry_order_invalid")
                    }
                    val bytes = readBounded(zip, MAX_TRIPDEBUG_CHUNK_BYTES)
                    zip.closeEntry()
                    if (bytes.size != descriptor.byteLength || sha256Hex(bytes) != descriptor.fileSha256) {
                        return invalid("tripdebug_chunk_file_mismatch")
                    }
                    val decoded = TelemetryChunkCodec.decode(bytes)
                    if (decoded !is TelemetryChunkDecodeResult.Success) {
                        return invalid("tripdebug_chunk_decode_failed")
                    }
                    val chunk = decoded.chunk
                    if (
                        chunk.metadata.tripId != manifest.tripId ||
                        chunk.metadata.sequence != descriptor.sequence ||
                        chunk.metadata.telemetrySchemaVersion != manifest.telemetrySchemaVersion ||
                        chunk.metadata.encodingVersion != manifest.chunkEncodingVersion
                    ) {
                        return invalid("tripdebug_chunk_metadata_mismatch")
                    }
                    if (previousChunkEnd != null) {
                        if (chunk.metadata.startElapsedNanos < previousChunkEnd) {
                            return invalid("tripdebug_chunk_order_invalid")
                        }
                        maxChunkGap = maxOf(maxChunkGap, chunk.metadata.startElapsedNanos - previousChunkEnd)
                    }
                    if (firstChunkStart == null) {
                        firstChunkStart = chunk.metadata.startElapsedNanos
                    }
                    previousChunkEnd = chunk.metadata.endElapsedNanos
                    for (record in chunk.records) {
                        firstByChannel.putIfAbsent(record.channel, record.tripElapsedNanos)
                        val previous = lastByChannel.put(record.channel, record.tripElapsedNanos)
                        if (previous != null) {
                            if (record.tripElapsedNanos < previous) {
                                return invalid("tripdebug_channel_order_invalid")
                            }
                            maxGapByChannel[record.channel] =
                                maxOf(
                                    maxGapByChannel[record.channel] ?: 0L,
                                    record.tripElapsedNanos - previous,
                                )
                        }
                        when (record.channel) {
                            TelemetryChannel.GNSS -> gnssCount += 1
                            TelemetryChannel.ACCELEROMETER -> accelerometerCount += 1
                            TelemetryChannel.GYROSCOPE -> gyroscopeCount += 1
                        }
                    }
                }
                if (zip.nextEntry != null) return invalid("tripdebug_unexpected_entry")
                if (
                    firstChunkStart != manifest.startElapsedNanos ||
                    previousChunkEnd != manifest.endElapsedNanos
                ) {
                    return invalid("tripdebug_manifest_bounds_mismatch")
                }
                if (
                    gnssCount != manifest.gnssSampleCount ||
                    accelerometerCount != manifest.accelerometerSampleCount ||
                    gyroscopeCount != manifest.gyroscopeSampleCount
                ) {
                    return invalid("tripdebug_sample_count_mismatch")
                }
                for (channel in TelemetryChannel.entries) {
                    val first = firstByChannel[channel]
                    val last = lastByChannel[channel]
                    maxGapByChannel[channel] =
                        if (first == null || last == null) {
                            manifest.endElapsedNanos - manifest.startElapsedNanos
                        } else {
                            maxOf(
                                maxGapByChannel[channel] ?: 0L,
                                first - manifest.startElapsedNanos,
                                manifest.endElapsedNanos - last,
                            )
                        }
                }
                TripDebugInspectionResult.Success(
                    TripDebugInspection(
                        manifest = manifest,
                        archiveByteLength = archiveByteLength,
                        maxChunkGapNanos = maxChunkGap,
                        maxGnssGapNanos = maxGapByChannel[TelemetryChannel.GNSS] ?: 0L,
                        maxAccelerometerGapNanos =
                            maxGapByChannel[TelemetryChannel.ACCELEROMETER] ?: 0L,
                        maxGyroscopeGapNanos = maxGapByChannel[TelemetryChannel.GYROSCOPE] ?: 0L,
                    ),
                )
            }
        } catch (_: Exception) {
            invalid("tripdebug_archive_invalid")
        }

    private fun writeStoredEntry(
        zip: ZipOutputStream,
        name: String,
        bytes: ByteArray,
    ) {
        val crc = CRC32().apply { update(bytes) }
        val entry =
            ZipEntry(name).apply {
                method = ZipEntry.STORED
                size = bytes.size.toLong()
                compressedSize = bytes.size.toLong()
                this.crc = crc.value
                time = 0L
            }
        zip.putNextEntry(entry)
        zip.write(bytes)
        zip.closeEntry()
    }

    private fun encodeManifest(manifest: TripDebugManifest): ByteArray {
        val lines = mutableListOf<String>()
        lines += "format=traelyx.tripdebug"
        lines += "archive_version=${manifest.archiveVersion}"
        lines += "privacy_class=${manifest.privacyClass}"
        lines += "contains_precise_location=${manifest.containsPreciseLocation}"
        lines += "trip_id=${manifest.tripId}"
        lines += "telemetry_schema_version=${manifest.telemetrySchemaVersion}"
        lines += "chunk_encoding_version=${manifest.chunkEncodingVersion}"
        lines += "chunk_count=${manifest.chunkCount}"
        lines += "start_elapsed_nanos=${manifest.startElapsedNanos}"
        lines += "end_elapsed_nanos=${manifest.endElapsedNanos}"
        lines += "gnss_sample_count=${manifest.gnssSampleCount}"
        lines += "accelerometer_sample_count=${manifest.accelerometerSampleCount}"
        lines += "gyroscope_sample_count=${manifest.gyroscopeSampleCount}"
        manifest.chunks.forEachIndexed { index, chunk ->
            lines += "chunk.$index.sequence=${chunk.sequence}"
            lines += "chunk.$index.entry=${chunk.entryName}"
            lines += "chunk.$index.byte_length=${chunk.byteLength}"
            lines += "chunk.$index.sha256=${chunk.fileSha256}"
        }
        return (lines.joinToString("\n") + "\n").toByteArray(Charsets.UTF_8)
    }

    private fun decodeManifest(bytes: ByteArray): TripDebugManifest? =
        runCatching {
            val text = bytes.toString(Charsets.UTF_8)
            require(text.endsWith("\n"))
            val values = linkedMapOf<String, String>()
            for (line in text.dropLast(1).split('\n')) {
                val separator = line.indexOf('=')
                require(separator > 0)
                val key = line.substring(0, separator)
                val value = line.substring(separator + 1)
                require(KEY_PATTERN.matches(key) && VALUE_PATTERN.matches(value))
                require(values.putIfAbsent(key, value) == null)
            }
            require(values.remove("format") == "traelyx.tripdebug")
            val archiveVersion = values.remove("archive_version")?.toIntOrNull()
            val privacyClass = values.remove("privacy_class")
            val containsPreciseLocation = values.remove("contains_precise_location")?.toBooleanStrictOrNull()
            val tripId = values.remove("trip_id")
            val telemetrySchemaVersion = values.remove("telemetry_schema_version")?.toIntOrNull()
            val chunkEncodingVersion = values.remove("chunk_encoding_version")?.toIntOrNull()
            val chunkCount = values.remove("chunk_count")?.toIntOrNull()
            val startElapsedNanos = values.remove("start_elapsed_nanos")?.toLongOrNull()
            val endElapsedNanos = values.remove("end_elapsed_nanos")?.toLongOrNull()
            val gnssSampleCount = values.remove("gnss_sample_count")?.toLongOrNull()
            val accelerometerSampleCount = values.remove("accelerometer_sample_count")?.toLongOrNull()
            val gyroscopeSampleCount = values.remove("gyroscope_sample_count")?.toLongOrNull()
            require(chunkCount != null && chunkCount in 1..MAX_TRIPDEBUG_CHUNKS)
            val chunks =
                (0 until chunkCount).map { index ->
                    TripDebugChunkDescriptor(
                        sequence = requireNotNull(values.remove("chunk.$index.sequence")?.toLongOrNull()),
                        entryName = requireNotNull(values.remove("chunk.$index.entry")),
                        byteLength = requireNotNull(values.remove("chunk.$index.byte_length")?.toIntOrNull()),
                        fileSha256 = requireNotNull(values.remove("chunk.$index.sha256")),
                    ).also { descriptor ->
                        require(descriptor.entryName == chunkEntryName(descriptor.sequence))
                        require(descriptor.byteLength in 1..MAX_TRIPDEBUG_CHUNK_BYTES)
                        require(SHA256_PATTERN.matches(descriptor.fileSha256))
                    }
                }
            require(values.isEmpty())
            TripDebugManifest(
                archiveVersion = requireNotNull(archiveVersion),
                privacyClass = requireNotNull(privacyClass),
                containsPreciseLocation = requireNotNull(containsPreciseLocation),
                tripId = requireNotNull(tripId),
                telemetrySchemaVersion = requireNotNull(telemetrySchemaVersion),
                chunkEncodingVersion = requireNotNull(chunkEncodingVersion),
                chunkCount = chunkCount,
                startElapsedNanos = requireNotNull(startElapsedNanos),
                endElapsedNanos = requireNotNull(endElapsedNanos),
                gnssSampleCount = requireNotNull(gnssSampleCount),
                accelerometerSampleCount = requireNotNull(accelerometerSampleCount),
                gyroscopeSampleCount = requireNotNull(gyroscopeSampleCount),
                chunks = chunks,
            )
        }.getOrNull()

    private fun readBounded(input: InputStream, limit: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8_192)
        var total = 0
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            require(total <= limit)
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    private fun invalid(errorCode: String): TripDebugInspectionResult.Invalid =
        TripDebugInspectionResult.Invalid(errorCode)

    private val KEY_PATTERN = Regex("[a-z0-9_.]{1,64}")
    private val VALUE_PATTERN = Regex("[A-Za-z0-9_./-]{1,256}")
}

fun TripDebugInspection.toBridgeMap(
    exported: Boolean,
    errorCode: String? = null,
): Map<String, Any?> =
    linkedMapOf(
        "contractVersion" to TRIPDEBUG_EXPORT_CONTRACT_VERSION,
        "archiveVersion" to manifest.archiveVersion,
        "tripId" to manifest.tripId,
        "exported" to exported,
        "containsPreciseLocation" to manifest.containsPreciseLocation,
        "privacyClass" to manifest.privacyClass,
        "chunkCount" to manifest.chunkCount,
        "gnssSampleCount" to manifest.gnssSampleCount,
        "accelerometerSampleCount" to manifest.accelerometerSampleCount,
        "gyroscopeSampleCount" to manifest.gyroscopeSampleCount,
        "durationNanos" to manifest.endElapsedNanos - manifest.startElapsedNanos,
        "archiveByteLength" to archiveByteLength,
        "maxChunkGapNanos" to maxChunkGapNanos,
        "maxGnssGapNanos" to maxGnssGapNanos,
        "maxAccelerometerGapNanos" to maxAccelerometerGapNanos,
        "maxGyroscopeGapNanos" to maxGyroscopeGapNanos,
        "errorCode" to errorCode,
    )

fun tripDebugExportFailureMap(
    tripId: String?,
    errorCode: String,
): Map<String, Any?> =
    linkedMapOf(
        "contractVersion" to TRIPDEBUG_EXPORT_CONTRACT_VERSION,
        "archiveVersion" to TRIPDEBUG_ARCHIVE_VERSION,
        "tripId" to tripId,
        "exported" to false,
        "containsPreciseLocation" to true,
        "privacyClass" to TRIPDEBUG_PRIVACY_CLASS,
        "chunkCount" to 0,
        "gnssSampleCount" to 0L,
        "accelerometerSampleCount" to 0L,
        "gyroscopeSampleCount" to 0L,
        "durationNanos" to 0L,
        "archiveByteLength" to 0L,
        "maxChunkGapNanos" to 0L,
        "maxGnssGapNanos" to 0L,
        "maxAccelerometerGapNanos" to 0L,
        "maxGyroscopeGapNanos" to 0L,
        "errorCode" to errorCode,
    )

private fun chunkEntryName(sequence: Long): String =
    "chunks/${String.format(Locale.ROOT, "%010d.tlxc", sequence)}"

private fun sha256Hex(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

private const val MAX_TRIPDEBUG_CHUNKS = 10_000
private const val MAX_TRIPDEBUG_MANIFEST_BYTES = 2 * 1024 * 1024
private const val MAX_TRIPDEBUG_CHUNK_BYTES = 4 * 1024 * 1024
private const val MAX_TRIPDEBUG_ARCHIVE_BYTES = 512L * 1024L * 1024L
private val SHA256_PATTERN = Regex("[0-9a-f]{64}")
private val STALE_EXPORT_PATTERN = Regex("[0-9a-fA-F-]{36}\\.tmp")
