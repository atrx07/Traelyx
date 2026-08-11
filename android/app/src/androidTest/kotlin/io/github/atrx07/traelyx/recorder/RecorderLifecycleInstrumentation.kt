package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.app.Activity
import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import io.github.atrx07.traelyx.MainActivity
import java.io.File
import java.util.UUID

class RecorderLifecycleInstrumentation : Instrumentation() {
    private var proofTripId: String? = null
    private var instrumentationArguments: Bundle? = null

    override fun onCreate(arguments: Bundle?) {
        instrumentationArguments = arguments
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
        try {
            val stream =
                when (instrumentationArguments?.getString("mode")) {
                    "index" ->
                        runIndexProof(
                            requireNotNull(instrumentationArguments?.getString("tripId")),
                        )
                    "cleanup" ->
                        runCleanupProof(
                            requireNotNull(instrumentationArguments?.getString("tripId")),
                        )
                    else -> {
                        runLifecycleProof()
                        "M2.7 recorder recovery, finalization handoff, and privacy-safe chunk proof passed."
                    }
                }
            results.putString(
                "stream",
                "\n$stream\n",
            )
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString(
                "stream",
                "\nM2.7 recorder recovery, finalization handoff, and chunk proof failed:\n" +
                    "${error.stackTraceToString()}\n",
            )
            finish(Activity.RESULT_CANCELED, results)
        }
    }

    private fun runCleanupProof(tripId: String): String {
        check(runCatching { UUID.fromString(tripId) }.isSuccess) {
            "Cleanup requires a valid trip UUID."
        }
        val databaseFile =
            File(targetContext.applicationInfo.dataDir, "app_flutter/traelyx.sqlite")
        check(databaseFile.isFile) { "Traelyx database is unavailable." }
        val deletedChunks: Int
        val deletedTrips: Int
        SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READWRITE).use {
                database ->
            database.beginTransaction()
            try {
                deletedChunks = database.delete("trip_chunks", "trip_id = ?", arrayOf(tripId))
                deletedTrips = database.delete("trips", "id = ?", arrayOf(tripId))
                database.execSQL(
                    """
                    DELETE FROM vehicles
                    WHERE id = ?
                      AND NOT EXISTS (SELECT 1 FROM trips WHERE vehicle_id = vehicles.id)
                    """.trimIndent(),
                    arrayOf("local-recorder-vehicle-v1"),
                )
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        }
        check(deletedTrips == 1) { "Exact proof trip cleanup deleted $deletedTrips trip rows." }
        check(deletedChunks > 0) { "Exact proof trip cleanup deleted no chunk rows." }
        check(AtomicFileTelemetryChunkStore(targetContext).deleteTripForTest(tripId)) {
            "Exact proof telemetry directory could not be deleted."
        }
        check(AtomicRecorderFinalizationStore(targetContext).acknowledge(tripId)) {
            "Exact proof pending-finalization cleanup failed."
        }
        return "M2.7 exact-UUID cleanup passed: deletedTripRows=$deletedTrips, " +
            "deletedChunkRows=$deletedChunks, privateTelemetryRemoved=true."
    }

    private fun runIndexProof(tripId: String): String {
        check(runCatching { UUID.fromString(tripId) }.isSuccess) {
            "Index proof requires a valid trip UUID."
        }
        val databaseFile =
            File(targetContext.applicationInfo.dataDir, "app_flutter/traelyx.sqlite")
        check(databaseFile.isFile) { "Traelyx database is unavailable." }
        SQLiteDatabase.openDatabase(
            databaseFile.path,
            null,
            SQLiteDatabase.OPEN_READONLY,
        ).use { database ->
            database.rawQuery(
                """
                SELECT t.completion_state, t.recovery_state, t.integrity_status,
                       COUNT(c.sequence),
                       SUM(CASE WHEN c.storage_reference LIKE ? THEN 0 ELSE 1 END)
                FROM trips AS t
                LEFT JOIN trip_chunks AS c ON c.trip_id = t.id
                WHERE t.id = ?
                GROUP BY t.id, t.completion_state, t.recovery_state, t.integrity_status
                """.trimIndent(),
                arrayOf("recorder/trips/$tripId/chunks/%", tripId),
            ).use { cursor ->
                check(cursor.moveToFirst()) { "Exact proof trip is absent from Drift." }
                val completionState = cursor.getString(0)
                val recoveryState = cursor.getString(1)
                val integrityStatus = cursor.getString(2)
                val chunkCount = cursor.getLong(3)
                val invalidReferenceCount = cursor.getLong(4)
                check(!cursor.moveToNext()) { "Exact proof trip was indexed more than once." }
                check(completionState == "completed") {
                    "Proof trip did not finalize as completed."
                }
                check(recoveryState == "recovered") {
                    "Process-restarted proof trip did not retain recovered state."
                }
                check(integrityStatus == "unassessed") {
                    "Proof trip integrity state was unexpectedly altered."
                }
                check(chunkCount > 0) { "Proof trip has no indexed chunks." }
                check(invalidReferenceCount == 0L) {
                    "Proof trip contains a non-relative chunk reference."
                }
                return "M2.7 exact-UUID Drift index proof passed: " +
                    "completion=$completionState, recovery=$recoveryState, " +
                    "integrity=$integrityStatus, indexedChunks=$chunkCount."
            }
        }
    }

