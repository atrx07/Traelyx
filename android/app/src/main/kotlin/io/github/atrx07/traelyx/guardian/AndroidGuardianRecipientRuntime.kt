package io.github.atrx07.traelyx.guardian

import android.content.Context
import java.util.concurrent.Executors

/** A single worker serializes recipient binding, persistence and erasure across Activity recreation. */
object AndroidGuardianRecipientRuntime {
    private val worker = Executors.newSingleThreadExecutor()
    private var bridge: GuardianRecipientBridge? = null

    fun dispatch(context: Context, method: String, arguments: Any?, complete: (Result<Any?>) -> Unit) {
        val app = context.applicationContext
        worker.execute {
            val result = runCatching {
                val current = bridge ?: GuardianRecipientBridge(
                    GuardianRecipientCoordinator(AndroidGuardianRecipientVault(app), System::currentTimeMillis),
                ).also { bridge = it }
                current.dispatch(method, arguments)
            }
            complete(result)
        }
    }
}
