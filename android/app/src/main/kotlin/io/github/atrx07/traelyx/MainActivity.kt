package io.github.atrx07.traelyx

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.github.atrx07.traelyx.diagnostics.DiagnosticsContract
import io.github.atrx07.traelyx.diagnostics.DiagnosticsSnapshotCollector
import io.github.atrx07.traelyx.recorder.RecorderContract
import io.github.atrx07.traelyx.recorder.RecorderService

class MainActivity : FlutterActivity() {
    override fun onPostResume() {
        super.onPostResume()
        RecorderService.requestRecovery(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RecorderContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                RecorderContract.GET_CAPABILITIES -> result.success(
                    mapOf(
                        "bridgeVersion" to RecorderContract.BRIDGE_VERSION,
                        "implementationState" to "lifecycle_ready",
                        "recordingAvailable" to false,
                        "serviceRegistered" to true,
                    ),
                )
                RecorderContract.GET_STATE -> result.success(
                    RecorderService.queryState(applicationContext).toMap(),
                )
                RecorderContract.START_TRIP -> result.success(
                    RecorderService.requestStart(applicationContext).toMap(),
                )
                RecorderContract.STOP_TRIP -> result.success(
                    RecorderService.requestStop(applicationContext).toMap(),
                )
                else -> result.notImplemented()
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
}