    private fun runLifecycleProof() {
        val context = targetContext
        val bridge = RecorderBridgeDispatcher(AndroidRecorderBridgeGateway(context))

        try {
            check(
                context.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
                    context.hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION),
            ) {
                "Grant coarse or fine location permission before running the lifecycle proof."
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                check(context.hasPermission(Manifest.permission.POST_NOTIFICATIONS)) {
                    "Grant notification permission before running the lifecycle proof."
                }
            }
            context.stopService(Intent(context, RecorderService::class.java))
            check(AtomicRecorderRecoveryStore(context).clear()) {
                "Could not clear recorder recovery metadata before the proof."
            }

            val activity =
                startActivitySync(
                    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            waitForIdleSync()
            checkBridgeCapabilities(bridge)

            val startStatus = bridgePayload(bridge, RecorderContract.START_TRIP)
            val startLifecycle = startStatus.mapValue("lifecycle")
            check(startLifecycle["state"] in setOf("starting", "recording")) {
                "Bridge start was not accepted: ${startLifecycle["state"]}/${startLifecycle["errorCode"]}"
            }
            val accepted = RecorderService.queryState(context)
            proofTripId = accepted.tripId
            val active = awaitState(context) { it.lifecycleState == RecorderLifecycleState.RECORDING }
            check(accepted.tripId == active.tripId) { "Active trip identity changed during start." }
            check(active.isActive) { "Recorder did not report an active lifecycle." }
            checkBridgeStatus(bridge, expectedActive = true)
            checkNotificationActive(context)
            val initialImu = awaitImuSamples()
            checkImuMetadata(initialImu)
            val initialGnss = awaitGnssFix()
            check(initialGnss.provider == "gps") { "Recorder did not use the GPS provider." }
            check(initialGnss.acceptedSampleCount > 0) { "No GNSS fix was accepted." }
            check(initialGnss.rejectedSampleCount >= 0) { "Invalid rejected-sample counter." }
            check(initialGnss.firstSourceTimestampNanos != null) {
                "GNSS source timestamp was not preserved."
            }
            check(initialGnss.lastSourceTimestampNanos != null) {
                "GNSS last source timestamp was not preserved."
            }
            check(initialGnss.lastTripElapsedNanos != null) {
                "GNSS trip elapsed time was unavailable for the same-boot trip."
            }
            check(initialGnss.lastHorizontalAccuracyMetres != null) {
                "GNSS horizontal accuracy was not preserved."
            }
            check(initialGnss.errorCode == null) {
                "GNSS health contained an acquisition error: ${initialGnss.errorCode}"
            }
            val initialTelemetry =
                awaitTelemetryChunks(
                    minimumChunkCount = 1,
                    minimumGnssSamples = 1,
                    minimumAccelerometerSamples = MINIMUM_IMU_SAMPLES_PER_SENSOR,
                    minimumGyroscopeSamples = MINIMUM_IMU_SAMPLES_PER_SENSOR,
                )
            checkTelemetryHealth(initialTelemetry)
            checkBridgeStatus(bridge, expectedActive = true)

            activity.runOnUiThread(activity::recreate)
            waitForIdleSync()
            val afterActivityRecreation = RecorderService.queryState(context)
            val afterActivityRecreationBuffer = RecorderService.queryTelemetryHealth()
            check(afterActivityRecreation.isActive) {
                "Recorder stopped during activity recreation: " +
                    "lifecycle=${afterActivityRecreation.lifecycleState.wireName}/" +
                    "${afterActivityRecreation.errorCode}, " +
                    "buffer=${afterActivityRecreationBuffer.state.wireName}/" +
                    "${afterActivityRecreationBuffer.errorCode}, " +
                    "queue=${afterActivityRecreationBuffer.queueDepth}, " +
                    "buffered=${afterActivityRecreationBuffer.bufferedSampleCount}, " +
                    "overflow=${afterActivityRecreationBuffer.overflowCount}, " +
                    "late=${afterActivityRecreationBuffer.lateSampleCount}, " +
                    "write=${afterActivityRecreationBuffer.writeFailureCount}."
            }

            check(context.stopService(Intent(context, RecorderService::class.java))) {
                "Android did not stop the recorder service for the recovery proof."
            }
            val stoppedForRecovery = awaitTelemetryWriterStopped()
            check(RecorderService.queryState(context).lifecycleState == RecorderLifecycleState.RECORDING) {
                "Stopping the service erased active-trip recovery metadata."
            }
            checkTelemetryHealth(stoppedForRecovery)
            bridgePayload(bridge, RecorderContract.RECOVER_TRIP)
            val recovered =
                awaitState(context) { it.lifecycleState == RecorderLifecycleState.RECOVERED }
            check(recovered.tripId == accepted.tripId) { "Recovery changed the active trip identity." }
            check(recovered.recoveryCount == 1) { "Recovery count was not incremented once." }
            checkBridgeStatus(bridge, expectedActive = true)
            checkNotificationActive(context)
            val recoveredCatalogHealth = awaitTelemetryWriterActive()
            check(
                recoveredCatalogHealth.recoveredValidChunkCount >=
                    initialTelemetry.completedChunkCount,
            ) {
                "Recovered writer did not discover the previously completed chunks."
            }
            checkTelemetryHealth(recoveredCatalogHealth)
            val recoveredImu = awaitImuSamples()
            checkImuMetadata(recoveredImu)
            val recoveredGnss = awaitGnssFix()
            check(recoveredGnss.acceptedSampleCount > 0) {
                "GNSS acquisition did not restart with the recovered lifecycle."
            }
            val afterRecoveryTelemetry =
                awaitTelemetryChunks(
                    minimumChunkCount = recoveredCatalogHealth.completedChunkCount + 1,
                    minimumGnssSamples = recoveredCatalogHealth.persistedGnssSampleCount + 1,
                    minimumAccelerometerSamples =
                        recoveredCatalogHealth.persistedAccelerometerSampleCount +
                            MINIMUM_IMU_SAMPLES_PER_SENSOR,
                    minimumGyroscopeSamples =
                        recoveredCatalogHealth.persistedGyroscopeSampleCount +
                            MINIMUM_IMU_SAMPLES_PER_SENSOR,
                )
            checkTelemetryHealth(afterRecoveryTelemetry)
            checkBridgeStatus(bridge, expectedActive = true)

            context.startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            SystemClock.sleep(500)
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped when the app was backgrounded."
            }
            checkNotificationActive(context)

            executeShellCommand("input keyevent 223")
            SystemClock.sleep(500)
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped when the screen turned off."
            }
            checkNotificationActive(context)
            executeShellCommand("input keyevent 224")

