package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.testGnssSample
import io.github.atrx07.traelyx.recorder.testImuSample
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Governed M3 regression corpus.
 *
 * Fixtures are generated from synthetic motion at an intentionally non-real coordinate origin.
 * They must never embed or derive from a private `.tripdebug` capture.
 */
internal object TelemetryRegressionFixtureCorpus {
    const val VERSION = 1
    const val SAMPLE_INTERVAL_NANOS = 10_000_000L
    const val GNSS_INTERVAL_NANOS = 100_000_000L
    const val REFERENCE_CALIBRATION_END_NANOS = 2_000_000_000L
    const val SUBSEQUENT_CALIBRATION_START_NANOS = 2_200_000_000L
    const val SUBSEQUENT_CALIBRATION_END_NANOS = 4_200_000_000L
    const val ACTION_START_NANOS = 5_000_000_000L
    const val ACTION_END_NANOS = 11_500_000_000L
    const val TRIP_END_NANOS = 12_000_000_000L
    const val GNSS_LOSS_START_NANOS = 5_000_000_000L
    const val GNSS_LOSS_END_NANOS = 10_100_000_000L
    const val PHONE_MOVE_START_NANOS = SUBSEQUENT_CALIBRATION_START_NANOS

    val scenarios: List<TelemetryRegressionScenario> = TelemetryRegressionScenario.entries

