package io.github.atrx07.traelyx.recorder

import android.content.Context
import android.util.AtomicFile
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.Locale
import java.util.UUID

const val RECORDER_FINALIZATION_CONTRACT_VERSION = 1
const val RECORDER_FINALIZATION_LOGIC_VERSION = 1
const val RECORDER_FINALIZATION_METADATA_VERSION = 1

data class PendingTripFinalizationRecord(
    val metadataVersion: Int = RECORDER_FINALIZATION_METADATA_VERSION,
    val tripId: String,
    val startedAtUtcEpochMillis: Long,
    val startedAtElapsedRealtimeNanos: Long,
    val stoppedAtUtcEpochMillis: Long,
    val recoveryCount: Int,
    val recorderErrorCode: String? = null,
) {
    init {
        require(metadataVersion == RECORDER_FINALIZATION_METADATA_VERSION)
        require(runCatching { UUID.fromString(tripId) }.isSuccess)
        require(startedAtUtcEpochMillis > 0)
        require(startedAtElapsedRealtimeNanos >= 0)
        require(stoppedAtUtcEpochMillis > 0)
        require(recoveryCount >= 0)
        require(recorderErrorCode == null || ERROR_CODE_PATTERN.matches(recorderErrorCode))
    }

    companion object {
        private val ERROR_CODE_PATTERN = Regex("[a-z0-9_]{1,64}")
    }
}

sealed interface RecorderFinalizationRead {
    data class Available(
        val records: List<PendingTripFinalizationRecord>,
        val invalidRecordCount: Int,
    ) : RecorderFinalizationRead
}

interface RecorderFinalizationStore {
    fun save(record: PendingTripFinalizationRecord): Boolean

    fun loadAll(): RecorderFinalizationRead.Available

    fun load(tripId: String): PendingTripFinalizationRecord?

    fun acknowledge(tripId: String): Boolean
}

object RecorderFinalizationCodec {
    private const val MAGIC = 0x54525846

    fun encode(record: PendingTripFinalizationRecord, output: OutputStream) {
        val data = DataOutputStream(BufferedOutputStream(output))
        data.writeInt(MAGIC)
        data.writeInt(record.metadataVersion)
        data.writeUTF(record.tripId)
        data.writeLong(record.startedAtUtcEpochMillis)
        data.writeLong(record.startedAtElapsedRealtimeNanos)
        data.writeLong(record.stoppedAtUtcEpochMillis)
        data.writeInt(record.recoveryCount)
        data.writeBoolean(record.recorderErrorCode != null)
        if (record.recorderErrorCode != null) data.writeUTF(record.recorderErrorCode)
        data.flush()
    }

    fun decode(input: InputStream): PendingTripFinalizationRecord? =
        try {
            val data = DataInputStream(BufferedInputStream(input))
            if (data.readInt() != MAGIC) return null
            val record = PendingTripFinalizationRecord(
                metadataVersion = data.readInt(),
                tripId = data.readUTF(),
                startedAtUtcEpochMillis = data.readLong(),
                startedAtElapsedRealtimeNanos = data.readLong(),
                stoppedAtUtcEpochMillis = data.readLong(),
                recoveryCount = data.readInt(),
                recorderErrorCode = if (data.readBoolean()) data.readUTF() else null,
            )
            if (data.read() != -1) return null
            record
        } catch (_: Exception) {
            null
        }
}

class AtomicRecorderFinalizationStore(context: Context) : RecorderFinalizationStore {
    private val directory =
        File(context.applicationContext.noBackupFilesDir, "$RECORDER_DIRECTORY_NAME/$DIRECTORY_NAME")

    override fun save(record: PendingTripFinalizationRecord): Boolean {
        if (!directory.exists() && !directory.mkdirs()) return false
        val atomicFile = AtomicFile(file(record.tripId))
        val output = runCatching { atomicFile.startWrite() }.getOrNull() ?: return false
        return try {
            RecorderFinalizationCodec.encode(record, output)
            atomicFile.finishWrite(output)
            true
        } catch (_: Exception) {
            atomicFile.failWrite(output)
            false
        }
    }

