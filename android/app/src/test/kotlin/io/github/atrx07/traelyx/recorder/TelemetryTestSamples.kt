package io.github.atrx07.traelyx.recorder

internal const val TEST_TRIP_ID = "123e4567-e89b-12d3-a456-426614174000"

internal fun testGnssSample(
    tripElapsedNanos: Long? = 100_000_000L,
    sourceTimestampNanos: Long = 1_100_000_000L,
): RawGnssSample =
    RawGnssSample(
        tripElapsedNanos = tripElapsedNanos,
        sourceTimestampNanos = sourceTimestampNanos,
        sourceWallTimeUtcEpochMillis = 1_777_777_777_000L,
        latitudeDegrees = 12.9716,
        longitudeDegrees = 77.5946,
        horizontalAccuracyMetres = 4.5f,
        altitudeMetres = 920.25,
        verticalAccuracyMetres = 2.0f,
        speedMetresPerSecond = 8.25f,
        speedAccuracyMetresPerSecond = 0.4f,
        bearingDegrees = 42.5f,
        bearingAccuracyDegrees = 1.5f,
        provider = "gps",
        isMockSignal = false,
        qualityFlags = emptySet(),
    )

internal fun testImuSample(
    sensorType: ImuSensorType = ImuSensorType.ACCELEROMETER,
    tripElapsedNanos: Long? = 110_000_000L,
    sourceTimestampNanos: Long = 1_110_000_000L,
): RawImuSample =
    RawImuSample(
        sensorType = sensorType,
        tripElapsedNanos = tripElapsedNanos,
        sourceTimestampNanos = sourceTimestampNanos,
        x = 1.25f,
        y = -2.5f,
        z = 9.75f,
        accuracyStatus = 3,
        qualityFlags = emptySet(),
    )
