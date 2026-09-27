package io.github.atrx07.traelyx.guardian

import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.Assert.*
import org.junit.Test

class GuardianVaultTest {
    private val owner = "11111111-1111-4111-8111-111111111111"
    private val activation = "22222222-2222-4222-8222-222222222222"
    private val event = "33333333-3333-4333-8333-333333333333"
    private val start = GuardianClock(1_800_000_000_000, 10_000, "boot-1")
    private fun lease(ownerId: String = owner, generation: String = activation) = GuardianDriverLease(
        ownerId, generation, "a".repeat(64), start.epochMillis, start.elapsedMillis,
        start.epochMillis + 28_800_000, start.bootId, "+y")
    private fun now(delta: Long = 0) = start.copy(epochMillis = start.epochMillis + delta, elapsedMillis = start.elapsedMillis + delta)
    private val detection = GuardianDetection(GuardianAlertKind.POSSIBLE_CRASH, 9_000_000_000, 10_000_000_000)
    private val cooldowns = GuardianSafetyCooldowns(10_000_000_000, 10_000_000_000)

    private class MemoryDisk : GuardianSealedStorage {
        var bytes: ByteArray? = null
        var failWrites = false
        override fun read() = bytes?.copyOf()
        override fun replace(bytes: ByteArray) { if (failWrites) error("disk failure"); this.bytes = bytes.copyOf() }
        override fun delete() { bytes = null }
    }
    private class Keys {
        var key: SecretKey? = null
        fun cipher() = GuardianVaultCipher { create ->
            key ?: if (create) KeyGenerator.getInstance("AES").apply { init(256) }.generateKey().also { key = it }
            else error("lost key")
        }
    }
    private class Fixture {
        val disk = MemoryDisk()
        val keys = Keys()
        fun vault() = EncryptedGuardianVault(disk, keys.cipher()) { keys.key = null }
        val vault = vault()
        val outbox = GuardianOutbox(vault)
    }
    private fun active(): Fixture = Fixture().also {
        it.outbox.activate(lease(), start)
        it.outbox.enqueue(owner, activation, detection, cooldowns, start, event)
    }
    private inline fun denied(block: () -> Unit) {
        try { block(); fail("Expected rejection") } catch (_: IllegalStateException) { } catch (_: IllegalArgumentException) { }
    }

    @Test fun `missing state is inert and creates no key`() {
        val f = Fixture()
        assertEquals(GuardianVaultSnapshot(), f.vault.read())
        assertNull(f.keys.key)
        assertNull(f.outbox.reserveNext(owner, start))
    }

    @Test fun `real authenticated encryption survives restoration without plaintext credentials`() {
        val f = active()
        val sealed = f.disk.bytes!!.copyOf()
        val snapshot = f.vault.read()
        assertFalse(String(sealed, Charsets.ISO_8859_1).contains(lease().credential))
        assertFalse(String(sealed, Charsets.ISO_8859_1).contains(owner))
        assertEquals(snapshot, f.vault().read())
        f.vault.write(snapshot)
        assertFalse(sealed.contentEquals(f.disk.bytes!!))
        assertEquals(snapshot, f.vault().read())
        assertFalse(snapshot.toString().contains(owner))
        assertFalse(lease().toString().contains(lease().credential))
    }

