package io.github.atrx07.traelyx.guardian

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import java.util.concurrent.Executors

/** A single worker serializes account binding and all encrypted-vault operations across Activity recreation. */
object AndroidGuardianActivationRuntime {
    private val worker = Executors.newSingleThreadExecutor()
    private var bridge: GuardianActivationBridge? = null

    fun dispatch(context: Context, method: String, arguments: Any?, complete: (Result<Any?>) -> Unit) {
        val app = context.applicationContext
        worker.execute {
            val result = runCatching {
                val current = bridge ?: GuardianActivationBridge(
                    GuardianActivationCoordinator(AndroidGuardianVault.outbox(app), { clock(app) }),
                ).also { bridge = it }
                current.dispatch(method, arguments)
            }
            complete(result)
        }
    }

    private fun clock(context: Context): GuardianClock {
        // Without a readable boot count, no lease may be recovered or activated.
        val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
        check(boot >= 0)
        return GuardianClock(System.currentTimeMillis(), SystemClock.elapsedRealtime(), "boot:$boot")
    }
}
