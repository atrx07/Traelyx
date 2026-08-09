package io.github.atrx07.traelyx.recorder

const val RAW_IMU_SCHEMA_VERSION = 1
const val IMU_HEALTH_CONTRACT_VERSION = 1
const val IMU_REQUESTED_SAMPLING_PERIOD_MICROS = 10_000
const val IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS = 1_000_000
const val IMU_DROPOUT_PERIOD_MULTIPLIER = 5L

enum class ImuSensorType(val wireName: String) {
    ACCELEROMETER("accelerometer"),
    GYROSCOPE("gyroscope"),
}

enum class ImuQualityFlag(val wireName: String) {
    CLOCK_DISCONTINUITY("clock_discontinuity"),
    IMU_DROPOUT("imu_dropout"),
    SENSOR_UNRELIABLE("sensor_unreliable"),
}

/**
 * Versioned, unfiltered Android motion evidence in the device coordinate frame.
 *
 * Accelerometer axes use m/s² and include gravity. Gyroscope axes use rad/s.
 * M2.3 keeps these vectors process-local until M2.4 defines durable chunks.
 */
data class RawImuSample(
    val schemaVersion: Int = RAW_IMU_SCHEMA_VERSION,
    val sensorType: ImuSensorType,
    val tripElapsedNanos: Long?,
    val sourceTimestampNanos: Long,
    val x: Float,
    val y: Float,
    val z: Float,
    val accuracyStatus: Int,
    val qualityFlags: Set<ImuQualityFlag>,
) {
    init {
        require(schemaVersion == RAW_IMU_SCHEMA_VERSION)
        require(tripElapsedNanos == null || tripElapsedNanos >= 0)
        require(sourceTimestampNanos >= 0)
        require(x.isFinite() && y.isFinite() && z.isFinite())
        require(accuracyStatus in MIN_SENSOR_ACCURACY_STATUS..MAX_SENSOR_ACCURACY_STATUS)
        require(
            (ImuQualityFlag.SENSOR_UNRELIABLE in qualityFlags) ==
                (accuracyStatus <= SENSOR_STATUS_UNRELIABLE),
        )
    }

    companion object {
        const val MIN_SENSOR_ACCURACY_STATUS = -1
        const val SENSOR_STATUS_UNRELIABLE = 0
        const val MAX_SENSOR_ACCURACY_STATUS = 3
    }
}

/** Platform-neutral input so mapping tests do not depend on Android runtime stubs. */
data class PlatformImuReading(
    val sensorType: ImuSensorType,
    val sourceTimestampNanos: Long,
    val x: Float,
    val y: Float,
    val z: Float,
    val accuracyStatus: Int,
)

enum class ImuSampleRejectionReason(val wireName: String) {
    INVALID_SOURCE_TIMESTAMP("invalid_source_timestamp"),
    INVALID_VECTOR("invalid_vector"),
    INVALID_ACCURACY_STATUS("invalid_accuracy_status"),
    INVALID_SAMPLING_PERIOD("invalid_sampling_period"),
}

sealed interface ImuSampleMappingResult {
    data class Accepted(val sample: RawImuSample) : ImuSampleMappingResult

    data class Rejected(val reason: ImuSampleRejectionReason) : ImuSampleMappingResult
}

