package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.HandlerThread

data class GnssAcquisitionStartResult(
    val started: Boolean,
    val errorCode: String? = null,
)

/** Native GPS-provider acquisition owned by the recorder service lifecycle. */
class AndroidGnssAcquisition(
    context: Context,
    private val tripStartedAtElapsedRealtimeNanos: Long,
    private val consumeSample: (RawGnssSample) -> Unit = {},
    publishHealth: (GnssHealthSnapshot) -> Unit = {},
) : LocationListener {
    private val applicationContext = context.applicationContext
    private val locationManager =
        applicationContext.getSystemService(LocationManager::class.java)
    private val healthTracker = GnssHealthTracker(publishHealth)
    private val lifecycleLock = Any()
    private var callbackThread: HandlerThread? = null
    private var registered = false
    private var previousSourceTimestampNanos: Long? = null

    fun start(): GnssAcquisitionStartResult =
        synchronized(lifecycleLock) {
            if (registered) return GnssAcquisitionStartResult(started = true)
            healthTracker.beginRegistration()
            if (
                applicationContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return failRegistration("fine_location_permission_missing")
            }
            if (LocationManager.GPS_PROVIDER !in locationManager.allProviders) {
                return failRegistration("gnss_provider_unavailable")
            }

            val thread = HandlerThread("traelyx-gnss-acquisition").also { it.start() }
            callbackThread = thread
            try {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    GNSS_REQUEST_INTERVAL_MILLIS,
                    0.0f,
                    this,
                    thread.looper,
                )
                registered = true
                previousSourceTimestampNanos = null
                healthTracker.registered(
                    locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER),
                )
                GnssAcquisitionStartResult(started = true)
            } catch (_: SecurityException) {
                releaseThread()
                failRegistration("gnss_permission_rejected")
            } catch (_: IllegalArgumentException) {
                releaseThread()
                failRegistration("gnss_provider_unavailable")
            } catch (_: RuntimeException) {
                releaseThread()
                failRegistration("gnss_registration_failed")
            }
        }

    fun stop() {
        synchronized(lifecycleLock) {
            if (registered) {
                try {
                    locationManager.removeUpdates(this)
                } catch (_: RuntimeException) {
                    // Removal is best-effort during teardown; the service process owns this listener.
                }
            }
            registered = false
            previousSourceTimestampNanos = null
            releaseThread()
            healthTracker.stopped()
        }
    }

    fun health(): GnssHealthSnapshot = healthTracker.current()

    override fun onLocationChanged(location: Location) {
        val reading = location.toPlatformReading()
        when (
            val result =
                GnssSampleMapper.map(
                    reading = reading,
                    tripStartedAtElapsedRealtimeNanos = tripStartedAtElapsedRealtimeNanos,
                    previousSourceTimestampNanos = previousSourceTimestampNanos,
                )
        ) {
            is GnssSampleMappingResult.Accepted -> {
                previousSourceTimestampNanos =
                    previousSourceTimestampNanos?.let {
                        maxOf(it, result.sample.sourceTimestampNanos)
                    } ?: result.sample.sourceTimestampNanos
                healthTracker.accepted(result.sample)
                consumeSample(result.sample)
            }

            is GnssSampleMappingResult.Rejected -> healthTracker.rejected()
        }
    }

    override fun onProviderEnabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER) healthTracker.providerEnabled()
    }

    override fun onProviderDisabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER) healthTracker.providerDisabled()
    }

    @Suppress("DEPRECATION")
    private fun Location.toPlatformReading(): PlatformLocationReading =
        PlatformLocationReading(
            sourceTimestampNanos = elapsedRealtimeNanos,
            sourceWallTimeUtcEpochMillis = time.takeIf { it > 0 },
            latitudeDegrees = latitude,
            longitudeDegrees = longitude,
            horizontalAccuracyMetres = accuracy.takeIf { hasAccuracy() },
            altitudeMetres = altitude.takeIf { hasAltitude() },
            verticalAccuracyMetres =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && hasVerticalAccuracy()) {
                    verticalAccuracyMeters
                } else {
                    null
                },
            speedMetresPerSecond = speed.takeIf { hasSpeed() },
            speedAccuracyMetresPerSecond =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && hasSpeedAccuracy()) {
                    speedAccuracyMetersPerSecond
                } else {
                    null
                },
            bearingDegrees = bearing.takeIf { hasBearing() },
            bearingAccuracyDegrees =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && hasBearingAccuracy()) {
                    bearingAccuracyDegrees
                } else {
                    null
                },
            provider = provider,
            isMockSignal =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    isMock
                } else {
                    isFromMockProvider
                },
        )

    private fun failRegistration(errorCode: String): GnssAcquisitionStartResult {
        healthTracker.registrationFailed(errorCode)
        return GnssAcquisitionStartResult(started = false, errorCode = errorCode)
    }

    private fun releaseThread() {
        callbackThread?.quitSafely()
        callbackThread = null
    }
}
