package io.github.atrx07.traelyx.guardian

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.util.UUID

/** Receipt authority for one opted-in device. It cannot authorize alert details. */
data class GuardianRecipientDevice(
    val ownerId: String,
    val deviceId: String,
    val generation: String,
    val credential: String,
    val registeredAtEpochMillis: Long,
    val expiresAtEpochMillis: Long,
    val noticeDeliveryIds: List<String> = emptyList(),
) {
    init {
        guardianUuid(ownerId); guardianUuid(deviceId); guardianUuid(generation)
        require(credential.matches(Regex("[a-f0-9]{64}")))
        require(registeredAtEpochMillis > 0 && expiresAtEpochMillis > registeredAtEpochMillis)
        require(expiresAtEpochMillis - registeredAtEpochMillis <= MAX_LIFETIME_MILLIS)
        require(noticeDeliveryIds.size <= MAX_NOTICE_IDS && noticeDeliveryIds.distinct().size == noticeDeliveryIds.size)
        noticeDeliveryIds.forEach(::guardianUuid)
    }

    fun validFor(owner: String, expectedGeneration: String, nowEpochMillis: Long): Boolean =
        ownerId == owner && generation == expectedGeneration &&
            nowEpochMillis in registeredAtEpochMillis until expiresAtEpochMillis

    override fun toString() = "GuardianRecipientDevice(redacted)"

    companion object {
        const val MAX_LIFETIME_MILLIS = 30L * 24 * 60 * 60 * 1000
        const val MAX_NOTICE_IDS = 1024
    }
}

/** Separate version and encryption domain from the driver lease/outbox. */
internal object GuardianRecipientVaultCodec {
    const val MAX_BYTES = 20 * 1024

    fun encode(device: GuardianRecipientDevice): ByteArray {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.writeInt(2)
            output.writeUTF(device.ownerId)
            output.writeUTF(device.deviceId)
            output.writeUTF(device.generation)
            output.writeUTF(device.credential)
            output.writeLong(device.registeredAtEpochMillis)
            output.writeLong(device.expiresAtEpochMillis)
            output.writeInt(device.noticeDeliveryIds.size)
            device.noticeDeliveryIds.forEach { id ->
                val uuid = UUID.fromString(id)
                output.writeLong(uuid.mostSignificantBits)
                output.writeLong(uuid.leastSignificantBits)
            }
        }
        return bytes.toByteArray().also { require(it.size in 1..MAX_BYTES) }
    }

    fun decode(bytes: ByteArray): GuardianRecipientDevice {
        require(bytes.size in 1..MAX_BYTES)
        return DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            val version = input.readInt()
            require(version == 1 || version == 2)
            val legacy = GuardianRecipientDevice(
                input.readUTF(), input.readUTF(), input.readUTF(), input.readUTF(),
                input.readLong(), input.readLong(),
            )
            val device = if (version == 1) legacy else {
                val count = input.readInt()
                require(count in 0..GuardianRecipientDevice.MAX_NOTICE_IDS)
                legacy.copy(noticeDeliveryIds = List(count) { UUID(input.readLong(), input.readLong()).toString() })
            }
            require(input.available() == 0)
            device
        }
    }
}

/** Native-only receipt authority. Callers must first bind the current Auth owner. */
interface GuardianRecipientVault {
    fun readStored(): GuardianRecipientDevice?
    fun write(device: GuardianRecipientDevice)
    fun erase()

    fun readBound(owner: String, generation: String, nowEpochMillis: Long): GuardianRecipientDevice? =
        readStored()?.takeIf { it.validFor(owner, generation, nowEpochMillis) }
}

/** Missing state is inert. Corruption and uncertain writes disable this instance. */
class EncryptedGuardianRecipientVault(
    private val storage: GuardianSealedStorage,
    private val cipher: GuardianVaultCipher,
    private val destroyKey: () -> Unit,
) : GuardianRecipientVault {
    private var failed = false

    @Synchronized override fun readStored(): GuardianRecipientDevice? {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val sealed = storage.read() ?: return null
            val plain = cipher.open(sealed)
            return try { GuardianRecipientVaultCodec.decode(plain) } finally { plain.fill(0) }
        } catch (_: Exception) {
            failed = true
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized override fun write(device: GuardianRecipientDevice) {
        if (failed) throw GuardianVaultUnavailable()
        try {
            persist(device)
        } catch (_: Exception) {
            failed = true
            runCatching { destroyKey() }
            runCatching { storage.delete() }
            throw GuardianVaultUnavailable()
        }
    }

    /** Persist before display. No eviction: replay cannot resurrect a dismissed notice. */
    @Synchronized fun claimNotice(
        deviceId: String, generation: String, credential: String, deliveryId: String, nowEpochMillis: Long,
    ): Boolean {
        guardianUuid(deliveryId)
        val stored = readStored() ?: return false
        if (stored.deviceId != deviceId || stored.credential != credential ||
            !stored.validFor(stored.ownerId, generation, nowEpochMillis) ||
            deliveryId in stored.noticeDeliveryIds ||
            stored.noticeDeliveryIds.size == GuardianRecipientDevice.MAX_NOTICE_IDS) return false
        try {
            persist(stored.copy(noticeDeliveryIds = stored.noticeDeliveryIds + deliveryId))
        } catch (_: Exception) {
            // Keep the atomic old/new encrypted record and key for restart/revocation.
            // This instance cannot display after an uncertain write.
            failed = true
            throw GuardianVaultUnavailable()
        }
        return true
    }

    private fun persist(device: GuardianRecipientDevice) {
        val plain = GuardianRecipientVaultCodec.encode(device)
        val sealed = try { cipher.seal(plain) } finally { plain.fill(0) }
        storage.replace(sealed)
        check(storage.read()?.contentEquals(sealed) == true)
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
