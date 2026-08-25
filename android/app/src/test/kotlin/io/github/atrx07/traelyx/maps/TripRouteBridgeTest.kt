package io.github.atrx07.traelyx.maps

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.TEST_TRIP_ID
import io.github.atrx07.traelyx.recorder.TelemetryChunkCandidate
import io.github.atrx07.traelyx.recorder.TelemetryChunkCatalog
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetryChunkStore
import io.github.atrx07.traelyx.recorder.TelemetryChunkSequenceSnapshot
import io.github.atrx07.traelyx.recorder.TelemetryChunkWriteResult
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TripRouteBridgeTest {
    @Test
    fun `verified evidence becomes governed display geometry without identifiers`() {
        val reader =
            TripRouteReader(
                FakeChunkStore(
                    encodedChunk(0, sample(0, 0.0)),
                    encodedChunk(1, sample(1, 0.0001)),
                    encodedChunk(
                        2,
                        sample(
                            seconds = 2,
                            longitude = 0.0002,
                            accuracy = 80f,
                            flags = setOf(GnssQualityFlag.GNSS_LOW_ACCURACY),
                        ),
                    ),
                    encodedChunk(3, sample(3, 0.0003)),
                ),
            )

        val result = reader.read(TEST_TRIP_ID) as TripRouteReadResult.Available

        assertEquals(4, result.geometry.sourceGnssCount)
        assertEquals(3, result.geometry.points.size)
        assertEquals(listOf(true, false, true), result.geometry.points.map { it.startsNewSegment })
        assertFalse(result.geometry.reduced)
        val payload = result.toBridgeMap()
        assertEquals(
            setOf(
                "contractVersion",
                "state",
                "processingVersion",
                "sourceGnssCount",
                "displayedPointCount",
                "reduced",
                "points",
            ),
            payload.keys,
        )
        assertEquals("available", payload["state"])
        assertFalse(payload.toString().contains(TEST_TRIP_ID))
        assertFalse(payload.toString().contains("gps"))
    }

    @Test
    fun `missing corrupt and insufficient evidence fail closed`() {
        val missing = TripRouteReader(FakeChunkStore()).read(TEST_TRIP_ID)
        assertEquals(TripRouteReadResult.Unavailable, missing)

        val incomplete =
            TripRouteReader(
                FakeChunkStore(
                    encodedChunk(0, sample(0, 0.0)),
                    encodedChunk(2, sample(2, 0.0002)),
                ),
            ).read(TEST_TRIP_ID)
        assertEquals(TripRouteReadResult.Invalid, incomplete)

        val corruptBytes = encodedChunk(0, sample(0, 0.0)).copyOf()
        corruptBytes[corruptBytes.lastIndex / 2] =
            (corruptBytes[corruptBytes.lastIndex / 2].toInt() xor 1).toByte()
        assertEquals(
            TripRouteReadResult.Invalid,
            TripRouteReader(FakeChunkStore(corruptBytes)).read(TEST_TRIP_ID),
        )

        val onePoint =
            TripRouteReader(FakeChunkStore(encodedChunk(0, sample(0, 0.0)))).read(TEST_TRIP_ID)
        assertEquals(TripRouteReadResult.Unavailable, onePoint)
        assertEquals(TripRouteReadResult.Invalid, TripRouteReader(FakeChunkStore()).read("bad-id"))
    }

    @Test
    fun `reducer is deterministic bounded and preserves route discontinuities`() {
        val points =
            List(20) { index ->
                TripRoutePoint(
                    tripElapsedNanos = index.toLong(),
                    latitude = 0.0,
                    longitude = index.toDouble(),
                    startsNewSegment = index == 0 || index == 7 || index == 14,
                )
            }

        val reduced = requireNotNull(TripRoutePointReducer.reduce(points, maximumPoints = 6))

        assertEquals(6, reduced.size)
        assertEquals(reduced, TripRoutePointReducer.reduce(points, maximumPoints = 6))
        assertEquals(0L, reduced.first().tripElapsedNanos)
        assertEquals(19L, reduced.last().tripElapsedNanos)
        assertTrue(reduced.any { it.tripElapsedNanos == 7L && it.startsNewSegment })
        assertTrue(reduced.any { it.tripElapsedNanos == 14L && it.startsNewSegment })
        assertNull(
            TripRoutePointReducer.reduce(
                points.map { it.copy(startsNewSegment = true) },
                maximumPoints = 6,
            ),
        )
    }

    private fun encodedChunk(
        sequence: Long,
        sample: RawGnssSample,
    ): ByteArray =
        TelemetryChunkCodec.encode(
            tripId = TEST_TRIP_ID,
            sequence = sequence,
            records = listOf(TelemetrySampleRecord.Gnss(sample)),
            createdAtUtcEpochMillis = 1_777_777_777_000L + sequence,
        ).bytes

    private fun sample(
        seconds: Long,
        longitude: Double,
        accuracy: Float = 1f,
        flags: Set<GnssQualityFlag> = emptySet(),
    ): RawGnssSample =
        RawGnssSample(
            tripElapsedNanos = seconds * 1_000_000_000L,
            sourceTimestampNanos = 10_000_000_000L + seconds * 1_000_000_000L,
            sourceWallTimeUtcEpochMillis = 1_777_777_777_000L + seconds * 1_000L,
            latitudeDegrees = 0.0,
            longitudeDegrees = longitude,
            horizontalAccuracyMetres = accuracy,
            altitudeMetres = null,
            verticalAccuracyMetres = null,
            speedMetresPerSecond = 12f,
            speedAccuracyMetresPerSecond = 1f,
            bearingDegrees = null,
            bearingAccuracyDegrees = null,
            provider = "gps",
            isMockSignal = false,
            qualityFlags = flags,
        )

    private class FakeChunkStore(vararg encodedChunks: ByteArray) : TelemetryChunkStore {
        private val chunks = encodedChunks.toList()

        override fun scan(tripId: String) =
            TelemetryChunkCatalog.inspect(
                chunks.mapIndexed { index, bytes ->
                    val decoded = TelemetryChunkCodec.decode(bytes)
                    val sequence =
                        (decoded as? io.github.atrx07.traelyx.recorder.TelemetryChunkDecodeResult.Success)
                            ?.chunk?.metadata?.sequence ?: index.toLong()
                    TelemetryChunkCandidate(observedSequence = sequence, bytes = bytes)
                },
            )

        override fun listSequences(tripId: String): TelemetryChunkSequenceSnapshot =
            TelemetryChunkSequenceSnapshot(
                sequences =
                    chunks.mapIndexed { index, bytes ->
                        val decoded = TelemetryChunkCodec.decode(bytes)
                        (decoded as? io.github.atrx07.traelyx.recorder.TelemetryChunkDecodeResult.Success)
                            ?.chunk?.metadata?.sequence ?: index.toLong()
                    }.distinct().sorted(),
                orphanedWriteCount = 0,
                invalidCandidateCount = 0,
            )

        override fun read(tripId: String, sequence: Long): ByteArray? =
            chunks.firstOrNull { bytes ->
                val decoded = TelemetryChunkCodec.decode(bytes)
                (decoded as? io.github.atrx07.traelyx.recorder.TelemetryChunkDecodeResult.Success)
                    ?.chunk?.metadata?.sequence == sequence
            }

        override fun write(
            chunk: io.github.atrx07.traelyx.recorder.EncodedTelemetryChunk,
        ): TelemetryChunkWriteResult = error("Not used")
    }
}
