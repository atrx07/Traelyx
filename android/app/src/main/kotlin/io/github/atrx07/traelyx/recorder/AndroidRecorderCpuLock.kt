package io.github.atrx07.traelyx.recorder

import android.content.Context
import android.os.PowerManager

internal class AndroidRecorderCpuLock(
    context: Context,
    tag: String = "Traelyx:RecorderCpuV1",
) : RecorderCpuLock {
    private val wakeLock = context.getSystemService(PowerManager::class.java)
        .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag)
        .apply { setReferenceCounted(false) }

    override val isHeld: Boolean get() = wakeLock.isHeld
    override fun acquire(timeoutMillis: Long) = wakeLock.acquire(timeoutMillis)
    override fun release() = wakeLock.release()
}
