package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.TelemetryChannel
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

const val GNSS_PROCESSING_VERSION = 1
const val DEFAULT_MAXIMUM_GNSS_HORIZONTAL_ACCURACY_METRES = 50.0
const val DEFAULT_MAXIMUM_GNSS_GAP_NANOS = 5_000_000_000L
const val DEFAULT_MAXIMUM_PLAUSIBLE_SPEED_METRES_PER_SECOND = 100.0
const val DEFAULT_STATIONARY_SPEED_THRESHOLD_METRES_PER_SECOND = 0.75

data class GnssProcessingConfig(
    val processingVersion: Int = GNSS_PROCESSING_VERSION,
    val maximumHorizontalAccuracyMetres: Double =
        DEFAULT_MAXIMUM_GNSS_HORIZONTAL_ACCURACY_METRES,
    val maximumGapNanos: Long = DEFAULT_MAXIMUM_GNSS_GAP_NANOS,
    val maximumPlausibleSpeedMetresPerSecond: Double =
        DEFAULT_MAXIMUM_PLAUSIBLE_SPEED_METRES_PER_SECOND,
    val stationarySpeedThresholdMetresPerSecond: Double =
        DEFAULT_STATIONARY_SPEED_THRESHOLD_METRES_PER_SECOND,
) {
    init {
        require(processingVersion == GNSS_PROCESSING_VERSION)
        require(maximumHorizontalAccuracyMetres.isFinite() && maximumHorizontalAccuracyMetres > 0)
        require(maximumGapNanos > 0)
        require(
            maximumPlausibleSpeedMetresPerSecond.isFinite() &&
                maximumPlausibleSpeedMetresPerSecond > 0,
        )
        require(
            stationarySpeedThresholdMetresPerSecond.isFinite() &&
                stationarySpeedThresholdMetresPerSecond >= 0 &&
                stationarySpeedThresholdMetresPerSecond <
                maximumPlausibleSpeedMetresPerSecond,
        )
    }
}

enum class GnssDecision {
    ACCEPTED_ANCHOR,
    ACCEPTED_RESOLVED_DISTANCE,
    ACCEPTED_MOTION_SUPPORTED_DISTANCE,
    EXCLUDED_LOW_ACCURACY,
    EXCLUDED_CLOCK_DISCONTINUITY,
    RESET_AFTER_GAP,
    EXCLUDED_IMPOSSIBLE_JUMP,
    EXCLUDED_STATIONARY_JITTER,
    EXCLUDED_UNRESOLVED_WITHIN_ACCURACY,
}

enum class GnssProcessingEvidence {
    RAW_LOW_ACCURACY,
    RAW_CLOCK_DISCONTINUITY,
    RAW_MOCK_LOCATION_SIGNAL,
    SOURCE_SPEED_IMPLAUSIBLE,
    SEGMENT_GAP,
    SEGMENT_WITHIN_ACCURACY,
    SOURCE_SPEED_SUPPORTS_MOTION,
    SOURCE_SPEED_SUPPORTS_STATIONARY,
    IMPOSSIBLE_JUMP,
}

