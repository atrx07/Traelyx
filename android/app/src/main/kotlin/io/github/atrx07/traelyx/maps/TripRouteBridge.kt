package io.github.atrx07.traelyx.maps

import io.github.atrx07.traelyx.recorder.TelemetryChunkStore
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetryChunkGnssDecodeResult
import io.github.atrx07.traelyx.recorder.TelemetryChannel
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.telemetry.GNSS_PROCESSING_VERSION
import io.github.atrx07.traelyx.telemetry.GnssDecision
import io.github.atrx07.traelyx.telemetry.GnssProcessingResult
import io.github.atrx07.traelyx.telemetry.GnssSanityFilter
import java.util.UUID

const val MAP_DATA_CONTRACT_VERSION = 1
const val MAP_DATA_MAX_DISPLAY_POINTS = 4_096

object MapDataContract {
    const val CHANNEL_NAME = "io.github.atrx07.traelyx/map-data/v1"
    const val LOAD_TRIP_ROUTE = "loadTripRoute"
}

data class TripRoutePoint(
    val tripElapsedNanos: Long,
    val latitude: Double,
    val longitude: Double,
    val startsNewSegment: Boolean,
)

data class TripRouteGeometry(
    val processingVersion: Int,
    val sourceGnssCount: Int,
    val points: List<TripRoutePoint>,
    val reduced: Boolean,
)

sealed interface TripRouteReadResult {
    data class Available(val geometry: TripRouteGeometry) : TripRouteReadResult

    data object Unavailable : TripRouteReadResult

    data object Invalid : TripRouteReadResult
}

/**
 * Reads immutable, app-private trip evidence into bounded display-only geometry.
 * Storage identifiers and raw quality/provider fields never cross this boundary.
 */
class TripRouteReader(
    private val chunkStore: TelemetryChunkStore,
    private val maximumDisplayPoints: Int = MAP_DATA_MAX_DISPLAY_POINTS,
) {
    init {
        require(maximumDisplayPoints >= 2)
    }

    fun read(tripId: String?): TripRouteReadResult {
        if (tripId == null || !isUuid(tripId)) return TripRouteReadResult.Invalid
        val catalog = chunkStore.listSequences(tripId)
        if (
            catalog.orphanedWriteCount != 0 ||
            catalog.invalidCandidateCount != 0
        ) {
            return TripRouteReadResult.Invalid
        }
        val maximumSequence = catalog.sequences.lastOrNull() ?: return TripRouteReadResult.Unavailable
        if (maximumSequence !in 0 until MAXIMUM_ROUTE_CHUNK_COUNT.toLong()) {
            return TripRouteReadResult.Invalid
        }
        if (
            catalog.sequences.size.toLong() != maximumSequence + 1L ||
            catalog.sequences.withIndex().any { (index, sequence) -> sequence != index.toLong() }
        ) {
            return TripRouteReadResult.Invalid
        }

        val gnssSamples = mutableListOf<RawGnssSample>()
        var firstContract: Triple<String, Int, Int>? = null
        var previousChunkEndElapsedNanos: Long? = null
        val previousChannelElapsedNanos = mutableMapOf<TelemetryChannel, Long>()
        for (sequence in catalog.sequences) {
            val bytes = chunkStore.read(tripId, sequence) ?: return TripRouteReadResult.Invalid
            val decoded = TelemetryChunkCodec.decodeGnss(bytes)
            val chunk = when (decoded) {
                is TelemetryChunkGnssDecodeResult.Invalid -> return TripRouteReadResult.Invalid
                is TelemetryChunkGnssDecodeResult.Success -> decoded.chunk
            }
            val metadata = chunk.metadata
            if (metadata.tripId != tripId || metadata.sequence != sequence) {
                return TripRouteReadResult.Invalid
            }
            val contract =
                Triple(
                    metadata.tripId,
                    metadata.encodingVersion,
                    metadata.telemetrySchemaVersion,
                )
            if (firstContract == null) firstContract = contract
            if (contract != firstContract) return TripRouteReadResult.Invalid
            val previousChunkEnd = previousChunkEndElapsedNanos
            if (previousChunkEnd != null && metadata.startElapsedNanos < previousChunkEnd) {
                return TripRouteReadResult.Invalid
            }
            previousChunkEndElapsedNanos = metadata.endElapsedNanos
            for ((channel, range) in chunk.channelElapsedRanges) {
                val previousChannelElapsed = previousChannelElapsedNanos[channel]
                if (previousChannelElapsed != null && range.first <= previousChannelElapsed) {
                    return TripRouteReadResult.Invalid
                }
                previousChannelElapsedNanos[channel] = range.last
            }
            for (sample in chunk.samples) {
                gnssSamples += sample
            }
        }

        val processed = GnssSanityFilter.processSamples(gnssSamples.asSequence())
        val summary = when (processed) {
            is GnssProcessingResult.Invalid -> return TripRouteReadResult.Invalid
            is GnssProcessingResult.Success -> processed.summary
        }
        val displayPoints = mutableListOf<TripRoutePoint>()
        var breakBeforeNextAccepted = true
        for (sample in summary.samples) {
            when (sample.decision) {
                GnssDecision.ACCEPTED_ANCHOR,
                GnssDecision.RESET_AFTER_GAP,
                GnssDecision.ACCEPTED_RESOLVED_DISTANCE,
                GnssDecision.ACCEPTED_MOTION_SUPPORTED_DISTANCE,
                -> {
                    val startsNewSegment =
                        breakBeforeNextAccepted ||
                            sample.decision == GnssDecision.ACCEPTED_ANCHOR ||
                            sample.decision == GnssDecision.RESET_AFTER_GAP
                    displayPoints +=
                        TripRoutePoint(
                            tripElapsedNanos = requireNotNull(sample.rawSample.tripElapsedNanos),
                            latitude = sample.rawSample.latitudeDegrees,
                            longitude = sample.rawSample.longitudeDegrees,
                            startsNewSegment = startsNewSegment,
                        )
                    breakBeforeNextAccepted = false
                }

                GnssDecision.EXCLUDED_LOW_ACCURACY,
                GnssDecision.EXCLUDED_CLOCK_DISCONTINUITY,
                GnssDecision.EXCLUDED_STATIONARY_JITTER,
                GnssDecision.EXCLUDED_UNRESOLVED_WITHIN_ACCURACY,
                -> breakBeforeNextAccepted = true

                GnssDecision.EXCLUDED_IMPOSSIBLE_JUMP -> Unit
            }
        }
        if (displayPoints.size < 2) return TripRouteReadResult.Unavailable
        val reduced = TripRoutePointReducer.reduce(displayPoints, maximumDisplayPoints)
            ?: return TripRouteReadResult.Invalid
        return TripRouteReadResult.Available(
            TripRouteGeometry(
                processingVersion = GNSS_PROCESSING_VERSION,
                sourceGnssCount = summary.samples.size,
                points = reduced,
                reduced = reduced.size != displayPoints.size,
            ),
        )
    }

    private fun isUuid(value: String): Boolean = runCatching { UUID.fromString(value) }.isSuccess

    private companion object {
        const val MAXIMUM_ROUTE_CHUNK_COUNT = 100_000
    }
}

