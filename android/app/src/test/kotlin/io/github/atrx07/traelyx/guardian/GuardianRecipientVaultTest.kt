package io.github.atrx07.traelyx.guardian

import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.Assert.*
import org.junit.Test

class GuardianRecipientVaultTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val otherOwner = "22222222-2222-4222-8222-222222222222"
    private val deviceId = "33333333-3333-4333-8333-333333333333"
    private val generation = "44444444-4444-4444-8444-444444444444"
    private val otherGeneration = "55555555-5555-4555-8555-555555555555"
    private val registered = 1_800_000_000_000L
    private val recipient = GuardianRecipientDevice(
        owner, deviceId, generation, "a".repeat(64), registered, registered + 29L * 24 * 60 * 60 * 1000,
    )

    private class MemoryStorage : GuardianSealedStorage {
        var bytes: ByteArray? = null
        var failReplace = false
        var failDelete = false
        var failAfterReplace = false
        override fun read() = bytes?.copyOf()
        override fun replace(bytes: ByteArray) {
            if (failReplace) error("write failure")
            this.bytes = bytes.copyOf()
            if (failAfterReplace) error("lost write confirmation")
        }
        override fun delete() {
            if (failDelete) error("delete failure")
            bytes = null
        }
    }

    private class Fixture {
        val disk = MemoryStorage()
        var key: SecretKey? = null
        fun cipher(domain: String = "io.github.atrx07.traelyx/guardian-recipient-vault/v1") =
            GuardianVaultCipher(
                domain = domain,
                maxPlainBytes = GuardianRecipientVaultCodec.MAX_BYTES,
                key = { create -> key ?: if (create) KeyGenerator.getInstance("AES").apply { init(256) }.generateKey().also { key = it }
                    else error("missing key") },
            )
        fun vault(domain: String = "io.github.atrx07.traelyx/guardian-recipient-vault/v1") =
            EncryptedGuardianRecipientVault(disk, cipher(domain)) { key = null }
    }

    private inline fun denied(block: () -> Unit) {
        try { block(); fail("Expected rejection") } catch (_: IllegalArgumentException) { } catch (_: IllegalStateException) { }
    }

    @Test fun `missing state is inert and creates no encryption key`() {
        val f = Fixture()
        assertNull(f.vault().readBound(owner, generation, registered))
        assertNull(f.key)
    }

    @Test fun `ciphertext survives restart without exposing authority`() {
        val f = Fixture()
        f.vault().write(recipient)
        val sealed = f.disk.bytes!!.copyOf()
        assertFalse(String(sealed, Charsets.ISO_8859_1).contains(owner))
        assertFalse(String(sealed, Charsets.ISO_8859_1).contains(recipient.credential))
        assertEquals(recipient, f.vault().readBound(owner, generation, registered + 1))
        assertFalse(recipient.toString().contains(recipient.credential))
    }

    @Test fun `owner generation lifetime and clock bounds deny stale authority`() {
        val f = Fixture()
        val vault = f.vault()
        vault.write(recipient)
        assertNull(vault.readBound(otherOwner, generation, registered + 1))
        assertNull(vault.readBound(owner, otherGeneration, registered + 1))
        assertNull(vault.readBound(owner, generation, registered - 1))
        assertNull(vault.readBound(owner, generation, recipient.expiresAtEpochMillis))
        assertEquals(recipient, vault.readBound(owner, generation, registered))
        denied { recipient.copy(expiresAtEpochMillis = registered + GuardianRecipientDevice.MAX_LIFETIME_MILLIS + 1) }
        denied { recipient.copy(credential = "A".repeat(64)) }
        denied { recipient.copy(ownerId = "not-a-uuid") }
        denied { recipient.copy(deviceId = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA") }
    }

    @Test fun `tampering lost key and wrong encryption domain fail closed`() {
        val f = Fixture()
        f.vault().write(recipient)
        val sealed = f.disk.bytes!!.copyOf()
        f.disk.bytes = sealed.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
        denied { f.vault().readBound(owner, generation, registered) }
        f.disk.bytes = sealed
        denied { f.vault("io.github.atrx07.traelyx/guardian-vault/v1").readBound(owner, generation, registered) }
        f.key = null
        denied { f.vault().readBound(owner, generation, registered) }
        assertNull(f.key)
    }

    @Test fun `codec rejects changed version trailing bytes and oversized input`() {
        val bytes = GuardianRecipientVaultCodec.encode(recipient)
        denied { GuardianRecipientVaultCodec.decode(bytes + byteArrayOf(0)) }
        denied { GuardianRecipientVaultCodec.decode(bytes.copyOf().also { it[3] = 3 }) }
        denied { GuardianRecipientVaultCodec.decode(ByteArray(GuardianRecipientVaultCodec.MAX_BYTES + 1)) }
    }

    @Test fun `uncertain write destroys key and cannot restore previous registration`() {
        val f = Fixture()
        val vault = f.vault()
        vault.write(recipient)
        f.disk.failReplace = true
        denied { vault.write(recipient.copy(generation = otherGeneration)) }
        assertNull(f.key)
        assertNull(f.disk.bytes)
        denied { vault.readBound(owner, generation, registered) }
        assertNull(f.vault().readBound(owner, generation, registered))
    }

    @Test fun `erase destroys key before ciphertext and refuses failed cleanup`() {
        val f = Fixture()
        val vault = f.vault()
        vault.write(recipient)
        f.disk.failDelete = true
        denied { vault.erase() }
        assertNull(f.key)
        denied { vault.readBound(owner, generation, registered) }
        denied { f.vault().readBound(owner, generation, registered) }
        f.disk.failDelete = false
        vault.erase()
        assertNull(f.disk.bytes)
        assertNull(vault.readBound(owner, generation, registered))
    }

    private val delivery = "66666666-6666-4666-8666-666666666666"
    private fun claim(vault: EncryptedGuardianRecipientVault, id: String = delivery, now: Long = registered) =
        vault.claimNotice(deviceId, generation, recipient.credential, id, now)

    @Test fun `version one authority upgrades without losing registration or encryption key`() {
        val f = Fixture()
        // Original v1 layout has no count or notice IDs.
        val legacy = GuardianRecipientVaultCodec.encode(recipient).dropLast(4).toByteArray().also { it[3] = 1 }
        f.disk.bytes = f.cipher().seal(legacy)
        val originalKey = f.key
        val vault = f.vault()
        assertEquals(recipient, vault.readStored())
        assertTrue(claim(vault))
        assertSame(originalKey, f.key)
        assertEquals(recipient.copy(noticeDeliveryIds = listOf(delivery)), f.vault().readStored())
        assertFalse(claim(f.vault()))
        assertFalse(String(f.disk.bytes!!, Charsets.ISO_8859_1).contains(delivery))
    }

    @Test fun `concurrent duplicates have a single durable winner across restart`() {
        val f = Fixture()
        val vault = f.vault()
        vault.write(recipient)
        val start = java.util.concurrent.CountDownLatch(1)
        val winners = java.util.concurrent.atomic.AtomicInteger()
        val failures = java.util.concurrent.atomic.AtomicInteger()
        val threads = List(8) { Thread {
            try { start.await(); if (claim(vault)) winners.incrementAndGet() }
            catch (_: Exception) { failures.incrementAndGet() }
        }.apply { start() } }
        start.countDown()
        threads.forEach { it.join(5_000); assertFalse(it.isAlive) }
        assertEquals(0, failures.get())
        assertEquals(1, winners.get())
        assertFalse(claim(f.vault()))
    }

    @Test fun `expiry mismatched credential and generation cannot claim`() {
        val f = Fixture()
        val vault = f.vault()
        vault.write(recipient)
        assertFalse(claim(vault, now = registered - 1))
        assertFalse(claim(vault, now = recipient.expiresAtEpochMillis))
        assertFalse(vault.claimNotice(deviceId, otherGeneration, recipient.credential, delivery, registered))
        assertFalse(vault.claimNotice(deviceId, generation, "b".repeat(64), delivery, registered))
        assertFalse(vault.claimNotice(otherOwner, generation, recipient.credential, delivery, registered))
        assertTrue(vault.readStored()!!.noticeDeliveryIds.isEmpty())
    }

    @Test fun `full ledger denies new notices without evicting any prior claim`() {
        val f = Fixture()
        val ids = List(GuardianRecipientDevice.MAX_NOTICE_IDS) {
            "00000000-0000-4000-8000-${it.toString(16).padStart(12, '0')}"
        }
        val full = recipient.copy(noticeDeliveryIds = ids)
        val vault = f.vault()
        vault.write(full)
        assertTrue(GuardianRecipientVaultCodec.encode(full).size <= GuardianRecipientVaultCodec.MAX_BYTES)
        assertFalse(claim(vault))
        assertFalse(claim(f.vault(), ids.first()))
        assertEquals(full, f.vault().readStored())
    }

    @Test fun `uncertain claim write never displays and preserves old or new authority for restart`() {
        for (after in listOf(false, true)) {
            val f = Fixture()
            val vault = f.vault()
            vault.write(recipient)
            val key = f.key
            f.disk.failReplace = !after
            f.disk.failAfterReplace = after
            denied { claim(vault) }
            denied { vault.readStored() }
            assertSame(key, f.key)
            f.disk.failReplace = false
            f.disk.failAfterReplace = false
            val restarted = f.vault()
            assertEquals(if (after) listOf(delivery) else emptyList<String>(), restarted.readStored()!!.noticeDeliveryIds)
            assertEquals(!after, claim(restarted))
        }
    }

    @Test fun `withdrawal clears claims and fresh registration has isolated notice history`() {
        val f = Fixture()
        val vault = f.vault()
        vault.write(recipient)
        assertTrue(claim(vault))
        vault.erase()
        assertNull(f.key)
        assertFalse(claim(vault))
        vault.write(recipient.copy(generation = otherGeneration))
        assertFalse(claim(vault))
        assertTrue(vault.claimNotice(deviceId, otherGeneration, recipient.credential, delivery, registered))
    }

    @Test fun `codec rejects duplicate invalid and excessive notice histories`() {
        denied { recipient.copy(noticeDeliveryIds = listOf(delivery, delivery)) }
        denied { recipient.copy(noticeDeliveryIds = listOf("invalid")) }
        denied { recipient.copy(noticeDeliveryIds = List(GuardianRecipientDevice.MAX_NOTICE_IDS + 1) { delivery }) }
        val bytes = GuardianRecipientVaultCodec.encode(recipient)
        denied { GuardianRecipientVaultCodec.decode(bytes.copyOf().also { it[it.lastIndex - 3] = -1 }) }
    }
}