object ImuSampleMapper {
    fun map(
        reading: PlatformImuReading,
        tripStartedAtElapsedRealtimeNanos: Long,
        previousSourceTimestampNanos: Long?,
        effectiveSamplingPeriodMicros: Int,
    ): ImuSampleMappingResult {
        if (reading.sourceTimestampNanos < 0 || tripStartedAtElapsedRealtimeNanos < 0) {
            return ImuSampleMappingResult.Rejected(
                ImuSampleRejectionReason.INVALID_SOURCE_TIMESTAMP,
            )
        }
        if (!reading.x.isFinite() || !reading.y.isFinite() || !reading.z.isFinite()) {
            return ImuSampleMappingResult.Rejected(ImuSampleRejectionReason.INVALID_VECTOR)
        }
        if (
            reading.accuracyStatus !in
            RawImuSample.MIN_SENSOR_ACCURACY_STATUS..RawImuSample.MAX_SENSOR_ACCURACY_STATUS
        ) {
            return ImuSampleMappingResult.Rejected(
                ImuSampleRejectionReason.INVALID_ACCURACY_STATUS,
            )
        }
        if (effectiveSamplingPeriodMicros <= 0) {
            return ImuSampleMappingResult.Rejected(
                ImuSampleRejectionReason.INVALID_SAMPLING_PERIOD,
            )
        }

        val qualityFlags = mutableSetOf<ImuQualityFlag>()
        val monotonicEpochValid =
            reading.sourceTimestampNanos >= tripStartedAtElapsedRealtimeNanos &&
                (previousSourceTimestampNanos == null ||
                    reading.sourceTimestampNanos > previousSourceTimestampNanos)
        if (!monotonicEpochValid) {
            qualityFlags += ImuQualityFlag.CLOCK_DISCONTINUITY
        }
        if (
            previousSourceTimestampNanos != null &&
            reading.sourceTimestampNanos > previousSourceTimestampNanos &&
            reading.sourceTimestampNanos - previousSourceTimestampNanos >
            effectiveSamplingPeriodMicros.toLong() * 1_000L * IMU_DROPOUT_PERIOD_MULTIPLIER
        ) {
            qualityFlags += ImuQualityFlag.IMU_DROPOUT
        }
        if (reading.accuracyStatus <= RawImuSample.SENSOR_STATUS_UNRELIABLE) {
            qualityFlags += ImuQualityFlag.SENSOR_UNRELIABLE
        }

        return ImuSampleMappingResult.Accepted(
            RawImuSample(
                sensorType = reading.sensorType,
                tripElapsedNanos =
                    if (monotonicEpochValid) {
                        reading.sourceTimestampNanos - tripStartedAtElapsedRealtimeNanos
                    } else {
                        null
                    },
                sourceTimestampNanos = reading.sourceTimestampNanos,
                x = reading.x,
                y = reading.y,
                z = reading.z,
                accuracyStatus = reading.accuracyStatus,
                qualityFlags = qualityFlags,
            ),
        )
    }
}

data class ImuSensorConfiguration(
    val sensorType: ImuSensorType,
    val requestedSamplingPeriodMicros: Int = IMU_REQUESTED_SAMPLING_PERIOD_MICROS,
    val effectiveSamplingPeriodMicros: Int,
    val requestedMaxReportLatencyMicros: Int = IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS,
    val effectiveMaxReportLatencyMicros: Int,
    val fifoMaxEventCount: Int,
) {
    init {
        require(requestedSamplingPeriodMicros > 0)
        require(effectiveSamplingPeriodMicros >= requestedSamplingPeriodMicros)
        require(requestedMaxReportLatencyMicros >= 0)
        require(effectiveMaxReportLatencyMicros in 0..requestedMaxReportLatencyMicros)
        require(fifoMaxEventCount >= 0)
        require(fifoMaxEventCount > 0 || effectiveMaxReportLatencyMicros == 0)
    }

    val batchingAvailable: Boolean
        get() = fifoMaxEventCount > 0 && effectiveMaxReportLatencyMicros > 0
}

enum class ImuAcquisitionState(val wireName: String) {
    IDLE("idle"),
    REGISTERING("registering"),
    AWAITING_SAMPLES("awaiting_samples"),
    ACTIVE("active"),
    STOPPED("stopped"),
    ERROR("error"),
}

data class ImuHealthSnapshot(
    val contractVersion: Int = IMU_HEALTH_CONTRACT_VERSION,
    val state: ImuAcquisitionState,
    val accelerometerConfiguration: ImuSensorConfiguration? = null,
    val gyroscopeConfiguration: ImuSensorConfiguration? = null,
    val accelerometerAcceptedSampleCount: Long = 0,
    val gyroscopeAcceptedSampleCount: Long = 0,
    val rejectedSampleCount: Long = 0,
    val unreliableAccuracySampleCount: Long = 0,
    val clockDiscontinuityCount: Long = 0,
    val dropoutCount: Long = 0,
    val accuracyChangeCount: Long = 0,
    val registrationFailureCount: Long = 0,
    val accelerometerFirstSourceTimestampNanos: Long? = null,
    val accelerometerLastSourceTimestampNanos: Long? = null,
    val accelerometerLastTripElapsedNanos: Long? = null,
    val gyroscopeFirstSourceTimestampNanos: Long? = null,
    val gyroscopeLastSourceTimestampNanos: Long? = null,
    val gyroscopeLastTripElapsedNanos: Long? = null,
    val accelerometerLastAccuracyStatus: Int? = null,
    val gyroscopeLastAccuracyStatus: Int? = null,
    val errorCode: String? = null,
) {
    init {
        require(contractVersion == IMU_HEALTH_CONTRACT_VERSION)
        require(
            listOf(
                accelerometerAcceptedSampleCount,
                gyroscopeAcceptedSampleCount,
                rejectedSampleCount,
                unreliableAccuracySampleCount,
                clockDiscontinuityCount,
                dropoutCount,
                accuracyChangeCount,
                registrationFailureCount,
            ).all { it >= 0 },
        )
        require(errorCode == null || Regex("[a-z0-9_]{1,64}").matches(errorCode))
    }

    companion object {
        fun idle(): ImuHealthSnapshot = ImuHealthSnapshot(state = ImuAcquisitionState.IDLE)
    }
}

