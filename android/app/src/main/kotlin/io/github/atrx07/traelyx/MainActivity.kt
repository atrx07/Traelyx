package io.github.atrx07.traelyx

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.github.atrx07.traelyx.diagnostics.DiagnosticsContract
import io.github.atrx07.traelyx.diagnostics.DiagnosticsSnapshotCollector
import io.github.atrx07.traelyx.recorder.RecorderContract

class MainActivity : FlutterActivity() {
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
                        "implementationState" to "skeleton",
                        "recordingAvailable" to false,
                        "serviceRegistered" to true,
                    ),
                )
                RecorderContract.GET_STATE -> result.success(
                    mapOf("state" to "unavailable"),
                )
                RecorderContract.START_TRIP,
                RecorderContract.STOP_TRIP,
                -> result.error(
                    "recorder_not_implemented",
                    "Trip recording is unavailable during bootstrap.",
                    null,
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
