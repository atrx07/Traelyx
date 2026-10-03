package io.github.atrx07.traelyx.guardian

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Separate no-backup Keystore domain for ID-only server-revocation work. */
class AndroidGuardianRecipientRevokeJournal(context: Context, private val namespace: String = "primary") :
    GuardianRecipientRevokeJournal {
    private val delegate: EncryptedGuardianRecipientRevokeJournal
    private val storage: GuardianSealedStorage
    private val alias: String

    init {
        require(namespace == "primary" || namespace.matches(Regex("proof-[a-f0-9-]{36}")))
        val root = File(context.noBackupFilesDir, "guardian")
        val file = File(root, "revoke-$namespace.vault")
        val atomic = AtomicFile(file)
        alias = "io.github.atrx07.traelyx.guardian.revoke.v1.$namespace"
        val cipher = GuardianVaultCipher(
            key = { create ->
                val existing = keyStore().getKey(alias, null) as? SecretKey
                existing ?: run {
                    check(create) { "Missing Guardian revoke journal key" }
                    KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                        init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                            .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                            .setRandomizedEncryptionRequired(true)
                            .setUserAuthenticationRequired(false).build())
                    }.generateKey()
                }
            },
            domain = "io.github.atrx07.traelyx/guardian-recipient-revoke/v1",
            maxPlainBytes = GuardianRecipientRevokeJournalCodec.MAX_BYTES,
        )
        storage = object : GuardianSealedStorage {
            override fun read(): ByteArray? {
                if (!file.exists() && !File(file.path + ".bak").exists()) {
                    check(!File(file.path + ".new").exists())
                    check(!keyStore().containsAlias(alias)) { "Missing Guardian revoke journal with existing key" }
                    return null
                }
                return atomic.openRead().use { input ->
                    val bytes = ByteArrayOutputStream()
                    val buffer = ByteArray(1024)
                    while (true) {
                        val n = input.read(buffer)
                        if (n == -1) break
                        check(bytes.size() + n <= GuardianRecipientRevokeJournalCodec.MAX_BYTES + 29)
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
        delegate = EncryptedGuardianRecipientRevokeJournal(storage, cipher)
    }

    override fun pending() = synchronized(LOCK) { delegate.pending() }
    override fun record(ticket: GuardianRecipientRevokeTicket) = synchronized(LOCK) { delegate.record(ticket) }
    override fun confirm(ticket: GuardianRecipientRevokeTicket) = synchronized(LOCK) { delegate.confirm(ticket) }

    /** Instrumentation uses a random proof namespace and removes its own key/file. */
    fun eraseProofState() = synchronized(LOCK) {
        require(namespace.startsWith("proof-"))
        keyStore().deleteEntry(alias)
        storage.delete()
    }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    companion object { private val LOCK = Any() }
}
