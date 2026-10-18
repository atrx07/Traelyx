package io.github.atrx07.traelyx.guardian

import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class GuardianControlExecutorTest {
    @Test fun `replaced long expiry wakes do not accumulate cancelled queue entries`() {
        val worker = guardianControlExecutor()
        try {
            worker.submit {
                repeat(500) {
                    val wake = worker.schedule({ fail("Cancelled wake executed") }, 10, TimeUnit.MINUTES)
                    assertEquals(1, worker.queue.size)
                    assertTrue(wake.cancel(false))
                    assertTrue(worker.queue.isEmpty())
                }
            }.get(5, TimeUnit.SECONDS)
        } finally { worker.shutdownNow() }
    }
}
