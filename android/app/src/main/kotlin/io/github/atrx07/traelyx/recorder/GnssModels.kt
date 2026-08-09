package io.github.atrx07.traelyx.recorder

const val RAW_GNSS_SCHEMA_VERSION = 1
const val GNSS_HEALTH_CONTRACT_VERSION = 1
const val GNSS_REQUEST_INTERVAL_MILLIS = 1_000L
const val GNSS_LOW_ACCURACY_THRESHOLD_METRES = 50.0f

enum class GnssQualityFlag(val wireName: String) {
    GNSS_LOW_ACCURACY("gnss_low_accuracy"),
    CLOCK_DISCONTINUITY("clock_discontinuity"),
    MOCK_LOCATION_SIGNAL("mock_location_signal"),
}

/**
 * Versioned, unfiltered location evidence captured directly from Android.
 *
 * Coordinates are deliberately absent from health/diagnostic snapshots. M2.4
 * persists these samples only inside checksummed app-private chunks.
 */
data class RawGnssSample(
    val schemaVersion: Int = RAW_GNSS_SCHEMA_VERSION,
    val tripElapsedNanos: Long?,
    val sourceTimestampNanos: Long,
    val sourceWallTimeUtcEpochMillis: Long?,
    val latitudeDegrees: Double,
    val longitudeDegrees: Double,
    val horizontalAccuracyMetres: Float,
    val altitudeMetres: Double?,
    val verticalAccuracyMetres: Float?,
    val speedMetresPerSecond: Float?,
    val speedAccuracyMetresPerSecond: Float?,
    val bearingDegrees: Float?,
    val bearingAccuracyDegrees: Float?,
    val provider: String,
    val isMockSignal: Boolean,
    val qualityFlags: Set<GnssQualityFlag>,
) {
    init {
        require(schemaVersion == RAW_GNSS_SCHEMA_VERSION)
        require(tripElapsedNanos == null || tripElapsedNanos >= 0)
        require(sourceTimestampNanos >= 0)
        require(latitudeDegrees.isFinite() && latitudeDegrees in -90.0..90.0)
        require(longitudeDegrees.isFinite() && longitudeDegrees in -180.0..180.0)
        require(horizontalAccuracyMetres.isFinite() && horizontalAccuracyMetres >= 0.0f)
        require(altitudeMetres == null || altitudeMetres.isFinite())
        require(
            verticalAccuracyMetres == null ||
                verticalAccuracyMetres.isFinite() && verticalAccuracyMetres >= 0.0f,
        )
        require(
            speedMetresPerSecond == null ||
                speedMetresPerSecond.isFinite() && speedMetresPerSecond >= 0.0f,
        )
        require(
            speedAccuracyMetresPerSecond == null ||
                speedAccuracyMetresPerSecond.isFinite() && speedAccuracyMetresPerSecond >= 0.0f,
        )
        require(
            bearingDegrees == null ||
                bearingDegrees.isFinite() && bearingDegrees >= 0.0f && bearingDegrees < 360.0f,
        )
        require(
            bearingAccuracyDegrees == null ||
                bearingAccuracyDegrees.isFinite() && bearingAccuracyDegrees >= 0.0f,
        )
        require(provider.isNotBlank())
        require(sourceWallTimeUtcEpochMillis == null || sourceWallTimeUtcEpochMillis > 0)
        require(
            (GnssQualityFlag.MOCK_LOCATION_SIGNAL in qualityFlags) == isMockSignal,
        )
    }
}

/** Platform-neutral input so semantic mapping can be tested without Android runtime stubs. */
data class PlatformLocationReading(
    val sourceTimestampNanos: Long,
    val sourceWallTimeUtcEpochMillis: Long?,
    val latitudeDegrees: Double,
    val longitudeDegrees: Double,
    val horizontalAccuracyMetres: Float?,
    val altitudeMetres: Double?,
    val verticalAccuracyMetres: Float?,
    val speedMetresPerSecond: Float?,
    val speedAccuracyMetresPerSecond: Float?,
    val bearingDegrees: Float?,
    val bearingAccuracyDegrees: Float?,
    val provider: String?,
    val isMockSignal: Boolean,
)

enum class GnssSampleRejectionReason(val wireName: String) {
    INVALID_SOURCE_TIMESTAMP("invalid_source_timestamp"),
    INVALID_COORDINATES("invalid_coordinates"),
    INVALID_HORIZONTAL_ACCURACY("invalid_horizontal_accuracy"),
    INVALID_OPTIONAL_FIELD("invalid_optional_field"),
    INVALID_PROVIDER("invalid_provider"),
}

sealed interface GnssSampleMappingResult {
    data class Accepted(val sample: RawGnssSample) : GnssSampleMappingResult

    data class Rejected(val reason: GnssSampleRejectionReason) : GnssSampleMappingResult
}

