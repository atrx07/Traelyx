package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import io.github.atrx07.traelyx.MainActivity
import io.github.atrx07.traelyx.R
import java.util.UUID

/**
 * Native foreground lifecycle owner for an active trip.
 *
 * M2.3 adds native GPS, accelerometer, and gyroscope acquisition while keeping
 * samples process-local until the durable chunk contract is implemented. It
 * holds no wake lock and never sends raw telemetry through logs, Flutter, or
 * the network.
 */
class RecorderService : Service() {
    private lateinit var coordinator: RecorderLifecycleCoordinator
    private var promotedToForeground = false
    private var gnssAcquisition: AndroidGnssAcquisition? = null
    private var imuAcquisition: AndroidImuAcquisition? = null

    override fun onCreate() {
        super.onCreate()
        serviceCreated = true
        coordinator = coordinator(applicationContext)
        ensureNotificationChannel()
    }

    override fun onDestroy() {
        stopAcquisition()
        serviceCreated = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> handleStart(intent, startId)
            ACTION_STOP -> handleStop(startId)
            ACTION_RECOVER,
            null,
            -> handleRecovery(startId)
            else -> {
                coordinator.markError("unknown_service_action")
                stopSelf(startId)
                START_NOT_STICKY
            }
        }
    }

    private fun handleStart(intent: Intent, startId: Int): Int {
        val tripId = intent.getStringExtra(EXTRA_TRIP_ID)
        if (tripId.isNullOrBlank()) {
            coordinator.markError("active_trip_missing")
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val snapshot = coordinator.query()
        if (snapshot.lifecycleState != RecorderLifecycleState.STARTING || snapshot.tripId != tripId) {
            coordinator.markError("invalid_state_transition")
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!promote(snapshot)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val outcome = coordinator.markRecording(tripId)
        if (outcome.kind == RecorderLifecycleOutcomeKind.REJECTED) {
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        if (!startGnssAcquisition(outcome.snapshot)) {
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        if (!startImuAcquisition(outcome.snapshot)) {
            stopGnssAcquisition()
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun handleRecovery(startId: Int): Int {
        val outcome = coordinator.recover()
        if (!outcome.snapshot.isActive || outcome.kind == RecorderLifecycleOutcomeKind.REJECTED) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!promote(outcome.snapshot)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!startGnssAcquisition(outcome.snapshot)) {
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        if (!startImuAcquisition(outcome.snapshot)) {
            stopGnssAcquisition()
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun handleStop(startId: Int): Int {
        val current = coordinator.query()
        if (current.isActive && !promotedToForeground && !promote(current)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        stopAcquisition()
        val stopping = coordinator.beginStop()
        if (stopping.kind == RecorderLifecycleOutcomeKind.REJECTED) {
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        if (promotedToForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            promotedToForeground = false
        }
        coordinator.completeStop()
        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun startGnssAcquisition(snapshot: RecorderStateSnapshot): Boolean {
        val tripEpoch = snapshot.startedAtElapsedRealtimeNanos
        if (tripEpoch == null) {
            coordinator.markError("gnss_trip_epoch_missing")
            return false
        }
        gnssAcquisition?.let {
            if (it.health().state != GnssAcquisitionState.STOPPED) return true
        }
        val acquisition =
            AndroidGnssAcquisition(
                context = applicationContext,
                tripStartedAtElapsedRealtimeNanos = tripEpoch,
                publishHealth = { latestGnssHealth = it },
            )
        gnssAcquisition = acquisition
        val result = acquisition.start()
        if (!result.started) {
            coordinator.markError(result.errorCode ?: "gnss_registration_failed")
            return false
        }
        return true
    }

    private fun stopGnssAcquisition() {
        gnssAcquisition?.stop()
        gnssAcquisition = null
    }

    private fun startImuAcquisition(snapshot: RecorderStateSnapshot): Boolean {
        val tripEpoch = snapshot.startedAtElapsedRealtimeNanos
        if (tripEpoch == null) {
            coordinator.markError("imu_trip_epoch_missing")
            return false
        }
        imuAcquisition?.let {
            if (it.health().state != ImuAcquisitionState.STOPPED) return true
        }
        val acquisition =
            AndroidImuAcquisition(
                context = applicationContext,
                tripStartedAtElapsedRealtimeNanos = tripEpoch,
                publishHealth = { latestImuHealth = it },
            )
        imuAcquisition = acquisition
        val result = acquisition.start()
        if (!result.started) {
            coordinator.markError(result.errorCode ?: "imu_registration_failed")
            return false
        }
        return true
    }

    private fun stopImuAcquisition() {
        imuAcquisition?.stop()
        imuAcquisition = null
    }

    private fun stopAcquisition() {
        stopImuAcquisition()
        stopGnssAcquisition()
    }

    private fun promote(snapshot: RecorderStateSnapshot): Boolean {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            coordinator.markError("location_permission_missing")
            return false
        }
        return try {
            val notification = buildNotification(snapshot)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            promotedToForeground = true
            true
        } catch (_: RuntimeException) {
            coordinator.markError("foreground_promotion_failed")
            false
        }
    }

    private fun buildNotification(snapshot: RecorderStateSnapshot): Notification {
        val openApp =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val stopIntent = Intent(this, RecorderService::class.java).setAction(ACTION_STOP)
        val stopRecorder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(
                    this,
                    1,
                    stopIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            } else {
                PendingIntent.getService(
                    this,
                    1,
                    stopIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
        val text =
            if (snapshot.lifecycleState == RecorderLifecycleState.RECOVERED) {
                "Recording location and motion locally after recorder recovery."
            } else {
                "Recording location and motion locally."
            }
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            } else {
                Notification.Builder(this)
            }
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Traelyx recorder")
            .setContentText(text)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setPriority(Notification.PRIORITY_LOW)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(
                        this,
                        android.R.drawable.ic_menu_close_clear_cancel,
                    ),
                    "Stop",
                    stopRecorder,
                ).build(),
            )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel =
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Active trip recording",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shows when the native Traelyx recorder lifecycle is active."
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
            }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun stopForegroundAndSelf(startId: Int) {
        if (promotedToForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            promotedToForeground = false
        }
        stopSelf(startId)
    }

    companion object {
        private const val ACTION_START = "io.github.atrx07.traelyx.recorder.START"
        private const val ACTION_STOP = "io.github.atrx07.traelyx.recorder.STOP"
        private const val ACTION_RECOVER = "io.github.atrx07.traelyx.recorder.RECOVER"
        private const val EXTRA_TRIP_ID = "trip_id"
        private const val NOTIFICATION_CHANNEL_ID = "active_trip_recording_v1"
        internal const val NOTIFICATION_ID = 7301

        @Volatile
        private var serviceCreated = false

        @Volatile
        private var latestGnssHealth = GnssHealthSnapshot.idle()

        @Volatile
        private var latestImuHealth = ImuHealthSnapshot.idle()

        fun requestStart(context: Context): RecorderStateSnapshot {
            val coordinator = coordinator(context)
            val outcome =
                coordinator.beginStart(
                    tripId = UUID.randomUUID().toString(),
                    startedAtUtcEpochMillis = System.currentTimeMillis(),
                    startedAtElapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos(),
                )
            if (outcome.kind != RecorderLifecycleOutcomeKind.APPLIED) {
                return outcome.snapshot
            }
            return try {
                val intent =
                    Intent(context, RecorderService::class.java)
                        .setAction(ACTION_START)
                        .putExtra(EXTRA_TRIP_ID, outcome.snapshot.tripId)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                outcome.snapshot
            } catch (_: RuntimeException) {
                coordinator.markError("foreground_service_start_rejected").snapshot
            }
        }

        fun requestStop(context: Context): RecorderStateSnapshot {
            val beforeStop = queryState(context)
            if (beforeStop.lifecycleState == RecorderLifecycleState.IDLE) {
                return beforeStop
            }
            return try {
                val intent = Intent(context, RecorderService::class.java).setAction(ACTION_STOP)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && beforeStop.isActive) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                beforeStop
            } catch (_: RuntimeException) {
                coordinator(context).markError("foreground_service_stop_rejected").snapshot
            }
        }

        fun requestRecovery(context: Context): RecorderStateSnapshot {
            val snapshot = queryState(context)
            if (!snapshot.isActive || serviceCreated) {
                return snapshot
            }
            return try {
                val intent =
                    Intent(context, RecorderService::class.java).setAction(ACTION_RECOVER)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                snapshot
            } catch (_: RuntimeException) {
                coordinator(context).markError("foreground_service_start_rejected").snapshot
            }
        }

        fun queryState(context: Context): RecorderStateSnapshot = coordinator(context).query()

        /** Privacy-safe internal proof surface; intentionally not part of the Flutter bridge yet. */
        internal fun queryGnssHealth(): GnssHealthSnapshot = latestGnssHealth

        /** Vector-free internal proof surface; intentionally not part of the Flutter bridge yet. */
        internal fun queryImuHealth(): ImuHealthSnapshot = latestImuHealth

        private fun coordinator(context: Context): RecorderLifecycleCoordinator =
            RecorderLifecycleCoordinator(AtomicRecorderRecoveryStore(context.applicationContext))
    }
}
