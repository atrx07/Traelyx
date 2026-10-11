package io.github.atrx07.traelyx.guardian

import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.telemetry.FrameVector3
import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque

class GuardianRecordingSessionTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val generation = "22222222-2222-4222-8222-222222222222"
    private val replacement = "33333333-3333-4333-8333-333333333333"
    private class MemoryVault : GuardianVault {
        var value = GuardianVaultSnapshot()
        var reads = 0
        var writes = 0
        var failWrite = false
        var failErase = false
        override fun read(): GuardianVaultSnapshot { reads++; return value }
        override fun write(snapshot: GuardianVaultSnapshot) { check(!failWrite); writes++; value = snapshot }
        override fun erase() { check(!failErase); value = GuardianVaultSnapshot() }
    }
    private class FakeWorker(val detected: (GuardianDetection) -> Unit, val failed: () -> Unit) : GuardianRecordingWorker {
        override var cooldowns = GuardianSafetyCooldowns()
        override var availability = GuardianEvaluationAvailability.CALIBRATING
        var offered: Any? = null
        var closed = false
        var failOffer = false
        var failClose = false
        override fun offer(sample: RawGnssSample) { check(!failOffer); offered = sample }
        override fun offer(sample: RawImuSample) { check(!failOffer); offered = sample }
        override fun close() { closed = true; check(!failClose) }
    }
    private inner class Fixture {
        var now = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
        var nextId = generation
        val vault = MemoryVault()
        val outbox = GuardianOutbox(vault)
        val activation = GuardianActivationCoordinator(outbox, { now }, { nextId }, { "a".repeat(64) })
        val tasks = ArrayDeque<() -> Unit>()
        val workers = mutableListOf<FakeWorker>()
        var confirmedForward: FrameVector3? = null
        var restored = GuardianSafetyCooldowns()
        var failCreate = false
        val session = GuardianRecordingSession(activation::recordingSnapshot, { now },
            { lease, detection, cooldowns, clock -> outbox.enqueue(lease.ownerId, lease.activationId, detection, cooldowns, clock) },
            activation::disable, { tasks.add(it) },
            { forward, cooldowns, detected, failed ->
                confirmedForward = forward; restored = cooldowns
                check(!failCreate)
                FakeWorker(detected, failed).also { workers.add(it) }
            })
        fun activate() {
            activation.bindOwner(owner)
            activation.begin(owner, "+y", true)
            activation.commit(owner, nextId, now.epochMillis + 28_800_000)
        }
        fun start() = GuardianRecorderHandle().also(session::start)
        fun drain() { while (tasks.isNotEmpty()) tasks.removeFirst().invoke() }
        fun detect(worker: FakeWorker = workers.last()) {
            worker.cooldowns = GuardianSafetyCooldowns(lastSevereNanos = now.elapsedMillis * 1_000_000)
            worker.detected(GuardianDetection(GuardianAlertKind.SEVERE_DRIVE, 0, now.elapsedMillis * 1_000_000))
        }
    }

    @Test fun `unknown owner and uncommitted proposal never start evaluation`() {
        val f = Fixture()
        f.start()
        assertEquals(0, f.vault.reads)
        assertTrue(f.workers.isEmpty())
        f.activation.bindOwner(owner)
        f.activation.begin(owner, "+y", true)
        f.session.refresh()
        assertTrue(f.workers.isEmpty())
        f.activation.commit(owner, generation, f.now.epochMillis + 28_800_000)
        f.session.refresh()
        assertEquals(1, f.workers.size)
        assertEquals(FrameVector3.DEVICE_TOP, f.confirmedForward)
    }

    @Test fun `same lease refresh preserves calibration and restored cooldowns`() {
        val f = Fixture(); f.activate()
        val cooldowns = GuardianSafetyCooldowns(5_000_000_000, null)
        f.vault.value = f.vault.value.copy(cooldowns = cooldowns)
        f.start(); f.session.refresh(); f.session.tick()
        assertEquals(1, f.workers.size)
        assertEquals(cooldowns, f.restored)
    }

    @Test fun `fresh process owner binding cannot resume telemetry from retained lease`() {
        val f = Fixture(); f.activate()
        val restarted = GuardianActivationCoordinator(f.outbox, { f.now })
        restarted.bindOwner(owner)
        assertNotNull(restarted.snapshot(owner).lease)
        assertNull(restarted.recordingSnapshot())
        val proposal = restarted.begin(owner, "+y", true)
        restarted.commit(owner, proposal.activationId, f.now.epochMillis + 28_800_000)
        assertNotNull(restarted.recordingSnapshot()?.lease)
    }

    @Test fun `acquisition offers original sample without disk work`() {
        val f = Fixture(); f.activate(); val handle = f.start()
        val sample = RawGnssSample(tripElapsedNanos = 10_000_000_000,
            sourceTimestampNanos = 10_000_000_000, sourceWallTimeUtcEpochMillis = null,
            latitudeDegrees = 0.0, longitudeDegrees = 0.0, horizontalAccuracyMetres = 3f,
            altitudeMetres = null, verticalAccuracyMetres = null, speedMetresPerSecond = 0f,
            speedAccuracyMetresPerSecond = 0.3f, bearingDegrees = null,
            bearingAccuracyDegrees = null, provider = "synthetic", isMockSignal = false,
            qualityFlags = emptySet())
        val reads = f.vault.reads; val writes = f.vault.writes
        handle.offer(sample)
        assertSame(sample, f.workers.single().offered)
        val motion = RawImuSample(sensorType = ImuSensorType.ACCELEROMETER,
            tripElapsedNanos = 10_000_000_000, sourceTimestampNanos = 10_000_000_000,
            x = 0f, y = 0f, z = 9.80665f, accuracyStatus = 3, qualityFlags = emptySet())
        handle.offer(motion)
        assertSame(motion, f.workers.single().offered)
        assertEquals(reads, f.vault.reads); assertEquals(writes, f.vault.writes)
    }

    @Test fun `qualified detection and cooldown are committed together without sending`() {
        val f = Fixture(); f.activate(); f.start()
        f.detect()
        assertTrue(f.vault.value.alerts.isEmpty()) // Callback only schedules owner work.
        f.drain()
        val alert = f.vault.value.alerts.single()
        assertEquals(GuardianSendState.CANCELLABLE, alert.state)
        assertEquals(0, alert.attempts)
        assertEquals(owner, alert.ownerId)
        assertEquals(generation, alert.consentGeneration)
        assertEquals(f.workers.single().cooldowns, f.vault.value.cooldowns)
    }

    @Test fun `stop signout and replacement reject queued old detections`() {
        for (action in 0..2) {
            val f = Fixture(); f.activate(); val handle = f.start(); f.detect()
            when (action) {
                0 -> { handle.close(); f.session.stop(handle) }
                1 -> { f.activation.bindOwner(null); f.session.refresh() }
                2 -> { f.nextId = replacement; f.activate(); f.session.refresh() }
            }
            f.drain()
            assertTrue(f.vault.value.alerts.isEmpty())
            assertTrue(f.workers.first().closed)
        }
    }

    @Test fun `late failure cannot revoke a new activation`() {
        val f = Fixture(); f.activate(); f.start()
        f.workers.single().failed()
        f.nextId = replacement; f.activate(); f.session.refresh(); f.drain()
        assertEquals(replacement, f.vault.value.lease?.activationId)
        assertFalse(f.workers.last().closed)
    }

    @Test fun `quiet expiry reboot and clock rollback stop without waiting for detections`() {
        for (fault in 0..3) {
            val f = Fixture(); f.activate(); f.start()
            f.now = when (fault) {
                0 -> f.now.copy(epochMillis = f.now.epochMillis + 28_800_000, elapsedMillis = f.now.elapsedMillis + 28_800_000)
                1 -> f.now.copy(bootId = "boot-2")
                2 -> f.now.copy(epochMillis = f.now.epochMillis - 1)
                else -> f.now.copy(elapsedMillis = f.now.elapsedMillis - 1)
            }
            f.session.tick()
            assertFalse(f.session.isEvaluating)
            assertTrue(f.workers.single().closed)
            assertNull(f.vault.value.lease)
        }
    }

    @Test fun `write failure revokes only Guardian and cannot replay callback`() {
        val f = Fixture(); f.activate(); val handle = f.start()
        f.vault.failWrite = true; f.detect(); f.drain()
        assertNull(f.vault.value.lease)
        assertEquals(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE, handle.availability)
        f.detect(f.workers.single()); f.drain()
        assertTrue(f.vault.value.alerts.isEmpty())
    }

    @Test fun `failed cleanup blocks same lease across trip restart until new activation`() {
        val f = Fixture(); f.activate(); val first = f.start()
        f.vault.failErase = true; f.workers.single().failed(); f.drain()
        f.session.stop(first); f.activation.bindOwner(owner); f.start()
        assertEquals(1, f.workers.size)
        f.vault.failErase = false; f.nextId = replacement; f.activate(); f.session.refresh()
        assertEquals(2, f.workers.size)
    }

    @Test fun `factory and shutdown failure do not escape recording control`() {
        val f = Fixture(); f.activate(); f.failCreate = true
        f.start()
        assertFalse(f.session.isEvaluating)
        assertNull(f.vault.value.lease)
        f.failCreate = false; f.nextId = replacement; f.activate()
        val handle = f.start(); f.workers.last().failClose = true; f.session.stop(handle)
        assertFalse(f.session.isEvaluating)
    }

    @Test fun `an old service stop cannot stop its replacement handle`() {
        val f = Fixture(); f.activate(); val first = f.start(); val second = f.start()
        f.session.stop(first)
        assertFalse(second.isClosed)
        assertTrue(f.session.isEvaluating)
        assertFalse(f.workers.last().closed)
    }

    @Test fun `offer failure returns to acquisition before any owner cleanup`() {
        val f = Fixture(); f.activate(); val handle = f.start()
        f.workers.single().failOffer = true
        val reads = f.vault.reads
        handle.offer(RawImuSample(sensorType = ImuSensorType.GYROSCOPE,
            tripElapsedNanos = 10_000_000_000, sourceTimestampNanos = 10_000_000_000,
            x = 0f, y = 0f, z = 0f, accuracyStatus = 3, qualityFlags = emptySet()))
        assertEquals(reads, f.vault.reads)
        assertEquals(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE, handle.availability)
        f.drain()
        assertNull(f.vault.value.lease)
    }

    @Test fun `evidence failure discards a detection already waiting on owner work`() {
        val f = Fixture(); f.activate(); f.start(); f.detect()
        f.workers.single().availability = GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE
        f.workers.single().failed(); f.drain()
        assertTrue(f.vault.value.alerts.isEmpty())
        assertNull(f.vault.value.lease)
    }
}