object GnssSampleMapper {
    fun map(
        reading: PlatformLocationReading,
        tripStartedAtElapsedRealtimeNanos: Long,
        previousSourceTimestampNanos: Long?,
    ): GnssSampleMappingResult {
        if (reading.sourceTimestampNanos < 0 || tripStartedAtElapsedRealtimeNanos < 0) {
            return GnssSampleMappingResult.Rejected(
                GnssSampleRejectionReason.INVALID_SOURCE_TIMESTAMP,
            )
        }
        if (
            !reading.latitudeDegrees.isFinite() || reading.latitudeDegrees !in -90.0..90.0 ||
            !reading.longitudeDegrees.isFinite() || reading.longitudeDegrees !in -180.0..180.0
        ) {
            return GnssSampleMappingResult.Rejected(GnssSampleRejectionReason.INVALID_COORDINATES)
        }
        val horizontalAccuracy = reading.horizontalAccuracyMetres
        if (horizontalAccuracy == null || !horizontalAccuracy.isFinite() || horizontalAccuracy < 0) {
            return GnssSampleMappingResult.Rejected(
                GnssSampleRejectionReason.INVALID_HORIZONTAL_ACCURACY,
            )
        }
        if (!reading.optionalFieldsAreValid()) {
            return GnssSampleMappingResult.Rejected(GnssSampleRejectionReason.INVALID_OPTIONAL_FIELD)
        }
        val provider = reading.provider
        if (provider.isNullOrBlank()) {
            return GnssSampleMappingResult.Rejected(GnssSampleRejectionReason.INVALID_PROVIDER)
        }

        val qualityFlags = mutableSetOf<GnssQualityFlag>()
        if (horizontalAccuracy > GNSS_LOW_ACCURACY_THRESHOLD_METRES) {
            qualityFlags += GnssQualityFlag.GNSS_LOW_ACCURACY
        }
        val monotonicEpochValid =
            reading.sourceTimestampNanos >= tripStartedAtElapsedRealtimeNanos &&
                (previousSourceTimestampNanos == null ||
                    reading.sourceTimestampNanos > previousSourceTimestampNanos)
        if (!monotonicEpochValid) {
            qualityFlags += GnssQualityFlag.CLOCK_DISCONTINUITY
        }
        if (reading.isMockSignal) {
            qualityFlags += GnssQualityFlag.MOCK_LOCATION_SIGNAL
        }

        return GnssSampleMappingResult.Accepted(
            RawGnssSample(
                tripElapsedNanos =
                    if (monotonicEpochValid) {
                        reading.sourceTimestampNanos - tripStartedAtElapsedRealtimeNanos
                    } else {
                        null
                    },
                sourceTimestampNanos = reading.sourceTimestampNanos,
                sourceWallTimeUtcEpochMillis =
                    reading.sourceWallTimeUtcEpochMillis?.takeIf { it > 0 },
                latitudeDegrees = reading.latitudeDegrees,
                longitudeDegrees = reading.longitudeDegrees,
                horizontalAccuracyMetres = horizontalAccuracy,
                altitudeMetres = reading.altitudeMetres,
                verticalAccuracyMetres = reading.verticalAccuracyMetres,
                speedMetresPerSecond = reading.speedMetresPerSecond,
                speedAccuracyMetresPerSecond = reading.speedAccuracyMetresPerSecond,
                bearingDegrees = reading.bearingDegrees,
                bearingAccuracyDegrees = reading.bearingAccuracyDegrees,
                provider = provider,
                isMockSignal = reading.isMockSignal,
                qualityFlags = qualityFlags,
            ),
        )
    }

    private fun PlatformLocationReading.optionalFieldsAreValid(): Boolean =
        (altitudeMetres == null || altitudeMetres.isFinite()) &&
            (verticalAccuracyMetres == null ||
                verticalAccuracyMetres.isFinite() && verticalAccuracyMetres >= 0.0f) &&
            (speedMetresPerSecond == null ||
                speedMetresPerSecond.isFinite() && speedMetresPerSecond >= 0.0f) &&
            (speedAccuracyMetresPerSecond == null ||
                speedAccuracyMetresPerSecond.isFinite() && speedAccuracyMetresPerSecond >= 0.0f) &&
            (bearingDegrees == null ||
                bearingDegrees.isFinite() && bearingDegrees >= 0.0f && bearingDegrees < 360.0f) &&
            (bearingAccuracyDegrees == null ||
                bearingAccuracyDegrees.isFinite() && bearingAccuracyDegrees >= 0.0f)
}

enum class GnssAcquisitionState(val wireName: String) {
    IDLE("idle"),
    REGISTERING("registering"),
    AWAITING_FIX("awaiting_fix"),
    ACTIVE("active"),
    PROVIDER_DISABLED("provider_disabled"),
    STOPPED("stopped"),
    ERROR("error"),
}

