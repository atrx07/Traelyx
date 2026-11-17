package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.app.Activity
import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import java.io.File
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/** M8.1 only. Refuses the ordinary package before any recorder or setting mutation. */
class RecorderHardeningInstrumentation : Instrumentation() {
    private lateinit var arguments: Bundle
    private val rows = JSONArray()
    private val app get() = targetContext.applicationContext
    private val journal get() = File(app.noBackupFilesDir, "recorder-hardening-v1.json")
    private val chunks get() = AtomicFileTelemetryChunkStore(app)
    private val finalizations get() = AtomicRecorderFinalizationStore(app)
    private val power get() = app.getSystemService(PowerManager::class.java)
    private var stage = "preflight"
    private var interruptionExpected = false

    override fun onCreate(arguments: Bundle?) {
        this.arguments = arguments ?: Bundle()
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val report = JSONObject().put("contractVersion", 1).put("api", Build.VERSION.SDK_INT)
            .put("phase", arguments.getString("phase", "matrix")).put("rows", rows)
        var success = false
        try {
            check(app.packageName == QA_PACKAGE)
            check(app.getString(io.github.atrx07.traelyx.R.string.traelyx_firebase_app_id).isEmpty())
            check(com.google.firebase.FirebaseApp.getApps(app).isEmpty())
            check(!io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(app).present())
            check(app.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED)
            if (Build.VERSION.SDK_INT >= 33) {
                check(app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
            }
            when (arguments.getString("phase", "matrix")) {
                "matrix" -> matrix()
                "prepare" -> prepare()
                "resume" -> resume()
                "cleanup" -> cleanup()
                else -> error("Unknown phase")
            }
            success = true
        } catch (error: Throwable) {
            // Never emit exception text, paths, coordinates or private sample evidence.
            report.put("failedStage", stage)
            val gnss = RecorderService.queryGnssHealth()
            report.put("gnssHealth", JSONObject().put("state", gnss.state.wireName)
                .put("accepted", gnss.acceptedSampleCount).put("rejected", gnss.rejectedSampleCount)
                .put("registrationFailures", gnss.registrationFailureCount))
            val code = error.message
            if (code in setOf("lifecycle_inactive", "buffer_unhealthy", "notice_missing", "chunks_not_advancing",
                    "accelerometer_not_advancing", "gyroscope_not_advancing", "catalog_invalid", "catalog_sequence_invalid")) {
                report.put("failureCode", code)
            }
        }
        report.put("passed", success)
        finish(if (success) Activity.RESULT_OK else Activity.RESULT_CANCELED,
            Bundle().apply { putString("stream", "\nM8_HARDENING_RESULT=$report\n") })
    }

    private fun foreground(): Activity {
        shell("input keyevent 224")
        return startActivitySync(Intent().setClassName(app.packageName, "$QA_ACTIVITY")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)).also { waitForIdleSync() }
    }

    private fun startOwnedTrip(): String {
        stage = "start_preconditions"
        check(!journal.exists())
        check(RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE)
        check(finalizations.loadAll().let { it.records.isEmpty() && it.invalidRecordCount == 0 })
        foreground()
        val id = requireNotNull(RecorderService.requestStart(app).tripId)
        journal.writeText(JSONObject().put("version", 1).put("tripId", id).toString())
        await("recording") { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.RECORDING }
        await("first_committed_samples") {
            val h = RecorderService.queryTelemetryHealth()
            h.completedChunkCount >= 2 && h.persistedAccelerometerSampleCount > 0 && h.persistedGyroscopeSampleCount > 0
        }
        checkActive(id)
        return id
    }