class ImuHealthTracker(
    private val publish: (ImuHealthSnapshot) -> Unit = {},
) {
    private val lock = Any()
    private var snapshot = ImuHealthSnapshot.idle()

    fun current(): ImuHealthSnapshot = synchronized(lock) { snapshot }

    fun beginRegistration(
        accelerometerConfiguration: ImuSensorConfiguration?,
        gyroscopeConfiguration: ImuSensorConfiguration?,
    ) =
        update {
            ImuHealthSnapshot(
                state = ImuAcquisitionState.REGISTERING,
                accelerometerConfiguration = accelerometerConfiguration,
                gyroscopeConfiguration = gyroscopeConfiguration,
            )
        }

    fun registered() =
        update { it.copy(state = ImuAcquisitionState.AWAITING_SAMPLES, errorCode = null) }

    fun accepted(sample: RawImuSample) =
        update {
            val unreliableIncrement =
                if (ImuQualityFlag.SENSOR_UNRELIABLE in sample.qualityFlags) 1 else 0
            val clockIncrement =
                if (ImuQualityFlag.CLOCK_DISCONTINUITY in sample.qualityFlags) 1 else 0
            val dropoutIncrement =
                if (ImuQualityFlag.IMU_DROPOUT in sample.qualityFlags) 1 else 0
            when (sample.sensorType) {
                ImuSensorType.ACCELEROMETER ->
                    it.copy(
                        state = ImuAcquisitionState.ACTIVE,
                        accelerometerAcceptedSampleCount =
                            it.accelerometerAcceptedSampleCount + 1,
                        unreliableAccuracySampleCount =
                            it.unreliableAccuracySampleCount + unreliableIncrement,
                        clockDiscontinuityCount =
                            it.clockDiscontinuityCount + clockIncrement,
                        dropoutCount = it.dropoutCount + dropoutIncrement,
                        accelerometerFirstSourceTimestampNanos =
                            it.accelerometerFirstSourceTimestampNanos
                                ?: sample.sourceTimestampNanos,
                        accelerometerLastSourceTimestampNanos = sample.sourceTimestampNanos,
                        accelerometerLastTripElapsedNanos = sample.tripElapsedNanos,
                        accelerometerLastAccuracyStatus = sample.accuracyStatus,
                        errorCode = null,
                    )

                ImuSensorType.GYROSCOPE ->
                    it.copy(
                        state = ImuAcquisitionState.ACTIVE,
                        gyroscopeAcceptedSampleCount = it.gyroscopeAcceptedSampleCount + 1,
                        unreliableAccuracySampleCount =
                            it.unreliableAccuracySampleCount + unreliableIncrement,
                        clockDiscontinuityCount =
                            it.clockDiscontinuityCount + clockIncrement,
                        dropoutCount = it.dropoutCount + dropoutIncrement,
                        gyroscopeFirstSourceTimestampNanos =
                            it.gyroscopeFirstSourceTimestampNanos ?: sample.sourceTimestampNanos,
                        gyroscopeLastSourceTimestampNanos = sample.sourceTimestampNanos,
                        gyroscopeLastTripElapsedNanos = sample.tripElapsedNanos,
                        gyroscopeLastAccuracyStatus = sample.accuracyStatus,
                        errorCode = null,
                    )
            }
        }

    fun rejected() =
        update { it.copy(rejectedSampleCount = it.rejectedSampleCount + 1) }

    fun accuracyChanged(
        sensorType: ImuSensorType,
        accuracyStatus: Int,
    ) =
        update {
            it.copy(
                accuracyChangeCount = it.accuracyChangeCount + 1,
                accelerometerLastAccuracyStatus =
                    if (sensorType == ImuSensorType.ACCELEROMETER) {
                        accuracyStatus
                    } else {
                        it.accelerometerLastAccuracyStatus
                    },
                gyroscopeLastAccuracyStatus =
                    if (sensorType == ImuSensorType.GYROSCOPE) {
                        accuracyStatus
                    } else {
                        it.gyroscopeLastAccuracyStatus
                    },
            )
        }

    fun registrationFailed(errorCode: String) =
        update {
            it.copy(
                state = ImuAcquisitionState.ERROR,
                registrationFailureCount = it.registrationFailureCount + 1,
                errorCode = errorCode,
            )
        }

    fun stopped() = update { it.copy(state = ImuAcquisitionState.STOPPED) }

    private fun update(transform: (ImuHealthSnapshot) -> ImuHealthSnapshot) {
        val updated = synchronized(lock) {
            snapshot = transform(snapshot)
            snapshot
        }
        publish(updated)
    }
}
