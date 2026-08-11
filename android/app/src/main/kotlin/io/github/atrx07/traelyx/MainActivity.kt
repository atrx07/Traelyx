package io.github.atrx07.traelyx

import android.Manifest
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.github.atrx07.traelyx.diagnostics.DiagnosticsContract
import io.github.atrx07.traelyx.diagnostics.DiagnosticsSnapshotCollector
import io.github.atrx07.traelyx.recorder.AndroidRecorderBridgeGateway
import io.github.atrx07.traelyx.recorder.AndroidRecorderPermissionGateway
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatchResult
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatcher
import io.github.atrx07.traelyx.recorder.RecorderContract
import io.github.atrx07.traelyx.recorder.RecorderService

class MainActivity : FlutterActivity() {
    private val permissionGateway by lazy { AndroidRecorderPermissionGateway(this) }
    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null

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
                else ->
                    when (val dispatched = recorderDispatcher.dispatch(call.method)) {
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
    }
}
