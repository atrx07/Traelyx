package io.github.atrx07.traelyx.guardian

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import io.github.atrx07.traelyx.telemetry.FrameVector3
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class GuardianSafetyEvaluatorTest {
    @Test fun `disabled without mount confirmation including apparent collision`() {
        val engine = GuardianSafetyEvaluator(null)
        assertTrue(replay(engine, impact = true).isEmpty())
        assertEquals(GuardianEvaluationAvailability.DISABLED, engine.availability)
    }

    @Test fun `impact speed loss and sustained stop produce one uncertain candidate`() {
        val events = replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true)
        assertEquals(1, events.size)
        assertEquals(GuardianAlertKind.POSSIBLE_CRASH, events.single().kind)
        assertEquals(10_000_000_000L, events.single().evidenceStartedAtNanos)
        assertEquals(17_000_000_000L, events.single().detectedAtNanos)
    }

    @Test fun `sustained braking requires independent consecutive speed loss fixes`() {
        val events = replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), severe = true)
        assertEquals(listOf(GuardianAlertKind.SEVERE_DRIVE), events.map { it.kind })
        assertEquals(12_000_000_000L, events.single().detectedAtNanos)
    }

    @Test fun `smooth movement stationary and isolated GPS spikes produce no alert`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP)).isEmpty())
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), speedOverride = { 0.0 }).isEmpty())
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), speedOverride = {
            when (it) { 11_000 -> 80.0; 12_000 -> 0.0; else -> normalSpeed(it) }
        }).isEmpty())
    }

    @Test fun `vertical pothole cannot become a crash even with coincident stop`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, verticalImpact = true).isEmpty())
    }

    @Test fun `horizontal phone impact at constant vehicle speed is not a crash`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true,
            speedOverride = ::normalSpeed).isEmpty())
    }

    @Test fun `moving or dropped phone invalidates mount and pending evidence`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true,
            rotationAtMillis = 10_020).isEmpty())
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true,
            freeFallAtMillis = 10_020).isEmpty())
    }

    @Test fun `unreliable low accuracy mock and missing speed accuracy fail closed`() {
        for (fault in listOf("unreliable", "low_imu", "mock", "gnss_accuracy", "speed_accuracy", "gnss_missing")) {
            assertTrue(fault, replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, fault = fault).isEmpty())
        }
    }

    @Test fun `quality failure after impact cancels pending crash candidate`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true,
            corruptAtMillis = 14_000).isEmpty())
    }

    @Test fun `queue loss acquisition gaps and reordered source samples invalidate candidate`() {
        for (fault in listOf("queue_loss", "imu_gap", "gnss_gap", "reordered")) {
            assertTrue(fault, replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, fault = fault).isEmpty())
        }
    }

    @Test fun `insufficient impulse short impulse prolonged load and no sustained stop are suppressed`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, impactEnd = 10_020).isEmpty())
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, impactEnd = 10_600).isEmpty())
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true,
            speedOverride = { if (it == 12_000) 0.0 else normalSpeed(it) }).isEmpty())
    }

    @Test fun `one depressed speed fix cannot corroborate severe braking`() {
        assertTrue(replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), severe = true,
            speedOverride = { if (it == 11_000) 13.0 else normalSpeed(it) }).isEmpty())
    }

    @Test fun `vertical forward selection never becomes a valid mount`() {
        val engine = GuardianSafetyEvaluator(FrameVector3.DEVICE_SCREEN_OUT)
        assertTrue(replay(engine, impact = true).isEmpty())
        assertNotEquals(GuardianEvaluationAvailability.MONITORING_EXPERIMENTAL, engine.availability)
    }

    @Test fun `live rule configuration is a separate version from completed trip scores`() {
        assertEquals(1, GuardianSafetyRulesV1.VERSION)
        assertEquals(30_000L, GuardianPendingAlert.CANCEL_WINDOW_MILLIS)
        assertEquals(300_000_000_000L, GuardianSafetyRulesV1.SEVERE_COOLDOWN_NS)
        assertEquals(1_800_000_000_000L, GuardianSafetyRulesV1.CRASH_COOLDOWN_NS)
    }

    @Test fun `bounded worker preserves detection through normal batching and stops cleanly`() {
        val detected = CountDownLatch(1)
        val events = java.util.concurrent.CopyOnWriteArrayList<GuardianDetection>()
        val worker = GuardianSafetyWorker(FrameVector3.DEVICE_TOP) { events += it; detected.countDown() }
        try {
            replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, worker = worker)
            assertTrue(detected.await(3, TimeUnit.SECONDS))
            assertFalse(worker.failed)
            assertEquals(listOf(GuardianAlertKind.POSSIBLE_CRASH), events.map { it.kind })
        } finally { worker.close() }
        assertEquals(GuardianEvaluationAvailability.DISABLED, worker.availability)
    }

    @Test fun `persisted cooldown prevents restart from creating a second crash alert`() {
        val first = GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP)
        assertEquals(1, replay(first, impact = true).size)
        val restored = GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP, first.cooldownSnapshot())
        assertTrue(replay(restored, impact = true, sourceOffsetNanos = 30_000_000_000L).isEmpty())
        val later = GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP, first.cooldownSnapshot())
        assertEquals(1, replay(later, impact = true, sourceOffsetNanos = 2_000_000_000_000L).size)
    }

    @Test fun `sidecar output failure remains inside worker and fails closed`() {
        val worker = GuardianSafetyWorker(FrameVector3.DEVICE_TOP) { throw IllegalStateException("synthetic IO failure") }
        try {
            replay(GuardianSafetyEvaluator(FrameVector3.DEVICE_TOP), impact = true, worker = worker)
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
            while (!worker.failed && System.nanoTime() < deadline) Thread.sleep(10)
            assertTrue(worker.failed)
            assertEquals(GuardianEvaluationAvailability.EVIDENCE_UNAVAILABLE, worker.availability)
        } finally { worker.close() }
    }

    private fun replay(
        engine: GuardianSafetyEvaluator,
        impact: Boolean = false,
        severe: Boolean = false,
        verticalImpact: Boolean = false,
        impactEnd: Int = 10_100,
        rotationAtMillis: Int = -1,
        freeFallAtMillis: Int = -1,
        corruptAtMillis: Int = -1,
        fault: String = "",
        speedOverride: ((Int) -> Double)? = null,
        worker: GuardianSafetyWorker? = null,
        sourceOffsetNanos: Long = 0,
    ): List<GuardianDetection> {
        val output = mutableListOf<GuardianDetection>()
        for (ms in 0..22_000 step 10) {
            // Exercise the real worker with bounded batches without overwhelming the test host.
            if (worker != null && ms % 500 == 0) Thread.sleep(5)
            if (ms == 14_000 && fault == "queue_loss") engine.invalidate()
            if (ms % 1000 == 0 && !(fault == "gnss_gap" && ms == 14_000)) {
                val speed = speedOverride?.invoke(ms) ?: when {
                    impact && ms >= 12_000 -> 0.0
                    impact && ms >= 11_000 -> 12.0
                    severe && ms >= 12_000 -> 7.0
                    severe && ms >= 11_000 -> 13.0
                    else -> normalSpeed(ms)
                }
                var fix = gnss(ms, speed).let { it.copy(sourceTimestampNanos = it.sourceTimestampNanos + sourceOffsetNanos) }
                fix = when (fault) {
                    "mock" -> fix.copy(isMockSignal = true, qualityFlags = setOf(GnssQualityFlag.MOCK_LOCATION_SIGNAL))
                    "gnss_accuracy" -> fix.copy(horizontalAccuracyMetres = 25f)
                    "speed_accuracy" -> fix.copy(speedAccuracyMetresPerSecond = 3f)
                    "gnss_missing" -> fix.copy(speedAccuracyMetresPerSecond = null)
                    else -> fix
                }
                output += engine.accept(fix)
                worker?.offer(fix)
            }
            if (fault == "imu_gap" && ms in 14_000..14_100) continue
            val unreliable = fault == "unreliable" || ms == corruptAtMillis
            val accuracy = if (unreliable) 0 else if (fault == "low_imu") 1 else 3
            val flags = if (unreliable) setOf(ImuQualityFlag.SENSOR_UNRELIABLE) else emptySet()
            val time = ms * 1_000_000L + sourceOffsetNanos
            val angular = RawImuSample(sensorType = ImuSensorType.GYROSCOPE, tripElapsedNanos = time,
                sourceTimestampNanos = time, x = if (ms == rotationAtMillis) 2f else 0f, y = 0f, z = 0f,
                accuracyStatus = accuracy, qualityFlags = flags)
            engine.accept(angular)
            worker?.offer(angular)
            val pulse = impact && ms in 10_000 until impactEnd
            val brake = severe && ms in 10_000 until 11_300
            val acc = RawImuSample(sensorType = ImuSensorType.ACCELEROMETER, tripElapsedNanos = time,
                sourceTimestampNanos = time, x = 0f,
                y = if (ms == freeFallAtMillis) 0f else if (pulse && !verticalImpact) -30f else if (brake) -7f else 0f,
                z = if (ms == freeFallAtMillis) 0f else (GuardianSafetyRulesV1.GRAVITY + if (pulse && verticalImpact) 30 else 0).toFloat(),
                accuracyStatus = accuracy, qualityFlags = flags)
            engine.accept(acc)
            worker?.offer(acc)
            if (fault == "reordered" && ms == 14_000) engine.accept(acc.copy(sourceTimestampNanos = time - 1))
        }
        return output
    }

    private fun normalSpeed(ms: Int) = when {
        ms <= 4000 -> 0.0
        ms < 8000 -> (ms - 4000) * 0.005
        else -> 20.0
    }

    private fun gnss(ms: Int, speed: Double) = RawGnssSample(
        tripElapsedNanos = ms * 1_000_000L, sourceTimestampNanos = ms * 1_000_000L,
        sourceWallTimeUtcEpochMillis = null, latitudeDegrees = 0.0, longitudeDegrees = 0.0,
        horizontalAccuracyMetres = 3f, altitudeMetres = null, verticalAccuracyMetres = null,
        speedMetresPerSecond = speed.toFloat(), speedAccuracyMetresPerSecond = 0.3f,
        bearingDegrees = null, bearingAccuracyDegrees = null, provider = "synthetic",
        isMockSignal = false, qualityFlags = emptySet(),
    )
}
