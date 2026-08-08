package io.github.atrx07.traelyx.recorder

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Disabled bootstrap shell for the future foreground recorder.
 *
 * It intentionally acquires no sensors, location, wake locks, or foreground
 * service state. M2 will replace this behavior only after lifecycle,
 * permission, buffering, and physical-device tests are in place.
 */
class RecorderService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