    override fun loadAll(): RecorderFinalizationRead.Available {
        val files = directory.listFiles()?.toList().orEmpty()
        val records = mutableListOf<PendingTripFinalizationRecord>()
        val recognized = files.mapNotNull { candidate ->
            FILE_PATTERN.matchEntire(candidate.name)?.let { match ->
                Triple(candidate, match.groupValues[1], match.groupValues[2])
            }
        }
        var invalidCount = files.size - recognized.size
        recognized.groupBy { it.second }.toSortedMap().forEach { (expectedTripId, candidates) ->
            val base = file(expectedTripId)
            val hasReadableCandidate = candidates.any { it.third.isEmpty() || it.third == ".bak" }
            val record =
                if (hasReadableCandidate) {
                    runCatching {
                        AtomicFile(base).openRead().use(RecorderFinalizationCodec::decode)
                    }.getOrNull()
                } else {
                    null
                }
            if (
                record == null ||
                record.tripId != expectedTripId ||
                candidates.any { it.third == ".new" } ||
                candidates.size > 2
            ) {
                invalidCount += 1
            } else {
                records += record
            }
        }
        return RecorderFinalizationRead.Available(
            records = records.sortedBy { it.startedAtUtcEpochMillis },
            invalidRecordCount = invalidCount,
        )
    }

    override fun load(tripId: String): PendingTripFinalizationRecord? {
        if (!isValidTripId(tripId)) return null
        val target = file(tripId)
        if (!target.exists() && !File(target.path + ".bak").exists()) return null
        return runCatching {
            AtomicFile(target).openRead().use(RecorderFinalizationCodec::decode)
        }.getOrNull()?.takeIf { it.tripId == tripId }
    }

    override fun acknowledge(tripId: String): Boolean {
        if (!isValidTripId(tripId)) return false
        val atomicFile = AtomicFile(file(tripId))
        if (!atomicFile.baseFile.exists() && !File(atomicFile.baseFile.path + ".bak").exists()) {
            return true
        }
        return try {
            atomicFile.delete()
            !atomicFile.baseFile.exists() && !File(atomicFile.baseFile.path + ".bak").exists()
        } catch (_: Exception) {
            false
        }
    }

    private fun file(tripId: String): File = File(directory, "$tripId$FILE_EXTENSION")

    private fun isValidTripId(tripId: String): Boolean =
        runCatching { UUID.fromString(tripId) }.isSuccess

    companion object {
        private const val RECORDER_DIRECTORY_NAME = "recorder"
        private const val DIRECTORY_NAME = "finalizations"
        private const val FILE_EXTENSION = ".trxf"
        private val FILE_PATTERN = Regex("^([0-9a-fA-F-]{36})\\.trxf(\\.bak|\\.new)?$")
    }
}

data class RecorderFinalizedChunkSnapshot(val metadata: TelemetryChunkMetadata) {
    fun toMap(): Map<String, Any> =
        linkedMapOf(
            "sequence" to metadata.sequence,
            "storageReference" to relativeChunkStorageReference(metadata.tripId, metadata.sequence),
            "encodingVersion" to metadata.encodingVersion,
            "telemetrySchemaVersion" to metadata.telemetrySchemaVersion,
            "startElapsedNanos" to metadata.startElapsedNanos,
            "endElapsedNanos" to metadata.endElapsedNanos,
            "gnssSampleCount" to metadata.gnssSampleCount,
            "accelerometerSampleCount" to metadata.accelerometerSampleCount,
            "gyroscopeSampleCount" to metadata.gyroscopeSampleCount,
            "compression" to metadata.compression,
            "atomicWriteStrategy" to metadata.atomicWriteStrategy,
            "checksumAlgorithm" to metadata.checksumAlgorithm,
            "checksum" to metadata.checksumHex,
            "byteLength" to metadata.byteLength,
            "createdAtUtcEpochMillis" to metadata.createdAtUtcEpochMillis,
        )
}

