package io.github.atrx07.traelyx.recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.IBinder
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.util.AtomicFile
import java.io.File
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/** Independent monitor: no observer CPU lock during recording; explicit awake idle control. */
class PerformanceControlService : Service() {
    @Volatile private var canceled = false
    @Volatile private var running = false
    private var stage = "preflight"
    private var idleCpuLease: RecorderCpuLease? = null
    private val journal get() = File(noBackupFilesDir, "performance-recorder-journal-v1.json")
    private val power get() = getSystemService(PowerManager::class.java)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        check(packageName == QA_PACKAGE)
        if (intent?.action == CANCEL) {
            canceled = true
            if (!running) stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != START || running) return START_NOT_STICKY
        running = true
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Isolated performance QA", NotificationManager.IMPORTANCE_LOW))
        }
        notifyPhase("Preparing isolated recorder; keep USB connected", foreground = true)
        Thread(::runMeasurement, "traelyx-performance-qa").start()
        return START_NOT_STICKY
    }

    private fun notifyPhase(message: String, foreground: Boolean = false) {
        val open = PendingIntent.getActivity(this, 91,
            Intent(this, PerformanceControlActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val cancel = PendingIntent.getService(this, 92,
            Intent(this, PerformanceControlService::class.java).setAction(CANCEL),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(io.github.atrx07.traelyx.R.mipmap.ic_launcher)
            .setContentTitle("Traelyx isolated performance QA").setContentText(message)
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel QA", cancel).build()
        if (foreground && Build.VERSION.SDK_INT >= 29) startForeground(NOTICE, notification,
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        else if (foreground) startForeground(NOTICE, notification)
        else getSystemService(NotificationManager::class.java).notify(NOTICE, notification)
    }

    private fun writeJson(name: String, value: JSONObject) {
        val atomic = AtomicFile(File(noBackupFilesDir, name))
        val output = atomic.startWrite()
        try { output.write(value.toString().toByteArray(Charsets.UTF_8)); atomic.finishWrite(output) }
        catch (error: Throwable) { atomic.failWrite(output); throw error }
    }

    private fun progress(name: String, elapsed: Long = 0) {
        stage = name
        writeJson("performance-progress-v1.json", JSONObject().put("contract_version", 1)
            .put("stage", name).put("elapsed_seconds", elapsed))
    }

    private fun battery(): JSONObject {
        val snapshot = requireNotNull(registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)))
        val charge = getSystemService(BatteryManager::class.java)
            .getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        return JSONObject().put("plugged", snapshot.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1))
            .put("status", snapshot.getIntExtra(BatteryManager.EXTRA_STATUS, -1))
            .put("level", snapshot.getIntExtra(BatteryManager.EXTRA_LEVEL, -1))
            .put("scale", snapshot.getIntExtra(BatteryManager.EXTRA_SCALE, -1))
            .put("temperature_tenths_c", snapshot.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE))
            .put("voltage_mv", snapshot.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1))
            .put("charge_counter_microah", if (charge == Int.MIN_VALUE) JSONObject.NULL else charge)
    }

    private fun observe(name: String, seconds: Int): JSONObject {
        progress(name)
        val initial = battery()
        check(initial.getInt("plugged") == 0 && initial.getInt("status") == BatteryManager.BATTERY_STATUS_DISCHARGING)
        val started = SystemClock.elapsedRealtime()
        val uptime = SystemClock.uptimeMillis()
        val cpu = Process.getElapsedCpuTime()
        val samples = JSONArray()
        var screenOn = 0
        while (SystemClock.elapsedRealtime() - started < seconds * 1000L) {
            check(!canceled)
            val current = battery()
            if (power.isInteractive) screenOn++
            samples.put(JSONObject().put("offset_ms", SystemClock.elapsedRealtime() - started)
                .put("cpu_ms", Process.getElapsedCpuTime() - cpu).put("pss_kib", Debug.getPss())
                .put("temperature_tenths_c", current.getInt("temperature_tenths_c"))
                .put("plugged", current.getInt("plugged")).put("battery_status", current.getInt("status")))
            writeJson("performance-$name-partial-v1.json", JSONObject().put("contract_version", 1)
                .put("duration_ms", SystemClock.elapsedRealtime() - started)
                .put("uptime_ms", SystemClock.uptimeMillis() - uptime)
                .put("cpu_ms", Process.getElapsedCpuTime() - cpu).put("battery_start", initial)
                .put("last_battery", current).put("samples", samples))
            check(current.getInt("plugged") == 0 && current.getInt("status") == BatteryManager.BATTERY_STATUS_DISCHARGING)
            if (name == "recording_baseline") {
                check(RecorderService.queryCpuLeaseHeld())
                check(RecorderService.queryState(this).isActive)
            }
            idleCpuLease?.let { check(it.renew()) }
            progress(name, (SystemClock.elapsedRealtime() - started) / 1000)
            SystemClock.sleep(10_000)
        }
        val last = battery()
        check(last.getInt("plugged") == 0 && last.getInt("status") == BatteryManager.BATTERY_STATUS_DISCHARGING)
        return JSONObject().put("duration_ms", SystemClock.elapsedRealtime() - started)
            .put("uptime_ms", SystemClock.uptimeMillis() - uptime)
            .put("cpu_ms", Process.getElapsedCpuTime() - cpu).put("battery_start", initial)
            .put("battery_end", last).put("samples", samples).put("screen_on_samples", screenOn)
            .put("screen_off_verified", screenOn == 0)
    }

    private fun await(name: String, timeout: Long, predicate: () -> Boolean) {
        stage = name
        val end = SystemClock.elapsedRealtime() + timeout
        while (!predicate() && SystemClock.elapsedRealtime() < end) {
            check(!canceled)
            SystemClock.sleep(250)
        }
        check(predicate())
    }

    private fun runMeasurement() {
        val report = JSONObject().put("contract_version", 1).put("api", Build.VERSION.SDK_INT)
            .put("build_mode", "profile_native_qa").put("phase", "recorder")
            .put("controller", "independent_monitor_no_cpu_lock_during_recording")
            .put("recorder_power_policy_version", RECORDER_POWER_POLICY_VERSION)
            .put("idle_control", "CPU-awake observer; not deep-suspend device idle")
            .put("phase_order", "recording_then_post_recording_instrumented_idle")
            .put("screen_timeout_ms", Settings.System.getInt(contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, -1))
        var id: String? = null
        var passed = false
        try {
            check(getString(io.github.atrx07.traelyx.R.string.traelyx_firebase_app_id).isEmpty())
            check(com.google.firebase.FirebaseApp.getApps(this).isEmpty())
            check(!io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(this).present())
            check(!journal.exists() && RecorderService.queryState(this).lifecycleState == RecorderLifecycleState.IDLE)
            val finalizations = AtomicRecorderFinalizationStore(this)
            check(finalizations.loadAll().let { it.records.isEmpty() && it.invalidRecordCount == 0 })
            id = requireNotNull(RecorderService.requestStart(this).tripId)
            writeJson(journal.name, JSONObject().put("version", 1).put("trip_id", id))
            await("recorder_warmup", 30_000) {
                RecorderService.queryState(this).isActive && RecorderService.queryTelemetryHealth().let {
                    it.state == TelemetryBufferState.ACTIVE && it.completedChunkCount >= 3 && RecorderService.queryCpuLeaseHeld()
                }
            }
            progress("ready_to_unplug_and_lock")
            notifyPhase("Ready: unplug USB, press Power once to lock, leave unused for 15 minutes")
            await("awaiting_unplug", 1_800_000) {
                battery().let { it.getInt("plugged") == 0 && it.getInt("status") == BatteryManager.BATTERY_STATUS_DISCHARGING }
            }
            await("awaiting_manual_screen_lock", 300_000) { !power.isInteractive }
            SystemClock.sleep(10_000)
            check(!power.isInteractive && battery().getInt("plugged") == 0)
            notifyPhase("Recording baseline: leave screen locked and phone unplugged")
            val before = RecorderService.queryTelemetryHealth()
            val epoch = requireNotNull(RecorderService.queryState(this).startedAtElapsedRealtimeNanos)
            val windowStart = SystemClock.elapsedRealtimeNanos() - epoch
            val measured = observe("recording_baseline", 600)
            val windowEnd = SystemClock.elapsedRealtimeNanos() - epoch
            val after = RecorderService.queryTelemetryHealth()
            check(RecorderService.queryState(this).let { it.isActive && it.tripId == id && it.errorCode == null })
            check(after.state == TelemetryBufferState.ACTIVE && after.errorCode == null && after.overflowCount == 0L &&
                after.lateSampleCount == 0L && after.writeFailureCount == 0L)
            measured.put("persisted_bytes_added", after.persistedByteCount - before.persistedByteCount)
                .put("chunks_added", after.completedChunkCount - before.completedChunkCount)
                .put("gnss_samples_added", after.persistedGnssSampleCount - before.persistedGnssSampleCount)
                .put("accelerometer_samples_added", after.persistedAccelerometerSampleCount - before.persistedAccelerometerSampleCount)
                .put("gyroscope_samples_added", after.persistedGyroscopeSampleCount - before.persistedGyroscopeSampleCount)
            report.put("recorder", measured)
            // Keep only the post-recording idle control awake; never mask the recorder's own CPU lease.
            idleCpuLease = RecorderCpuLease(AndroidRecorderCpuLock(this, "Traelyx:QaIdleObserverV1"), SystemClock::elapsedRealtime)
            check(requireNotNull(idleCpuLease).start())
            RecorderService.requestStop(this)
            await("recorder_finalization", 30_000) { RecorderService.queryState(this).lifecycleState == RecorderLifecycleState.IDLE }
            check(!RecorderService.queryCpuLeaseHeld())
            SystemClock.sleep(5_000)
            notifyPhase("Post-recording idle baseline: keep unplugged and locked")
            report.put("instrumented_idle", observe("idle_baseline", 180))
            val store = AtomicFileTelemetryChunkStore(this)
            val catalog = store.scanMetadata(id)
            check(catalog.corruptChunkCount == 0 && catalog.orphanedWriteCount == 0 && catalog.orderingViolationCount == 0)
            check(finalizations.load(id) != null)
            report.put("whole_trip_quality", quality(store, id, catalog))
            val window = windowQuality(store, id, catalog, windowStart, windowEnd)
            report.put("recording_window_quality", window)
            stage = "measured_motion_continuity"
            for (channel in listOf("accelerometer", "gyroscope")) {
                check(window.getDouble("${channel}_observed_to_configured_rate") >= .90)
                check(window.getDouble("${channel}_max_gap_ms") <= 1000.0)
            }
            cleanup(id)
            id = null
            report.put("fixture_cleanup", true)
            check(requireNotNull(idleCpuLease).release())
            idleCpuLease = null
            passed = true
        } catch (_: Throwable) {
            report.put("failed_stage", stage)
        } finally {
            idleCpuLease?.release()
            idleCpuLease = null
            id?.let { owned ->
                runCatching {
                    if (RecorderService.queryState(this).tripId == owned) RecorderService.requestStop(this)
                }
            }
            report.put("passed", passed)
            writeJson("performance-recorder-result-v1.json", report)
            progress(if (passed) "complete" else "failed")
            stopForeground(STOP_FOREGROUND_REMOVE)
            running = false
            stopSelf()
        }
    }

    private fun quality(store: AtomicFileTelemetryChunkStore, id: String, catalog: TelemetryChunkMetadataCatalog): JSONObject {
        val previous = mutableMapOf<TelemetryChannel, Long>()
        val gaps = mutableMapOf<TelemetryChannel, Long>()
        for (chunk in catalog.chunks) {
            val decoded = TelemetryChunkCodec.decode(requireNotNull(store.read(id, chunk.sequence))) as TelemetryChunkDecodeResult.Success
            for (sample in decoded.chunk.records) {
                gaps[sample.channel] = maxOf(gaps[sample.channel] ?: 0L, sample.tripElapsedNanos - (previous[sample.channel] ?: 0L))
                previous[sample.channel] = sample.tripElapsedNanos
            }
        }
        val end = catalog.lastVerifiedEndElapsedNanos ?: 0L
        val result = JSONObject().put("catalog_bytes", catalog.chunks.sumOf { it.byteLength.toLong() })
            .put("duration_to_last_sample_ms", end / 1_000_000.0)
        for (channel in TelemetryChannel.entries) result.put("${channel.wireName}_max_gap_ms",
            if (previous[channel] == null) JSONObject.NULL
            else maxOf(gaps[channel] ?: 0L, end - requireNotNull(previous[channel])) / 1_000_000.0)
        val imu = RecorderService.queryImuHealth()
        return result.put("imu_dropout_flags", imu.dropoutCount).put("imu_unreliable_samples", imu.unreliableAccuracySampleCount)
            .put("imu_rejected_samples", imu.rejectedSampleCount).put("imu_clock_discontinuities", imu.clockDiscontinuityCount)
    }

    private fun cleanup(id: String) {
        check(!RecorderService.queryState(this).isActive)
        check(JSONObject(journal.readText()).getString("trip_id") == id)
        UUID.fromString(id)
        check(AtomicRecorderFinalizationStore(this).acknowledge(id))
        val root = File(noBackupFilesDir, "recorder/trips").canonicalFile
        val target = File(root, id).canonicalFile
        check(target.parentFile == root)
        check(!target.exists() || target.deleteRecursively())
        check(journal.delete())
    }

    private fun windowQuality(store: AtomicFileTelemetryChunkStore, id: String,
        catalog: TelemetryChunkMetadataCatalog, start: Long, end: Long): JSONObject {
        val previous = mutableMapOf<TelemetryChannel, Long>()
        val gaps = mutableMapOf<TelemetryChannel, Long>()
        val counts = mutableMapOf<TelemetryChannel, Long>()
        for (chunk in catalog.chunks) {
            if (chunk.endElapsedNanos < start || chunk.startElapsedNanos > end) continue
            val decoded = TelemetryChunkCodec.decode(requireNotNull(store.read(id, chunk.sequence))) as TelemetryChunkDecodeResult.Success
            for (sample in decoded.chunk.records) {
                if (sample.tripElapsedNanos !in start..end) continue
                gaps[sample.channel] = maxOf(gaps[sample.channel] ?: 0L,
                    sample.tripElapsedNanos - (previous[sample.channel] ?: start))
                previous[sample.channel] = sample.tripElapsedNanos
                counts[sample.channel] = (counts[sample.channel] ?: 0L) + 1
            }
        }
        val seconds = (end - start) / 1_000_000_000.0
        val imu = RecorderService.queryImuHealth()
        val result = JSONObject().put("duration_seconds", seconds)
            .put("minimum_observed_to_configured_rate", .90).put("maximum_motion_gap_budget_ms", 1000)
        for (channel in TelemetryChannel.entries) {
            val count = counts[channel] ?: 0L
            result.put("${channel.wireName}_samples", count)
                .put("${channel.wireName}_effective_hz", count / seconds)
                .put("${channel.wireName}_max_gap_ms", if (count == 0L) JSONObject.NULL
                    else maxOf(gaps[channel] ?: 0L, end - requireNotNull(previous[channel])) / 1_000_000.0)
            val period = when (channel) {
                TelemetryChannel.ACCELEROMETER -> imu.accelerometerConfiguration?.effectiveSamplingPeriodMicros
                TelemetryChannel.GYROSCOPE -> imu.gyroscopeConfiguration?.effectiveSamplingPeriodMicros
                else -> null
            }
            if (period != null) result.put("${channel.wireName}_configured_period_micros", period)
                .put("${channel.wireName}_observed_to_configured_rate", count / seconds / (1_000_000.0 / period))
        }
        return result
    }

    override fun onDestroy() { canceled = true; super.onDestroy() }

    companion object {
        const val START = "io.github.atrx07.traelyx.PERFORMANCE_START"
        const val CANCEL = "io.github.atrx07.traelyx.PERFORMANCE_CANCEL"
        private const val QA_PACKAGE = "io.github.atrx07.traelyx.hardening"
        private const val CHANNEL = "isolated_performance_qa_v1"
        private const val NOTICE = 7302
    }
}
