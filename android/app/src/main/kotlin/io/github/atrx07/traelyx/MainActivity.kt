package io.github.atrx07.traelyx

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.github.atrx07.traelyx.data.DataManagementContract
import io.github.atrx07.traelyx.data.RedactedTripSummaryPayload
import io.github.atrx07.traelyx.data.rawTelemetryDeletionMap
import io.github.atrx07.traelyx.data.redactedSummaryExportMap
import io.github.atrx07.traelyx.diagnostics.DiagnosticsContract
import io.github.atrx07.traelyx.diagnostics.DiagnosticsSnapshotCollector
import io.github.atrx07.traelyx.maps.MapDataContract
import io.github.atrx07.traelyx.maps.TripRouteReader
import io.github.atrx07.traelyx.maps.toBridgeMap
import io.github.atrx07.traelyx.recorder.AndroidRecorderBridgeGateway
import io.github.atrx07.traelyx.recorder.AndroidRecorderPermissionGateway
import io.github.atrx07.traelyx.recorder.AtomicRecorderFinalizationStore
import io.github.atrx07.traelyx.recorder.AtomicFileTelemetryChunkStore
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatchResult
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatcher
import io.github.atrx07.traelyx.recorder.RecorderContract
import io.github.atrx07.traelyx.recorder.RecorderService
import io.github.atrx07.traelyx.recorder.RawTelemetryDeletionResult
import io.github.atrx07.traelyx.recorder.PreparedTripDebugExport
import io.github.atrx07.traelyx.recorder.TripDebugArchiveExporter
import io.github.atrx07.traelyx.recorder.TripDebugPreparationResult
import io.github.atrx07.traelyx.recorder.toBridgeMap
import io.github.atrx07.traelyx.recorder.tripDebugExportFailureMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val permissionGateway by lazy { AndroidRecorderPermissionGateway(this) }
    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingTripDebugResult: MethodChannel.Result? = null
    private var pendingTripDebugTripId: String? = null
    private var preparedTripDebugExport: PreparedTripDebugExport? = null
    private var pendingRedactedSummaryResult: MethodChannel.Result? = null
    private var preparedRedactedSummary: ByteArray? = null
    private val tripDebugExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val dataManagementExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val routeExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun onPostResume() {
        super.onPostResume()
        RecorderService.requestRecovery(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val recorderDispatcher =
            RecorderBridgeDispatcher(
                AndroidRecorderBridgeGateway(
                    applicationContext,
                    recordingReadiness = { permissionGateway.snapshot().recordingReady },
                ),
            )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RecorderContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                RecorderContract.GET_PERMISSION_STATUS ->
                    result.success(permissionGateway.snapshot().toMap())
                RecorderContract.REQUEST_LOCATION_PERMISSION -> requestLocation(result)
                RecorderContract.REQUEST_NOTIFICATION_PERMISSION -> requestNotification(result)
                RecorderContract.OPEN_APP_SETTINGS -> {
                    permissionGateway.openAppSettings()
                    result.success(permissionGateway.snapshot().toMap())
                }
                RecorderContract.OPEN_LOCATION_SETTINGS -> {
                    permissionGateway.openLocationSettings()
                    result.success(permissionGateway.snapshot().toMap())
                }
                RecorderContract.EXPORT_TRIPDEBUG ->
                    beginTripDebugExport(call.argument<String>("tripId"), result)
                else ->
                    when (
                        val dispatched =
                            recorderDispatcher.dispatch(
                                call.method,
                                @Suppress("UNCHECKED_CAST")
                                (call.arguments as? Map<String, Any?>),
                            )
                    ) {
                        is RecorderBridgeDispatchResult.Handled -> result.success(dispatched.payload)
                        RecorderBridgeDispatchResult.NotImplemented -> result.notImplemented()
                    }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DiagnosticsContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                DiagnosticsContract.GET_SNAPSHOT -> result.success(
                    DiagnosticsSnapshotCollector(applicationContext).collect(),
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DataManagementContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                DataManagementContract.DELETE_RAW_TELEMETRY ->
                    deleteRawTelemetry(call.argument<String>("tripId"), result)
                DataManagementContract.EXPORT_REDACTED_SUMMARY -> {
                    @Suppress("UNCHECKED_CAST")
                    val payload = RedactedTripSummaryPayload.fromMap(
                        call.arguments as? Map<String, Any?>,
                    )
                    beginRedactedSummaryExport(payload, result)
                }
                else -> result.notImplemented()
            }
        }

        val routeReader = TripRouteReader(AtomicFileTelemetryChunkStore(applicationContext))
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MapDataContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                MapDataContract.LOAD_TRIP_ROUTE -> {
                    val tripId = call.argument<String>("tripId")
                    routeExecutor.execute {
                        val payload = routeReader.read(tripId).toBridgeMap()
                        runOnUiThread {
                            if (!isDestroyed) result.success(payload)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun beginTripDebugExport(
        tripId: String?,
        result: MethodChannel.Result,
    ) {
        if (pendingTripDebugResult != null || pendingRedactedSummaryResult != null) {
            result.success(tripDebugExportFailureMap(tripId, "export_in_progress"))
            return
        }
        if (tripId == null) {
            result.success(tripDebugExportFailureMap(null, "export_invalid_trip_id"))
            return
        }
        val lifecycle = RecorderService.queryState(applicationContext)
        if (lifecycle.isActive) {
            result.success(tripDebugExportFailureMap(tripId, "export_recorder_active"))
            return
        }
        if (AtomicRecorderFinalizationStore(applicationContext).load(tripId) != null) {
            result.success(tripDebugExportFailureMap(tripId, "export_finalization_pending"))
            return
        }
        pendingTripDebugResult = result
        pendingTripDebugTripId = tripId
        tripDebugExecutor.execute {
            val preparation = TripDebugArchiveExporter(applicationContext).prepare(tripId)
            runOnUiThread {
                if (pendingTripDebugResult == null || isDestroyed) {
                    if (preparation is TripDebugPreparationResult.Success) {
                        preparation.prepared.deleteTemporaryFile()
                    }
                    return@runOnUiThread
                }
                when (preparation) {
                    is TripDebugPreparationResult.Failure -> {
                        pendingTripDebugResult?.success(
                            tripDebugExportFailureMap(tripId, preparation.errorCode),
                        )
                        pendingTripDebugResult = null
                        pendingTripDebugTripId = null
                    }
                    is TripDebugPreparationResult.Success -> {
                        preparedTripDebugExport = preparation.prepared
                        val intent =
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, preparation.prepared.suggestedFileName)
                            }
                        try {
                            startActivityForResult(intent, TRIPDEBUG_EXPORT_REQUEST_CODE)
                        } catch (_: Exception) {
                            completeTripDebugExport(false, "export_picker_unavailable")
                        }
                    }
                }
            }
        }
    }

    @Deprecated("Deprecated in Android platform API; retained for FlutterActivity compatibility")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REDACTED_SUMMARY_EXPORT_REQUEST_CODE) {
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                completeRedactedSummaryExport(false, "export_cancelled")
                return
            }
            val target = requireNotNull(data.data)
            val bytes = preparedRedactedSummary
            if (bytes == null) {
                completeRedactedSummaryExport(false, "export_preparation_missing")
                return
            }
            dataManagementExecutor.execute {
                val written = runCatching {
                    contentResolver.openOutputStream(target, "w")?.use { it.write(bytes) } != null
                }.getOrDefault(false)
                runOnUiThread {
                    completeRedactedSummaryExport(
                        exported = written,
                        errorCode = if (written) null else "export_write_failed",
                    )
                }
            }
            return
        }
        if (requestCode != TRIPDEBUG_EXPORT_REQUEST_CODE) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            completeTripDebugExport(false, "export_cancelled")
            return
        }
        val target = requireNotNull(data.data)
        val prepared = preparedTripDebugExport
        if (prepared == null) {
            completeTripDebugExport(false, "export_preparation_missing")
            return
        }
        tripDebugExecutor.execute {
            val written =
                runCatching {
                    contentResolver.openOutputStream(target, "w")?.use(prepared::copyTo) != null
                }.getOrDefault(false)
            runOnUiThread {
                completeTripDebugExport(
                    exported = written,
                    errorCode = if (written) null else "export_write_failed",
                )
            }
        }
    }

    private fun completeTripDebugExport(
        exported: Boolean,
        errorCode: String?,
    ) {
        val prepared = preparedTripDebugExport
        val payload =
            if (prepared != null) {
                prepared.inspection.toBridgeMap(exported = exported, errorCode = errorCode)
            } else {
                tripDebugExportFailureMap(pendingTripDebugTripId, errorCode ?: "export_failed")
            }
        pendingTripDebugResult?.success(payload)
        pendingTripDebugResult = null
        pendingTripDebugTripId = null
        prepared?.deleteTemporaryFile()
        preparedTripDebugExport = null
    }

    private fun deleteRawTelemetry(
        tripId: String?,
        result: MethodChannel.Result,
    ) {
        if (tripId == null) {
            result.success(rawTelemetryDeletionMap(null, false, 0L, "raw_delete_invalid_trip_id"))
            return
        }
        if (RecorderService.queryState(applicationContext).isActive) {
            result.success(rawTelemetryDeletionMap(tripId, false, 0L, "raw_delete_recorder_active"))
            return
        }
        if (AtomicRecorderFinalizationStore(applicationContext).load(tripId) != null) {
            result.success(rawTelemetryDeletionMap(tripId, false, 0L, "raw_delete_finalization_pending"))
            return
        }
        dataManagementExecutor.execute {
            val payload = when (
                val deletion = AtomicFileTelemetryChunkStore(applicationContext)
                    .deleteTripRawTelemetry(tripId)
            ) {
                is RawTelemetryDeletionResult.Success ->
                    rawTelemetryDeletionMap(tripId, true, deletion.bytesDeleted, null)
                is RawTelemetryDeletionResult.Failure ->
                    rawTelemetryDeletionMap(tripId, false, 0L, deletion.errorCode)
            }
            runOnUiThread {
                if (!isDestroyed) result.success(payload)
            }
        }
    }

    private fun beginRedactedSummaryExport(
        payload: RedactedTripSummaryPayload?,
        result: MethodChannel.Result,
    ) {
        if (pendingTripDebugResult != null || pendingRedactedSummaryResult != null) {
            result.success(redactedSummaryExportMap(false, 0L, "export_in_progress"))
            return
        }
        if (payload == null) {
            result.success(redactedSummaryExportMap(false, 0L, "export_payload_invalid"))
            return
        }
        preparedRedactedSummary = payload.encode()
        pendingRedactedSummaryResult = result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, "traelyx-redacted-trip-summary.json")
        }
        try {
            startActivityForResult(intent, REDACTED_SUMMARY_EXPORT_REQUEST_CODE)
        } catch (_: Exception) {
            completeRedactedSummaryExport(false, "export_picker_unavailable")
        }
    }

    private fun completeRedactedSummaryExport(
        exported: Boolean,
        errorCode: String?,
    ) {
        val byteLength = preparedRedactedSummary?.size?.toLong() ?: 0L
        pendingRedactedSummaryResult?.success(
            redactedSummaryExportMap(exported, byteLength, errorCode),
        )
        pendingRedactedSummaryResult = null
        preparedRedactedSummary = null
    }

    override fun onDestroy() {
        runCatching {
            pendingTripDebugResult?.success(
                tripDebugExportFailureMap(pendingTripDebugTripId, "export_activity_destroyed"),
            )
        }
        pendingTripDebugResult = null
        pendingTripDebugTripId = null
        preparedTripDebugExport?.deleteTemporaryFile()
        preparedTripDebugExport = null
        runCatching {
            pendingRedactedSummaryResult?.success(
                redactedSummaryExportMap(false, 0L, "export_activity_destroyed"),
            )
        }
        pendingRedactedSummaryResult = null
        preparedRedactedSummary = null
        tripDebugExecutor.shutdownNow()
        dataManagementExecutor.shutdownNow()
        routeExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun requestLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error("permission_request_in_progress", null, null)
            return
        }
        val snapshot = permissionGateway.snapshot()
        if (!snapshot.canRequestLocation) {
            result.success(snapshot.toMap())
            return
        }
        pendingLocationResult = result
        permissionGateway.markLocationRequestStarted()
        requestPermissions(
            AndroidRecorderPermissionGateway.LOCATION_PERMISSIONS,
            LOCATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun requestNotification(result: MethodChannel.Result) {
        if (pendingNotificationResult != null) {
            result.error("permission_request_in_progress", null, null)
            return
        }
        val snapshot = permissionGateway.snapshot()
        if (!snapshot.canRequestNotification || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(snapshot.toMap())
            return
        }
        pendingNotificationResult = result
        permissionGateway.markNotificationRequestStarted()
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                pendingLocationResult?.success(permissionGateway.snapshot().toMap())
                pendingLocationResult = null
            }
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                pendingNotificationResult?.success(permissionGateway.snapshot().toMap())
                pendingNotificationResult = null
            }
        }
    }

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 7302
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7303
        private const val TRIPDEBUG_EXPORT_REQUEST_CODE = 7308
        private const val REDACTED_SUMMARY_EXPORT_REQUEST_CODE = 7309
    }
}
