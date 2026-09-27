package io.github.atrx07.traelyx.guardian

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal fun guardianUuid(value: String) { require(UUID.fromString(value).toString() == value) }

/** Native-only background authority. Never expose credentials through logs or status maps. */
data class GuardianDriverLease(
    val ownerId: String,
    val activationId: String,
    val credential: String,
    val startedEpochMillis: Long,
    val startedElapsedMillis: Long,
    val expiresEpochMillis: Long,
    val bootId: String,
    val forwardAxis: String,
) {
    init {
        guardianUuid(ownerId); guardianUuid(activationId)
        require(credential.matches(Regex("[a-f0-9]{64}")))
        require(startedEpochMillis > 0 && startedElapsedMillis >= 0)
        require(expiresEpochMillis > startedEpochMillis && expiresEpochMillis - startedEpochMillis <= MAX_DURATION_MILLIS)
        require(bootId.isNotBlank() && bootId.length <= 128)
        require(forwardAxis in setOf("+x", "-x", "+y", "-y", "+z", "-z"))
    }

    fun valid(now: GuardianClock, owner: String) = ownerId == owner && bootId == now.bootId &&
        now.epochMillis in startedEpochMillis until expiresEpochMillis &&
        now.elapsedMillis >= startedElapsedMillis &&
        now.elapsedMillis - startedElapsedMillis < expiresEpochMillis - startedEpochMillis

    override fun toString() = "GuardianDriverLease(redacted)"
    companion object { const val MAX_DURATION_MILLIS = 8 * 60 * 60 * 1000L }
}

data class GuardianClock(val epochMillis: Long, val elapsedMillis: Long, val bootId: String) {
    init { require(epochMillis > 0 && elapsedMillis >= 0 && bootId.isNotBlank()) }
}

data class GuardianVaultSnapshot(
    val lease: GuardianDriverLease? = null,
    val cooldowns: GuardianSafetyCooldowns = GuardianSafetyCooldowns(),
    val alerts: List<GuardianPendingAlert> = emptyList(),
) {
    init {
        require(alerts.size <= MAX_ALERTS && alerts.map { it.eventId }.distinct().size == alerts.size)
        require(lease != null || (alerts.isEmpty() && cooldowns == GuardianSafetyCooldowns()))
        require(alerts.all { it.ownerId == lease?.ownerId && it.consentGeneration == lease.activationId && it.bootId == lease.bootId })
    }
    override fun toString() = "GuardianVaultSnapshot(redacted, alerts=${alerts.size})"
    companion object { const val MAX_ALERTS = 16 }
}

/** A missing file is empty. Corruption, key loss and write failures throw; never silently reset. */
interface GuardianVault {
    fun read(): GuardianVaultSnapshot
    fun write(snapshot: GuardianVaultSnapshot)
    /** Destroy the encryption key before removing ciphertext; interrupted erasure fails closed. */
    fun erase()
}

/** Explicit bounded binary schema; unknown versions, trailing bytes and malformed values are rejected. */
object GuardianVaultCodec {
    const val MAX_BYTES = 32_768
    fun encode(snapshot: GuardianVaultSnapshot): ByteArray {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { out ->
            out.writeInt(1)
            out.writeBoolean(snapshot.lease != null)
            snapshot.lease?.let {
                out.writeUTF(it.ownerId); out.writeUTF(it.activationId); out.writeUTF(it.credential)
                out.writeLong(it.startedEpochMillis); out.writeLong(it.startedElapsedMillis); out.writeLong(it.expiresEpochMillis)
                out.writeUTF(it.bootId); out.writeUTF(it.forwardAxis)
            }
            out.writeLong(snapshot.cooldowns.lastSevereNanos ?: -1)
            out.writeLong(snapshot.cooldowns.lastCrashNanos ?: -1)
            out.writeInt(snapshot.alerts.size)
            snapshot.alerts.forEach {
                out.writeUTF(it.eventId); out.writeUTF(it.ownerId); out.writeUTF(it.consentGeneration)
                out.writeUTF(it.kind.name); out.writeLong(it.occurredAtEpochMillis); out.writeLong(it.createdAtElapsedMillis)
                out.writeUTF(it.bootId); out.writeInt(it.ruleVersion); out.writeUTF(it.state.name)
                out.writeInt(it.attempts); out.writeLong(it.nextAttemptAtElapsedMillis)
            }
        }
        return bytes.toByteArray().also { require(it.size <= MAX_BYTES) }
    }

    fun decode(bytes: ByteArray): GuardianVaultSnapshot {
        require(bytes.size in 1..MAX_BYTES)
        return DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            require(input.readInt() == 1)
            val lease = if (input.readBoolean()) GuardianDriverLease(
                input.readUTF(), input.readUTF(), input.readUTF(), input.readLong(), input.readLong(), input.readLong(),
                input.readUTF(), input.readUTF(),
            ) else null
            fun cooldown(): Long? = input.readLong().also { require(it >= -1) }.takeUnless { it == -1L }
            val cooldowns = GuardianSafetyCooldowns(cooldown(), cooldown())
            val count = input.readInt().also { require(it in 0..GuardianVaultSnapshot.MAX_ALERTS) }
            val alerts = List(count) {
                GuardianPendingAlert(input.readUTF(), input.readUTF(), input.readUTF(),
                    GuardianAlertKind.valueOf(input.readUTF()), input.readLong(), input.readLong(), input.readUTF(),
                    input.readInt(), GuardianSendState.valueOf(input.readUTF()), input.readInt(), input.readLong())
            }
            require(input.available() == 0)
            GuardianVaultSnapshot(lease, cooldowns, alerts)
        }
    }
}

/** Platform/JCA authenticated encryption; IV generated by provider, with format-bound associated data. */
class GuardianVaultCipher(private val key: (create: Boolean) -> SecretKey) {
    fun seal(plain: ByteArray): ByteArray {
        require(plain.size <= GuardianVaultCodec.MAX_BYTES)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        require(cipher.iv.size == 12)
        cipher.updateAAD(AAD)
        return byteArrayOf(1) + cipher.iv + cipher.doFinal(plain)
    }

    fun open(sealed: ByteArray): ByteArray {
        require(sealed.size in 29..MAX_SEALED_BYTES && sealed[0] == 1.toByte())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, sealed.copyOfRange(1, 13)))
        cipher.updateAAD(AAD)
        return cipher.doFinal(sealed, 13, sealed.size - 13)
    }

    companion object {
        const val MAX_SEALED_BYTES = GuardianVaultCodec.MAX_BYTES + 29
        private val AAD = "io.github.atrx07.traelyx/guardian-vault/v1".toByteArray(Charsets.UTF_8)
    }
}
