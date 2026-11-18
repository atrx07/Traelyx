package io.github.atrx07.traelyx.recorder

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.SystemClock
import java.io.File
import org.json.JSONObject

/** Bounded profile replay/cleanup checks. Unplugged measurement uses the independent service. */
class RecorderPerformanceInstrumentation : Instrumentation() {
    private lateinit var arguments: Bundle
    private val app get() = targetContext.applicationContext
    private val power get() = app.getSystemService(PowerManager::class.java)
    private val progressFile get() = File(app.noBackupFilesDir, "performance-progress-v1.json")
    private val journal get() = File(app.noBackupFilesDir, "performance-recorder-journal-v1.json")
    private var stage = "preflight"

    override fun onCreate(arguments: Bundle?) {
        this.arguments = arguments ?: Bundle()
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val report = JSONObject().put("contract_version", 1).put("api", Build.VERSION.SDK_INT)
            .put("build_mode", "profile_native_qa").put("phase", arguments.getString("phase", "replay"))
        var passed = false
        val interactive = power.isInteractive
        try {
            check(app.packageName == QA_PACKAGE)
            check(app.getString(io.github.atrx07.traelyx.R.string.traelyx_firebase_app_id).isEmpty())
            check(com.google.firebase.FirebaseApp.getApps(app).isEmpty())
            check(!io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(app).present())
            when (arguments.getString("phase", "replay")) {
                "replay" -> replay(report)
                "inspect" -> inspect(report)
                "power-lifecycle" -> powerLifecycle(report)
                "recorder" -> error("Use the independent foreground controller")
                "cleanup" -> cleanup()
                else -> error("Unknown performance phase")
            }
            passed = true
        } catch (_: Throwable) {
            report.put("failed_stage", stage)
        } finally {
            // Exact journal ownership only; preserve failed raw evidence for scoped cleanup.
            if (journal.exists()) {
                runCatching {
                    val id = JSONObject(journal.readText()).getString("trip_id")
                    if (RecorderService.queryState(app).tripId == id) RecorderService.requestStop(app)
                }
            }
            shell(if (interactive) "input keyevent 224" else "input keyevent 223")
        }
        report.put("passed", passed)
        if (app.packageName == QA_PACKAGE) {
            File(app.noBackupFilesDir, "performance-${arguments.getString("phase", "replay")}-result-v1.json")
                .writeText(report.toString())
        }
        finish(if (passed) Activity.RESULT_OK else Activity.RESULT_CANCELED,
            Bundle().apply { putString("stream", "\nM8_PERFORMANCE_RESULT=$report\n") })
    }

