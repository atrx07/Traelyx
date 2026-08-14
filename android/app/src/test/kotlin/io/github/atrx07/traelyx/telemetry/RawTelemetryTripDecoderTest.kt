package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import io.github.atrx07.traelyx.recorder.TelemetryChannel
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.recorder.testGnssSample
import io.github.atrx07.traelyx.recorder.testImuSample
import java.io.DataInputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RawTelemetryTripDecoderTest {
    @Test
    fun `golden version one chunk preserves raw contract and units`() {
        val stream = requireNotNull(javaClass.getResourceAsStream("/telemetry/chunk_v1_golden.hex"))
        val hex =
            DataInputStream(stream).use { it.readBytes().decodeToString() }
                .filterNot(Char::isWhitespace)
        val bytes = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

        val result = RawTelemetryTripDecoder.decode(listOf(bytes)) as RawTelemetryTripDecodeResult.Success
        val trip = result.trip
        val records = trip.records().toList()

        assertEquals(RAW_TELEMETRY_TRIP_DECODER_VERSION, trip.decoderVersion)
        assertEquals(TEST_TRIP_ID, trip.tripId)
        assertEquals(1, trip.chunkEncodingVersion)
        assertEquals(1, trip.telemetrySchemaVersion)
        assertEquals(2L, trip.totalSampleCount)
        assertEquals(listOf(TelemetryChannel.GNSS, TelemetryChannel.ACCELEROMETER), records.map { it.channel })

        val gnss = (records.first() as TelemetrySampleRecord.Gnss).sample
        assertEquals(100_000_000L, gnss.tripElapsedNanos)
        assertEquals(1_100_000_000L, gnss.sourceTimestampNanos)
        assertEquals(8.25f, gnss.speedMetresPerSecond)

        val accelerometer = (records.last() as TelemetrySampleRecord.Imu).sample
        assertEquals(1.25f, accelerometer.x)
        assertEquals(-2.5f, accelerometer.y)
        assertEquals(9.75f, accelerometer.z)
    }

    @Test
    fun `input order cannot reorder a complete trip`() {
        val first =
            encode(
                sequence = 0,
                records =
                    listOf(
                        TelemetrySampleRecord.Gnss(testGnssSample(tripElapsedNanos = 100L)),
                        TelemetrySampleRecord.Imu(
                            testImuSample(
                                tripElapsedNanos = 110L,
                                sourceTimestampNanos = 1_110L,
                            ),
                        ),
                    ),
            )
        val second =
            encode(
                sequence = 1,
                records =
                    listOf(
                        TelemetrySampleRecord.Imu(
                            testImuSample(
                                sensorType = ImuSensorType.GYROSCOPE,
                                tripElapsedNanos = 120L,
                                sourceTimestampNanos = 1_120L,
                            ),
                        ),
                    ),
            )

        val result =
            RawTelemetryTripDecoder.decode(listOf(second, first)) as RawTelemetryTripDecodeResult.Success

        assertEquals(listOf(0L, 1L), result.trip.chunks.map { it.metadata.sequence })
        assertEquals(listOf(100L, 110L, 120L), result.trip.records().map { it.tripElapsedNanos }.toList())
    }

    @Test
    fun `corrupt mixed gapped and overlapping trips fail closed`() {
        val first =
            encode(
                sequence = 0,
                records = listOf(accelerometerRecord(elapsedNanos = 100L, sourceNanos = 1_100L)),
            )
        val corrupt = first.copyOf().also { it[it.size / 2] = (it[it.size / 2].toInt() xor 1).toByte() }
        val corruptResult = RawTelemetryTripDecoder.decode(listOf(corrupt)) as RawTelemetryTripDecodeResult.Invalid
        assertTrue(corruptResult.errorCode.startsWith("raw_trip_chunk_"))

        val gap =
            encode(
                sequence = 2,
                records = listOf(accelerometerRecord(elapsedNanos = 200L, sourceNanos = 1_200L)),
            )
        assertInvalid(listOf(first, gap), "raw_trip_sequence_invalid")

        val mixed =
            encode(
                tripId = "223e4567-e89b-12d3-a456-426614174000",
                sequence = 1,
                records = listOf(accelerometerRecord(elapsedNanos = 200L, sourceNanos = 1_200L)),
            )
        assertInvalid(listOf(first, mixed), "raw_trip_mixed_contract")

        val overlap =
            encode(
                sequence = 1,
                records = listOf(accelerometerRecord(elapsedNanos = 90L, sourceNanos = 1_090L)),
            )
        assertInvalid(listOf(first, overlap), "raw_trip_chunk_overlap")
    }

    @Test
    fun `same channel cannot repeat an elapsed timestamp across chunks`() {
        val first =
            encode(
                sequence = 0,
                records = listOf(accelerometerRecord(elapsedNanos = 100L, sourceNanos = 1_100L)),
            )
        val second =
            encode(
                sequence = 1,
                records = listOf(accelerometerRecord(elapsedNanos = 100L, sourceNanos = 1_200L)),
            )

        assertInvalid(listOf(first, second), "raw_trip_channel_time_invalid")
    }

    private fun accelerometerRecord(
        elapsedNanos: Long,
        sourceNanos: Long,
    ): TelemetrySampleRecord.Imu =
        TelemetrySampleRecord.Imu(
            testImuSample(
                tripElapsedNanos = elapsedNanos,
                sourceTimestampNanos = sourceNanos,
            ),
        )

    private fun encode(
        tripId: String = TEST_TRIP_ID,
        sequence: Long,
        records: List<TelemetrySampleRecord>,
    ): ByteArray =
        TelemetryChunkCodec.encode(
            tripId = tripId,
            sequence = sequence,
            records = records.sortedWith(TELEMETRY_SAMPLE_COMPARATOR),
            createdAtUtcEpochMillis = 1_777_777_777_500L + sequence,
        ).bytes

    private fun assertInvalid(
        chunks: List<ByteArray>,
        expectedError: String,
    ) {
        val result = RawTelemetryTripDecoder.decode(chunks) as RawTelemetryTripDecodeResult.Invalid
        assertEquals(expectedError, result.errorCode)
    }
}