    @Test fun `tampering truncation wrong key and unknown cipher format all fail closed`() {
        val f = active()
        val original = f.disk.bytes!!.copyOf()
        for (corrupt in listOf(original.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() },
            original.copyOf(15), original.copyOf().also { it[0] = 2 })) {
            f.disk.bytes = corrupt
            denied { f.vault().read() }
        }
        f.disk.bytes = original
        f.keys.key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        denied { f.vault().read() }
        f.keys.key = null
        denied { f.vault().read() }
    }

    @Test fun `codec rejects future schema trailing bytes excessive length and mixed account`() {
        val f = active()
        val state = f.vault.read()
        val bytes = GuardianVaultCodec.encode(state)
        denied { GuardianVaultCodec.decode(bytes + byteArrayOf(0)) }
        denied { GuardianVaultCodec.decode(bytes.copyOf().also { it[3] = 2 }) }
        denied { GuardianVaultCodec.decode(ByteArray(GuardianVaultCodec.MAX_BYTES + 1)) }
        denied { state.copy(alerts = listOf(state.alerts.single().copy(ownerId = event))) }
        denied { state.copy(alerts = listOf(state.alerts.single(), state.alerts.single())) }
    }

    @Test fun `attempt persists before return and process restart consumes reservation`() {
        val f = active()
        assertNull(f.outbox.reserveNext(owner, now(29_999)))
        val attempt = f.outbox.reserveNext(owner, now(30_000))!!
        assertEquals(1, attempt.alert.attempts)
        val restored = GuardianOutbox(f.vault())
        assertNull(restored.reserveNext(owner, now(30_001)))
        assertEquals(2, restored.reserveNext(owner, now(35_000))!!.alert.attempts)
        assertEquals(cooldowns, restored.recover(owner, now(35_000)).cooldowns)
    }

    @Test fun `failed reservation never returns dispatch authority and destroys restoration key`() {
        val f = active()
        f.outbox.recover(owner, now(30_000))
        f.disk.failWrites = true
        denied { f.outbox.reserveNext(owner, now(30_000)) }
        assertNull(f.keys.key)
        assertNull(GuardianOutbox(f.vault()).reserveNext(owner, now(35_000)))
        f.disk.failWrites = false
        f.vault.erase()
        assertEquals(GuardianVaultSnapshot(), f.vault.read())
    }

    @Test fun `reboot rollback expired lease and different account destroy old activation`() {
        for (clock in listOf(now().copy(bootId = "boot-2"), now().copy(epochMillis = start.epochMillis - 1),
            now().copy(elapsedMillis = 9_999), now(28_800_000))) {
            val f = active()
            assertNull(f.outbox.recover(owner, clock).lease)
            assertNull(f.disk.bytes)
            assertNull(f.keys.key)
        }
        val f = active()
        assertNull(f.outbox.recover(event, start).lease)
    }

    @Test fun `cancellation survives restart and cannot claim retract after reservation`() {
        val f = active()
        assertTrue(f.outbox.cancel(owner, event, now(20_000)))
        assertNull(GuardianOutbox(f.vault()).reserveNext(owner, now(30_000)))
        val other = active()
        other.outbox.reserveNext(owner, now(30_000))
        assertFalse(other.outbox.cancel(owner, event, now(31_000)))
    }

    @Test fun `late callbacks cannot overwrite retry or new account activation`() {
        val f = active()
        val first = f.outbox.reserveNext(owner, now(30_000))!!
        val second = f.outbox.reserveNext(owner, now(35_000))!!
        f.outbox.complete(first, true, false, now(36_000))
        assertEquals(GuardianSendState.QUEUED, f.vault.read().alerts.single().state)
        f.outbox.complete(second, true, false, now(36_000))
        assertEquals(GuardianSendState.BACKEND_ACCEPTED, f.vault.read().alerts.single().state)
        val replacement = lease(event, owner)
        f.outbox.activate(replacement, now(36_000))
        f.outbox.complete(second, false, true, now(37_000))
        assertEquals(replacement, f.vault.read().lease)
    }

    @Test fun `cooldown and event persist atomically and duplicate detection is rejected`() {
        val f = active()
        denied { f.outbox.enqueue(owner, activation, detection, cooldowns, start) }
        denied { f.outbox.enqueue(owner, event, detection, cooldowns, start) }
        assertEquals(1, f.vault.read().alerts.size)
        assertEquals(cooldowns, f.vault.read().cooldowns)
        assertTrue(f.outbox.recover(owner, now(600_000)).alerts.isEmpty())
        assertEquals(cooldowns, f.vault.read().cooldowns)
    }

    @Test fun `activation retry cannot silently alter or extend consent`() {
        val f = active()
        f.outbox.activate(lease(), now(1_000))
        assertEquals(1, f.vault.read().alerts.size)
        denied { f.outbox.activate(lease().copy(credential = "b".repeat(64)), now(1_000)) }
        f.outbox.revoke()
        assertNull(f.disk.bytes)
        assertNull(f.keys.key)
    }
}
