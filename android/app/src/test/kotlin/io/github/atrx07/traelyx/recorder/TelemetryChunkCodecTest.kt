package io.github.atrx07.traelyx.recorder

import java.io.DataInputStream
import kotlin.math.cos
import kotlin.math.sin
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TelemetryChunkCodecTest {
    @Test
    fun `round trip preserves raw fields units optionality flags and order`() {
        val gnss =
            testGnssSample().copy(
                isMockSignal = true,
                qualityFlags =
                    setOf(
                        GnssQualityFlag.GNSS_LOW_ACCURACY,
                        GnssQualityFlag.MOCK_LOCATION_SIGNAL,
                    ),
            )
        val accelerometer = testImuSample()
        val gyroscope =
            testImuSample(
                sensorType = ImuSensorType.GYROSCOPE,
                tripElapsedNanos = 120_000_000L,
                sourceTimestampNanos = 1_120_000_000L,
            ).copy(
                x = -0.25f,
                y = 0.5f,
                z = 1.0f,
                accuracyStatus = 0,
                qualityFlags = setOf(ImuQualityFlag.SENSOR_UNRELIABLE),
            )
        val records =
            listOf(
                TelemetrySampleRecord.Gnss(gnss),
                TelemetrySampleRecord.Imu(accelerometer),
                TelemetrySampleRecord.Imu(gyroscope),
            )

        val encoded =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = 7,
                records = records,
                createdAtUtcEpochMillis = 1_777_777_777_500L,
            )
        val decoded = (TelemetryChunkCodec.decode(encoded.bytes) as TelemetryChunkDecodeResult.Success).chunk
        val decodedGnss =
            (TelemetryChunkCodec.decodeGnss(encoded.bytes) as TelemetryChunkGnssDecodeResult.Success)
                .chunk

        assertEquals(encoded.metadata, decoded.metadata)
        assertEquals(records, decoded.records)
        assertEquals(encoded.metadata, decodedGnss.metadata)
        assertEquals(listOf(gnss), decodedGnss.samples)
        assertEquals(
            mapOf(
                TelemetryChannel.GNSS to 100_000_000L..100_000_000L,
                TelemetryChannel.ACCELEROMETER to 110_000_000L..110_000_000L,
                TelemetryChannel.GYROSCOPE to 120_000_000L..120_000_000L,
            ),
            decodedGnss.channelElapsedRanges,
        )
        assertEquals(
            mapOf("gnss" to 1, "accelerometer" to 1, "gyroscope" to 1),
            decoded.metadata.channelSampleCounts(),
        )
        assertTrue(encoded.bytes.size < 1_024)
    }

    @Test
    fun `encoding is deterministic for a fixed clock and input`() {
        val records =
            listOf(
                TelemetrySampleRecord.Gnss(testGnssSample()),
                TelemetrySampleRecord.Imu(testImuSample()),
            )
        val first = TelemetryChunkCodec.encode(TEST_TRIP_ID, 0, records, 1_777_777_777_500L)
        val second = TelemetryChunkCodec.encode(TEST_TRIP_ID, 0, records, 1_777_777_777_500L)

        assertArrayEquals(first.bytes, second.bytes)
    }

    @Test
    fun `truncation checksum damage and unknown versions fail closed`() {
        val encoded =
            TelemetryChunkCodec.encode(
                TEST_TRIP_ID,
                0,
                listOf(TelemetrySampleRecord.Gnss(testGnssSample())),
                1_777_777_777_500L,
            ).bytes
        val truncated = encoded.copyOf(encoded.size - 4)
        assertInvalid(truncated, "chunk_truncated")
        assertGnssInvalid(truncated, "chunk_truncated")

        val damaged = encoded.copyOf()
        damaged[damaged.size / 2] = (damaged[damaged.size / 2].toInt() xor 0x01).toByte()
        assertTrue(TelemetryChunkCodec.decode(damaged) is TelemetryChunkDecodeResult.Invalid)
        assertTrue(
            TelemetryChunkCodec.decodeGnss(damaged) is TelemetryChunkGnssDecodeResult.Invalid,
        )

        val unknownVersion = encoded.copyOf()
        unknownVersion[7] = 2
        assertInvalid(unknownVersion, "chunk_unknown_version")
        assertGnssInvalid(unknownVersion, "chunk_unknown_version")
    }

    @Test
    fun `catalog isolates corruption orphaned writes and overlapping chunks`() {
        val first = encode(sequence = 0, elapsed = 100L)
        val overlapping = encode(sequence = 1, elapsed = 50L)
        val last = encode(sequence = 4, elapsed = 200L)
        val corrupt = first.copyOf().also { it[it.lastIndex / 2] = 0 }

        val catalog =
            TelemetryChunkCatalog.inspect(
                listOf(
                    TelemetryChunkCandidate(0, first),
                    TelemetryChunkCandidate(1, overlapping),
                    TelemetryChunkCandidate(2, corrupt),
                    TelemetryChunkCandidate(3, null, orphanedIncompleteWrite = true),
                    TelemetryChunkCandidate(4, last),
                ),
            )

        assertEquals(listOf(0L, 4L), catalog.validChunks.map { it.metadata.sequence })
        assertEquals(1, catalog.corruptChunkCount)
        assertEquals(1, catalog.orphanedWriteCount)
        assertEquals(1, catalog.orderingViolationCount)
        assertEquals(4L, catalog.maxObservedSequence)
        assertEquals(200L, catalog.lastVerifiedEndElapsedNanos)
    }

    @Test
    fun `golden version one fixture remains readable`() {
        val stream = requireNotNull(javaClass.getResourceAsStream("/telemetry/chunk_v1_golden.hex"))
        val hex = DataInputStream(stream).use { it.readBytes().decodeToString() }
            .filterNot(Char::isWhitespace)
        val bytes = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        val result = TelemetryChunkCodec.decode(bytes) as TelemetryChunkDecodeResult.Success

        assertEquals(TEST_TRIP_ID, result.chunk.metadata.tripId)
        assertEquals(0L, result.chunk.metadata.sequence)
        assertEquals(2, result.chunk.records.size)
        assertEquals(TelemetryChannel.GNSS, result.chunk.records.first().channel)
        assertEquals(TelemetryChannel.ACCELEROMETER, result.chunk.records.last().channel)
    }

    @Test
    fun `synthetic dual 100 hertz second has a measured bounded encoded size`() {
        val records = mutableListOf<TelemetrySampleRecord>()
        records += TelemetrySampleRecord.Gnss(testGnssSample(tripElapsedNanos = 0L))
        repeat(100) { index ->
            val elapsed = index * 10_000_000L + 1L
            records +=
                TelemetrySampleRecord.Imu(
                    testImuSample(
                        tripElapsedNanos = elapsed,
                        sourceTimestampNanos = 1_000_000_000L + elapsed,
                    ).copy(
                        x = sin(index / 7.0).toFloat(),
                        y = cos(index / 11.0).toFloat(),
                        z = (9.8 + sin(index / 13.0) * 0.2).toFloat(),
                    ),
                )
            records +=
                TelemetrySampleRecord.Imu(
                    testImuSample(
                        sensorType = ImuSensorType.GYROSCOPE,
                        tripElapsedNanos = elapsed,
                        sourceTimestampNanos = 1_000_000_000L + elapsed,
                    ).copy(
                        x = (sin(index / 9.0) * 0.3).toFloat(),
                        y = (cos(index / 8.0) * 0.2).toFloat(),
                        z = (sin(index / 10.0) * 0.1).toFloat(),
                    ),
                )
        }
        val encoded =
            TelemetryChunkCodec.encode(
                TEST_TRIP_ID,
                0,
                records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR),
                1_777_777_777_500L,
            )
        val projectedMebibytesPerHour = encoded.bytes.size * 3_600.0 / (1024.0 * 1024.0)

        println(
            "M2.4 synthetic storage measurement: ${encoded.bytes.size} bytes/second, " +
                "${"%.2f".format(projectedMebibytesPerHour)} MiB/hour.",
        )
        assertEquals(201, encoded.metadata.totalSampleCount)
        assertTrue(encoded.bytes.size < 16_384)
    }

    private fun encode(sequence: Long, elapsed: Long): ByteArray =
        TelemetryChunkCodec.encode(
            TEST_TRIP_ID,
            sequence,
            listOf(
                TelemetrySampleRecord.Imu(
                    testImuSample(
                        tripElapsedNanos = elapsed,
                        sourceTimestampNanos = elapsed + 1_000L,
                    ),
                ),
            ),
            1_777_777_777_500L,
        ).bytes

    private fun assertInvalid(bytes: ByteArray, expectedError: String) {
        val result = TelemetryChunkCodec.decode(bytes) as TelemetryChunkDecodeResult.Invalid
        assertEquals(expectedError, result.errorCode)
    }

    private fun assertGnssInvalid(bytes: ByteArray, expectedError: String) {
        val result = TelemetryChunkCodec.decodeGnss(bytes) as TelemetryChunkGnssDecodeResult.Invalid
        assertEquals(expectedError, result.errorCode)
    }
}
