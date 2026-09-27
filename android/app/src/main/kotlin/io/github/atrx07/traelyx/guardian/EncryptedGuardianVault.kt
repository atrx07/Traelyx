package io.github.atrx07.traelyx.guardian

/** Implementations atomically replace bounded ciphertext. No plaintext reaches this interface. */
interface GuardianSealedStorage {
    fun read(): ByteArray?
    fun replace(bytes: ByteArray)
    fun delete()
}

class GuardianVaultUnavailable : IllegalStateException("Guardian encrypted storage unavailable")

class EncryptedGuardianVault(
    private val storage: GuardianSealedStorage,
    private val cipher: GuardianVaultCipher,
    private val destroyKey: () -> Unit,
) : GuardianVault {
    private var failed = false

    @Synchronized override fun read(): GuardianVaultSnapshot {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val bytes = storage.read() ?: return GuardianVaultSnapshot()
            val plain = cipher.open(bytes)
            return try { GuardianVaultCodec.decode(plain) } finally { plain.fill(0) }
        } catch (_: Exception) {
            failed = true
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized override fun write(snapshot: GuardianVaultSnapshot) {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val plain = GuardianVaultCodec.encode(snapshot)
            val sealed = try { cipher.seal(plain) } finally { plain.fill(0) }
            storage.replace(sealed)
            check(storage.read()?.contentEquals(sealed) == true)
        } catch (_: Exception) {
            failed = true
            // On uncertain commit, disable recovery rather than restoring an older reservation.
            runCatching { destroyKey() }
            runCatching { storage.delete() }
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized override fun erase() {
        failed = true
        try {
            val keyResult = runCatching { destroyKey() }
            val fileResult = runCatching { storage.delete() }
            keyResult.getOrThrow()
            fileResult.getOrThrow()
            check(storage.read() == null)
            failed = false
        } catch (_: Exception) { throw GuardianVaultUnavailable() }
    }
}
