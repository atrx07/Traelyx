package io.github.atrx07.traelyx.guardian

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Serial worker boundary: no owner transition succeeds while provider cleanup is uncertain. */
internal class GuardianRecipientOwnerLifecycle(
    private val coordinator: GuardianRecipientCoordinator,
    private val vault: GuardianRecipientVault,
    private val marker: GuardianProviderMarker,
    private val push: GuardianPushRegistration,
    private val epochMillis: () -> Long,
    private val cleanupTimeoutMillis: Long = 25_000L,
) {
    init { require(cleanupTimeoutMillis > 0) }

    fun bindOwner(nextOwner: String?) {
        try {
            nextOwner?.let(::guardianUuid)
            val marked = marker.present()
            val stored = try { vault.readStored() } catch (_: GuardianVaultUnavailable) { null }
            val sameActiveOwner = marked && nextOwner != null && stored != null &&
                stored.validFor(nextOwner, stored.generation, epochMillis())

            if (marked && !sameActiveOwner) {
                // Drop local receipt authority before a potentially slow provider deletion.
                coordinator.bindOwner(null)
                check(deleteProvider()) { "Guardian provider cleanup could not be confirmed" }
            } else if (!marked && stored != null) {
                // A receipt capability without a durable provider marker is incomplete.
                coordinator.bindOwner(null)
            }
            coordinator.bindOwner(nextOwner)
        } catch (error: Exception) {
            runCatching { coordinator.bindOwner(null) }
            throw error
        }
    }

    private fun deleteProvider(): Boolean {
        val latch = CountDownLatch(1)
        var deleted = false
        push.unregister { success ->
            deleted = success
            latch.countDown()
        }
        return latch.await(cleanupTimeoutMillis, TimeUnit.MILLISECONDS) && deleted
    }
}
