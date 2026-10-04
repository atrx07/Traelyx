package io.github.atrx07.traelyx.guardian

import android.content.Context
import java.util.concurrent.Executors

/** A single worker serializes recipient binding, persistence and erasure across Activity recreation. */
object AndroidGuardianRecipientRuntime {
    private val worker = Executors.newSingleThreadExecutor()
    private var bridge: GuardianRecipientBridge? = null

    private fun current(context: Context): GuardianRecipientBridge = bridge ?: run {
        val app = context.applicationContext
        val vault = AndroidGuardianRecipientVault(app)
        val journal = AndroidGuardianRecipientRevokeJournal(app)
        val coordinator = GuardianRecipientCoordinator(vault, journal, System::currentTimeMillis)
        val marker = AndroidGuardianProviderMarker(app)
        val ownerLifecycle = GuardianRecipientOwnerLifecycle(
            coordinator, vault, marker, FirebaseGuardianRegistration.get(app),
            System::currentTimeMillis,
        )
        GuardianRecipientBridge(coordinator, ownerLifecycle::bindOwner).also { bridge = it }
    }

    fun dispatch(context: Context, method: String, arguments: Any?, complete: (Result<Any?>) -> Unit) {
        val app = context.applicationContext
        worker.execute {
            val result = runCatching {
                current(app).dispatch(method, arguments)
            }
            complete(result)
        }
    }

    fun acquireToken(context: Context, arguments: Any?, complete: (Result<Any?>) -> Unit) {
        val app = context.applicationContext
        worker.execute {
            val acquirer = runCatching {
                GuardianRecipientTokenAcquirer(current(app), FirebaseGuardianRegistration.get(app))
            }
            acquirer.fold(
                onSuccess = { it.acquire(arguments) { outcome -> complete(outcome.map { token -> token as Any? }) } },
                onFailure = { complete(Result.failure(it)) },
            )
        }
    }
}