    private fun matrix() {
        val wasInteractive = power.isInteractive
        var id: String? = null
        try {
            id = startOwnedTrip()
            val duplicate = RecorderService.requestStart(app)
            check(duplicate.tripId == id)
            row("duplicate_start", "passed")

            stage = "activity_recreation"
            val activity = foreground()
            runOnMainSync { activity.recreate() }
            waitForIdleSync()
            progress(id, "activity_recreation", 4_000)

            stage = "background"
            app.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            progress(id, "background", 8_000)

            stage = "screen_off"
            shell("input keyevent 223")
            await("screen_off_confirmed") { !power.isInteractive }
            progress(id, "screen_off", 10_000)
            shell("input keyevent 224")

            if (arguments.getString("platformFaults") == "true") {
                check(Build.HARDWARE in setOf("ranchu", "goldfish"))
                platformFaults(id)
            } else {
                row("provider_network_power_faults", "not_run_physical_settings_preserved")
            }

            stage = "service_recreation"
            val prefix = catalog(id).validChunks.map { it.metadata.checksumHex }
            check(app.stopService(Intent(app, RecorderService::class.java)))
            await("writer_stopped") { RecorderService.queryTelemetryHealth().state == TelemetryBufferState.STOPPED }
            foreground()
            RecorderService.requestRecovery(app)
            await("recovered") { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.RECOVERED }
            check(RecorderService.queryState(app).recoveryCount == 1)
            progress(id, "service_recreation", 5_000)
            check(catalog(id).validChunks.take(prefix.size).map { it.metadata.checksumHex } == prefix)
            stopAndVerify(id)
            row("finalization", "passed")
            cleanup()
            id = null
        } finally {
            // Only a journal-owned QA trip may be stopped. Failed evidence is retained for inspection.
            if (id != null && RecorderService.queryState(app).tripId == id) {
                RecorderService.requestStop(app)
            }
            shell(if (wasInteractive) "input keyevent 224" else "input keyevent 223")
        }
    }

    private fun platformFaults(id: String) {
        val location = app.getSystemService(LocationManager::class.java)
        val enabled = location.isLocationEnabled
        try {
            check(enabled)
            stage = "provider_loss"
            shell("cmd location set-location-enabled false --user 0")
            await("provider_disabled") {
                !location.isLocationEnabled && RecorderService.queryGnssHealth().state == GnssAcquisitionState.PROVIDER_DISABLED
            }
            progress(id, "provider_loss", 5_000)
            val before = RecorderService.queryGnssHealth().acceptedSampleCount
            shell("cmd location set-location-enabled true --user 0")
            await("provider_reenabled") {
                location.isLocationEnabled && RecorderService.queryGnssHealth().state in
                    setOf(GnssAcquisitionState.AWAITING_FIX, GnssAcquisitionState.ACTIVE)
            }
            // The host emits synthetic emulator fixes throughout this phase.
            await("provider_fix_returned") { RecorderService.queryGnssHealth().acceptedSampleCount > before }
            row("provider_fix_returned", "passed_synthetic_emulator")
        } finally {
            shell("cmd location set-location-enabled $enabled --user 0")
            check(location.isLocationEnabled == enabled)
        }

        val connectivity = app.getSystemService(ConnectivityManager::class.java)
        stage = "offline_preconditions"
        val airplane = shell("settings get global airplane_mode_on").trim()
        val wifi = shell("settings get global wifi_on").trim()
        val mobileData = shell("settings get global mobile_data").trim()
        check(airplane in setOf("0", "1") && wifi in setOf("0", "1") && mobileData in setOf("0", "1"))
        try {
            shell("cmd connectivity airplane-mode enable")
            shell("svc wifi disable")
            shell("svc data disable")
            await("no_active_network") { connectivity.activeNetwork == null }
            progress(id, "offline_recording", 6_000)
        } finally {
            shell("cmd connectivity airplane-mode ${if (airplane == "1") "enable" else "disable"}")
            shell("svc wifi ${if (wifi == "1") "enable" else "disable"}")
            shell("svc data ${if (mobileData == "1") "enable" else "disable"}")
            check(shell("settings get global airplane_mode_on").trim() == airplane)
            await("network_settings_restored") {
                shell("settings get global wifi_on").trim() == wifi &&
                    shell("settings get global mobile_data").trim() == mobileData
            }
        }
        row("network_settings_restored", "passed")

        stage = "power_saver_preconditions"
        check(!power.isPowerSaveMode)
        try {
            shell("cmd power set-mode 1")
            if (power.isPowerSaveMode) progress(id, "battery_saver", 6_000)
            else row("battery_saver", "not_supported_while_charging")
        } finally {
            shell("cmd power set-mode 0")
            check(!power.isPowerSaveMode)
        }
    }

