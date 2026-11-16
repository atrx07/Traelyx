package io.github.atrx07.traelyx.intelligence

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Test

class LocalCommentaryStorageTest {
    @Test fun canonicalizesTrustedParentWithoutAdoptingNamespaceAliases() {
        val parent = Files.createTempDirectory("local-commentary-parent").toFile().canonicalFile
        try {
            val noBackup = parent.resolve("no_backup").apply { mkdir() }
            val root = LocalCommentaryStorage.root(parent.resolve("no_backup/../no_backup"))
            assertEquals(noBackup.resolve("local_commentary/v1"), root)
            root.mkdirs()
            assertEquals(0L, LocalCommentaryStorage.bytes(root))
        } finally { parent.deleteRecursively() }
    }
    @Test fun countsWeightsReceiptsAndPartialsWithoutTouchingSiblingData() {
        val parent = Files.createTempDirectory("local-commentary").toFile().canonicalFile
        try {
            val root = parent.resolve("models").apply { mkdir() }
            parent.resolve("trip.bin").writeBytes(ByteArray(31))
            val installed = root.resolve("a".repeat(64)).apply { mkdir() }
            installed.resolve("weights").writeBytes(ByteArray(7))
            installed.resolve("receipt.json").writeBytes(ByteArray(3))
            val partial = root.resolve("b".repeat(64) + ".partial").apply { mkdir() }
            partial.resolve("weights").writeBytes(ByteArray(5))
            root.resolve(".lock").writeBytes(byteArrayOf())
            assertEquals(15L, LocalCommentaryStorage.bytes(root))
            assertEquals(0L, LocalCommentaryStorage.bytes(parent.resolve("missing")))
            assertEquals(31L, parent.resolve("trip.bin").length())
        } finally { parent.deleteRecursively() }
    }

    @Test(expected = IllegalStateException::class)
    fun refusesUnknownNamespaceContent() {
        val root = Files.createTempDirectory("local-commentary").toFile().canonicalFile
        try {
            root.resolve("unknown").writeText("private")
            LocalCommentaryStorage.bytes(root)
        } finally { root.deleteRecursively() }
    }
}
