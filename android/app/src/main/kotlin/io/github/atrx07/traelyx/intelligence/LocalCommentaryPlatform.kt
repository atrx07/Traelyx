package io.github.atrx07.traelyx.intelligence

import android.content.Context
import android.os.Build
import java.io.File

/** Metadata only: no runtime, network, weights, recorder or permission changes. */
object LocalCommentaryPlatform {
    const val CHANNEL = "io.github.atrx07.traelyx/local_commentary/v1"

    fun device(context: Context): Map<String, Any> {
        val parent = context.noBackupFilesDir.canonicalFile
        val root = LocalCommentaryStorage.root(context.noBackupFilesDir)
        check(root.mkdirs() || root.isDirectory)
        check(root.canonicalFile == root.absoluteFile)
        check(root.canonicalPath.startsWith(parent.path + File.separator))
        return mapOf(
            "version" to 1,
            "root" to root.canonicalPath,
            "api" to Build.VERSION.SDK_INT,
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "freeBytes" to root.usableSpace,
        )
    }
}

/** Bounded, link-refusing storage accounting shared by diagnostics. No reads of
 * model contents or recursion into other app data. Missing namespace costs 0B. */
internal object LocalCommentaryStorage {
    // Android may supply /data/user/0 while canonical paths use /data/data.
    // Normalize the trusted parent, then refuse links inside our namespace.
    fun root(noBackupDirectory: File): File = File(noBackupDirectory.canonicalFile, "local_commentary/v1")

    fun bytes(root: File): Long {
        if (!root.exists()) return 0L
        check(root.canonicalFile == root.absoluteFile && root.isDirectory)
        val entries = checkNotNull(root.listFiles())
        check(entries.size <= 17)
        return entries.sumOf { entry ->
            check(entry.canonicalFile == entry.absoluteFile)
            if (entry.name == ".lock") {
                check(entry.isFile && entry.length() == 0L)
                entry.length()
            } else {
                check(Regex("^[a-f0-9]{64}(\\.partial)?$").matches(entry.name) && entry.isDirectory)
                val files = checkNotNull(entry.listFiles())
                check(files.size <= 2)
                files.sumOf { file ->
                    check(file.name in setOf("weights", "receipt.json") && file.isFile && file.canonicalFile == file.absoluteFile)
                    file.length()
                }
            }
        }
    }
}