data class GnssHealthSnapshot(
    val contractVersion: Int = GNSS_HEALTH_CONTRACT_VERSION,
    val state: GnssAcquisitionState,
    val provider: String = "gps",
    val requestedIntervalMillis: Long = GNSS_REQUEST_INTERVAL_MILLIS,
    val acceptedSampleCount: Long = 0,
    val rejectedSampleCount: Long = 0,
    val lowAccuracySampleCount: Long = 0,
    val clockDiscontinuityCount: Long = 0,
    val mockSignalCount: Long = 0,
    val providerDisabledCount: Long = 0,
    val registrationFailureCount: Long = 0,
    val firstSourceTimestampNanos: Long? = null,
    val lastSourceTimestampNanos: Long? = null,
    val lastTripElapsedNanos: Long? = null,
    val lastHorizontalAccuracyMetres: Float? = null,
    val lastFixWallTimeUtcEpochMillis: Long? = null,
    val lastFixHadSpeed: Boolean = false,
    val lastFixHadBearing: Boolean = false,
    val errorCode: String? = null,
) {
    init {
        require(contractVersion == GNSS_HEALTH_CONTRACT_VERSION)
        require(requestedIntervalMillis > 0)
        require(
            listOf(
                acceptedSampleCount,
                rejectedSampleCount,
                lowAccuracySampleCount,
                clockDiscontinuityCount,
                mockSignalCount,
                providerDisabledCount,
                registrationFailureCount,
            ).all { it >= 0 },
        )
        require(errorCode == null || Regex("[a-z0-9_]{1,64}").matches(errorCode))
    }

    companion object {
        fun idle(): GnssHealthSnapshot = GnssHealthSnapshot(state = GnssAcquisitionState.IDLE)
    }
}

class GnssHealthTracker(
    private val publish: (GnssHealthSnapshot) -> Unit = {},
) {
    private val lock = Any()
    private var snapshot = GnssHealthSnapshot.idle()

    fun current(): GnssHealthSnapshot = synchronized(lock) { snapshot }

    fun beginRegistration() = update { GnssHealthSnapshot(state = GnssAcquisitionState.REGISTERING) }

    fun registered(providerEnabled: Boolean) =
        update {
            it.copy(
                state =
                    if (providerEnabled) {
                        GnssAcquisitionState.AWAITING_FIX
                    } else {
                        GnssAcquisitionState.PROVIDER_DISABLED
                    },
                errorCode = null,
            )
        }

    fun providerEnabled() =
        update {
            it.copy(
                state = GnssAcquisitionState.AWAITING_FIX,
                errorCode = null,
            )
        }

    fun providerDisabled() =
        update {
            it.copy(
                state = GnssAcquisitionState.PROVIDER_DISABLED,
                providerDisabledCount = it.providerDisabledCount + 1,
            )
        }

    fun accepted(sample: RawGnssSample) =
        update {
            it.copy(
                state = GnssAcquisitionState.ACTIVE,
                acceptedSampleCount = it.acceptedSampleCount + 1,
                lowAccuracySampleCount =
                    it.lowAccuracySampleCount +
                        if (GnssQualityFlag.GNSS_LOW_ACCURACY in sample.qualityFlags) 1 else 0,
                clockDiscontinuityCount =
                    it.clockDiscontinuityCount +
                        if (GnssQualityFlag.CLOCK_DISCONTINUITY in sample.qualityFlags) 1 else 0,
                mockSignalCount =
                    it.mockSignalCount +
                        if (GnssQualityFlag.MOCK_LOCATION_SIGNAL in sample.qualityFlags) 1 else 0,
                firstSourceTimestampNanos =
                    it.firstSourceTimestampNanos ?: sample.sourceTimestampNanos,
                lastSourceTimestampNanos = sample.sourceTimestampNanos,
                lastTripElapsedNanos = sample.tripElapsedNanos,
                lastHorizontalAccuracyMetres = sample.horizontalAccuracyMetres,
                lastFixWallTimeUtcEpochMillis = sample.sourceWallTimeUtcEpochMillis,
                lastFixHadSpeed = sample.speedMetresPerSecond != null,
                lastFixHadBearing = sample.bearingDegrees != null,
                errorCode = null,
            )
        }

    fun rejected() =
        update { it.copy(rejectedSampleCount = it.rejectedSampleCount + 1) }

    fun registrationFailed(errorCode: String) =
        update {
            it.copy(
                state = GnssAcquisitionState.ERROR,
                registrationFailureCount = it.registrationFailureCount + 1,
                errorCode = errorCode,
            )
        }

    fun stopped() = update { it.copy(state = GnssAcquisitionState.STOPPED) }

    private fun update(transform: (GnssHealthSnapshot) -> GnssHealthSnapshot) {
        val updated = synchronized(lock) {
            snapshot = transform(snapshot)
            snapshot
        }
        publish(updated)
    }
}
