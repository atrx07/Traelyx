package io.github.atrx07.traelyx.guardian

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream

/** Only the IDs needed to revoke an orphaned server row; never a capability or telemetry. */
data class GuardianDriverRevokeTicket(
    val ownerId: String,
    val activationId: String,
) {
    init { guardianUuid(ownerId); guardianUuid(activationId) }
    override fun toString() = "GuardianDriverRevokeTicket(redacted)"
}

internal object GuardianDriverRevokeJournalCodec {
    const val MAX_TICKETS = 8
    const val MAX_BYTES = 4096

    fun encode(tickets: List<GuardianDriverRevokeTicket>): ByteArray {
        require(tickets.size <= MAX_TICKETS && tickets.distinct().size == tickets.size)
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.writeInt(1)
            output.writeInt(tickets.size)
            tickets.forEach {
                output.writeUTF(it.ownerId)
                output.writeUTF(it.activationId)
            }
        }
        return bytes.toByteArray().also { require(it.size in 1..MAX_BYTES) }
    }

    fun decode(bytes: ByteArray): List<GuardianDriverRevokeTicket> {
        require(bytes.size in 1..MAX_BYTES)
        return DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            require(input.readInt() == 1)
            val count = input.readInt().also { require(it in 0..MAX_TICKETS) }
            val tickets = List(count) {
                GuardianDriverRevokeTicket(input.readUTF(), input.readUTF())
            }
            require(input.available() == 0 && tickets.distinct().size == tickets.size)
            tickets
        }
    }
}

/** Missing state is empty. Any uncertain read/write denies further mutations in this instance. */
interface GuardianDriverRevokeJournal {
    fun pending(): List<GuardianDriverRevokeTicket>
    fun record(ticket: GuardianDriverRevokeTicket)
    fun confirm(ticket: GuardianDriverRevokeTicket)
}

class EncryptedGuardianDriverRevokeJournal(
    private val storage: GuardianSealedStorage,
    private val cipher: GuardianVaultCipher,
) : GuardianDriverRevokeJournal {
    private var failed = false

    @Synchronized override fun pending(): List<GuardianDriverRevokeTicket> {
        if (failed) throw GuardianVaultUnavailable()
        try {
            val sealed = storage.read() ?: return emptyList()
            val plain = cipher.open(sealed)
            return try { GuardianDriverRevokeJournalCodec.decode(plain) } finally { plain.fill(0) }
        } catch (_: Exception) {
            failed = true
            throw GuardianVaultUnavailable()
        }
    }

    @Synchronized override fun record(ticket: GuardianDriverRevokeTicket) {
        val current = pending()
        if (ticket in current) return
        write(current + ticket)
    }

    @Synchronized override fun confirm(ticket: GuardianDriverRevokeTicket) {
        val current = pending()
        if (ticket !in current) return
        write(current - ticket)
    }

    private fun write(tickets: List<GuardianDriverRevokeTicket>) {
        if (failed) throw GuardianVaultUnavailable()
        // Capacity failure leaves the existing journal readable and unchanged.
        val plain = GuardianDriverRevokeJournalCodec.encode(tickets)
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
