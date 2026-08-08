package io.github.atrx07.traelyx

import org.junit.Assert.assertEquals
import org.junit.Test

class BootstrapIdentityTest {
    @Test
    fun mainActivityUsesCanonicalPackage() {
        assertEquals(
            "io.github.atrx07.traelyx.MainActivity",
            MainActivity::class.java.name,
        )
    }
}
