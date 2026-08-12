package io.github.atrx07.traelyx

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.github.atrx07.traelyx.diagnostics.DiagnosticsContract
import io.github.atrx07.traelyx.diagnostics.DiagnosticsSnapshotCollector
import io.github.atrx07.traelyx.recorder.AndroidRecorderBridgeGateway
import io.github.atrx07.traelyx.recorder.AndroidRecorderPermissionGateway
import io.github.atrx07.traelyx.recorder.AtomicRecorderFinalizationStore
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatchResult
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatcher
import io.github.atrx07.traelyx.recorder.RecorderContract
import io.github.atrx07.traelyx.recorder.RecorderService
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
    private val tripDebugExecutor: ExecutorService = Executors.newSingleThreadExecutor()

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
    }

    private fun beginTripDebugExport(
        tripId: String?,
        result: MethodChannel.Result,
    ) {
        if (pendingTripDebugResult != null) {
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
        tripDebugExecutor.shutdownNow()
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
    }
}
