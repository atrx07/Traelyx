package io.github.atrx07.traelyx.guardian

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.github.atrx07.traelyx.MainActivity
import io.github.atrx07.traelyx.R

/** No account, event kind, telemetry or credential appears in the visible notification. */
class AndroidGuardianCancellationNotice(context: Context) : GuardianCancellationNotice {
    private val app = context.applicationContext
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val submitted = mutableSetOf<GuardianEventReference>()
    private var channelEnsured = false

    override fun available(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return false
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26) {
            if (!channelEnsured) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL, "Guardian pending alerts",
                    NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Local experimental alert cancellation. No driver or trip details."
                })
                channelEnsured = true
            }
            if (manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    override fun show(reference: GuardianEventReference, expiresAfterMillis: Long): Boolean {
        require(expiresAfterMillis in 1..GuardianPendingAlert.TTL_MILLIS)
        if (!available()) return false
        if (present(reference)) return true
        // A dismissed/unobserved submission never becomes a repeated notification loop.
        if (!submitted.add(reference)) return false
        val cancel = PendingIntent.getBroadcast(app, 0,
            Intent(app, GuardianCancelAlertReceiver::class.java).setAction(CANCEL)
                .setData(Uri.Builder().scheme("traelyx-guardian-cancel").authority("local")
                    .appendPath(reference.ownerId).appendPath(reference.activationId).appendPath(reference.eventId).build()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(app, 0, Intent(app, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW).setData(Uri.parse("io.github.atrx07.traelyx://guardian-notice/")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(app, CHANNEL)
            else Notification.Builder(app).setPriority(Notification.PRIORITY_HIGH)
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(expiresAfterMillis)
        manager.notify(tag(reference), 0, builder.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Guardian alert pending")
            .setContentText("Experimental alert. Cancel before sending, or open Traelyx.")
            .setContentIntent(open).setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setOnlyAlertOnce(true).setShowWhen(false)
            .setAutoCancel(false).addAction(Notification.Action.Builder(null, "Cancel alert", cancel).build()).build())
        return present(reference)
    }

    override fun remove(reference: GuardianEventReference) {
        submitted.remove(reference)
        manager.cancel(tag(reference), 0)
    }
    override fun present(reference: GuardianEventReference) = manager.activeNotifications.any { it.tag == tag(reference) && it.id == 0 }
    private fun tag(ref: GuardianEventReference) = "guardian-pending:${ref.ownerId}:${ref.activationId}:${ref.eventId}"

    companion object {
        const val CHANNEL = "traelyx_guardian_pending_v1"
        const val CANCEL = "io.github.atrx07.traelyx.CANCEL_GUARDIAN_ALERT"
        fun parse(intent: Intent): GuardianEventReference? = runCatching {
            require(intent.action == CANCEL && intent.extras == null)
            val data = requireNotNull(intent.data)
            require(data.scheme == "traelyx-guardian-cancel" && data.authority == "local" &&
                data.query == null && data.fragment == null && data.pathSegments.size == 3)
            GuardianEventReference(data.pathSegments[0], data.pathSegments[1], data.pathSegments[2])
        }.getOrNull()
    }
}

/** Explicit immutable app-owned PendingIntent only; manifest export is false. */
class GuardianCancelAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reference = AndroidGuardianCancellationNotice.parse(intent) ?: return
        val pending = goAsync()
        try {
            AndroidGuardianActivationRuntime.cancelEvent(context, reference) { pending.finish() }
        } catch (_: Exception) { pending.finish() }
    }
}
