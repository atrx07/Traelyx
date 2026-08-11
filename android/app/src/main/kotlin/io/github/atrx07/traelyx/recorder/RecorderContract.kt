package io.github.atrx07.traelyx.recorder

object RecorderContract {
    const val BRIDGE_VERSION = 1
    const val CHANNEL_NAME = "io.github.atrx07.traelyx/recorder/v1"
    const val GET_CAPABILITIES = "getCapabilities"
    const val GET_STATE = "getState"
    const val GET_STATUS = "getStatus"
    const val GET_PERMISSION_STATUS = "getPermissionStatus"
    const val REQUEST_LOCATION_PERMISSION = "requestLocationPermission"
    const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
    const val OPEN_APP_SETTINGS = "openAppSettings"
    const val OPEN_LOCATION_SETTINGS = "openLocationSettings"
    const val START_TRIP = "startTrip"
    const val STOP_TRIP = "stopTrip"
    const val RECOVER_TRIP = "recoverTrip"
    const val GET_PENDING_FINALIZATIONS = "getPendingFinalizations"
    const val ACKNOWLEDGE_TRIP_FINALIZATION = "acknowledgeTripFinalization"
}
