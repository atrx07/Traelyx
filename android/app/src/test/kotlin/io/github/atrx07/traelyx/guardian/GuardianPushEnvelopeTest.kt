package io.github.atrx07.traelyx.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class GuardianPushEnvelopeTest {
    private val delivery = "a1111111-1111-4111-8111-111111111111"
    private val generation = "22222222-2222-4222-8222-222222222222"
    private val valid = mapOf(
        "schema_version" to "1",
        "delivery_id" to delivery,
        "device_generation" to generation,
    )

    @Test fun `accepts only the fixed data envelope and redacts diagnostics`() {
        val parsed = GuardianPushEnvelope.parse(valid, hasNotificationPayload = false)
        assertNotNull(parsed)
        assertEquals(delivery, parsed!!.deliveryId)
        assertEquals(generation, parsed.deviceGeneration)
        assertFalse(parsed.toString().contains(delivery))
        assertFalse(parsed.toString().contains(generation))
    }

    @Test fun `rejects notification copy unknown fields and schema drift`() {
        assertNull(GuardianPushEnvelope.parse(valid, hasNotificationPayload = true))
        assertNull(GuardianPushEnvelope.parse(valid + ("driver_name" to "private"), false))
        assertNull(GuardianPushEnvelope.parse(valid - "device_generation", false))
        assertNull(GuardianPushEnvelope.parse(valid + ("schema_version" to "2"), false))
    }

    @Test fun `rejects noncanonical or malformed identifiers`() {
        assertNull(GuardianPushEnvelope.parse(valid + ("delivery_id" to delivery.uppercase()), false))
        assertNull(GuardianPushEnvelope.parse(valid + ("delivery_id" to "$delivery\n"), false))
        assertNull(GuardianPushEnvelope.parse(valid + ("device_generation" to "short"), false))
    }
}