    private fun prepare() {
        val id = startOwnedTrip()
        progress(id, "prepare_committed_prefix", 5_000)
        val prefix = catalog(id).validChunks.map { it.metadata.checksumHex }
        val record = JSONObject(journal.readText()).put("pid", Process.myPid())
            .put("prefix", JSONArray(prefix)).put("recoveryCount", RecorderService.queryState(app).recoveryCount)
        journal.writeText(record.toString())
        row("process_checkpoint", "passed", prefix.size.toLong())
        // Deliberately leave recovery metadata/chunks for host interruption; no cleanup here.
    }

    private fun resume() {
        stage = "resume_preconditions"
        interruptionExpected = true
        val record = JSONObject(journal.readText())
        check(record.getInt("version") == 1 && record.getInt("pid") != Process.myPid())
        val id = record.getString("tripId").also { UUID.fromString(it) }
        val prefix = record.getJSONArray("prefix").let { a -> (0 until a.length()).map(a::getString) }
        check(prefix.isNotEmpty())
        check(catalog(id).validChunks.take(prefix.size).map { it.metadata.checksumHex } == prefix)
        check(RecorderService.queryState(app).tripId == id)
        foreground()
        RecorderService.requestRecovery(app)
        await("process_recovered") { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.RECOVERED }
        check(RecorderService.queryState(app).recoveryCount == record.getInt("recoveryCount") + 1)
        progress(id, "process_recovery", 5_000)
        check(catalog(id).validChunks.take(prefix.size).map { it.metadata.checksumHex } == prefix)
        stopAndVerify(id)
        row("prefix_and_finalization", "passed", prefix.size.toLong())
        cleanup()
    }

    private fun progress(id: String, name: String, millis: Long) {
        await("writer_ready") { RecorderService.queryTelemetryHealth().state == TelemetryBufferState.ACTIVE }
        stage = name
        val before = RecorderService.queryTelemetryHealth()
        val start = SystemClock.elapsedRealtime()
        SystemClock.sleep(millis)
        checkActive(id)
        val after = RecorderService.queryTelemetryHealth()
        check(after.completedChunkCount > before.completedChunkCount) { "chunks_not_advancing" }
        check(after.persistedAccelerometerSampleCount > before.persistedAccelerometerSampleCount) { "accelerometer_not_advancing" }
        check(after.persistedGyroscopeSampleCount > before.persistedGyroscopeSampleCount) { "gyroscope_not_advancing" }
        catalog(id)
        row(name, "passed", after.completedChunkCount - before.completedChunkCount,
            SystemClock.elapsedRealtime() - start)
    }

    private fun checkActive(id: String) {
        check(RecorderService.queryState(app).let { it.isActive && it.tripId == id && it.errorCode == null }) { "lifecycle_inactive" }
        check(RecorderService.queryTelemetryHealth().let {
            it.state == TelemetryBufferState.ACTIVE && it.errorCode == null && it.overflowCount == 0L &&
                it.lateSampleCount == 0L && it.writeFailureCount == 0L && it.invalidTripTimeCount == 0L
        }) { "buffer_unhealthy" }
        check(app.getSystemService(NotificationManager::class.java).activeNotifications.any {
            it.id == RecorderService.NOTIFICATION_ID
        }) { "notice_missing" }
    }

