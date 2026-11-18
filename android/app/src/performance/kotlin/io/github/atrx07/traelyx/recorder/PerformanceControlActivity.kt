package io.github.atrx07.traelyx.recorder

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File
import org.json.JSONObject

/** Shell/DUMP-protected entrypoint present only in the isolated profile QA APK. */
class PerformanceControlActivity : Activity() {
    private lateinit var status: TextView
    private val handler = Handler(Looper.getMainLooper())
    private val refresh = object : Runnable {
        override fun run() {
            renderStatus()
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        check(packageName == "io.github.atrx07.traelyx.hardening")
        status = TextView(this).apply { textSize = 20f; setPadding(30, 45, 30, 30) }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(status)
            addView(Button(this@PerformanceControlActivity).apply {
                text = "Cancel this QA test"
                setOnClickListener { startService(Intent(this@PerformanceControlActivity,
                    PerformanceControlService::class.java).setAction(PerformanceControlService.CANCEL)) }
            })
        })
        if (intent.action == PerformanceControlService.START) {
            val start = Intent(this, PerformanceControlService::class.java)
                .setAction(PerformanceControlService.START)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(start) else startService(start)
            status.text = "Preparing isolated QA recorder. Keep USB connected until Codex confirms readiness."
        } else if (intent.action == PerformanceControlService.CANCEL) {
            startService(Intent(this, PerformanceControlService::class.java).setAction(PerformanceControlService.CANCEL))
        }
    }

    override fun onResume() {
        super.onResume()
        refresh.run()
    }

    override fun onPause() {
        handler.removeCallbacks(refresh)
        super.onPause()
    }

    private fun renderStatus() {
        val stage = runCatching { JSONObject(File(noBackupFilesDir,
            "performance-progress-v1.json").readText()).getString("stage") }.getOrDefault("preparing")
        val message = when (stage) {
            "ready_to_unplug_and_lock" -> "Ready. When Codex confirms: unplug USB, press Power once to lock, then leave the phone unused for about 15 minutes. A QA notification remains."
            "complete" -> "QA finished. Reconnect USB for result verification."
            "failed" -> "QA stopped without a valid pass. Reconnect USB for inspection."
            else -> "Isolated QA status: $stage. Keep the phone unused while measuring."
        }
        if (status.text.toString() != message) status.text = message
    }
}
