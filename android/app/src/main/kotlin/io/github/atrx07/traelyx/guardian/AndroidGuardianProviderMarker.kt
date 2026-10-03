package io.github.atrx07.traelyx.guardian

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.io.FileOutputStream

/** A no-backup, account-free cleanup marker; even interrupted writes demand cleanup. */
class AndroidGuardianProviderMarker(context: Context, namespace: String = "primary") : GuardianProviderMarker {
    private val root = File(context.noBackupFilesDir, "guardian")
    private val file: File
    private val atomic: AtomicFile

    init {
        require(namespace == "primary" || namespace.matches(Regex("proof-[a-f0-9-]{36}")))
        file = File(root, "recipient-provider-$namespace.v1")
        atomic = AtomicFile(file)
    }

    private fun variants() = listOf(file, File(file.path + ".bak"), File(file.path + ".new"))

    @Synchronized override fun present(): Boolean = synchronized(LOCK) { variants().any { it.exists() } }

    @Synchronized override fun mark() = synchronized(LOCK) {
        check(root.isDirectory || root.mkdirs())
        var stream: FileOutputStream? = null
        try {
            stream = atomic.startWrite()
            stream.write(byteArrayOf(1))
            stream.fd.sync()
            atomic.finishWrite(stream)
            check(file.isFile && file.length() == 1L)
        } catch (error: Exception) {
            atomic.failWrite(stream)
            throw error
        }
    }

    @Synchronized override fun clear() = synchronized(LOCK) {
        atomic.delete()
        check(variants().none { it.exists() })
    }

    companion object { private val LOCK = Any() }
}
