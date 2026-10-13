package io.github.atrx07.traelyx.guardian

import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.Assert.*
import org.junit.Test

class GuardianDriverRevokeJournalTest {
    private val ticket = GuardianDriverRevokeTicket(
        "11111111-1111-4111-8111-111111111111",
        "22222222-2222-4222-8222-222222222222",
    )

    private class Storage : GuardianSealedStorage {
        var bytes: ByteArray? = null
        var failReplace = false
        override fun read() = bytes?.copyOf()
        override fun replace(bytes: ByteArray) {
            if (failReplace) error("storage failure")
            this.bytes = bytes.copyOf()
        }
        override fun delete() { bytes = null }
    }

    private class Fixture {
        val disk = Storage()
        var key: SecretKey? = null
        fun journal(domain: String = "io.github.atrx07.traelyx/guardian-driver-revoke/v1") =
            EncryptedGuardianDriverRevokeJournal(
                disk,
                GuardianVaultCipher(domain = domain, maxPlainBytes = GuardianDriverRevokeJournalCodec.MAX_BYTES,
                    key = { create -> key ?: if (create) KeyGenerator.getInstance("AES").apply { init(256) }
                        .generateKey().also { key = it } else error("missing key") }),
            )
    }

    @Test fun `empty state creates no key and record survives restart without plaintext IDs`() {
        val f = Fixture()
        assertEquals(emptyList<GuardianDriverRevokeTicket>(), f.journal().pending())
        assertNull(f.key)
        f.journal().record(ticket)
        val ciphertext = String(f.disk.bytes!!, Charsets.ISO_8859_1)
        assertFalse(ciphertext.contains(ticket.ownerId))
        assertFalse(ciphertext.contains(ticket.activationId))
        assertEquals(listOf(ticket), f.journal().pending())
        assertFalse(ticket.toString().contains(ticket.ownerId))
    }

    @Test fun `duplicate record and confirmation are idempotent and exact`() {
        val journal = Fixture().journal()
        journal.record(ticket)
        journal.record(ticket)
        val other = ticket.copy(activationId = "44444444-4444-4444-8444-444444444444")
        journal.record(other)
        journal.confirm(ticket)
        journal.confirm(ticket)
        assertEquals(listOf(other), journal.pending())
        journal.confirm(other)
        assertTrue(journal.pending().isEmpty())
    }

    @Test fun `capacity never discards an unconfirmed ticket`() {
        val journal = Fixture().journal()
        val tickets = (1..GuardianDriverRevokeJournalCodec.MAX_TICKETS).map {
            ticket.copy(activationId = "${it.toString().padStart(8, '0')}-2222-4222-8222-222222222222")
        }
        tickets.forEach(journal::record)
        assertThrows(IllegalArgumentException::class.java) { journal.record(ticket) }
        assertEquals(tickets, journal.pending())
    }

    @Test fun `corruption lost key and wrong encryption domain deny reads`() {
        val f = Fixture()
        f.journal().record(ticket)
        val sealed = f.disk.bytes!!.copyOf()
        f.disk.bytes = sealed.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
        assertThrows(GuardianVaultUnavailable::class.java) { f.journal().pending() }
        f.disk.bytes = sealed
        assertThrows(GuardianVaultUnavailable::class.java) { f.journal("other-domain").pending() }
        f.key = null
        assertThrows(GuardianVaultUnavailable::class.java) { f.journal().pending() }
    }

    @Test fun `uncertain write blocks instance but preserves prior durable ticket`() {
        val f = Fixture()
        val journal = f.journal()
        journal.record(ticket)
        f.disk.failReplace = true
        assertThrows(GuardianVaultUnavailable::class.java) {
            journal.record(ticket.copy(activationId = "44444444-4444-4444-8444-444444444444"))
        }
        assertThrows(GuardianVaultUnavailable::class.java) { journal.pending() }
        assertEquals(listOf(ticket), f.journal().pending())
    }

    @Test fun `codec refuses drift duplicates trailing bytes and invalid IDs`() {
        val bytes = GuardianDriverRevokeJournalCodec.encode(listOf(ticket))
        assertThrows(IllegalArgumentException::class.java) { GuardianDriverRevokeJournalCodec.decode(bytes + byteArrayOf(0)) }
        assertThrows(IllegalArgumentException::class.java) {
            GuardianDriverRevokeJournalCodec.decode(bytes.copyOf().also { it[3] = 2 })
        }
        assertThrows(IllegalArgumentException::class.java) {
            GuardianDriverRevokeJournalCodec.decode(ByteArray(GuardianDriverRevokeJournalCodec.MAX_BYTES + 1))
        }
        assertThrows(IllegalArgumentException::class.java) { GuardianDriverRevokeJournalCodec.encode(listOf(ticket, ticket)) }
        assertThrows(IllegalArgumentException::class.java) { ticket.copy(ownerId = "bad") }
    }
}