    private fun foreground(className: String = "RecorderHardeningActivity"): Activity {
        shell("input keyevent 224")
        return startActivitySync(Intent().setClassName(app.packageName,
            "io.github.atrx07.traelyx.recorder.$className")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
    }

    private fun replay(report: JSONObject) {
        stage = "replay_preflight"
        check(!RecorderService.queryState(app).isActive && !journal.exists())
        val output = File(app.noBackupFilesDir, "performance-replay-v1.json")
        check(!output.exists())
        val activity = foreground("ReplayPerformanceActivity")
        await("replay_rendering", 120_000) { output.exists() }
        val evidence = JSONObject(output.readText())
        check(!evidence.optBoolean("failed") && evidence.getString("build_mode") == "profile")
        report.put("profile_probe", evidence)
        @Suppress("DEPRECATION")
        report.put("display_refresh_rate_hz_at_end", activity.windowManager.defaultDisplay.refreshRate)
        runOnMainSync { activity.finishAndRemoveTask() }
    }

    private fun inspect(report: JSONObject) {
        stage = "inspect_owned_evidence"
        val owner = JSONObject(journal.readText())
        check(owner.getInt("version") == 1)
        val id = owner.getString("trip_id").also { java.util.UUID.fromString(it) }
        check(!RecorderService.queryState(app).isActive)
        val pending = requireNotNull(AtomicRecorderFinalizationStore(app).load(id))
        val store = AtomicFileTelemetryChunkStore(app)
        val catalog = store.scanMetadata(id)
        val previous = mutableMapOf<TelemetryChannel, Long>()
        val gaps = mutableMapOf<TelemetryChannel, Long>()
        val counts = mutableMapOf<TelemetryChannel, Long>()
        for (chunk in catalog.chunks) {
            val decoded = TelemetryChunkCodec.decode(requireNotNull(store.read(id, chunk.sequence))) as TelemetryChunkDecodeResult.Success
            for (sample in decoded.chunk.records) {
                gaps[sample.channel] = maxOf(gaps[sample.channel] ?: 0L,
                    sample.tripElapsedNanos - (previous[sample.channel] ?: 0L))
                previous[sample.channel] = sample.tripElapsedNanos
                counts[sample.channel] = (counts[sample.channel] ?: 0L) + 1
            }
        }
        val end = catalog.lastVerifiedEndElapsedNanos ?: 0L
        report.put("wall_span_ms", pending.stoppedAtUtcEpochMillis - pending.startedAtUtcEpochMillis)
            .put("last_sample_trip_offset_ms", end / 1_000_000.0)
            .put("chunks", catalog.chunks.size).put("bytes", catalog.chunks.sumOf { it.byteLength.toLong() })
            .put("corrupt_chunks", catalog.corruptChunkCount).put("orphaned_writes", catalog.orphanedWriteCount)
            .put("ordering_violations", catalog.orderingViolationCount)
            .put("recorder_error", pending.recorderErrorCode ?: JSONObject.NULL)
        for (channel in TelemetryChannel.entries) {
            report.put("${channel.wireName}_samples", counts[channel] ?: 0L)
            report.put("${channel.wireName}_max_gap_ms", if (previous[channel] == null) JSONObject.NULL
                else maxOf(gaps[channel] ?: 0L, end - requireNotNull(previous[channel])) / 1_000_000.0)
        }
    }

    private fun powerLifecycle(report: JSONObject) {
        stage = "power_lifecycle_preflight"
        check(!journal.exists() && RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE)
        check(!RecorderService.queryCpuLeaseHeld())
        foreground()
        val id = requireNotNull(RecorderService.requestStart(app).tripId)
        journal.writeText(JSONObject().put("version", 1).put("trip_id", id).toString())
        await("power_start", 15_000) {
            RecorderService.queryCpuLeaseHeld() && RecorderService.queryTelemetryHealth().completedChunkCount > 0
        }
        check(RecorderService.requestStart(app).tripId == id)
        check(app.stopService(Intent(app, RecorderService::class.java)))
        await("power_destroy_release", 15_000) {
            !RecorderService.queryCpuLeaseHeld() && RecorderService.queryTelemetryHealth().state == TelemetryBufferState.STOPPED
        }
        foreground()
        RecorderService.requestRecovery(app)
        await("power_recovery", 15_000) {
            RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.RECOVERED &&
                RecorderService.queryCpuLeaseHeld() && RecorderService.queryTelemetryHealth().state == TelemetryBufferState.ACTIVE
        }
        app.startService(Intent(app, RecorderService::class.java).setAction("qa_invalid_action"))
        await("power_error_release", 15_000) {
            RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.ERROR && !RecorderService.queryCpuLeaseHeld()
        }
        foreground()
        RecorderService.requestStop(app)
        await("power_stop", 15_000) { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE }
        check(!RecorderService.queryCpuLeaseHeld())
        cleanup()
        report.put("power_policy_version", RECORDER_POWER_POLICY_VERSION)
            .put("duplicate_start_preserved", true).put("destroy_release", true)
            .put("recovery_acquired", true).put("error_release", true).put("stop_released", true)
            .put("fixture_cleanup", true)
    }

    private fun cleanup() {
        stage = "cleanup"
        if (!journal.exists()) {
            check(RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE)
            return
        }
        val owner = JSONObject(journal.readText())
        check(owner.getInt("version") == 1)
        val id = owner.getString("trip_id").also { java.util.UUID.fromString(it) }
        val state = RecorderService.queryState(app)
        check(state.tripId == null || state.tripId == id)
        if (state.lifecycleState != RecorderLifecycleState.IDLE) {
            foreground()
            RecorderService.requestStop(app)
            await("cleanup_stop", 30_000) { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE }
        }
        check(AtomicRecorderFinalizationStore(app).acknowledge(id))
        val root = File(app.noBackupFilesDir, "recorder/trips").canonicalFile
        val target = File(root, id).canonicalFile
        check(target.parentFile == root)
        check(!target.exists() || target.deleteRecursively())
        check(journal.delete())
    }

    private fun await(name: String, timeout: Long, predicate: () -> Boolean) {
        stage = name
        val deadline = SystemClock.elapsedRealtime() + timeout
        while (!predicate() && SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(250)
        check(predicate())
    }

    private fun shell(command: String) {
        android.os.ParcelFileDescriptor.AutoCloseInputStream(uiAutomation.executeShellCommand(command))
            .use { it.readBytes() }
    }

    companion object { private const val QA_PACKAGE = "io.github.atrx07.traelyx.hardening" }
}
