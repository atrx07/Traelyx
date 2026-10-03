package io.github.atrx07.traelyx.guardian

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream

/** Only the IDs needed to revoke an orphaned server row; never a push token or credential. */
data class GuardianRecipientRevokeTicket(
    val ownerId: String,
    val deviceId: String,
    val generation: String,
) {
    init { guardianUuid(ownerId); guardianUuid(deviceId); guardianUuid(generation) }
    override fun toString() = "GuardianRecipientRevokeTicket(redacted)"
}

internal object GuardianRecipientRevokeJournalCodec {
    const val MAX_TICKETS = 8
    const val MAX_BYTES = 4096

    fun encode(tickets: List<GuardianRecipientRevokeTicket>): ByteArray {
        require(tickets.size <= MAX_TICKETS && tickets.distinct().size == tickets.size)
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.writeInt(1)
            output.writeInt(tickets.size)
            tickets.forEach {
                output.writeUTF(it.ownerId)
                output.writeUTF(it.deviceId)
                output.writeUTF(it.generation)
            }
        }
        return bytes.toByteArray().also { require(it.size in 1..MAX_BYTES) }
    }

    fun decode(bytes: ByteArray): List<GuardianRecipientRevokeTicket> {
        require(bytes.size in 1..MAX_BYTES)
        return DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            require(input.readInt() == 1)
            val count = input.readInt().also { require(it in 0..MAX_TICKETS) }
            val tickets = List(count) {
                GuardianRecipientRevokeTicket(input.readUTF(), input.readUTF(), input.readUTF())
            }
            require(input.available() == 0 && tickets.distinct().size == tickets.size)
            tickets
        }
    }
}

/** Missing state is empty. Any uncertain read/write denies further mutations in this instance. */
interface GuardianRecipientRevokeJournal {
    fun pending(): List<GuardianRecipientRevokeTicket>
    fun record(ticket: GuardianRecipientRevokeTicket)
    fun confirm(ticket: GuardianRecipientRevokeTicket)
}

class EncryptedGuardianRecipientRevokeJournal(
    private val storage: GuardianSealedStorage,
    private val cipher: GuardianVaultCipher,
) : GuardianRecipientRevokeJournal {
    private var failed = false

    @Synchronized override fun pending(): List<GuardianRecipientRevokeTicket> {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val sealed = storage.read() ?: return emptyList()
            val plain = cipher.open(sealed)
            return try { GuardianRecipientRevokeJournalCodec.decode(plain) } finally { plain.fill(0) }
        } catch (_: Exception) {
            failed = true
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized override fun record(ticket: GuardianRecipientRevokeTicket) {
        val current = pending()
        if (ticket in current) return
        write(current + ticket)
    }

    @Synchronized override fun confirm(ticket: GuardianRecipientRevokeTicket) {
        val current = pending()
        if (ticket !in current) return
        write(current - ticket)
    }

    private fun write(tickets: List<GuardianRecipientRevokeTicket>) {
        if (failed) throw GuardianVaultUnavailable()
        // Capacity failure leaves the existing journal readable and unchanged.
        val plain = GuardianRecipientRevokeJournalCodec.encode(tickets)
        try {
            val sealed = try { cipher.seal(plain) } finally { plain.fill(0) }
            storage.replace(sealed)
            check(storage.read()?.contentEquals(sealed) == true)
        } catch (_: Exception) {
            plain.fill(0)
            failed = true
            throw GuardianVaultUnavailable()
        }
    }
}
