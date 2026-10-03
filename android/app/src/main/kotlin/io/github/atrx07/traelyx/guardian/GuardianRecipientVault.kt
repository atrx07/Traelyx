package io.github.atrx07.traelyx.guardian

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream

/** Receipt authority for one opted-in device. It cannot authorize alert details. */
data class GuardianRecipientDevice(
    val ownerId: String,
    val deviceId: String,
    val generation: String,
    val credential: String,
    val registeredAtEpochMillis: Long,
    val expiresAtEpochMillis: Long,
) {
    init {
        guardianUuid(ownerId); guardianUuid(deviceId); guardianUuid(generation)
        require(credential.matches(Regex("[a-f0-9]{64}")))
        require(registeredAtEpochMillis > 0 && expiresAtEpochMillis > registeredAtEpochMillis)
        require(expiresAtEpochMillis - registeredAtEpochMillis <= MAX_LIFETIME_MILLIS)
    }

    fun validFor(owner: String, expectedGeneration: String, nowEpochMillis: Long): Boolean =
        ownerId == owner && generation == expectedGeneration &&
            nowEpochMillis in registeredAtEpochMillis until expiresAtEpochMillis

    override fun toString() = "GuardianRecipientDevice(redacted)"

    companion object { const val MAX_LIFETIME_MILLIS = 30L * 24 * 60 * 60 * 1000 }
}

/** Separate version and encryption domain from the driver lease/outbox. */
internal object GuardianRecipientVaultCodec {
    const val MAX_BYTES = 4096

    fun encode(device: GuardianRecipientDevice): ByteArray {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.writeInt(1)
            output.writeUTF(device.ownerId)
            output.writeUTF(device.deviceId)
            output.writeUTF(device.generation)
            output.writeUTF(device.credential)
            output.writeLong(device.registeredAtEpochMillis)
            output.writeLong(device.expiresAtEpochMillis)
        }
        return bytes.toByteArray().also { require(it.size in 1..MAX_BYTES) }
    }

    fun decode(bytes: ByteArray): GuardianRecipientDevice {
        require(bytes.size in 1..MAX_BYTES)
        return DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            require(input.readInt() == 1)
            val device = GuardianRecipientDevice(
                input.readUTF(), input.readUTF(), input.readUTF(), input.readUTF(),
                input.readLong(), input.readLong(),
            )
            require(input.available() == 0)
            device
        }
    }
}

/** Missing state is inert. Corruption and uncertain writes disable this instance. */
class EncryptedGuardianRecipientVault(
    private val storage: GuardianSealedStorage,
    private val cipher: GuardianVaultCipher,
    private val destroyKey: () -> Unit,
) {
    private var failed = false

    @Synchronized fun readBound(owner: String, generation: String, nowEpochMillis: Long): GuardianRecipientDevice? {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val sealed = storage.read() ?: return null
            val plain = cipher.open(sealed)
            val device = try { GuardianRecipientVaultCodec.decode(plain) } finally { plain.fill(0) }
            return device.takeIf { it.validFor(owner, generation, nowEpochMillis) }
        } catch (_: Exception) {
            failed = true
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized fun write(device: GuardianRecipientDevice) {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val plain = GuardianRecipientVaultCodec.encode(device)
            val sealed = try { cipher.seal(plain) } finally { plain.fill(0) }
            storage.replace(sealed)
            check(storage.read()?.contentEquals(sealed) == true)
        } catch (_: Exception) {
            failed = true
            runCatching { destroyKey() }
            runCatching { storage.delete() }
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized fun erase() {
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
