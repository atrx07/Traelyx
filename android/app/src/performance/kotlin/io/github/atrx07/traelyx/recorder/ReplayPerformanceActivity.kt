package io.github.atrx07.traelyx.recorder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

/** Dedicated profile Dart entrypoint; never invokes the ordinary app/account boot path. */
class ReplayPerformanceActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        check(packageName == "io.github.atrx07.traelyx.hardening")
        check(getString(io.github.atrx07.traelyx.R.string.traelyx_firebase_app_id).isEmpty())
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.atrx07.traelyx/performance-qa/v1").setMethodCallHandler { call, result ->
            when (call.method) {
                "temporaryDirectory" -> result.success(cacheDir.absolutePath)
                "finished" -> {
                    val report = JSONObject(call.arguments as Map<*, *>)
                    check(report.getInt("contract_version") == 1 && report.getString("build_mode") == "profile")
                    File(noBackupFilesDir, "performance-replay-v1.json").writeText(report.toString())
                    result.success(null)
                }
                "failed" -> {
                    File(noBackupFilesDir, "performance-replay-v1.json")
                        .writeText(JSONObject().put("failed", true).toString())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
