package io.github.atrx07.traelyx.recorder

const val RECORDER_POWER_POLICY_VERSION = 1
const val RECORDER_CPU_LEASE_MILLIS = 120_000L
const val RECORDER_CPU_RENEWAL_MILLIS = 30_000L

interface RecorderCpuLock {
    val isHeld: Boolean
    fun acquire(timeoutMillis: Long)
    fun release()
}

/** Non-reference-counted, renewable CPU lease owned exclusively by recorder acquisition. */
class RecorderCpuLease(
    private val lock: RecorderCpuLock,
    private val elapsedMillis: () -> Long,
) {
    private var owned = false
    private var acquiredAt = 0L
    private var deadline = 0L

    @Synchronized
    fun isHeld(): Boolean = runCatching {
        val now = elapsedMillis()
        owned && now >= acquiredAt && now < deadline && lock.isHeld
    }.getOrDefault(false)

    @Synchronized
    fun start(): Boolean {
        if (owned) return isHeld()
        return acquire()
    }

    @Synchronized
    fun renew(): Boolean {
        if (!isHeld()) {
            release()
            return false // Never silently reacquire after a potentially unrecorded interval.
        }
        return acquire()
    }

    private fun acquire(): Boolean {
        return try {
            val now = elapsedMillis()
            if (now < 0 || now > Long.MAX_VALUE - RECORDER_CPU_LEASE_MILLIS) return false
            owned = true // Also clean up a backend that acquires and then throws.
            lock.acquire(RECORDER_CPU_LEASE_MILLIS)
            check(lock.isHeld)
            acquiredAt = now
            deadline = now + RECORDER_CPU_LEASE_MILLIS
            true
        } catch (_: RuntimeException) {
            release()
            false
        }
    }

    @Synchronized
    fun release(): Boolean {
        val hadOwnership = owned
        owned = false
        acquiredAt = 0
        deadline = 0
        if (!hadOwnership) return true
        return runCatching {
            if (lock.isHeld) lock.release()
            !lock.isHeld
        }.getOrDefault(false)
    }
}
