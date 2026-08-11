package io.github.atrx07.traelyx

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.github.atrx07.traelyx.diagnostics.DiagnosticsContract
import io.github.atrx07.traelyx.diagnostics.DiagnosticsSnapshotCollector
import io.github.atrx07.traelyx.recorder.AndroidRecorderBridgeGateway
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatchResult
import io.github.atrx07.traelyx.recorder.RecorderBridgeDispatcher
import io.github.atrx07.traelyx.recorder.RecorderContract
import io.github.atrx07.traelyx.recorder.RecorderService

class MainActivity : FlutterActivity() {
    override fun onPostResume() {
        super.onPostResume()
        RecorderService.requestRecovery(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val recorderDispatcher =
            RecorderBridgeDispatcher(AndroidRecorderBridgeGateway(applicationContext))
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RecorderContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (val dispatched = recorderDispatcher.dispatch(call.method)) {
                is RecorderBridgeDispatchResult.Handled -> result.success(dispatched.payload)
                RecorderBridgeDispatchResult.NotImplemented -> result.notImplemented()
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
