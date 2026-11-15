package io.github.atrx07.traelyx.data

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.atomic.AtomicBoolean

class CorrectionContributionExporter(
    private val activity: Activity,
    private val executor: ExecutorService,
    private val channel: MethodChannel,
    private val isIdle: () -> Boolean,
    private val otherExportPending: () -> Boolean,
) {
    private var pending: MethodChannel.Result? = null
    private var prepared: ByteArray? = null
    @Volatile private var authorizationId: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var timeout: Runnable? = null
    private val closed = AtomicBoolean(false)
    val busy: Boolean get() = pending != null

    fun begin(arguments: Any?, result: MethodChannel.Result) {
        if (closed.get() || busy || otherExportPending()) {
            result.success(correctionExportResult(false, 0, "export_in_progress"))
            return
        }
        val envelope = arguments as? Map<*, *>
        val id = envelope?.get("authorizationId") as? String
        val payload = CorrectionContributionPayload.fromMap(envelope?.get("payload") as? Map<*, *>)
        if (envelope?.keys != setOf("authorizationId", "payload") ||
            id == null || !id.matches(Regex("[0-9]{1,20}")) || payload == null || !idle()) {
            result.success(correctionExportResult(false, 0, if (payload == null) "export_payload_invalid" else "recorder_not_idle"))
            return
        }
        pending = result
        prepared = payload.encode()
        authorizationId = id
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                putExtra(Intent.EXTRA_TITLE, "traelyx-event-corrections.json")
            }, REQUEST_CODE)
        } catch (_: Exception) {
            finish(false, "export_picker_unavailable")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        if (pending == null) return true
        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            finish(false, "export_cancelled")
            return true
        }
        val bytes = prepared
        val id = authorizationId
        if (closed.get() || bytes == null || id == null || !idle()) {
            finish(false, "recorder_not_idle")
            return true
        }
        val deadline = Runnable {
            if (authorizationId == id) finish(false, "export_authorization_failed")
        }
        timeout = deadline
        handler.postDelayed(deadline, 5000)
        try {
            channel.invokeMethod("authorizeContribution", id, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (authorizationId != id || closed.get()) return
                    handler.removeCallbacks(deadline)
                    timeout = null
                    if (result != true || !idle()) {
                        finish(false, "export_authorization_failed")
                        return
                    }
                    try {
                        executor.execute {
                            val written = !closed.get() && authorizationId == id && idle() && runCatching {
                                activity.contentResolver.openOutputStream(target, "w")?.use { it.write(bytes) } != null
                            }.getOrDefault(false)
                            activity.runOnUiThread {
                                if (authorizationId == id) finish(written, if (written) null else "export_write_failed")
                            }
                        }
                    } catch (_: Exception) {
                        finish(false, "export_write_failed")
                    }
                }
                override fun error(code: String, message: String?, details: Any?) = denied()
                override fun notImplemented() = denied()
                private fun denied() {
                    if (authorizationId == id) finish(false, "export_authorization_failed")
                }
            })
        } catch (_: Exception) {
            finish(false, "export_authorization_failed")
        }
        return true
    }

    private fun idle(): Boolean = runCatching(isIdle).getOrDefault(false)

    private fun finish(exported: Boolean, error: String?) {
        val result = pending ?: return
        val size = prepared?.size ?: 0
        pending = null
        prepared = null
        authorizationId = null
        timeout?.let(handler::removeCallbacks)
        timeout = null
        runCatching {
            result.success(correctionExportResult(exported && !closed.get(), if (exported && !closed.get()) size else 0,
                if (closed.get()) "export_activity_destroyed" else error))
        }
    }

    fun close() {
        closed.set(true)
        finish(false, "export_activity_destroyed")
    }

    companion object {
        const val CHANNEL = "io.github.atrx07.traelyx/event_corrections/v1"
        private const val REQUEST_CODE = 7310
    }
}
