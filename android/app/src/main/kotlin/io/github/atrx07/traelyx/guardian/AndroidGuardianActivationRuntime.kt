package io.github.atrx07.traelyx.guardian

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import io.github.atrx07.traelyx.R
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/** A single worker serializes account binding and all encrypted-vault operations across Activity recreation. */
object AndroidGuardianActivationRuntime {
    private val worker = guardianControlExecutor()
    private var bridge: GuardianActivationBridge? = null
    private var coordinator: GuardianActivationCoordinator? = null
    private var recording: GuardianRecordingSession? = null
    private var recordingWatchdog: ScheduledFuture<*>? = null
    private var cancellation: GuardianCancellationControls? = null
    private var alertSchedule: GuardianDispatchSchedule? = null

    // Existing review explicitly says sending is unavailable. No build define,
    // restored lease or receiver registration can bypass this consent gate.
    private const val SENDING_AVAILABLE = false

    fun dispatch(context: Context, method: String, arguments: Any?, complete: (Result<Any?>) -> Unit) {
        val app = context.applicationContext
        worker.execute {
            val result = runCatching {
                val current = bridge ?: GuardianActivationBridge(coordinator(app),
                    recordingObservation = { recording?.observation() ?: GuardianRecordingObservation() },
                    pendingAlerts = { controls(app).views(it) },
                    cancelAlert = { controls(app).cancel(it) }).also { bridge = it }
                val args = arguments as? Map<*, *>
                val owner = args?.get("ownerId") as? String
                val ownerChanges = method == GuardianActivationBridge.BIND_OWNER && !coordinator(app).isBoundTo(owner)
                val changesCurrent = coordinator(app).isBoundTo(owner) && method in setOf(
                    GuardianActivationBridge.BEGIN, GuardianActivationBridge.STOP, GuardianActivationBridge.DISABLE)
                val abortsCurrent = method == GuardianActivationBridge.ABORT &&
                    coordinator(app).isCurrentActivation(owner, args?.get("activationId") as? String)
                if (ownerChanges || changesCurrent || abortsCurrent) {
                    invalidateAlerts()
                }
                try { current.dispatch(method, arguments) } finally {
                    recording?.refresh()
                    refreshAlerts(app)
                    syncRecordingWatchdog()
                }
            }
            complete(result)
        }
    }

    /** Returns immediately; no Keystore/disk/evaluator operation runs on the service thread. */
    fun startRecording(context: Context): GuardianRecorderHandle {
        val handle = GuardianRecorderHandle()
        val app = context.applicationContext
        try {
            worker.execute {
                try {
                    val session = recording ?: GuardianRecordingSession(
                        authority = { coordinator(app).recordingSnapshot() },
                        clock = { clock(app) },
                        enqueue = { lease, detection, cooldowns, now ->
                            AndroidGuardianVault.outbox(app).enqueue(lease.ownerId, lease.activationId,
                                detection, cooldowns, now)
                            schedule(app).refresh()
                        },
                        revoke = { invalidateAlerts(); coordinator(app).disable(it); refreshAlerts(app) },
                        post = { worker.execute(it) },
                    ).also { recording = it }
                    session.start(handle)
                    syncRecordingWatchdog()
                } catch (_: Exception) { handle.close() }
            }
        } catch (_: Exception) { handle.close() }
        return handle
    }

    fun stopRecording(handle: GuardianRecorderHandle) {
        handle.close() // Acquisition forwarding stops before asynchronous worker shutdown.
        try { worker.execute { recording?.stop(handle); syncRecordingWatchdog() } } catch (_: Exception) { }
    }

    private fun syncRecordingWatchdog() {
        if (recording?.isEvaluating != true) {
            recordingWatchdog?.cancel(false)
            recordingWatchdog = null
        } else if (recordingWatchdog == null) {
            recordingWatchdog = worker.scheduleWithFixedDelay({
                recording?.tick()
                syncRecordingWatchdog()
            }, 1, 1, TimeUnit.SECONDS)
        }
    }

    private fun coordinator(context: Context): GuardianActivationCoordinator = coordinator ?:
        GuardianActivationCoordinator(AndroidGuardianVault.outbox(context), { clock(context) },
            AndroidGuardianDriverRevokeJournal(context))
            .also { coordinator = it }

    private fun controls(context: Context): GuardianCancellationControls = cancellation ?:
        GuardianCancellationControls(AndroidGuardianVault.outbox(context), { coordinator(context).recordingSnapshot() },
            { clock(context) }, AndroidGuardianCancellationNotice(context)).also { cancellation = it }

    private fun schedule(context: Context): GuardianDispatchSchedule = alertSchedule ?:
        GuardianDispatchSchedule(controls(context), { clock(context) }, { SENDING_AVAILABLE },
            createDispatch = { post ->
                GuardianOutboxDispatchCoordinator(AndroidGuardianVault.outbox(context),
                    { coordinator(context).recordingSnapshot() }, { clock(context) }, { SENDING_AVAILABLE },
                    { controls(context).allows(it) },
                    GuardianIngestWorker(GuardianCapabilityIngestGateway(
                        context.getString(R.string.traelyx_guardian_capability_url),
                        BoundedGuardianHttpsTransport(), { clock(context) })), post)
            }, postControl = { worker.execute(it) },
            schedule = { delay, action ->
                val future = worker.schedule(action, delay, TimeUnit.MILLISECONDS)
                GuardianScheduledWake { future.cancel(false) }
            }).also { alertSchedule = it }

    private fun invalidateAlerts() {
        if (alertSchedule != null) alertSchedule?.invalidate() else cancellation?.invalidate()
    }

    private fun refreshAlerts(context: Context) {
        if (cancellation != null) schedule(context).refresh()
    }

    fun cancelEvent(context: Context, reference: GuardianEventReference, complete: () -> Unit) {
        val app = context.applicationContext
        try {
            worker.execute {
                try { controls(app).cancel(reference) } finally {
                    try { refreshAlerts(app) } finally { complete() }
                }
            }
        } catch (_: Exception) { complete() }
    }

    private fun clock(context: Context): GuardianClock {
        // Without a readable boot count, no lease may be recovered or activated.
        val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
        check(boot >= 0)
        return GuardianClock(System.currentTimeMillis(), SystemClock.elapsedRealtime(), "boot:$boot")
    }
}
