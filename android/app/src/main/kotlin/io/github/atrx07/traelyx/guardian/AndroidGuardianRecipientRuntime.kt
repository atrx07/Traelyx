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
                val current = bridge ?: run {
                    val vault = AndroidGuardianRecipientVault(app)
                    val coordinator = GuardianRecipientCoordinator(vault, System::currentTimeMillis)
                    val marker = AndroidGuardianProviderMarker(app)
                    val ownerLifecycle = GuardianRecipientOwnerLifecycle(
                        coordinator, vault, marker, FirebaseGuardianRegistration.get(app),
                        System::currentTimeMillis,
                    )
                    GuardianRecipientBridge(coordinator, ownerLifecycle::bindOwner).also { bridge = it }
                }
                current.dispatch(method, arguments)
            }
            complete(result)
        }
    }
}