data class RecorderTripFinalizationSnapshot(
    val contractVersion: Int = RECORDER_FINALIZATION_CONTRACT_VERSION,
    val finalizationLogicVersion: Int = RECORDER_FINALIZATION_LOGIC_VERSION,
    val tripId: String,
    val startedAtUtcEpochMillis: Long,
    val startedAtElapsedRealtimeNanos: Long,
    val stoppedAtUtcEpochMillis: Long,
    val endElapsedRealtimeNanos: Long?,
    val durationMillis: Long?,
    val completionState: String,
    val recoveryState: String,
    val integrityStatus: String,
    val recoveryCount: Int,
    val qualityFlags: List<String>,
    val corruptChunkCount: Int,
    val orphanedWriteCount: Int,
    val orderingViolationCount: Int,
    val chunks: List<RecorderFinalizedChunkSnapshot>,
) {
    fun toMap(): Map<String, Any?> =
        linkedMapOf(
            "contractVersion" to contractVersion,
            "finalizationLogicVersion" to finalizationLogicVersion,
            "tripId" to tripId,
            "startedAtUtcEpochMillis" to startedAtUtcEpochMillis,
            "startedAtElapsedRealtimeNanos" to startedAtElapsedRealtimeNanos,
            "stoppedAtUtcEpochMillis" to stoppedAtUtcEpochMillis,
            "endElapsedRealtimeNanos" to endElapsedRealtimeNanos,
            "durationMillis" to durationMillis,
            "completionState" to completionState,
            "recoveryState" to recoveryState,
            "integrityStatus" to integrityStatus,
            "recoveryCount" to recoveryCount,
            "qualityFlags" to qualityFlags,
            "corruptChunkCount" to corruptChunkCount,
            "orphanedWriteCount" to orphanedWriteCount,
            "orderingViolationCount" to orderingViolationCount,
            "chunks" to chunks.map { it.toMap() },
        )
}

object RecorderFinalizationEvaluator {
    fun evaluate(
        record: PendingTripFinalizationRecord,
        catalog: TelemetryChunkCatalogSnapshot,
    ): RecorderTripFinalizationSnapshot {
        val flags = linkedSetOf<String>()
        if (catalog.validChunks.isEmpty()) flags += "no_valid_chunks"
        if (catalog.corruptChunkCount > 0) flags += "corrupt_chunks_isolated"
        if (catalog.orphanedWriteCount > 0) flags += "orphaned_writes_isolated"
        if (catalog.orderingViolationCount > 0) flags += "chunk_ordering_violation"
        if (record.recoveryCount > 0) flags += "recorder_recovered"
        if (record.recorderErrorCode != null) flags += "recorder_error"
        if (record.stoppedAtUtcEpochMillis < record.startedAtUtcEpochMillis) {
            flags += "wall_clock_regression"
        }

        val lastTripElapsed = catalog.lastVerifiedEndElapsedNanos
        val endElapsed =
            lastTripElapsed?.let {
                runCatching { Math.addExact(record.startedAtElapsedRealtimeNanos, it) }.getOrNull()
            }
        if (lastTripElapsed != null && endElapsed == null) flags += "elapsed_time_overflow"
        val incomplete =
            catalog.validChunks.isEmpty() ||
                catalog.corruptChunkCount > 0 ||
                catalog.orphanedWriteCount > 0 ||
                catalog.orderingViolationCount > 0 ||
                record.recorderErrorCode != null ||
                record.stoppedAtUtcEpochMillis < record.startedAtUtcEpochMillis ||
                (lastTripElapsed != null && endElapsed == null)

        return RecorderTripFinalizationSnapshot(
            tripId = record.tripId,
            startedAtUtcEpochMillis = record.startedAtUtcEpochMillis,
            startedAtElapsedRealtimeNanos = record.startedAtElapsedRealtimeNanos,
            stoppedAtUtcEpochMillis =
                record.stoppedAtUtcEpochMillis.coerceAtLeast(record.startedAtUtcEpochMillis),
            endElapsedRealtimeNanos = endElapsed,
            durationMillis = lastTripElapsed?.div(1_000_000L),
            completionState = if (incomplete) "incomplete" else "completed",
            recoveryState = if (record.recoveryCount > 0) "recovered" else "not_needed",
            integrityStatus = if (incomplete) "review_required" else "unassessed",
            recoveryCount = record.recoveryCount,
            qualityFlags = flags.toList(),
            corruptChunkCount = catalog.corruptChunkCount,
            orphanedWriteCount = catalog.orphanedWriteCount,
            orderingViolationCount = catalog.orderingViolationCount,
            chunks = catalog.validChunks.map { RecorderFinalizedChunkSnapshot(it.metadata) },
        )
    }
}

fun relativeChunkStorageReference(tripId: String, sequence: Long): String {
    require(runCatching { UUID.fromString(tripId) }.isSuccess)
    require(sequence >= 0)
    val fileName = String.format(Locale.ROOT, "%010d.tlxc", sequence)
    return "recorder/trips/$tripId/chunks/$fileName"
}