    fun generate(scenario: TelemetryRegressionScenario): TelemetryRegressionFixture {
        val motion = generateMotion(scenario)
        val records = buildList {
            motion.imu.forEach { point ->
                add(imuRecord(ImuSensorType.ACCELEROMETER, point.timeNanos, point.acceleration))
                add(imuRecord(ImuSensorType.GYROSCOPE, point.timeNanos, point.gyroscope))
            }
            motion.gnss.forEach { add(TelemetrySampleRecord.Gnss(it)) }
        }
        return TelemetryRegressionFixture(
            corpusVersion = VERSION,
            scenario = scenario,
            records = records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR),
        )
    }

    private fun generateMotion(scenario: TelemetryRegressionScenario): SyntheticMotion {
        val imu =
            (0L..TRIP_END_NANOS / SAMPLE_INTERVAL_NANOS).map { index ->
                val timeNanos = index * SAMPLE_INTERVAL_NANOS
                val seconds = timeNanos.toDouble() / NANOS_PER_SECOND
                val actionSeconds =
                    ((timeNanos - ACTION_START_NANOS).coerceAtLeast(0L)).toDouble() /
                        NANOS_PER_SECOND
                val desiredVehicle = vehicleAcceleration(scenario, timeNanos, actionSeconds)
                val gyroscope = vehicleGyroscope(scenario, timeNanos, seconds)
                val gravity = gravityDevice(scenario, timeNanos)
                TelemetryRegressionImuPoint(
                    timeNanos = timeNanos,
                    acceleration =
                        FrameVector3(
                            x = -desiredVehicle.y + vibrationX(scenario, timeNanos, seconds),
                            y = desiredVehicle.x + gravity.y + vibrationY(scenario, timeNanos, seconds),
                            z = desiredVehicle.z + gravity.z + vibrationZ(scenario, timeNanos, seconds),
                        ),
                    gyroscope = gyroscope,
                )
            }

        var latitudeDegrees = SYNTHETIC_LATITUDE_DEGREES
        var longitudeDegrees = SYNTHETIC_LONGITUDE_DEGREES
        var previousTimeNanos = 0L
        val gnss = mutableListOf<RawGnssSample>()
        for (index in 0L..TRIP_END_NANOS / GNSS_INTERVAL_NANOS) {
            val timeNanos = index * GNSS_INTERVAL_NANOS
            val seconds = timeNanos.toDouble() / NANOS_PER_SECOND
            val speed = speedMetresPerSecond(scenario, timeNanos)
            val bearing = bearingDegrees(scenario, timeNanos)
            val elapsedSeconds = (timeNanos - previousTimeNanos).toDouble() / NANOS_PER_SECOND
            val distanceMetres = speed * elapsedSeconds
            val bearingRadians = Math.toRadians(bearing)
            val northMetres = distanceMetres * cos(bearingRadians)
            val eastMetres = distanceMetres * sin(bearingRadians)
            latitudeDegrees += Math.toDegrees(northMetres / EARTH_RADIUS_METRES)
            longitudeDegrees +=
                Math.toDegrees(
                    eastMetres /
                        (EARTH_RADIUS_METRES * cos(Math.toRadians(latitudeDegrees))),
                )
            previousTimeNanos = timeNanos
            if (
                scenario == TelemetryRegressionScenario.GNSS_LOSS &&
                timeNanos in GNSS_LOSS_START_NANOS until GNSS_LOSS_END_NANOS
            ) {
                continue
            }
            gnss +=
                gnssSample(
                    timeNanos = timeNanos,
                    latitudeDegrees = latitudeDegrees,
                    longitudeDegrees = longitudeDegrees,
                    speedMetresPerSecond = speed,
                    bearingDegrees = bearing,
                )
        }
        return SyntheticMotion(imu = imu, gnss = gnss)
    }

    private fun vehicleAcceleration(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
        actionSeconds: Double,
    ): FrameVector3 {
        if (timeNanos < ACTION_START_NANOS) return FrameVector3(0.0, 0.0, 0.0)
        return when (scenario) {
            TelemetryRegressionScenario.SMOOTH_ACCELERATION -> FrameVector3(2.0, 0.0, 0.0)
            TelemetryRegressionScenario.BRAKING ->
                FrameVector3(if (actionSeconds <= 3.0) -3.0 else 0.0, 0.0, 0.0)
            TelemetryRegressionScenario.LEFT_CORNER -> FrameVector3(0.0, 2.5, 0.0)
            TelemetryRegressionScenario.RIGHT_CORNER -> FrameVector3(0.0, -2.5, 0.0)
            TelemetryRegressionScenario.POTHOLE ->
                FrameVector3(
                    0.0,
                    0.0,
                    when (timeNanos) {
                        in 7_000_000_000L..7_100_000_000L -> 6.0
                        in 7_110_000_000L..7_220_000_000L -> -3.0
                        else -> 0.0
                    },
                )
            else -> FrameVector3(0.0, 0.0, 0.0)
        }
    }

    private fun vehicleGyroscope(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
        seconds: Double,
    ): FrameVector3 {
        if (timeNanos < ACTION_START_NANOS) return FrameVector3(0.0, 0.0, 0.0)
        val yaw =
            when (scenario) {
                TelemetryRegressionScenario.LEFT_CORNER -> 0.25
                TelemetryRegressionScenario.RIGHT_CORNER -> -0.25
                else -> 0.0
            }
        val vibration =
            if (scenario == TelemetryRegressionScenario.MOTORCYCLE_VIBRATION) {
                0.025 * sin(2.0 * PI * 13.0 * seconds)
            } else {
                0.0
            }
        return FrameVector3(0.0, 0.0, yaw + vibration)
    }

    private fun gravityDevice(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
    ): FrameVector3 {
        if (
            scenario != TelemetryRegressionScenario.PHONE_MOVE ||
            timeNanos < PHONE_MOVE_START_NANOS
        ) {
            return FrameVector3(0.0, 0.0, STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED)
        }
        val angle = Math.toRadians(30.0)
        return FrameVector3(
            0.0,
            STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED * sin(angle),
            STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED * cos(angle),
        )
    }

    private fun vibrationX(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
        seconds: Double,
    ): Double =
        if (
            scenario == TelemetryRegressionScenario.MOTORCYCLE_VIBRATION &&
            timeNanos >= ACTION_START_NANOS
        ) {
            0.25 * sin(2.0 * PI * 11.0 * seconds)
        } else {
            0.0
        }

    private fun vibrationY(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
        seconds: Double,
    ): Double =
        if (
            scenario == TelemetryRegressionScenario.MOTORCYCLE_VIBRATION &&
            timeNanos >= ACTION_START_NANOS
        ) {
            0.35 * sin(2.0 * PI * 13.0 * seconds)
        } else {
            0.0
        }

    private fun vibrationZ(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
        seconds: Double,
    ): Double =
        if (
            scenario == TelemetryRegressionScenario.MOTORCYCLE_VIBRATION &&
            timeNanos >= ACTION_START_NANOS
        ) {
            0.50 * sin(2.0 * PI * 17.0 * seconds)
        } else {
            0.0
        }

    private fun speedMetresPerSecond(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
    ): Double {
        if (timeNanos < ACTION_START_NANOS) return 0.0
        val actionSeconds = (timeNanos - ACTION_START_NANOS).toDouble() / NANOS_PER_SECOND
        return when (scenario) {
            TelemetryRegressionScenario.STATIONARY -> 0.0
            TelemetryRegressionScenario.SMOOTH_ACCELERATION -> (2.0 * actionSeconds).coerceAtMost(10.0)
            TelemetryRegressionScenario.BRAKING -> (12.0 - 3.0 * actionSeconds).coerceAtLeast(3.0)
            TelemetryRegressionScenario.PHONE_MOVE -> 8.0
            TelemetryRegressionScenario.MOTORCYCLE_VIBRATION -> 8.0
            else -> 10.0
        }
    }

    private fun bearingDegrees(
        scenario: TelemetryRegressionScenario,
        timeNanos: Long,
    ): Double {
        if (timeNanos < ACTION_START_NANOS) return 0.0
        val actionSeconds = (timeNanos - ACTION_START_NANOS).toDouble() / NANOS_PER_SECOND
        val signedDegrees =
            when (scenario) {
                TelemetryRegressionScenario.LEFT_CORNER -> Math.toDegrees(0.25 * actionSeconds)
                TelemetryRegressionScenario.RIGHT_CORNER -> -Math.toDegrees(0.25 * actionSeconds)
                else -> 0.0
            }
        return (signedDegrees % 360.0 + 360.0) % 360.0
    }

    private fun imuRecord(
        sensorType: ImuSensorType,
        timeNanos: Long,
        value: FrameVector3,
    ): TelemetrySampleRecord.Imu =
        TelemetrySampleRecord.Imu(
            testImuSample(
                sensorType = sensorType,
                tripElapsedNanos = timeNanos,
                sourceTimestampNanos = SOURCE_TIMESTAMP_OFFSET_NANOS + timeNanos,
            ).copy(
                x = value.x.toFloat(),
                y = value.y.toFloat(),
                z = value.z.toFloat(),
                accuracyStatus = 3,
                qualityFlags = emptySet<ImuQualityFlag>(),
            ),
        )

    private fun gnssSample(
        timeNanos: Long,
        latitudeDegrees: Double,
        longitudeDegrees: Double,
        speedMetresPerSecond: Double,
        bearingDegrees: Double,
    ): RawGnssSample =
        testGnssSample(
            tripElapsedNanos = timeNanos,
            sourceTimestampNanos = SOURCE_TIMESTAMP_OFFSET_NANOS + timeNanos,
        ).copy(
            latitudeDegrees = latitudeDegrees,
            longitudeDegrees = longitudeDegrees,
            horizontalAccuracyMetres = 3.0f,
            speedMetresPerSecond = speedMetresPerSecond.toFloat(),
            speedAccuracyMetresPerSecond = 0.1f,
            bearingDegrees = bearingDegrees.toFloat(),
            bearingAccuracyDegrees = 1.0f,
        )

    private data class SyntheticMotion(
        val imu: List<TelemetryRegressionImuPoint>,
        val gnss: List<RawGnssSample>,
    )

    private const val NANOS_PER_SECOND = 1_000_000_000.0
    private const val SOURCE_TIMESTAMP_OFFSET_NANOS = 8_000_000_000L
    private const val EARTH_RADIUS_METRES = 6_371_008.8
    private const val SYNTHETIC_LATITUDE_DEGREES = 0.0
    private const val SYNTHETIC_LONGITUDE_DEGREES = 0.0
}

