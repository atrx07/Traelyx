package io.github.atrx07.traelyx.recorder

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.HandlerThread

data class ImuAcquisitionStartResult(
    val started: Boolean,
    val errorCode: String? = null,
)

/** Native calibrated accelerometer/gyroscope acquisition owned by RecorderService. */
class AndroidImuAcquisition(
    context: Context,
    private val tripStartedAtElapsedRealtimeNanos: Long,
    private val consumeSample: (RawImuSample) -> Unit = {},
    publishHealth: (ImuHealthSnapshot) -> Unit = {},
) : SensorEventListener {
    private val sensorManager =
        context.applicationContext.getSystemService(SensorManager::class.java)
    private val healthTracker = ImuHealthTracker(publishHealth)
    private val lifecycleLock = Any()
    private var callbackThread: HandlerThread? = null
    private var registered = false

    @Volatile
    private var acceptingEvents = false

    private var accelerometerPreviousSourceTimestampNanos: Long? = null
    private var gyroscopePreviousSourceTimestampNanos: Long? = null
    private var accelerometerConfiguration: ImuSensorConfiguration? = null
    private var gyroscopeConfiguration: ImuSensorConfiguration? = null

    fun start(): ImuAcquisitionStartResult =
        synchronized(lifecycleLock) {
            if (registered) return ImuAcquisitionStartResult(started = true)

            val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            val gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
            val accelerometerConfig = accelerometer?.toConfiguration(ImuSensorType.ACCELEROMETER)
            val gyroscopeConfig = gyroscope?.toConfiguration(ImuSensorType.GYROSCOPE)
            accelerometerConfiguration = accelerometerConfig
            gyroscopeConfiguration = gyroscopeConfig
            healthTracker.beginRegistration(accelerometerConfig, gyroscopeConfig)

            if (accelerometer == null || accelerometerConfig == null) {
                return failRegistration("imu_accelerometer_unavailable")
            }
            if (gyroscope == null || gyroscopeConfig == null) {
                return failRegistration("imu_gyroscope_unavailable")
            }

            val thread = HandlerThread("traelyx-imu-acquisition").also { it.start() }
            callbackThread = thread
            val handler = Handler(thread.looper)
            try {
                val accelerometerRegistered =
                    sensorManager.registerListener(
                        this,
                        accelerometer,
                        accelerometerConfig.effectiveSamplingPeriodMicros,
                        accelerometerConfig.effectiveMaxReportLatencyMicros,
                        handler,
                    )
                if (!accelerometerRegistered) {
                    releaseRegistrations()
                    return failRegistration("imu_accelerometer_registration_failed")
                }
                val gyroscopeRegistered =
                    sensorManager.registerListener(
                        this,
                        gyroscope,
                        gyroscopeConfig.effectiveSamplingPeriodMicros,
                        gyroscopeConfig.effectiveMaxReportLatencyMicros,
                        handler,
                    )
                if (!gyroscopeRegistered) {
                    releaseRegistrations()
                    return failRegistration("imu_gyroscope_registration_failed")
                }
                accelerometerPreviousSourceTimestampNanos = null
                gyroscopePreviousSourceTimestampNanos = null
                acceptingEvents = true
                registered = true
                healthTracker.registered()
                ImuAcquisitionStartResult(started = true)
            } catch (_: RuntimeException) {
                releaseRegistrations()
                failRegistration("imu_registration_failed")
            }
        }

    fun stop() {
        synchronized(lifecycleLock) {
            releaseRegistrations()
            healthTracker.stopped()
        }
    }

    fun health(): ImuHealthSnapshot = healthTracker.current()

    override fun onSensorChanged(event: SensorEvent) {
        if (!acceptingEvents) return
        val sensorType = event.sensor.toImuSensorType() ?: return
        if (event.values.size < 3) {
            healthTracker.rejected()
            return
        }
        val configuration = configurationFor(sensorType) ?: run {
            healthTracker.rejected()
            return
        }
        val previousTimestamp = previousTimestampFor(sensorType)
        when (
            val result =
                ImuSampleMapper.map(
                    reading =
                        PlatformImuReading(
                            sensorType = sensorType,
                            sourceTimestampNanos = event.timestamp,
                            x = event.values[0],
                            y = event.values[1],
                            z = event.values[2],
                            accuracyStatus = event.accuracy,
                        ),
                    tripStartedAtElapsedRealtimeNanos = tripStartedAtElapsedRealtimeNanos,
                    previousSourceTimestampNanos = previousTimestamp,
                    effectiveSamplingPeriodMicros =
                        configuration.effectiveSamplingPeriodMicros,
                )
        ) {
            is ImuSampleMappingResult.Accepted -> {
                updatePreviousTimestamp(sensorType, result.sample.sourceTimestampNanos)
                healthTracker.accepted(result.sample)
                consumeSample(result.sample)
            }

            is ImuSampleMappingResult.Rejected -> healthTracker.rejected()
        }
    }

    override fun onAccuracyChanged(
        sensor: Sensor,
        accuracy: Int,
    ) {
        if (!acceptingEvents) return
        val sensorType = sensor.toImuSensorType() ?: return
        if (
            accuracy in
            RawImuSample.MIN_SENSOR_ACCURACY_STATUS..RawImuSample.MAX_SENSOR_ACCURACY_STATUS
        ) {
            healthTracker.accuracyChanged(sensorType, accuracy)
        }
    }

    private fun Sensor.toConfiguration(sensorType: ImuSensorType): ImuSensorConfiguration {
        val effectivePeriod = maxOf(IMU_REQUESTED_SAMPLING_PERIOD_MICROS, minDelay.coerceAtLeast(1))
        val safeFifoMaxEventCount = fifoMaxEventCount.coerceAtLeast(0)
        val fifoCapacityMicros = safeFifoMaxEventCount.toLong() * effectivePeriod.toLong()
        val effectiveLatency =
            if (safeFifoMaxEventCount > 0) {
                minOf(
                    IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS.toLong(),
                    fifoCapacityMicros,
                ).toInt()
            } else {
                0
            }
        return ImuSensorConfiguration(
            sensorType = sensorType,
            effectiveSamplingPeriodMicros = effectivePeriod,
            effectiveMaxReportLatencyMicros = effectiveLatency,
            fifoMaxEventCount = safeFifoMaxEventCount,
        )
    }

    private fun Sensor.toImuSensorType(): ImuSensorType? =
        when (type) {
            Sensor.TYPE_ACCELEROMETER -> ImuSensorType.ACCELEROMETER
            Sensor.TYPE_GYROSCOPE -> ImuSensorType.GYROSCOPE
            else -> null
        }

    private fun configurationFor(sensorType: ImuSensorType): ImuSensorConfiguration? =
        when (sensorType) {
            ImuSensorType.ACCELEROMETER -> accelerometerConfiguration
            ImuSensorType.GYROSCOPE -> gyroscopeConfiguration
        }

    private fun previousTimestampFor(sensorType: ImuSensorType): Long? =
        when (sensorType) {
            ImuSensorType.ACCELEROMETER -> accelerometerPreviousSourceTimestampNanos
            ImuSensorType.GYROSCOPE -> gyroscopePreviousSourceTimestampNanos
        }

    private fun updatePreviousTimestamp(
        sensorType: ImuSensorType,
        sourceTimestampNanos: Long,
    ) {
        when (sensorType) {
            ImuSensorType.ACCELEROMETER ->
                accelerometerPreviousSourceTimestampNanos =
                    maxOf(accelerometerPreviousSourceTimestampNanos ?: 0L, sourceTimestampNanos)

            ImuSensorType.GYROSCOPE ->
                gyroscopePreviousSourceTimestampNanos =
                    maxOf(gyroscopePreviousSourceTimestampNanos ?: 0L, sourceTimestampNanos)
        }
    }

    private fun failRegistration(errorCode: String): ImuAcquisitionStartResult {
        healthTracker.registrationFailed(errorCode)
        return ImuAcquisitionStartResult(started = false, errorCode = errorCode)
    }

    private fun releaseRegistrations() {
        acceptingEvents = false
        try {
            sensorManager.unregisterListener(this)
        } catch (_: RuntimeException) {
            // Teardown remains best-effort; the service process owns the listener and callback thread.
        }
        registered = false
        accelerometerPreviousSourceTimestampNanos = null
        gyroscopePreviousSourceTimestampNanos = null
        callbackThread?.quitSafely()
        callbackThread = null
    }
}
