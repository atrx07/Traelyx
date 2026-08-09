package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.app.Activity
import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import io.github.atrx07.traelyx.MainActivity

class RecorderLifecycleInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
        try {
            runLifecycleProof()
            results.putString("stream", "\nM2.1 recorder lifecycle proof passed.\n")
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString(
                "stream",
                "\nM2.1 recorder lifecycle proof failed:\n${error.stackTraceToString()}\n",
            )
            finish(Activity.RESULT_CANCELED, results)
        }
    }

    private fun runLifecycleProof() {
        val context = targetContext

        try {
            check(
                context.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
                    context.hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION),
            ) {
                "Grant coarse or fine location permission before running the lifecycle proof."
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                check(context.hasPermission(Manifest.permission.POST_NOTIFICATIONS)) {
                    "Grant notification permission before running the lifecycle proof."
                }
            }
            context.stopService(Intent(context, RecorderService::class.java))
            check(AtomicRecorderRecoveryStore(context).clear()) {
                "Could not clear recorder recovery metadata before the proof."
            }

            val activity =
                startActivitySync(
                    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            waitForIdleSync()

            val accepted = RecorderService.requestStart(context)
            check(accepted.lifecycleState == RecorderLifecycleState.STARTING) {
                "Start was not accepted: ${accepted.lifecycleState.wireName}/${accepted.errorCode}"
            }
            val active = awaitState(context) { it.lifecycleState == RecorderLifecycleState.RECORDING }
            check(accepted.tripId == active.tripId) { "Active trip identity changed during start." }
            check(active.isActive) { "Recorder did not report an active lifecycle." }
            checkNotificationActive(context)

            activity.runOnUiThread(activity::recreate)
            waitForIdleSync()
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped during activity recreation."
            }

            check(context.stopService(Intent(context, RecorderService::class.java))) {
                "Android did not stop the recorder service for the recovery proof."
            }
            SystemClock.sleep(250)
            check(RecorderService.queryState(context).lifecycleState == RecorderLifecycleState.RECORDING) {
                "Stopping the service erased active-trip recovery metadata."
            }
            RecorderService.requestRecovery(context)
            val recovered =
                awaitState(context) { it.lifecycleState == RecorderLifecycleState.RECOVERED }
            check(recovered.tripId == accepted.tripId) { "Recovery changed the active trip identity." }
            check(recovered.recoveryCount == 1) { "Recovery count was not incremented once." }
            checkNotificationActive(context)

            context.startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            SystemClock.sleep(500)
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped when the app was backgrounded."
            }
            checkNotificationActive(context)

            executeShellCommand("input keyevent 223")
            SystemClock.sleep(500)
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped when the screen turned off."
            }
            checkNotificationActive(context)
            executeShellCommand("input keyevent 224")

            RecorderService.requestStop(context)
            val idle = awaitState(context) { it.lifecycleState == RecorderLifecycleState.IDLE }
            check(!idle.isActive) { "Recorder remained active after stop." }
            checkNotificationStopped(context)
        } finally {
            executeShellCommand("input keyevent 224")
            context.stopService(Intent(context, RecorderService::class.java))
            AtomicRecorderRecoveryStore(context).clear()
        }
    }

    private fun awaitState(
        context: Context,
        predicate: (RecorderStateSnapshot) -> Boolean,
    ): RecorderStateSnapshot {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryState(context)
        while (!predicate(latest) && SystemClock.uptimeMillis() < deadline) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryState(context)
        }
        check(predicate(latest)) {
            "Timed out waiting for recorder state; " +
                "latest=${latest.lifecycleState.wireName}, error=${latest.errorCode}"
        }
        return latest
    }

    private fun checkNotificationActive(context: Context) {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        val manager = context.getSystemService(NotificationManager::class.java)
        while (
            manager.activeNotifications.none { it.id == RecorderService.NOTIFICATION_ID } &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
        }
        check(manager.activeNotifications.any { it.id == RecorderService.NOTIFICATION_ID }) {
            "Recorder foreground notification was not active."
        }
    }

    private fun checkNotificationStopped(context: Context) {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        val manager = context.getSystemService(NotificationManager::class.java)
        while (
            manager.activeNotifications.any { it.id == RecorderService.NOTIFICATION_ID } &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
        }
        check(manager.activeNotifications.none { it.id == RecorderService.NOTIFICATION_ID }) {
            "Recorder foreground notification remained after stop."
        }
    }

    private fun executeShellCommand(command: String) {
        uiAutomation.executeShellCommand(command).close()
    }

    private fun Context.hasPermission(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        private const val STATE_TIMEOUT_MILLIS = 5_000L
        private const val POLL_INTERVAL_MILLIS = 50L
    }
}