internal enum class TelemetryRegressionScenario {
    STATIONARY,
    SMOOTH_STRAIGHT,
    SMOOTH_ACCELERATION,
    BRAKING,
    LEFT_CORNER,
    RIGHT_CORNER,
    POTHOLE,
    PHONE_MOVE,
    GNSS_LOSS,
    MOTORCYCLE_VIBRATION,
}

internal data class TelemetryRegressionFixture(
    val corpusVersion: Int,
    val scenario: TelemetryRegressionScenario,
    val records: List<TelemetrySampleRecord>,
) {
    init {
        require(corpusVersion == TelemetryRegressionFixtureCorpus.VERSION)
        require(records.isNotEmpty())
    }

    fun encodedChunks(): List<ByteArray> {
        val groups = mutableListOf<MutableList<TelemetrySampleRecord>>()
        records.forEach { record ->
            val current = groups.lastOrNull()
            val shouldStartNew =
                current == null ||
                    current.size == MAX_RECORDS_PER_CHUNK ||
                    record.tripElapsedNanos - current.first().tripElapsedNanos > MAX_CHUNK_SPAN_NANOS
            if (shouldStartNew) groups += mutableListOf(record) else current.add(record)
        }
        return groups.mapIndexed { index, group ->
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = index.toLong(),
                records = group,
                createdAtUtcEpochMillis = FIXED_CREATED_AT_UTC_EPOCH_MILLIS + index,
            ).bytes
        }
    }

    private companion object {
        const val MAX_RECORDS_PER_CHUNK = 256
        const val MAX_CHUNK_SPAN_NANOS = 1_000_000_000L
        const val FIXED_CREATED_AT_UTC_EPOCH_MILLIS = 1_777_777_777_500L
    }
}

private data class TelemetryRegressionImuPoint(
    val timeNanos: Long,
    val acceleration: FrameVector3,
    val gyroscope: FrameVector3,
)