data class ProcessedGnssSample(
    val processingVersion: Int = GNSS_PROCESSING_VERSION,
    val rawSample: RawGnssSample,
    val decision: GnssDecision,
    val evidence: Set<GnssProcessingEvidence>,
    val previousAnchorElapsedNanos: Long?,
    val segmentElapsedNanos: Long?,
    val geodesicDistanceMetres: Double?,
    val combinedHorizontalAccuracyMetres: Double?,
    val apparentSpeedMetresPerSecond: Double?,
    val minimumPlausibleSpeedMetresPerSecond: Double?,
    val distanceIncrementMetres: Double,
    val cumulativeDistanceMetres: Double,
    val cumulativeResolvedDistanceMetres: Double,
    val cumulativeMotionSupportedDistanceMetres: Double,
) {
    init {
        require(processingVersion == GNSS_PROCESSING_VERSION)
        require(rawSample.tripElapsedNanos != null)
        require(segmentElapsedNanos == null || segmentElapsedNanos > 0)
        requireFiniteNonNegative(geodesicDistanceMetres)
        requireFiniteNonNegative(combinedHorizontalAccuracyMetres)
        requireFiniteNonNegative(apparentSpeedMetresPerSecond)
        requireFiniteNonNegative(minimumPlausibleSpeedMetresPerSecond)
        require(distanceIncrementMetres.isFinite() && distanceIncrementMetres >= 0)
        require(cumulativeDistanceMetres.isFinite() && cumulativeDistanceMetres >= 0)
        require(
            cumulativeResolvedDistanceMetres.isFinite() &&
                cumulativeResolvedDistanceMetres >= 0,
        )
        require(
            cumulativeMotionSupportedDistanceMetres.isFinite() &&
                cumulativeMotionSupportedDistanceMetres >= 0,
        )
        require(
            approximatelyEqual(
                cumulativeDistanceMetres,
                cumulativeResolvedDistanceMetres + cumulativeMotionSupportedDistanceMetres,
            ),
        )
    }

    private fun requireFiniteNonNegative(value: Double?) {
        require(value == null || value.isFinite() && value >= 0)
    }

    private fun approximatelyEqual(
        left: Double,
        right: Double,
    ): Boolean {
        val scale = max(1.0, max(kotlin.math.abs(left), kotlin.math.abs(right)))
        return kotlin.math.abs(left - right) <= scale * DISTANCE_SUM_RELATIVE_EPSILON
    }

    private companion object {
        const val DISTANCE_SUM_RELATIVE_EPSILON = 1e-12
    }
}

data class GnssProcessingSummary(
    val processingVersion: Int = GNSS_PROCESSING_VERSION,
    val config: GnssProcessingConfig,
    val samples: List<ProcessedGnssSample>,
) {
    init {
        require(processingVersion == GNSS_PROCESSING_VERSION)
    }

    val totalDistanceMetres: Double
        get() = samples.lastOrNull()?.cumulativeDistanceMetres ?: 0.0

    val resolvedDistanceMetres: Double
        get() = samples.lastOrNull()?.cumulativeResolvedDistanceMetres ?: 0.0

    val motionSupportedDistanceMetres: Double
        get() = samples.lastOrNull()?.cumulativeMotionSupportedDistanceMetres ?: 0.0

    val decisionCounts: Map<GnssDecision, Int>
        get() = samples.groupingBy { it.decision }.eachCount()
}

sealed interface GnssProcessingResult {
    data class Success(val summary: GnssProcessingSummary) : GnssProcessingResult

    data class Invalid(
        val errorCode: String,
        val sampleIndex: Int? = null,
    ) : GnssProcessingResult
}

/** Pure, deterministic GNSS classification and distance accumulation. */
object GnssSanityFilter {
    fun process(
        trip: DecodedRawTelemetryTrip,
        config: GnssProcessingConfig = GnssProcessingConfig(),
    ): GnssProcessingResult =
        processSamples(
            samples =
                trip.records(TelemetryChannel.GNSS)
                    .map { (it as TelemetrySampleRecord.Gnss).sample },
            config = config,
        )

