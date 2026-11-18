package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecorderCpuLeaseTest {
    @Test fun duplicateStartAndRenewalNeverAddAnUnboundedOrReferenceCountedClaim() {
        val clock = Clock()
        val lock = Lock()
        val lease = RecorderCpuLease(lock) { clock.now }
        assertFalse(lease.isHeld())
        assertTrue(lease.start())
        assertTrue(lease.start())
        assertEquals(listOf(120_000L), lock.acquisitions)
        repeat(20) { clock.now += 30_000; assertTrue(lease.renew()) }
        assertTrue(lease.isHeld())
        assertTrue(lock.acquisitions.all { it == RECORDER_CPU_LEASE_MILLIS })
        assertTrue(lease.release())
        assertTrue(lease.release())
        assertEquals(1, lock.releases)
        assertFalse(lease.isHeld())
    }

    @Test fun timeoutOrLostBackendFailsWithoutSilentlyReacquiring() {
        for (expire in listOf(true, false)) {
            val clock = Clock()
            val lock = Lock()
            val lease = RecorderCpuLease(lock) { clock.now }
            assertTrue(lease.start())
            if (expire) clock.now += RECORDER_CPU_LEASE_MILLIS else lock.held = false
            assertFalse(lease.renew())
            assertEquals(1, lock.acquisitions.size)
            assertFalse(lease.isHeld())
        }
    }

    @Test fun deniedAcquisitionAndPartiallyAcquiredFailureBothCleanUp() {
        for (partial in listOf(true, false)) {
            val lock = Lock().apply { failAcquire = true; acquireBeforeFailure = partial }
            val lease = RecorderCpuLease(lock) { 10L }
            assertFalse(lease.start())
            assertFalse(lock.held)
            assertFalse(lease.isHeld())
        }
    }

    @Test fun renewalFailureReleasesAndReleaseFailureIsObservable() {
        val lock = Lock()
        val lease = RecorderCpuLease(lock) { 10L }
        assertTrue(lease.start())
        lock.failAcquire = true
        assertFalse(lease.renew())
        assertFalse(lock.held)
        lock.failAcquire = false
        assertTrue(lease.start())
        lock.failRelease = true
        assertFalse(lease.release())
        assertFalse(lease.isHeld())
    }

    @Test fun clockRegressionAndDeadlineOverflowCannotExtendRecording() {
        val clock = Clock()
        val lock = Lock()
        val lease = RecorderCpuLease(lock) { clock.now }
        clock.now = Long.MAX_VALUE
        assertFalse(lease.start())
        assertTrue(lock.acquisitions.isEmpty())
        clock.now = 10
        assertTrue(lease.start())
        clock.now = 9
        assertFalse(lease.renew())
        assertFalse(lock.held)
    }

    private class Clock(var now: Long = 100)
    private class Lock : RecorderCpuLock {
        var held = false
        var failAcquire = false
        var acquireBeforeFailure = false
        var failRelease = false
        var releases = 0
        val acquisitions = mutableListOf<Long>()
        override val isHeld: Boolean get() = held
        override fun acquire(timeoutMillis: Long) {
            acquisitions += timeoutMillis
            if (failAcquire) {
                if (acquireBeforeFailure) held = true
                throw SecurityException("synthetic")
            }
            held = true
        }
        override fun release() { if (failRelease) throw IllegalStateException("synthetic"); releases++; held = false }
    }
}
