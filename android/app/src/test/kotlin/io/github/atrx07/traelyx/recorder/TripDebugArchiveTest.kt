package io.github.atrx07.traelyx.recorder

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class TripDebugArchiveTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun exporterCreatesDeterministicSelfInspectedPrivateArchive() {
        val chunks = sampleChunks()
        val exporter = TripDebugArchiveExporter(FakeReadableStore(chunks), temporaryFolder.root)

        val first = exporter.prepare(TEST_TRIP_ID) as TripDebugPreparationResult.Success
        val firstBytes = first.prepared.file.readBytes()
        val inspection = first.prepared.inspection
        assertEquals(2, inspection.manifest.chunkCount)
        assertEquals(1, inspection.manifest.gnssSampleCount)
        assertEquals(2, inspection.manifest.accelerometerSampleCount)
        assertEquals(1, inspection.manifest.gyroscopeSampleCount)
        assertTrue(inspection.manifest.containsPreciseLocation)
        assertEquals(TRIPDEBUG_PRIVACY_CLASS, inspection.manifest.privacyClass)
        assertEquals(100_000_000L, inspection.maxAccelerometerGapNanos)

        val second = exporter.prepare(TEST_TRIP_ID) as TripDebugPreparationResult.Success
        assertArrayEquals(firstBytes, second.prepared.file.readBytes())
    }

    @Test
    fun manifestContainsNoCoordinatesDeviceIdentityOrAbsolutePath() {
        val prepared =
            (TripDebugArchiveExporter(FakeReadableStore(sampleChunks()), temporaryFolder.root)
                .prepare(TEST_TRIP_ID) as TripDebugPreparationResult.Success).prepared
        val manifest =
            FileInputStream(prepared.file).use { file ->
                ZipInputStream(file).use { zip ->
                    assertEquals("manifest.txt", zip.nextEntry.name)
                    zip.readBytes().toString(Charsets.UTF_8)
                }
            }

        assertTrue(manifest.contains("privacy_class=precise_private"))
        assertTrue(manifest.contains("contains_precise_location=true"))
        assertFalse(manifest.contains("latitude", ignoreCase = true))
        assertFalse(manifest.contains("longitude", ignoreCase = true))
        assertFalse(manifest.contains("device", ignoreCase = true))
        assertFalse(manifest.contains("C:\\"))
        assertFalse(manifest.contains("/data/"))
    }

    @Test
    fun exporterRejectsCorruptCatalogAndSequenceGaps() {
        val chunks = sampleChunks()
        val corruptCatalog = catalog(chunks).copy(corruptChunkCount = 1)
        val corrupt =
            TripDebugArchiveExporter(
                FakeReadableStore(chunks, catalogOverride = corruptCatalog),
                File(temporaryFolder.root, "corrupt"),
            ).prepare(TEST_TRIP_ID)
        assertEquals(
            "export_catalog_not_verified",
            (corrupt as TripDebugPreparationResult.Failure).errorCode,
        )

        val sequenceTwo =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = 2,
                records =
                    listOf(
                        TelemetrySampleRecord.Imu(
                            testImuSample(tripElapsedNanos = 300_000_000L),
                        ),
                    ),
                createdAtUtcEpochMillis = 1_777_777_777_002L,
            )
        val gapChunks = listOf(chunks.first(), sequenceTwo)
        val gap =
            TripDebugArchiveExporter(
                FakeReadableStore(gapChunks),
                File(temporaryFolder.root, "gap"),
            ).prepare(TEST_TRIP_ID)
        assertEquals("export_sequence_gap", (gap as TripDebugPreparationResult.Failure).errorCode)
    }

    @Test
    fun inspectorRejectsTamperedArchive() {
        val prepared =
            (TripDebugArchiveExporter(FakeReadableStore(sampleChunks()), temporaryFolder.root)
                .prepare(TEST_TRIP_ID) as TripDebugPreparationResult.Success).prepared
        val bytes = prepared.file.readBytes()
        val marker = "manifest.txt".toByteArray()
        val markerIndex = bytes.indexOfSubsequence(marker)
        assertTrue(markerIndex >= 0)
        bytes[markerIndex] = 'x'.code.toByte()

        val result = TripDebugArchiveCodec.inspect(ByteArrayInputStream(bytes), bytes.size.toLong())
        assertTrue(result is TripDebugInspectionResult.Invalid)
    }

    @Test
    fun inspectorRejectsCompressedArchiveEntries() {
        val prepared =
            (TripDebugArchiveExporter(FakeReadableStore(sampleChunks()), temporaryFolder.root)
                .prepare(TEST_TRIP_ID) as TripDebugPreparationResult.Success).prepared
        val compressed = ByteArrayOutputStream()
        ZipInputStream(FileInputStream(prepared.file)).use { source ->
            ZipOutputStream(compressed).use { target ->
                var entry = source.nextEntry
                while (entry != null) {
                    val bytes = source.readBytes()
                    target.putNextEntry(ZipEntry(entry.name))
                    target.write(bytes)
                    target.closeEntry()
                    source.closeEntry()
                    entry = source.nextEntry
                }
            }
        }

        val bytes = compressed.toByteArray()
        val result = TripDebugArchiveCodec.inspect(ByteArrayInputStream(bytes), bytes.size.toLong())
        assertTrue(result is TripDebugInspectionResult.Invalid)
    }

    private fun sampleChunks(): List<EncodedTelemetryChunk> {
        val first =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = 0,
                records =
                    listOf(
                        TelemetrySampleRecord.Gnss(testGnssSample(tripElapsedNanos = 100_000_000L)),
                        TelemetrySampleRecord.Imu(
                            testImuSample(tripElapsedNanos = 110_000_000L),
                        ),
                    ),
                createdAtUtcEpochMillis = 1_777_777_777_000L,
            )
        val second =
            TelemetryChunkCodec.encode(
                tripId = TEST_TRIP_ID,
                sequence = 1,
                records =
                    listOf(
                        TelemetrySampleRecord.Imu(
                            testImuSample(
                                tripElapsedNanos = 210_000_000L,
                                sourceTimestampNanos = 1_210_000_000L,
                            ),
                        ),
                        TelemetrySampleRecord.Imu(
                            testImuSample(
                                sensorType = ImuSensorType.GYROSCOPE,
                                tripElapsedNanos = 220_000_000L,
                                sourceTimestampNanos = 1_220_000_000L,
                            ),
                        ),
                    ),
                createdAtUtcEpochMillis = 1_777_777_777_001L,
            )
        return listOf(first, second)
    }

    private fun catalog(chunks: List<EncodedTelemetryChunk>): TelemetryChunkCatalogSnapshot =
        TelemetryChunkCatalog.inspect(
            chunks.map { chunk ->
                TelemetryChunkCandidate(chunk.metadata.sequence, chunk.bytes)
            },
        )
}

private class FakeReadableStore(
    chunks: List<EncodedTelemetryChunk>,
    private val catalogOverride: TelemetryChunkCatalogSnapshot? = null,
) : TelemetryChunkStore {
    private val chunksBySequence = chunks.associateBy { it.metadata.sequence }

    override fun scan(tripId: String): TelemetryChunkCatalogSnapshot =
        catalogOverride ?: TelemetryChunkCatalog.inspect(
            chunksBySequence.values.map { chunk ->
                TelemetryChunkCandidate(chunk.metadata.sequence, chunk.bytes)
            },
        )

    override fun write(chunk: EncodedTelemetryChunk): TelemetryChunkWriteResult =
        TelemetryChunkWriteResult.Failure("not_supported")

    override fun read(tripId: String, sequence: Long): ByteArray? =
        chunksBySequence[sequence]?.bytes
}

private fun ByteArray.indexOfSubsequence(needle: ByteArray): Int {
    if (needle.isEmpty() || needle.size > size) return -1
    for (index in 0..size - needle.size) {
        if (needle.indices.all { offset -> this[index + offset] == needle[offset] }) return index
    }
    return -1
}