    private fun catalog(id: String): TelemetryChunkCatalogSnapshot = (
        if (RecorderService.queryTelemetryHealth().state == TelemetryBufferState.ACTIVE) {
            // Verify only the committed prefix. A concurrently written AtomicFile .new is not an orphan.
            val count = RecorderService.queryTelemetryHealth().completedChunkCount.toInt()
            TelemetryChunkCatalog.inspect((0 until count).map { sequence ->
                TelemetryChunkCandidate(sequence.toLong(), chunks.read(id, sequence.toLong()))
            })
        } else chunks.scan(id)
    ).also {
        check(it.validChunks.isNotEmpty() && it.corruptChunkCount == 0 &&
            (interruptionExpected || it.orphanedWriteCount == 0) && it.orderingViolationCount == 0) { "catalog_invalid" }
        check(it.validChunks.all { chunk -> chunk.metadata.tripId == id }) { "catalog_invalid" }
        if (!interruptionExpected) {
            check(it.validChunks.map { c -> c.metadata.sequence } == it.validChunks.indices.map(Int::toLong)) { "catalog_sequence_invalid" }
        }
    }

    private fun stopAndVerify(id: String) {
        stage = "stop_and_finalization"
        RecorderService.requestStop(app)
        await("idle_after_stop") { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE }
        check(RecorderService.queryTelemetryHealth().state == TelemetryBufferState.STOPPED)
        check(RecorderService.queryGnssHealth().state == GnssAcquisitionState.STOPPED)
        check(RecorderService.queryImuHealth().state == ImuAcquisitionState.STOPPED)
        check(finalizations.loadAll().let { it.invalidRecordCount == 0 && it.records.single().tripId == id })
        val finalCatalog = catalog(id)
        check(finalCatalog.validChunks.size.toLong() == RecorderService.queryTelemetryHealth().completedChunkCount)
        val evaluated = RecorderFinalizationEvaluator.evaluate(requireNotNull(finalizations.load(id)), finalCatalog)
        if (interruptionExpected) {
            check(evaluated.recoveryState == "recovered" && "recorder_recovered" in evaluated.qualityFlags)
            if (finalCatalog.orphanedWriteCount > 0) {
                check(evaluated.completionState == "incomplete" && "orphaned_writes_isolated" in evaluated.qualityFlags)
                row("interrupted_atomic_write", "isolated_and_flagged", finalCatalog.orphanedWriteCount.toLong())
            }
        }
        check(app.getSystemService(NotificationManager::class.java).activeNotifications.none {
            it.id == RecorderService.NOTIFICATION_ID
        })
    }

    private fun cleanup() {
        stage = "fixture_cleanup"
        if (!journal.exists()) {
            check(RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE)
            row("cleanup", "nothing_owned")
            return
        }
        val record = JSONObject(journal.readText())
        check(record.getInt("version") == 1)
        val id = record.getString("tripId").also { UUID.fromString(it) }
        val state = RecorderService.queryState(app)
        check(state.tripId == null || state.tripId == id)
        if (state.lifecycleState != RecorderLifecycleState.IDLE) {
            foreground()
            RecorderService.requestStop(app)
            await("cleanup_idle") { RecorderService.queryState(app).lifecycleState == RecorderLifecycleState.IDLE }
        }
        check(finalizations.acknowledge(id))
        val root = File(app.noBackupFilesDir, "recorder/trips").canonicalFile
        val trip = File(root, id).canonicalFile
        check(trip.parentFile == root)
        check(!trip.exists() || trip.deleteRecursively())
        check(journal.delete())
        check(!trip.exists() && finalizations.load(id) == null)
        row("cleanup", "passed")
    }

    private fun await(name: String, predicate: () -> Boolean) {
        stage = name
        val end = SystemClock.elapsedRealtime() + 15_000
        while (!predicate() && SystemClock.elapsedRealtime() < end) SystemClock.sleep(100)
        check(predicate())
    }

    private fun shell(command: String): String =
        android.os.ParcelFileDescriptor.AutoCloseInputStream(uiAutomation.executeShellCommand(command))
            .bufferedReader().use { it.readText() }

    private fun row(name: String, status: String, count: Long? = null, elapsed: Long? = null) {
        rows.put(JSONObject().put("case", name).put("status", status).apply {
            if (count != null) put("verifiedChunks", count)
            if (elapsed != null) put("observedMillis", elapsed)
        })
    }

    companion object {
        private const val QA_PACKAGE = "io.github.atrx07.traelyx.hardening"
        private const val QA_ACTIVITY = "io.github.atrx07.traelyx.recorder.RecorderHardeningActivity"
    }
}