object TripRoutePointReducer {
    /** Preserves endpoints and every segment start. Null means the mandatory shape exceeds the cap. */
    fun reduce(
        points: List<TripRoutePoint>,
        maximumPoints: Int = MAP_DATA_MAX_DISPLAY_POINTS,
    ): List<TripRoutePoint>? {
        require(maximumPoints >= 2)
        if (points.size <= maximumPoints) return points.toList()

        val mandatory = sortedSetOf(0, points.lastIndex)
        points.forEachIndexed { index, point ->
            if (point.startsNewSegment) mandatory += index
        }
        if (mandatory.size > maximumPoints) return null

        val optional = points.indices.filterNot(mandatory::contains)
        val slots = maximumPoints - mandatory.size
        val selected = mandatory.toMutableSet()
        if (slots > 0) {
            for (slot in 0 until slots) {
                val optionalIndex = ((slot + 0.5) * optional.size / slots).toInt()
                    .coerceIn(0, optional.lastIndex)
                selected += optional[optionalIndex]
            }
        }
        return selected.sorted().map(points::get)
    }
}

fun TripRouteReadResult.toBridgeMap(): Map<String, Any?> {
    val geometry = (this as? TripRouteReadResult.Available)?.geometry
    return linkedMapOf(
        "contractVersion" to MAP_DATA_CONTRACT_VERSION,
        "state" to when (this) {
            is TripRouteReadResult.Available -> "available"
            TripRouteReadResult.Unavailable -> "unavailable"
            TripRouteReadResult.Invalid -> "invalid"
        },
        "processingVersion" to geometry?.processingVersion,
        "sourceGnssCount" to (geometry?.sourceGnssCount ?: 0),
        "displayedPointCount" to (geometry?.points?.size ?: 0),
        "reduced" to (geometry?.reduced ?: false),
        "points" to geometry?.points.orEmpty().map { point ->
            linkedMapOf(
                "tripElapsedNanos" to point.tripElapsedNanos,
                "latitude" to point.latitude,
                "longitude" to point.longitude,
                "startsNewSegment" to point.startsNewSegment,
            )
        },
    )
}
