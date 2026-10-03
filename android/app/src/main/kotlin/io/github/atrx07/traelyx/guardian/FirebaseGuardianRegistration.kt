package io.github.atrx07.traelyx.guardian

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.installations.FirebaseInstallations
import com.google.firebase.messaging.FirebaseMessaging
import io.github.atrx07.traelyx.R

/** One process-wide coordinator; obtaining it does not initialize Firebase or register a device. */
object FirebaseGuardianRegistration {
    private var instance: GuardianPushRegistration? = null
    @Synchronized fun get(context: Context): GuardianPushRegistration = instance
        ?: MarkedGuardianPushRegistration(
            AndroidGuardianProviderMarker(context.applicationContext),
            ConsentBoundGuardianRegistration(FirebaseRegistrationBackend(context.applicationContext)),
        ).also { instance = it }
}

private class FirebaseRegistrationBackend(private val context: Context) : GuardianRegistrationBackend {
    override val configured get() = context.getString(R.string.traelyx_firebase_app_id).isNotEmpty()

    private fun app(): FirebaseApp {
        check(configured) { "Guardian push provider is not configured" }
        val app = FirebaseApp.getApps(context).firstOrNull { it.name == FirebaseApp.DEFAULT_APP_NAME }
            ?: requireNotNull(FirebaseApp.initializeApp(context, FirebaseOptions.Builder()
                .setApplicationId(context.getString(R.string.traelyx_firebase_app_id))
                .setProjectId(context.getString(R.string.traelyx_firebase_project_id))
                .setGcmSenderId(context.getString(R.string.traelyx_firebase_sender_id))
                .setApiKey(context.getString(R.string.traelyx_firebase_client_key))
                .build()))
        app.setDataCollectionDefaultEnabled(false)
        return app
    }

    override fun unavailableReason(): String? {
        if (!context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()) {
            return "notification_permission_required"
        }
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return "notification_permission_required"
        }
        if (GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(context) != ConnectionResult.SUCCESS) {
            return "play_services_unavailable"
        }
        return null
    }

    override fun acquire(complete: (String?) -> Unit) {
        app()
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = false
        messaging.setDeliveryMetricsExportToBigQuery(false)
        messaging.token.addOnCompleteListener { complete(if (it.isSuccessful) it.result else null) }
    }

    override fun delete(complete: (Boolean) -> Unit) {
        // A durable marker can outlive this process. Initialize only for explicit cleanup,
        // then delete the prior installation even when auto-init has stayed disabled.
        app()
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = false
        messaging.deleteToken().addOnCompleteListener { tokenDeletion ->
            FirebaseInstallations.getInstance().delete().addOnCompleteListener { installationDeletion ->
                complete(tokenDeletion.isSuccessful && installationDeletion.isSuccessful)
            }
        }
    }
}