    fun processSamples(
        samples: Sequence<RawGnssSample>,
        config: GnssProcessingConfig = GnssProcessingConfig(),
    ): GnssProcessingResult {
        val processed = mutableListOf<ProcessedGnssSample>()
        var anchor: RawGnssSample? = null
        var previousInputElapsedNanos: Long? = null
        var cumulativeDistanceMetres = 0.0
        var cumulativeResolvedDistanceMetres = 0.0
        var cumulativeMotionSupportedDistanceMetres = 0.0

        for ((sampleIndex, sample) in samples.withIndex()) {
            val elapsedNanos =
                sample.tripElapsedNanos
                    ?: return GnssProcessingResult.Invalid(
                        errorCode = "gnss_trip_time_missing",
                        sampleIndex = sampleIndex,
                    )
            val previousElapsed = previousInputElapsedNanos
            if (previousElapsed != null && elapsedNanos <= previousElapsed) {
                return GnssProcessingResult.Invalid(
                    errorCode = "gnss_time_order_invalid",
                    sampleIndex = sampleIndex,
                )
            }
            previousInputElapsedNanos = elapsedNanos

            val rawEvidence = sample.rawEvidence(config)
            if (GnssProcessingEvidence.RAW_CLOCK_DISCONTINUITY in rawEvidence) {
                processed +=
                    excludedPoint(
                        sample = sample,
                        decision = GnssDecision.EXCLUDED_CLOCK_DISCONTINUITY,
                        evidence = rawEvidence,
                        anchor = anchor,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                anchor = null
                continue
            }
            if (GnssProcessingEvidence.RAW_LOW_ACCURACY in rawEvidence) {
                processed +=
                    excludedPoint(
                        sample = sample,
                        decision = GnssDecision.EXCLUDED_LOW_ACCURACY,
                        evidence = rawEvidence,
                        anchor = anchor,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                anchor = null
                continue
            }

            val previousAnchor = anchor
            if (previousAnchor == null) {
                processed +=
                    pointWithoutSegment(
                        sample = sample,
                        decision = GnssDecision.ACCEPTED_ANCHOR,
                        evidence = rawEvidence,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                anchor = sample
                continue
            }

            val segmentElapsedNanos = elapsedNanos - requireNotNull(previousAnchor.tripElapsedNanos)
            if (segmentElapsedNanos > config.maximumGapNanos) {
                processed +=
                    pointWithoutDistance(
                        sample = sample,
                        decision = GnssDecision.RESET_AFTER_GAP,
                        evidence = rawEvidence + GnssProcessingEvidence.SEGMENT_GAP,
                        anchor = previousAnchor,
                        segmentElapsedNanos = segmentElapsedNanos,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                anchor = sample
                continue
            }

            val geodesicDistanceMetres = greatCircleDistanceMetres(previousAnchor, sample)
            val combinedAccuracyMetres =
                previousAnchor.horizontalAccuracyMetres.toDouble() +
                    sample.horizontalAccuracyMetres.toDouble()
            val elapsedSeconds = segmentElapsedNanos / NANOS_PER_SECOND
            val apparentSpeedMetresPerSecond = geodesicDistanceMetres / elapsedSeconds
            val minimumPlausibleSpeedMetresPerSecond =
                max(0.0, geodesicDistanceMetres - combinedAccuracyMetres) / elapsedSeconds
            val withinAccuracy = geodesicDistanceMetres <= combinedAccuracyMetres
            val speedEvidence = speedEvidence(previousAnchor, sample, config)
            val segmentEvidence = buildSet {
                addAll(rawEvidence)
                addAll(speedEvidence.flags)
                if (withinAccuracy) add(GnssProcessingEvidence.SEGMENT_WITHIN_ACCURACY)
            }

            if (
                minimumPlausibleSpeedMetresPerSecond >
                config.maximumPlausibleSpeedMetresPerSecond
            ) {
                processed +=
                    pointWithSegment(
                        sample = sample,
                        decision = GnssDecision.EXCLUDED_IMPOSSIBLE_JUMP,
                        evidence = segmentEvidence + GnssProcessingEvidence.IMPOSSIBLE_JUMP,
                        anchor = previousAnchor,
                        segmentElapsedNanos = segmentElapsedNanos,
                        geodesicDistanceMetres = geodesicDistanceMetres,
                        combinedAccuracyMetres = combinedAccuracyMetres,
                        apparentSpeedMetresPerSecond = apparentSpeedMetresPerSecond,
                        minimumPlausibleSpeedMetresPerSecond =
                            minimumPlausibleSpeedMetresPerSecond,
                        distanceIncrementMetres = 0.0,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                continue
            }

            if (withinAccuracy && speedEvidence.stationary) {
                processed +=
                    pointWithSegment(
                        sample = sample,
                        decision = GnssDecision.EXCLUDED_STATIONARY_JITTER,
                        evidence = segmentEvidence,
                        anchor = previousAnchor,
                        segmentElapsedNanos = segmentElapsedNanos,
                        geodesicDistanceMetres = geodesicDistanceMetres,
                        combinedAccuracyMetres = combinedAccuracyMetres,
                        apparentSpeedMetresPerSecond = apparentSpeedMetresPerSecond,
                        minimumPlausibleSpeedMetresPerSecond =
                            minimumPlausibleSpeedMetresPerSecond,
                        distanceIncrementMetres = 0.0,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                anchor = sample
                continue
            }

            if (withinAccuracy && !speedEvidence.moving) {
                processed +=
                    pointWithSegment(
                        sample = sample,
                        decision = GnssDecision.EXCLUDED_UNRESOLVED_WITHIN_ACCURACY,
                        evidence = segmentEvidence,
                        anchor = previousAnchor,
                        segmentElapsedNanos = segmentElapsedNanos,
                        geodesicDistanceMetres = geodesicDistanceMetres,
                        combinedAccuracyMetres = combinedAccuracyMetres,
                        apparentSpeedMetresPerSecond = apparentSpeedMetresPerSecond,
                        minimumPlausibleSpeedMetresPerSecond =
                            minimumPlausibleSpeedMetresPerSecond,
                        distanceIncrementMetres = 0.0,
                        cumulativeDistanceMetres = cumulativeDistanceMetres,
                        cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                        cumulativeMotionSupportedDistanceMetres =
                            cumulativeMotionSupportedDistanceMetres,
                    )
                anchor = sample
                continue
            }

            val decision =
                if (withinAccuracy) {
                    GnssDecision.ACCEPTED_MOTION_SUPPORTED_DISTANCE
                } else {
                    GnssDecision.ACCEPTED_RESOLVED_DISTANCE
                }
            cumulativeDistanceMetres += geodesicDistanceMetres
            if (withinAccuracy) {
                cumulativeMotionSupportedDistanceMetres += geodesicDistanceMetres
            } else {
                cumulativeResolvedDistanceMetres += geodesicDistanceMetres
            }
            processed +=
                pointWithSegment(
                    sample = sample,
                    decision = decision,
                    evidence = segmentEvidence,
                    anchor = previousAnchor,
                    segmentElapsedNanos = segmentElapsedNanos,
                    geodesicDistanceMetres = geodesicDistanceMetres,
                    combinedAccuracyMetres = combinedAccuracyMetres,
                    apparentSpeedMetresPerSecond = apparentSpeedMetresPerSecond,
                    minimumPlausibleSpeedMetresPerSecond =
                        minimumPlausibleSpeedMetresPerSecond,
                    distanceIncrementMetres = geodesicDistanceMetres,
                    cumulativeDistanceMetres = cumulativeDistanceMetres,
                    cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
                    cumulativeMotionSupportedDistanceMetres =
                        cumulativeMotionSupportedDistanceMetres,
                )
            anchor = sample
        }

        return GnssProcessingResult.Success(
            GnssProcessingSummary(
                config = config,
                samples = processed.toList(),
            ),
        )
    }

    private fun RawGnssSample.rawEvidence(
        config: GnssProcessingConfig,
    ): Set<GnssProcessingEvidence> = buildSet {
        if (
            horizontalAccuracyMetres > config.maximumHorizontalAccuracyMetres ||
            GnssQualityFlag.GNSS_LOW_ACCURACY in qualityFlags
        ) {
            add(GnssProcessingEvidence.RAW_LOW_ACCURACY)
        }
        if (GnssQualityFlag.CLOCK_DISCONTINUITY in qualityFlags) {
            add(GnssProcessingEvidence.RAW_CLOCK_DISCONTINUITY)
        }
        if (isMockSignal || GnssQualityFlag.MOCK_LOCATION_SIGNAL in qualityFlags) {
            add(GnssProcessingEvidence.RAW_MOCK_LOCATION_SIGNAL)
        }
        val speed = speedMetresPerSecond?.toDouble()
        if (speed != null && speed > config.maximumPlausibleSpeedMetresPerSecond) {
            add(GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE)
        }
    }

    private fun speedEvidence(
        previous: RawGnssSample,
        current: RawGnssSample,
        config: GnssProcessingConfig,
    ): SourceSpeedEvidence {
        val reportedSpeeds =
            listOfNotNull(
                previous.speedMetresPerSecond?.toDouble(),
                current.speedMetresPerSecond?.toDouble(),
            )
        val sourceSpeedImplausible =
            reportedSpeeds.any { it > config.maximumPlausibleSpeedMetresPerSecond }
        val speeds =
            reportedSpeeds.filter { it <= config.maximumPlausibleSpeedMetresPerSecond }
        val moving = speeds.any { it > config.stationarySpeedThresholdMetresPerSecond }
        val stationary =
            speeds.size == 2 &&
                speeds.all { it <= config.stationarySpeedThresholdMetresPerSecond }
        return SourceSpeedEvidence(
            moving = moving,
            stationary = stationary,
            flags = buildSet {
                if (sourceSpeedImplausible) {
                    add(GnssProcessingEvidence.SOURCE_SPEED_IMPLAUSIBLE)
                }
                if (moving) add(GnssProcessingEvidence.SOURCE_SPEED_SUPPORTS_MOTION)
                if (stationary) add(GnssProcessingEvidence.SOURCE_SPEED_SUPPORTS_STATIONARY)
            },
        )
    }

    private fun pointWithoutSegment(
        sample: RawGnssSample,
        decision: GnssDecision,
        evidence: Set<GnssProcessingEvidence>,
        cumulativeDistanceMetres: Double,
        cumulativeResolvedDistanceMetres: Double,
        cumulativeMotionSupportedDistanceMetres: Double,
    ): ProcessedGnssSample =
        ProcessedGnssSample(
            rawSample = sample,
            decision = decision,
            evidence = evidence,
            previousAnchorElapsedNanos = null,
            segmentElapsedNanos = null,
            geodesicDistanceMetres = null,
            combinedHorizontalAccuracyMetres = null,
            apparentSpeedMetresPerSecond = null,
            minimumPlausibleSpeedMetresPerSecond = null,
            distanceIncrementMetres = 0.0,
            cumulativeDistanceMetres = cumulativeDistanceMetres,
            cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
            cumulativeMotionSupportedDistanceMetres = cumulativeMotionSupportedDistanceMetres,
        )

    private fun excludedPoint(
        sample: RawGnssSample,
        decision: GnssDecision,
        evidence: Set<GnssProcessingEvidence>,
        anchor: RawGnssSample?,
        cumulativeDistanceMetres: Double,
        cumulativeResolvedDistanceMetres: Double,
        cumulativeMotionSupportedDistanceMetres: Double,
    ): ProcessedGnssSample =
        pointWithoutDistance(
            sample = sample,
            decision = decision,
            evidence = evidence,
            anchor = anchor,
            segmentElapsedNanos =
                anchor?.let {
                    requireNotNull(sample.tripElapsedNanos) - requireNotNull(it.tripElapsedNanos)
                },
            cumulativeDistanceMetres = cumulativeDistanceMetres,
            cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
            cumulativeMotionSupportedDistanceMetres = cumulativeMotionSupportedDistanceMetres,
        )

    private fun pointWithoutDistance(
        sample: RawGnssSample,
        decision: GnssDecision,
        evidence: Set<GnssProcessingEvidence>,
        anchor: RawGnssSample?,
        segmentElapsedNanos: Long?,
        cumulativeDistanceMetres: Double,
        cumulativeResolvedDistanceMetres: Double,
        cumulativeMotionSupportedDistanceMetres: Double,
    ): ProcessedGnssSample =
        ProcessedGnssSample(
            rawSample = sample,
            decision = decision,
            evidence = evidence,
            previousAnchorElapsedNanos = anchor?.tripElapsedNanos,
            segmentElapsedNanos = segmentElapsedNanos,
            geodesicDistanceMetres = null,
            combinedHorizontalAccuracyMetres = null,
            apparentSpeedMetresPerSecond = null,
            minimumPlausibleSpeedMetresPerSecond = null,
            distanceIncrementMetres = 0.0,
            cumulativeDistanceMetres = cumulativeDistanceMetres,
            cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
            cumulativeMotionSupportedDistanceMetres = cumulativeMotionSupportedDistanceMetres,
        )

    private fun pointWithSegment(
        sample: RawGnssSample,
        decision: GnssDecision,
        evidence: Set<GnssProcessingEvidence>,
        anchor: RawGnssSample,
        segmentElapsedNanos: Long,
        geodesicDistanceMetres: Double,
        combinedAccuracyMetres: Double,
        apparentSpeedMetresPerSecond: Double,
        minimumPlausibleSpeedMetresPerSecond: Double,
        distanceIncrementMetres: Double,
        cumulativeDistanceMetres: Double,
        cumulativeResolvedDistanceMetres: Double,
        cumulativeMotionSupportedDistanceMetres: Double,
    ): ProcessedGnssSample =
        ProcessedGnssSample(
            rawSample = sample,
            decision = decision,
            evidence = evidence,
            previousAnchorElapsedNanos = anchor.tripElapsedNanos,
            segmentElapsedNanos = segmentElapsedNanos,
            geodesicDistanceMetres = geodesicDistanceMetres,
            combinedHorizontalAccuracyMetres = combinedAccuracyMetres,
            apparentSpeedMetresPerSecond = apparentSpeedMetresPerSecond,
            minimumPlausibleSpeedMetresPerSecond = minimumPlausibleSpeedMetresPerSecond,
            distanceIncrementMetres = distanceIncrementMetres,
            cumulativeDistanceMetres = cumulativeDistanceMetres,
            cumulativeResolvedDistanceMetres = cumulativeResolvedDistanceMetres,
            cumulativeMotionSupportedDistanceMetres = cumulativeMotionSupportedDistanceMetres,
        )

    private fun greatCircleDistanceMetres(
        previous: RawGnssSample,
        current: RawGnssSample,
    ): Double {
        val previousLatitude = Math.toRadians(previous.latitudeDegrees)
        val currentLatitude = Math.toRadians(current.latitudeDegrees)
        val latitudeDelta = currentLatitude - previousLatitude
        val longitudeDelta = Math.toRadians(current.longitudeDegrees - previous.longitudeDegrees)
        val haversine =
            sin(latitudeDelta / 2).let { it * it } +
                cos(previousLatitude) * cos(currentLatitude) *
                sin(longitudeDelta / 2).let { it * it }
        val centralAngle = 2 * asin(sqrt(haversine.coerceIn(0.0, 1.0)))
        return EARTH_MEAN_RADIUS_METRES * centralAngle
    }

    private data class SourceSpeedEvidence(
        val moving: Boolean,
        val stationary: Boolean,
        val flags: Set<GnssProcessingEvidence>,
    )

    private const val NANOS_PER_SECOND = 1_000_000_000.0
    private const val EARTH_MEAN_RADIUS_METRES = 6_371_008.8
}
