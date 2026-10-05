package io.github.atrx07.traelyx.guardian

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.github.atrx07.traelyx.MainActivity
import io.github.atrx07.traelyx.R

/** Data-only ingress; never trusts FCM acceptance as recipient permission. */
class GuardianFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        // An unconfigured build cannot acknowledge or display Guardian messages.
        val endpoint = getString(R.string.traelyx_guardian_capability_url)
        if (endpoint.isEmpty() || !notificationsAllowed()) return
        try {
            val vault = AndroidGuardianRecipientVault(applicationContext)
            val marker = AndroidGuardianProviderMarker(applicationContext)
            val handler = GuardianIncomingMessageHandler(
                GuardianPushPreflight(
                    vault,
                    marker,
                    System::currentTimeMillis,
                ),
                GuardianCapabilityReceiptGateway(endpoint, BoundedGuardianHttpsTransport()),
                GuardianNoticeClaim { request, generation ->
                    marker.present() && vault.claimNotice(
                        request.deviceId, generation, request.credential, request.deliveryId, System.currentTimeMillis(),
                    )
                },
                GuardianGenericNotice(::postGenericNotice),
            )
            handler.handle(message.data, message.notification != null)
        } catch (_: Exception) {
            // Missing keys, local uncertainty, and network failure show no notice.
        }
    }

    private fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    private fun postGenericNotice(deliveryId: String) {
        if (!notificationsAllowed()) return
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "Guardian notices", NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Private Guardian notices with no driver or trip details." })
        }
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.parse("io.github.atrx07.traelyx://guardian-notice/")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }
        manager.notify(deliveryId, 0, builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Traelyx Guardian notice")
            .setContentText("Open Traelyx to check a private notice.")
            .setContentIntent(openApp)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build())
    }

    private companion object { const val CHANNEL_ID = "traelyx_guardian_notices_v1" }
}
