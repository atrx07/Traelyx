package io.github.atrx07.traelyx.guardian

import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.Assert.*
import org.junit.Test

class GuardianRecipientRevokeJournalTest {
    private val ticket = GuardianRecipientRevokeTicket(
        "11111111-1111-4111-8111-111111111111",
        "22222222-2222-4222-8222-222222222222",
        "33333333-3333-4333-8333-333333333333",
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
        fun journal(domain: String = "io.github.atrx07.traelyx/guardian-recipient-revoke/v1") =
            EncryptedGuardianRecipientRevokeJournal(
                disk,
                GuardianVaultCipher(domain = domain, maxPlainBytes = GuardianRecipientRevokeJournalCodec.MAX_BYTES,
                    key = { create -> key ?: if (create) KeyGenerator.getInstance("AES").apply { init(256) }
                        .generateKey().also { key = it } else error("missing key") }),
            )
    }

    @Test fun `empty state creates no key and record survives restart without plaintext IDs`() {
        val f = Fixture()
        assertEquals(emptyList<GuardianRecipientRevokeTicket>(), f.journal().pending())
        assertNull(f.key)
        f.journal().record(ticket)
        val ciphertext = String(f.disk.bytes!!, Charsets.ISO_8859_1)
        assertFalse(ciphertext.contains(ticket.ownerId))
        assertFalse(ciphertext.contains(ticket.deviceId))
        assertEquals(listOf(ticket), f.journal().pending())
        assertFalse(ticket.toString().contains(ticket.ownerId))
    }

    @Test fun `duplicate record and confirmation are idempotent and exact`() {
        val journal = Fixture().journal()
        journal.record(ticket)
        journal.record(ticket)
        val other = ticket.copy(generation = "44444444-4444-4444-8444-444444444444")
        journal.record(other)
        journal.confirm(ticket)
        journal.confirm(ticket)
        assertEquals(listOf(other), journal.pending())
        journal.confirm(other)
        assertTrue(journal.pending().isEmpty())
    }

    @Test fun `capacity never discards an unconfirmed ticket`() {
        val journal = Fixture().journal()
        val tickets = (1..GuardianRecipientRevokeJournalCodec.MAX_TICKETS).map {
            ticket.copy(deviceId = "${it.toString().padStart(8, '0')}-2222-4222-8222-222222222222")
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
            journal.record(ticket.copy(generation = "44444444-4444-4444-8444-444444444444"))
        }
        assertThrows(GuardianVaultUnavailable::class.java) { journal.pending() }
        assertEquals(listOf(ticket), f.journal().pending())
    }

    @Test fun `codec refuses drift duplicates trailing bytes and invalid IDs`() {
        val bytes = GuardianRecipientRevokeJournalCodec.encode(listOf(ticket))
        assertThrows(IllegalArgumentException::class.java) { GuardianRecipientRevokeJournalCodec.decode(bytes + byteArrayOf(0)) }
        assertThrows(IllegalArgumentException::class.java) {
            GuardianRecipientRevokeJournalCodec.decode(bytes.copyOf().also { it[3] = 2 })
        }
        assertThrows(IllegalArgumentException::class.java) {
            GuardianRecipientRevokeJournalCodec.decode(ByteArray(GuardianRecipientRevokeJournalCodec.MAX_BYTES + 1))
        }
        assertThrows(IllegalArgumentException::class.java) { GuardianRecipientRevokeJournalCodec.encode(listOf(ticket, ticket)) }
        assertThrows(IllegalArgumentException::class.java) { ticket.copy(ownerId = "bad") }
    }
}
