package io.github.atrx07.traelyx.recorder

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecorderRecoveryCodecTest {
    @Test
    fun recoveryRecordRoundTripsWithoutChangingTimestampSemantics() {
        val expected =
            ActiveTripRecoveryRecord(
                tripId = TRIP_ID,
                startedAtUtcEpochMillis = 1_786_200_000_000L,
                startedAtElapsedRealtimeNanos = 987_654_321L,
                lifecycleState = RecorderLifecycleState.RECOVERED,
                recoveryCount = 2,
            )

        val decoded = decode(encode(expected))

        assertTrue(decoded is RecorderRecoveryRead.Available)
        assertEquals(expected, (decoded as RecorderRecoveryRead.Available).record)
    }

    @Test
    fun errorRecordRoundTripsOnlyTheAllowlistedFailureCode() {
        val expected =
            ActiveTripRecoveryRecord(
                tripId = TRIP_ID,
                startedAtUtcEpochMillis = 1_786_200_000_000L,
                startedAtElapsedRealtimeNanos = 987_654_321L,
                lifecycleState = RecorderLifecycleState.ERROR,
                errorCode = "location_permission_missing",
            )

        val decoded = decode(encode(expected))

        assertEquals(expected, (decoded as RecorderRecoveryRead.Available).record)
    }

    @Test
    fun truncatedRecordFailsClosed() {
        val bytes =
            encode(
                ActiveTripRecoveryRecord(
                    tripId = TRIP_ID,
                    startedAtUtcEpochMillis = 1_786_200_000_000L,
                    startedAtElapsedRealtimeNanos = 987_654_321L,
                    lifecycleState = RecorderLifecycleState.RECORDING,
                ),
            )

        val decoded = decode(bytes.copyOf(9))

        assertTrue(decoded is RecorderRecoveryRead.Invalid)
    }

    @Test
    fun unknownEncodingMagicFailsClosed() {
        val decoded = decode(byteArrayOf(0, 0, 0, 0))

        assertTrue(decoded is RecorderRecoveryRead.Invalid)
    }

    private fun encode(record: ActiveTripRecoveryRecord): ByteArray =
        ByteArrayOutputStream().also { RecorderRecoveryCodec.encode(record, it) }.toByteArray()

    private fun decode(bytes: ByteArray): RecorderRecoveryRead =
        RecorderRecoveryCodec.decode(ByteArrayInputStream(bytes))

    companion object {
        private const val TRIP_ID = "d181f268-f3ef-4a43-a142-8bf0671dcd49"
    }
}
