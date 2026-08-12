package io.github.atrx07.traelyx.recorder

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.util.Locale
import java.util.UUID

sealed interface TelemetryChunkWriteResult {
    data object Success : TelemetryChunkWriteResult

    data class Failure(val errorCode: String) : TelemetryChunkWriteResult
}

interface TelemetryChunkStore {
    fun scan(tripId: String): TelemetryChunkCatalogSnapshot

    fun write(chunk: EncodedTelemetryChunk): TelemetryChunkWriteResult

    fun read(tripId: String, sequence: Long): ByteArray? = null
}

class AtomicFileTelemetryChunkStore(context: Context) : TelemetryChunkStore {
    private val tripsDirectory =
        File(context.applicationContext.noBackupFilesDir, "$RECORDER_DIRECTORY_NAME/$TRIPS_DIRECTORY_NAME")

    override fun scan(tripId: String): TelemetryChunkCatalogSnapshot {
        if (!isValidTripId(tripId)) return emptyCatalogWithCorruption()
        val directory = chunkDirectory(tripId)
        val files = directory.listFiles()?.toList().orEmpty()
        val observed =
            files.mapNotNull { file ->
                val match = CHUNK_FILE_PATTERN.matchEntire(file.name) ?: return@mapNotNull null
                val sequence = match.groupValues[1].toLongOrNull() ?: return@mapNotNull null
                sequence to match.groupValues[2]
            }
        val sequences = observed.map { it.first }.distinct().sorted()
        val candidates =
            sequences.map { sequence ->
                val baseFile = File(directory, fileName(sequence))
                val hasBaseOrBackup =
                    observed.any { (candidateSequence, suffix) ->
                        candidateSequence == sequence && (suffix.isEmpty() || suffix == ".bak")
                    }
                if (!hasBaseOrBackup) {
                    TelemetryChunkCandidate(
                        observedSequence = sequence,
                        bytes = null,
                        orphanedIncompleteWrite = true,
                    )
                } else {
                    val bytes =
                        runCatching {
                            AtomicFile(baseFile).openRead().use { it.readBytes() }
                        }.getOrNull()
                    TelemetryChunkCandidate(
                        observedSequence = sequence,
                        bytes = bytes,
                        orphanedIncompleteWrite = bytes == null,
                    )
                }
            }
        val inspected = TelemetryChunkCatalog.inspect(candidates)
        val validForTrip = inspected.validChunks.filter { it.metadata.tripId == tripId }
        val tripMismatchCount = inspected.validChunks.size - validForTrip.size
        return inspected.copy(
            validChunks = validForTrip,
            corruptChunkCount = inspected.corruptChunkCount + tripMismatchCount,
        )
    }

    override fun write(chunk: EncodedTelemetryChunk): TelemetryChunkWriteResult {
        val metadata = chunk.metadata
        if (!isValidTripId(metadata.tripId)) {
            return TelemetryChunkWriteResult.Failure("chunk_invalid_trip_id")
        }
        if (TelemetryChunkCodec.decode(chunk.bytes) !is TelemetryChunkDecodeResult.Success) {
            return TelemetryChunkWriteResult.Failure("chunk_prewrite_invalid")
        }
        val directory = chunkDirectory(metadata.tripId)
        if (!directory.exists() && !directory.mkdirs()) {
            return TelemetryChunkWriteResult.Failure("chunk_directory_failed")
        }
        val baseFile = File(directory, fileName(metadata.sequence))
        if (baseFile.exists() || File(baseFile.path + ".bak").exists() || File(baseFile.path + ".new").exists()) {
            return TelemetryChunkWriteResult.Failure("chunk_sequence_exists")
        }

        val atomicFile = AtomicFile(baseFile)
        val output = runCatching { atomicFile.startWrite() }.getOrNull()
            ?: return TelemetryChunkWriteResult.Failure("chunk_write_start_failed")
        try {
            output.write(chunk.bytes)
            atomicFile.finishWrite(output)
        } catch (_: Exception) {
            atomicFile.failWrite(output)
            return TelemetryChunkWriteResult.Failure("chunk_write_failed")
        }

        val verified =
            runCatching {
                atomicFile.openRead().use { TelemetryChunkCodec.decode(it.readBytes()) }
            }.getOrNull()
        return if (
            verified is TelemetryChunkDecodeResult.Success &&
            verified.chunk.metadata.tripId == metadata.tripId &&
            verified.chunk.metadata.sequence == metadata.sequence &&
            verified.chunk.metadata.checksumHex == metadata.checksumHex
        ) {
            TelemetryChunkWriteResult.Success
        } else {
            TelemetryChunkWriteResult.Failure("chunk_postwrite_verification_failed")
        }
    }

    override fun read(tripId: String, sequence: Long): ByteArray? {
        if (!isValidTripId(tripId) || sequence < 0) return null
        val baseFile = File(chunkDirectory(tripId), fileName(sequence))
        if (!baseFile.exists() && !File(baseFile.path + ".bak").exists()) return null
        return runCatching { AtomicFile(baseFile).openRead().use { it.readBytes() } }.getOrNull()
    }

    internal fun deleteTripForTest(tripId: String): Boolean {
        if (!isValidTripId(tripId)) return false
        val target = chunkDirectory(tripId).parentFile ?: return false
        val canonicalTrips = runCatching { tripsDirectory.canonicalFile }.getOrNull() ?: return false
        val canonicalTarget = runCatching { target.canonicalFile }.getOrNull() ?: return false
        if (canonicalTarget.parentFile?.canonicalFile != canonicalTrips) return false
        return !canonicalTarget.exists() || canonicalTarget.deleteRecursively()
    }

    private fun chunkDirectory(tripId: String): File =
        File(File(tripsDirectory, tripId), CHUNKS_DIRECTORY_NAME)

    private fun fileName(sequence: Long): String =
        String.format(Locale.ROOT, "%010d%s", sequence, CHUNK_FILE_EXTENSION)

    private fun isValidTripId(tripId: String): Boolean =
        runCatching { UUID.fromString(tripId) }.isSuccess

    private fun emptyCatalogWithCorruption(): TelemetryChunkCatalogSnapshot =
        TelemetryChunkCatalogSnapshot(
            validChunks = emptyList(),
            corruptChunkCount = 1,
            orphanedWriteCount = 0,
            orderingViolationCount = 0,
            maxObservedSequence = null,
        )

    companion object {
        private const val RECORDER_DIRECTORY_NAME = "recorder"
        private const val TRIPS_DIRECTORY_NAME = "trips"
        private const val CHUNKS_DIRECTORY_NAME = "chunks"
        private const val CHUNK_FILE_EXTENSION = ".tlxc"
        private val CHUNK_FILE_PATTERN = Regex("^(\\d{10,19})\\.tlxc(\\.bak|\\.new)?$")
    }
}
