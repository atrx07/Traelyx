package io.github.atrx07.traelyx.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecorderPermissionEvaluatorTest {
    @Test
    fun firstLocationRequestIsContextuallyRequestable() {
        val snapshot = evaluate()

        assertEquals(RecorderPermissionState.REQUESTABLE, snapshot.locationState)
        assertTrue(snapshot.canRequestLocation)
        assertFalse(snapshot.recordingReady)
        assertFalse(snapshot.backgroundLocationRequired)
    }

    @Test
    fun approximateLocationAllowsOneExplicitPrecisionUpgrade() {
        val firstUpgrade =
            evaluate(
                coarseLocationGranted = true,
                locationRequestAttempts = 1,
            )
        val exhaustedUpgrade =
            evaluate(
                coarseLocationGranted = true,
                locationRequestAttempts = 2,
            )

        assertEquals(RecorderPermissionState.APPROXIMATE_ONLY, firstUpgrade.locationState)
        assertTrue(firstUpgrade.canRequestLocation)
        assertEquals(RecorderPermissionState.APPROXIMATE_ONLY, exhaustedUpgrade.locationState)
        assertFalse(exhaustedUpgrade.canRequestLocation)
    }

    @Test
    fun deniedLocationWithoutRationaleRequiresSettings() {
        val snapshot = evaluate(locationRequestAttempts = 1)

        assertEquals(RecorderPermissionState.SETTINGS_REQUIRED, snapshot.locationState)
        assertFalse(snapshot.canRequestLocation)
    }

    @Test
    fun preciseLocationAndGpsAreTheOnlyRecordingReadinessRequirements() {
        val notificationDenied =
            evaluate(
                fineLocationGranted = true,
                coarseLocationGranted = true,
                gpsProviderEnabled = true,
                notificationRequestedBefore = true,
            )
        val gpsDisabled =
            evaluate(
                fineLocationGranted = true,
                coarseLocationGranted = true,
                gpsProviderEnabled = false,
                notificationGranted = true,
            )

        assertTrue(notificationDenied.recordingReady)
        assertFalse(notificationDenied.foregroundNotificationVisible)
        assertFalse(gpsDisabled.recordingReady)
    }

    @Test
    fun notificationRuntimePermissionIsNotRequiredBeforeAndroidThirteen() {
        val snapshot = evaluate(platformApiLevel = 32)

        assertEquals(RecorderPermissionState.NOT_REQUIRED, snapshot.notificationState)
        assertFalse(snapshot.canRequestNotification)
        assertTrue(snapshot.foregroundNotificationVisible)
    }

    @Test
    fun notificationDenialWithRationaleRemainsRequestable() {
        val snapshot =
            evaluate(
                notificationRequestedBefore = true,
                showNotificationRationale = true,
            )

        assertEquals(RecorderPermissionState.REQUESTABLE, snapshot.notificationState)
        assertTrue(snapshot.canRequestNotification)
    }

    @Test
    fun permissionMapContainsOnlyBoundedReadinessEvidence() {
        val map = evaluate().toMap()

        assertEquals(
            setOf(
                "contractVersion",
                "platformApiLevel",
                "locationState",
                "notificationState",
                "fineLocationGranted",
                "coarseLocationGranted",
                "gpsProviderEnabled",
                "canRequestLocation",
                "canRequestNotification",
                "backgroundLocationRequired",
                "recordingReady",
                "foregroundNotificationVisible",
            ),
            map.keys,
        )
        assertEquals(false, map["backgroundLocationRequired"])
        assertFalse(map.keys.any { it.contains("coordinate", ignoreCase = true) })
        assertFalse(map.keys.any { it.contains("path", ignoreCase = true) })
    }

    private fun evaluate(
        platformApiLevel: Int = 34,
        fineLocationGranted: Boolean = false,
        coarseLocationGranted: Boolean = false,
        notificationGranted: Boolean = false,
        gpsProviderEnabled: Boolean = true,
        locationRequestAttempts: Int = 0,
        notificationRequestedBefore: Boolean = false,
        showLocationRationale: Boolean = false,
        showNotificationRationale: Boolean = false,
    ): RecorderPermissionSnapshot =
        RecorderPermissionEvaluator.evaluate(
            RecorderPermissionInputs(
                platformApiLevel = platformApiLevel,
                fineLocationGranted = fineLocationGranted,
                coarseLocationGranted = coarseLocationGranted,
                notificationGranted = notificationGranted,
                gpsProviderEnabled = gpsProviderEnabled,
                locationRequestAttempts = locationRequestAttempts,
                notificationRequestedBefore = notificationRequestedBefore,
                showLocationRationale = showLocationRationale,
                showNotificationRationale = showNotificationRationale,
            ),
        )
}
