package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

const val RECORDER_PERMISSION_CONTRACT_VERSION = 1

enum class RecorderPermissionState(val wireName: String) {
    GRANTED("granted"),
    APPROXIMATE_ONLY("approximate_only"),
    REQUESTABLE("requestable"),
    SETTINGS_REQUIRED("settings_required"),
    NOT_REQUIRED("not_required"),
}

data class RecorderPermissionInputs(
    val platformApiLevel: Int,
    val fineLocationGranted: Boolean,
    val coarseLocationGranted: Boolean,
    val notificationGranted: Boolean,
    val gpsProviderEnabled: Boolean,
    val locationRequestAttempts: Int,
    val notificationRequestedBefore: Boolean,
    val showLocationRationale: Boolean,
    val showNotificationRationale: Boolean,
) {
    init {
        require(platformApiLevel > 0)
        require(locationRequestAttempts >= 0)
    }
}

data class RecorderPermissionSnapshot(
    val contractVersion: Int = RECORDER_PERMISSION_CONTRACT_VERSION,
    val platformApiLevel: Int,
    val locationState: RecorderPermissionState,
    val notificationState: RecorderPermissionState,
    val fineLocationGranted: Boolean,
    val coarseLocationGranted: Boolean,
    val gpsProviderEnabled: Boolean,
    val canRequestLocation: Boolean,
    val canRequestNotification: Boolean,
    val backgroundLocationRequired: Boolean = false,
) {
    val recordingReady: Boolean
        get() = fineLocationGranted && gpsProviderEnabled

    val foregroundNotificationVisible: Boolean
        get() =
            notificationState == RecorderPermissionState.GRANTED ||
                notificationState == RecorderPermissionState.NOT_REQUIRED

    fun toMap(): Map<String, Any> =
        linkedMapOf(
            "contractVersion" to contractVersion,
            "platformApiLevel" to platformApiLevel,
            "locationState" to locationState.wireName,
            "notificationState" to notificationState.wireName,
            "fineLocationGranted" to fineLocationGranted,
            "coarseLocationGranted" to coarseLocationGranted,
            "gpsProviderEnabled" to gpsProviderEnabled,
            "canRequestLocation" to canRequestLocation,
            "canRequestNotification" to canRequestNotification,
            "backgroundLocationRequired" to backgroundLocationRequired,
            "recordingReady" to recordingReady,
            "foregroundNotificationVisible" to foregroundNotificationVisible,
        )
}

object RecorderPermissionEvaluator {
    fun evaluate(inputs: RecorderPermissionInputs): RecorderPermissionSnapshot {
        val canRequestLocation =
            when {
                inputs.fineLocationGranted -> false
                inputs.coarseLocationGranted ->
                    inputs.locationRequestAttempts < MAX_LOCATION_REQUEST_ATTEMPTS ||
                        inputs.showLocationRationale
                else ->
                    inputs.locationRequestAttempts == 0 || inputs.showLocationRationale
            }
        val locationState =
            when {
                inputs.fineLocationGranted -> RecorderPermissionState.GRANTED
                inputs.coarseLocationGranted -> RecorderPermissionState.APPROXIMATE_ONLY
                canRequestLocation -> RecorderPermissionState.REQUESTABLE
                else -> RecorderPermissionState.SETTINGS_REQUIRED
            }

        val notificationRequired = inputs.platformApiLevel >= Build.VERSION_CODES.TIRAMISU
        val canRequestNotification =
            notificationRequired &&
                !inputs.notificationGranted &&
                (!inputs.notificationRequestedBefore || inputs.showNotificationRationale)
        val notificationState =
            when {
                !notificationRequired -> RecorderPermissionState.NOT_REQUIRED
                inputs.notificationGranted -> RecorderPermissionState.GRANTED
                canRequestNotification -> RecorderPermissionState.REQUESTABLE
                else -> RecorderPermissionState.SETTINGS_REQUIRED
            }

        return RecorderPermissionSnapshot(
            platformApiLevel = inputs.platformApiLevel,
            locationState = locationState,
            notificationState = notificationState,
            fineLocationGranted = inputs.fineLocationGranted,
            coarseLocationGranted = inputs.coarseLocationGranted,
            gpsProviderEnabled = inputs.gpsProviderEnabled,
            canRequestLocation = canRequestLocation,
            canRequestNotification = canRequestNotification,
        )
    }

    private const val MAX_LOCATION_REQUEST_ATTEMPTS = 2
}

class AndroidRecorderPermissionGateway(private val activity: Activity) {
    private val preferences =
        activity.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun snapshot(): RecorderPermissionSnapshot =
        RecorderPermissionEvaluator.evaluate(
            RecorderPermissionInputs(
                platformApiLevel = Build.VERSION.SDK_INT,
                fineLocationGranted = activity.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION),
                coarseLocationGranted =
                    activity.hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION),
                notificationGranted =
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        activity.hasPermission(Manifest.permission.POST_NOTIFICATIONS),
                gpsProviderEnabled = isGpsProviderEnabled(),
                locationRequestAttempts =
                    preferences.getInt(KEY_LOCATION_REQUEST_ATTEMPTS, 0),
                notificationRequestedBefore =
                    preferences.getBoolean(KEY_NOTIFICATION_REQUESTED, false),
                showLocationRationale =
                    activity.shouldShowRequestPermissionRationale(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                    ),
                showNotificationRationale =
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        activity.shouldShowRequestPermissionRationale(
                            Manifest.permission.POST_NOTIFICATIONS,
                        ),
            ),
        )

    fun markLocationRequestStarted() {
        val attempts = preferences.getInt(KEY_LOCATION_REQUEST_ATTEMPTS, 0)
        preferences.edit().putInt(KEY_LOCATION_REQUEST_ATTEMPTS, attempts + 1).apply()
    }

    fun markNotificationRequestStarted() {
        preferences.edit().putBoolean(KEY_NOTIFICATION_REQUESTED, true).apply()
    }

    fun openAppSettings() {
        activity.startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", activity.packageName, null),
            ),
        )
    }

    fun openLocationSettings() {
        activity.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
    }

    private fun isGpsProviderEnabled(): Boolean =
        try {
            activity.getSystemService(LocationManager::class.java)
                .isProviderEnabled(LocationManager.GPS_PROVIDER)
        } catch (_: RuntimeException) {
            false
        }

    private fun Context.hasPermission(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        val LOCATION_PERMISSIONS =
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )

        private const val PREFERENCES_NAME = "recorder_permission_onboarding_v1"
        private const val KEY_LOCATION_REQUEST_ATTEMPTS = "location_request_attempts"
        private const val KEY_NOTIFICATION_REQUESTED = "notification_requested"
    }
}

internal fun isPlatformRecordingReady(context: Context): Boolean {
    val fineGranted =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    val gpsEnabled =
        try {
            context.getSystemService(LocationManager::class.java)
                .isProviderEnabled(LocationManager.GPS_PROVIDER)
        } catch (_: RuntimeException) {
            false
        }
    return fineGranted && gpsEnabled
}
