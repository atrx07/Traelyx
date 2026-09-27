package io.github.atrx07.traelyx.guardian

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Credential-encrypted, no-backup storage; keys never leave Android Keystore. */
class AndroidGuardianVault(context: Context, namespace: String = "primary") : GuardianVault {
    private val delegate: EncryptedGuardianVault

    init {
        require(namespace == "primary" || namespace.matches(Regex("proof-[a-f0-9-]{36}")))
        val root = File(context.noBackupFilesDir, "guardian")
        val file = File(root, "$namespace.vault")
        val atomic = AtomicFile(file)
        val alias = "io.github.atrx07.traelyx.guardian.v1.$namespace"
        fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val cipher = GuardianVaultCipher { create ->
            val existing = keyStore().getKey(alias, null) as? SecretKey
            existing ?: run {
                check(create) { "Missing Guardian key" }
                KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                    init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                        .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setRandomizedEncryptionRequired(true)
                        .setUserAuthenticationRequired(false).build())
                }.generateKey()
            }
        }
        val storage = object : GuardianSealedStorage {
            override fun read(): ByteArray? {
                if (!file.exists() && !File(file.path + ".bak").exists()) {
                    check(!File(file.path + ".new").exists())
                    return null
                }
                return atomic.openRead().use { input ->
                    val bytes = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(4096)
                    while (true) {
                        val n = input.read(buffer)
                        if (n == -1) break
                        check(bytes.size() + n <= GuardianVaultCipher.MAX_SEALED_BYTES)
                        bytes.write(buffer, 0, n)
                    }
                    bytes.toByteArray()
                }
            }
            override fun replace(bytes: ByteArray) {
                check(root.isDirectory || root.mkdirs())
                var stream: FileOutputStream? = null
                try {
                    stream = atomic.startWrite()
                    stream.write(bytes)
                    stream.fd.sync()
                    atomic.finishWrite(stream)
                } catch (error: Exception) {
                    atomic.failWrite(stream)
                    throw error
                }
            }
            override fun delete() {
                atomic.delete()
                check(listOf(file, File(file.path + ".bak"), File(file.path + ".new")).none { it.exists() })
            }
        }
        delegate = EncryptedGuardianVault(storage, cipher) { keyStore().deleteEntry(alias) }
    }

    override fun read() = synchronized(LOCK) { delegate.read() }
    override fun write(snapshot: GuardianVaultSnapshot) = synchronized(LOCK) { delegate.write(snapshot) }
    override fun erase() = synchronized(LOCK) { delegate.erase() }

    companion object {
        private val LOCK = Any()
        @Volatile private var outbox: GuardianOutbox? = null
        fun outbox(context: Context): GuardianOutbox = synchronized(LOCK) {
            outbox ?: GuardianOutbox(AndroidGuardianVault(context.applicationContext)).also { outbox = it }
        }
    }
}
