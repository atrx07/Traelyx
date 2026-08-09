package io.github.atrx07.traelyx.diagnostics

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Test

class DiagnosticsStorageTest {
    @Test
    fun sumsOnlyExistingFileBytesRecursively() {
        val root = Files.createTempDirectory("traelyx-diagnostics").toFile()
        try {
            root.resolve("one.bin").writeBytes(ByteArray(3))
            root.resolve("nested").mkdirs()
            root.resolve("nested/two.bin").writeBytes(ByteArray(5))

            assertEquals(8L, DiagnosticsStorage.sizeOf(root))
            assertEquals(
                8L,
                DiagnosticsStorage.sumFiles(
                    listOf(root.resolve("one.bin"), root.resolve("nested")),
                ),
            )
            assertEquals(0L, DiagnosticsStorage.sizeOf(root.resolve("missing")))
        } finally {
            root.deleteRecursively()
        }
    }
}
