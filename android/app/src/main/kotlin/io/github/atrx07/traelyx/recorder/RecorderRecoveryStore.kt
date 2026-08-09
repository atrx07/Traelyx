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

interface RecorderRecoveryStore {
    fun load(): RecorderRecoveryRead

    fun save(record: ActiveTripRecoveryRecord): Boolean

    fun clear(): Boolean
}

object RecorderRecoveryCodec {
    private const val MAGIC = 0x54525852

    fun encode(record: ActiveTripRecoveryRecord, output: OutputStream) {
        val data = DataOutputStream(BufferedOutputStream(output))
        data.writeInt(MAGIC)
        data.writeInt(record.metadataVersion)
        data.writeUTF(record.tripId)
        data.writeLong(record.startedAtUtcEpochMillis)
        data.writeLong(record.startedAtElapsedRealtimeNanos)
        data.writeUTF(record.lifecycleState.wireName)
        data.writeInt(record.recoveryCount)
        data.writeBoolean(record.errorCode != null)
        if (record.errorCode != null) {
            data.writeUTF(record.errorCode)
        }
        data.flush()
    }

    fun decode(input: InputStream): RecorderRecoveryRead =
        try {
            val data = DataInputStream(BufferedInputStream(input))
            if (data.readInt() != MAGIC) {
                return RecorderRecoveryRead.Invalid()
            }
            val metadataVersion = data.readInt()
            val tripId = data.readUTF()
            val startedAtUtcEpochMillis = data.readLong()
            val startedAtElapsedRealtimeNanos = data.readLong()
            val lifecycleState =
                RecorderLifecycleState.fromWireName(data.readUTF())
                    ?: return RecorderRecoveryRead.Invalid()
            val recoveryCount = data.readInt()
            val errorCode = if (data.readBoolean()) data.readUTF() else null
            RecorderRecoveryRead.Available(
                ActiveTripRecoveryRecord(
                    metadataVersion = metadataVersion,
                    tripId = tripId,
                    startedAtUtcEpochMillis = startedAtUtcEpochMillis,
                    startedAtElapsedRealtimeNanos = startedAtElapsedRealtimeNanos,
                    lifecycleState = lifecycleState,
                    recoveryCount = recoveryCount,
                    errorCode = errorCode,
                ),
            )
        } catch (_: Exception) {
            RecorderRecoveryRead.Invalid()
        }
}

class AtomicRecorderRecoveryStore(context: Context) : RecorderRecoveryStore {
    private val recorderDirectory = File(context.noBackupFilesDir, DIRECTORY_NAME)
    private val atomicFile = AtomicFile(File(recorderDirectory, FILE_NAME))

    override fun load(): RecorderRecoveryRead {
        if (!atomicFile.baseFile.exists()) {
            return RecorderRecoveryRead.Empty
        }
        return try {
            atomicFile.openRead().use(RecorderRecoveryCodec::decode)
        } catch (_: Exception) {
            RecorderRecoveryRead.Invalid()
        }
    }

    override fun save(record: ActiveTripRecoveryRecord): Boolean {
        if (!recorderDirectory.exists() && !recorderDirectory.mkdirs()) {
            return false
        }
        val output = runCatching { atomicFile.startWrite() }.getOrNull() ?: return false
        return try {
            RecorderRecoveryCodec.encode(record, output)
            atomicFile.finishWrite(output)
            true
        } catch (_: Exception) {
            atomicFile.failWrite(output)
            false
        }
    }

    override fun clear(): Boolean =
        try {
            atomicFile.delete()
            !atomicFile.baseFile.exists()
        } catch (_: Exception) {
            false
        }

    companion object {
        private const val DIRECTORY_NAME = "recorder"
        private const val FILE_NAME = "active_trip_v1.bin"
    }
}