            bridgePayload(bridge, RecorderContract.STOP_TRIP)
            val idle = awaitState(context) { it.lifecycleState == RecorderLifecycleState.IDLE }
            check(!idle.isActive) { "Recorder remained active after stop." }
            checkBridgeStatus(bridge, expectedActive = false)
            checkNotificationStopped(context)
            check(RecorderService.queryGnssHealth().state == GnssAcquisitionState.STOPPED) {
                "GNSS callbacks did not stop with the recorder lifecycle."
            }
            check(RecorderService.queryImuHealth().state == ImuAcquisitionState.STOPPED) {
                "IMU callbacks did not stop with the recorder lifecycle."
            }
            val stoppedTelemetry = RecorderService.queryTelemetryHealth()
            check(stoppedTelemetry.state == TelemetryBufferState.STOPPED) {
                "Durable writer did not stop with the recorder lifecycle."
            }
            checkTelemetryHealth(stoppedTelemetry)
            val finalCatalog =
                AtomicFileTelemetryChunkStore(context).scan(requireNotNull(accepted.tripId))
            check(finalCatalog.validChunks.size.toLong() == stoppedTelemetry.completedChunkCount) {
                "Final catalog and durable health chunk counts differ."
            }
            check(finalCatalog.corruptChunkCount == 0) { "Final catalog contained corruption." }
            check(finalCatalog.orphanedWriteCount == 0) {
                "Final catalog contained an incomplete atomic write."
            }
            check(finalCatalog.orderingViolationCount == 0) {
                "Final catalog contained an elapsed-time ordering violation."
            }
            check(finalCatalog.validChunks.all { it.metadata.checksumHex.length == 64 }) {
                "A final chunk did not contain a verified SHA-256 checksum."
            }
            checkFinalizationHandoff(bridge, requireNotNull(accepted.tripId), finalCatalog)
        } finally {
            executeShellCommand("input keyevent 224")
            context.stopService(Intent(context, RecorderService::class.java))
            AtomicRecorderRecoveryStore(context).clear()
            proofTripId?.let { tripId ->
                AtomicRecorderFinalizationStore(context).acknowledge(tripId)
                awaitTelemetryWriterTeardown()
                check(deleteProofTripWithRetry(context, tripId)) {
                    "Could not remove the proof trip's private telemetry chunks."
                }
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun checkFinalizationHandoff(
        bridge: RecorderBridgeDispatcher,
        tripId: String,
        catalog: TelemetryChunkCatalogSnapshot,
    ) {
        val batch = bridgePayload(bridge, RecorderContract.GET_PENDING_FINALIZATIONS)
        check(batch["contractVersion"] == RECORDER_FINALIZATION_CONTRACT_VERSION)
        check(batch["invalidRecordCount"] == 0)
        val finalizations = batch["finalizations"] as List<Map<String, Any?>>
        val finalization = finalizations.single { it["tripId"] == tripId }
        check(finalization["completionState"] == "completed")
        check(finalization["recoveryState"] == "recovered")
        check(finalization["integrityStatus"] == "unassessed")
        val chunks = finalization["chunks"] as List<Map<String, Any?>>
        check(chunks.size == catalog.validChunks.size)
        check(chunks.all { chunk ->
            val reference = chunk["storageReference"] as? String
            reference != null &&
                reference.startsWith("recorder/trips/$tripId/chunks/") &&
                !reference.startsWith("/") &&
                !reference.contains("\\")
        }) {
            "Finalization exposed an invalid or absolute storage reference."
        }
        check(chunks.none { chunk ->
            chunk.keys.any { key ->
                key.contains("coordinate", ignoreCase = true) ||
                    key.contains("vector", ignoreCase = true) ||
                    key.contains("sourceTimestamp", ignoreCase = true)
            }
        }) {
            "Finalization exposed raw telemetry evidence."
        }
        val acknowledged =
            bridgePayload(
                bridge,
                RecorderContract.ACKNOWLEDGE_TRIP_FINALIZATION,
                mapOf("tripId" to tripId),
            )
        check(acknowledged["acknowledged"] == true)
        check(AtomicRecorderFinalizationStore(targetContext).load(tripId) == null) {
            "Finalization acknowledgement did not remove the pending handoff."
        }
    }

    private fun checkBridgeCapabilities(bridge: RecorderBridgeDispatcher) {
        val capabilities = bridgePayload(bridge, RecorderContract.GET_CAPABILITIES)
        check(capabilities["bridgeVersion"] == RecorderContract.BRIDGE_VERSION)
        check(capabilities["statusContractVersion"] == RECORDER_STATUS_CONTRACT_VERSION)
        check(capabilities["implementationState"] == "bridge_ready")
        check(capabilities["recordingAvailable"] == isPlatformRecordingReady(targetContext))
        check(capabilities["commandsAvailable"] == true)
        check(capabilities["healthAvailable"] == true)
        check(capabilities["permissionOnboardingAvailable"] == true)
        val requestedPermissions =
            targetContext.packageManager
                .getPackageInfo(targetContext.packageName, PackageManager.GET_PERMISSIONS)
                .requestedPermissions
                ?.toSet()
                .orEmpty()
        check(Manifest.permission.ACCESS_BACKGROUND_LOCATION !in requestedPermissions) {
            "Recorder must not declare background location permission."
        }
    }

    private fun checkBridgeStatus(
        bridge: RecorderBridgeDispatcher,
        expectedActive: Boolean,
    ) {
        val status = bridgePayload(bridge, RecorderContract.GET_STATUS)
        check(status["contractVersion"] == RECORDER_STATUS_CONTRACT_VERSION)
        check(status["bridgeVersion"] == RecorderContract.BRIDGE_VERSION)
        val lifecycle = status.mapValue("lifecycle")
        val gnss = status.mapValue("gnss")
        val imu = status.mapValue("imu")
        val buffer = status.mapValue("buffer")
        check(lifecycle["active"] == expectedActive)
        check(!lifecycle.containsKey("startedAtUtcEpochMillis"))
        check(!lifecycle.containsKey("startedAtElapsedRealtimeNanos"))
        check(!gnss.containsKey("lastSourceTimestampNanos"))
        check(!gnss.containsKey("lastHorizontalAccuracyMetres"))
        check(!gnss.containsKey("lastFixWallTimeUtcEpochMillis"))
        check(imu.keys.none { it.contains("Timestamp") || it.contains("AccuracyStatus") })
        check(buffer.keys.none { it.contains("path", ignoreCase = true) })
        check(status.keys.none { it.contains("device", ignoreCase = true) })
    }

    private fun bridgePayload(
        bridge: RecorderBridgeDispatcher,
        method: String,
        arguments: Map<String, Any?>? = null,
    ): Map<String, Any?> =
        when (val result = bridge.dispatch(method, arguments)) {
            is RecorderBridgeDispatchResult.Handled -> result.payload
            RecorderBridgeDispatchResult.NotImplemented -> error("Bridge method was unavailable: $method")
        }

    @Suppress("UNCHECKED_CAST")
    private fun Map<String, Any?>.mapValue(key: String): Map<String, Any?> =
        getValue(key) as Map<String, Any?>

    private fun awaitTelemetryWriterTeardown() {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_STATE_TIMEOUT_MILLIS
        var state = RecorderService.queryTelemetryHealth().state
        while (
            state != TelemetryBufferState.STOPPED &&
            state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            state = RecorderService.queryTelemetryHealth().state
        }
    }

    private fun awaitTelemetryWriterStopped(): TelemetryBufferHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryTelemetryHealth()
        while (
            latest.state != TelemetryBufferState.STOPPED &&
            latest.state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryTelemetryHealth()
        }
        check(latest.state == TelemetryBufferState.STOPPED) {
            "Service teardown did not flush and stop the durable writer; " +
                "state=${latest.state.wireName}, error=${latest.errorCode}."
        }
        return latest
    }

    private fun awaitTelemetryWriterActive(): TelemetryBufferHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryTelemetryHealth()
        while (
            latest.state != TelemetryBufferState.ACTIVE &&
            latest.state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryTelemetryHealth()
        }
        check(latest.state == TelemetryBufferState.ACTIVE) {
            "Recovered durable writer did not become active; " +
                "state=${latest.state.wireName}, error=${latest.errorCode}."
        }
        return latest
    }

    private fun deleteProofTripWithRetry(
        context: Context,
        tripId: String,
    ): Boolean {
        val store = AtomicFileTelemetryChunkStore(context)
        repeat(PROOF_DELETE_ATTEMPTS) {
            if (store.deleteTripForTest(tripId)) return true
            SystemClock.sleep(PROOF_DELETE_RETRY_MILLIS)
        }
        return false
    }

    private fun awaitTelemetryChunks(
        minimumChunkCount: Long,
        minimumGnssSamples: Long,
        minimumAccelerometerSamples: Long,
        minimumGyroscopeSamples: Long,
    ): TelemetryBufferHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_TIMEOUT_MILLIS
        var latest = RecorderService.queryTelemetryHealth()
        while (
            (latest.completedChunkCount < minimumChunkCount ||
                latest.persistedGnssSampleCount < minimumGnssSamples ||
                latest.persistedAccelerometerSampleCount < minimumAccelerometerSamples ||
                latest.persistedGyroscopeSampleCount < minimumGyroscopeSamples) &&
            latest.state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(TELEMETRY_POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryTelemetryHealth()
        }
        check(latest.state != TelemetryBufferState.ERROR) {
            "Durable telemetry writer failed: ${latest.errorCode}"
        }
        check(latest.completedChunkCount >= minimumChunkCount) {
            "Timed out waiting for durable chunk completion."
        }
        check(latest.persistedGnssSampleCount >= minimumGnssSamples) {
            "Timed out waiting for durable GNSS evidence."
        }
        check(latest.persistedAccelerometerSampleCount >= minimumAccelerometerSamples) {
            "Timed out waiting for durable accelerometer evidence."
        }
        check(latest.persistedGyroscopeSampleCount >= minimumGyroscopeSamples) {
            "Timed out waiting for durable gyroscope evidence."
        }
        return latest
    }

    private fun checkTelemetryHealth(health: TelemetryBufferHealthSnapshot) {
        check(health.queueCapacity == TELEMETRY_CHUNK_INGRESS_CAPACITY)
        check(health.reorderBufferCapacity == TELEMETRY_CHUNK_REORDER_BUFFER_CAPACITY)
        check(health.queueDepth in 0..health.queueCapacity)
        check(health.completedChunkCount > 0)
        check(health.persistedByteCount > 0)
        check(health.corruptChunkCount == 0)
        check(health.orphanedWriteCount == 0)
        check(health.orderingViolationCount == 0)
        check(health.overflowCount == 0L)
        check(health.invalidTripTimeCount == 0L)
        check(health.lateSampleCount == 0L)
        check(health.writeFailureCount == 0L)
        check(health.lastCompletedSequence != null)
        check(health.hasCommittedElapsedBoundary)
        check(health.errorCode == null)
    }

    private fun awaitImuSamples(): ImuHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + IMU_SAMPLE_TIMEOUT_MILLIS
        var latest = RecorderService.queryImuHealth()
        while (
            (latest.accelerometerAcceptedSampleCount < MINIMUM_IMU_SAMPLES_PER_SENSOR ||
                latest.gyroscopeAcceptedSampleCount < MINIMUM_IMU_SAMPLES_PER_SENSOR) &&
            latest.state != ImuAcquisitionState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(IMU_POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryImuHealth()
        }
        check(latest.state != ImuAcquisitionState.ERROR) {
            "IMU registration failed: ${latest.errorCode}"
        }
        check(latest.accelerometerAcceptedSampleCount >= MINIMUM_IMU_SAMPLES_PER_SENSOR) {
            "Timed out waiting for accelerometer samples; " +
                "accepted=${latest.accelerometerAcceptedSampleCount}, " +
                "rejected=${latest.rejectedSampleCount}."
        }
        check(latest.gyroscopeAcceptedSampleCount >= MINIMUM_IMU_SAMPLES_PER_SENSOR) {
            "Timed out waiting for gyroscope samples; " +
                "accepted=${latest.gyroscopeAcceptedSampleCount}, " +
                "rejected=${latest.rejectedSampleCount}."
        }
        return latest
    }

    private fun checkImuMetadata(health: ImuHealthSnapshot) {
        val accelerometerConfig = health.accelerometerConfiguration
        val gyroscopeConfig = health.gyroscopeConfiguration
        check(accelerometerConfig != null) { "Accelerometer configuration was unavailable." }
        check(gyroscopeConfig != null) { "Gyroscope configuration was unavailable." }
        check(accelerometerConfig.sensorType == ImuSensorType.ACCELEROMETER)
        check(gyroscopeConfig.sensorType == ImuSensorType.GYROSCOPE)
        check(
            accelerometerConfig.requestedSamplingPeriodMicros ==
                IMU_REQUESTED_SAMPLING_PERIOD_MICROS,
        )
        check(
            gyroscopeConfig.requestedSamplingPeriodMicros ==
                IMU_REQUESTED_SAMPLING_PERIOD_MICROS,
        )
        check(
            accelerometerConfig.effectiveMaxReportLatencyMicros <=
                IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS,
        )
        check(
            gyroscopeConfig.effectiveMaxReportLatencyMicros <=
                IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS,
        )
        check(health.accelerometerFirstSourceTimestampNanos != null) {
            "Accelerometer source timestamp was not preserved."
        }
        check(health.gyroscopeFirstSourceTimestampNanos != null) {
            "Gyroscope source timestamp was not preserved."
        }
        check(health.accelerometerLastTripElapsedNanos != null) {
            "Accelerometer trip elapsed time was unavailable."
        }
        check(health.gyroscopeLastTripElapsedNanos != null) {
            "Gyroscope trip elapsed time was unavailable."
        }
        check(health.accelerometerLastAccuracyStatus != null) {
            "Accelerometer accuracy status was not preserved."
        }
        check(health.gyroscopeLastAccuracyStatus != null) {
            "Gyroscope accuracy status was not preserved."
        }
        check(health.errorCode == null) { "IMU health contained an error: ${health.errorCode}" }
    }

    private fun awaitGnssFix(): GnssHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + GNSS_FIX_TIMEOUT_MILLIS
        var latest = RecorderService.queryGnssHealth()
        while (
            latest.acceptedSampleCount == 0L &&
            latest.state != GnssAcquisitionState.PROVIDER_DISABLED &&
            latest.state != GnssAcquisitionState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(GNSS_POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryGnssHealth()
        }
        check(latest.state != GnssAcquisitionState.PROVIDER_DISABLED) {
            "GPS provider is disabled; enable precise device location before running the proof."
        }
        check(latest.state != GnssAcquisitionState.ERROR) {
            "GNSS registration failed: ${latest.errorCode}"
        }
        check(latest.acceptedSampleCount > 0) {
            "Timed out waiting for a real GPS fix; " +
                "state=${latest.state.wireName}, " +
                "rejected=${latest.rejectedSampleCount}, " +
                "registrationFailures=${latest.registrationFailureCount}. " +
                "Place the phone outdoors with a clear sky view."
        }
        return latest
    }

    private fun awaitState(
        context: Context,
        predicate: (RecorderStateSnapshot) -> Boolean,
    ): RecorderStateSnapshot {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryState(context)
        while (!predicate(latest) && SystemClock.uptimeMillis() < deadline) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryState(context)
        }
        check(predicate(latest)) {
            "Timed out waiting for recorder state; " +
                "latest=${latest.lifecycleState.wireName}, error=${latest.errorCode}"
        }
        return latest
    }

    private fun awaitRecovery(context: Context): RecorderStateSnapshot {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        var latest = RecorderService.requestRecovery(context)
        while (
            latest.lifecycleState != RecorderLifecycleState.RECOVERED &&
            latest.lifecycleState != RecorderLifecycleState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.requestRecovery(context)
        }
        check(latest.lifecycleState == RecorderLifecycleState.RECOVERED) {
            "Timed out waiting for recorder recovery; " +
                "latest=${latest.lifecycleState.wireName}, error=${latest.errorCode}"
        }
        return latest
    }

    private fun checkNotificationActive(context: Context) {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        val manager = context.getSystemService(NotificationManager::class.java)
        while (
            manager.activeNotifications.none { it.id == RecorderService.NOTIFICATION_ID } &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
        }
        check(manager.activeNotifications.any { it.id == RecorderService.NOTIFICATION_ID }) {
            "Recorder foreground notification was not active."
        }
    }

    private fun checkNotificationStopped(context: Context) {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        val manager = context.getSystemService(NotificationManager::class.java)
        while (
            manager.activeNotifications.any { it.id == RecorderService.NOTIFICATION_ID } &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
        }
        check(manager.activeNotifications.none { it.id == RecorderService.NOTIFICATION_ID }) {
            "Recorder foreground notification remained after stop."
        }
    }

    private fun executeShellCommand(command: String) {
        uiAutomation.executeShellCommand(command).close()
    }

    private fun Context.hasPermission(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        private const val STATE_TIMEOUT_MILLIS = 5_000L
        private const val POLL_INTERVAL_MILLIS = 50L
        private const val GNSS_FIX_TIMEOUT_MILLIS = 120_000L
        private const val GNSS_POLL_INTERVAL_MILLIS = 250L
        private const val IMU_SAMPLE_TIMEOUT_MILLIS = 10_000L
        private const val IMU_POLL_INTERVAL_MILLIS = 50L
        private const val MINIMUM_IMU_SAMPLES_PER_SENSOR = 20L
        private const val TELEMETRY_TIMEOUT_MILLIS = 15_000L
        private const val TELEMETRY_STATE_TIMEOUT_MILLIS = 15_000L
        private const val TELEMETRY_POLL_INTERVAL_MILLIS = 100L
        private const val PROOF_DELETE_ATTEMPTS = 20
        private const val PROOF_DELETE_RETRY_MILLIS = 50L
    }
}
