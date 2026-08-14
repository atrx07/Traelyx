package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.DecodedTelemetryChunk
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.RawGnssSample
import io.github.atrx07.traelyx.recorder.RawImuSample
import io.github.atrx07.traelyx.recorder.TELEMETRY_SAMPLE_COMPARATOR
import io.github.atrx07.traelyx.recorder.TelemetryChannel
import io.github.atrx07.traelyx.recorder.TelemetryChunkCodec
import io.github.atrx07.traelyx.recorder.TelemetryChunkDecodeResult
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord

const val RAW_TELEMETRY_TRIP_DECODER_VERSION = 1
const val ANALYSIS_TIMELINE_VERSION = 1
const val DEFAULT_ANALYSIS_INTERVAL_NANOS = 10_000_000L
const val DEFAULT_MAX_IMU_INTERPOLATION_GAP_NANOS = 50_000_000L

class DecodedRawTelemetryTrip internal constructor(
    val decoderVersion: Int = RAW_TELEMETRY_TRIP_DECODER_VERSION,
    val tripId: String,
    val chunkEncodingVersion: Int,
    val telemetrySchemaVersion: Int,
    val chunks: List<DecodedTelemetryChunk>,
) {
    init {
        require(decoderVersion == RAW_TELEMETRY_TRIP_DECODER_VERSION)
        require(chunks.isNotEmpty())
    }

    val startElapsedNanos: Long
        get() = chunks.first().metadata.startElapsedNanos

    val endElapsedNanos: Long
        get() = chunks.last().metadata.endElapsedNanos

    val totalSampleCount: Long
        get() = chunks.sumOf { it.metadata.totalSampleCount.toLong() }

    fun records(): Sequence<TelemetrySampleRecord> =
        chunks.asSequence().flatMap { it.records.asSequence() }

    fun records(channel: TelemetryChannel): Sequence<TelemetrySampleRecord> =
        records().filter { it.channel == channel }
}

sealed interface RawTelemetryTripDecodeResult {
    data class Success(val trip: DecodedRawTelemetryTrip) : RawTelemetryTripDecodeResult

    data class Invalid(
        val errorCode: String,
        val inputIndex: Int? = null,
        val sequence: Long? = null,
    ) : RawTelemetryTripDecodeResult
}

/**
 * Decodes a complete raw trip without depending on directory or input-list order.
 *
 * Chunk encoding/schema validation remains owned by [TelemetryChunkCodec]. This
 * layer adds trip-wide identity, sequence, boundary, and channel-time checks so
 * downstream analysis never consumes a partially ordered or mixed trip.
 */
object RawTelemetryTripDecoder {
    fun decode(encodedChunks: List<ByteArray>): RawTelemetryTripDecodeResult {
        if (encodedChunks.isEmpty()) return invalid("raw_trip_empty")

        val decoded = ArrayList<DecodedTelemetryChunk>(encodedChunks.size)
        for ((inputIndex, bytes) in encodedChunks.withIndex()) {
            when (val result = TelemetryChunkCodec.decode(bytes)) {
                is TelemetryChunkDecodeResult.Invalid ->
                    return invalid(
                        errorCode = "raw_trip_${result.errorCode}",
                        inputIndex = inputIndex,
                    )

                is TelemetryChunkDecodeResult.Success -> decoded += result.chunk
            }
        }

        val ordered = decoded.sortedBy { it.metadata.sequence }
        for ((expectedSequence, chunk) in ordered.withIndex()) {
            if (chunk.metadata.sequence != expectedSequence.toLong()) {
                return invalid(
                    errorCode = "raw_trip_sequence_invalid",
                    sequence = chunk.metadata.sequence,
                )
            }
        }

        val first = ordered.first().metadata
        if (
            ordered.any {
                it.metadata.tripId != first.tripId ||
                    it.metadata.encodingVersion != first.encodingVersion ||
                    it.metadata.telemetrySchemaVersion != first.telemetrySchemaVersion
            }
        ) {
            return invalid("raw_trip_mixed_contract")
        }

        var previousChunk: DecodedTelemetryChunk? = null
        var previousRecord: TelemetrySampleRecord? = null
        val lastChannelElapsedNanos = mutableMapOf<TelemetryChannel, Long>()
        for (chunk in ordered) {
            val priorChunk = previousChunk
            if (
                priorChunk != null &&
                chunk.metadata.startElapsedNanos < priorChunk.metadata.endElapsedNanos
            ) {
                return invalid(
                    errorCode = "raw_trip_chunk_overlap",
                    sequence = chunk.metadata.sequence,
                )
            }

            for (record in chunk.records) {
                val priorRecord = previousRecord
                if (priorRecord != null) {
                    val comparison = TELEMETRY_SAMPLE_COMPARATOR.compare(priorRecord, record)
                    if (comparison > 0) {
                        return invalid(
                            errorCode = "raw_trip_record_order_invalid",
                            sequence = chunk.metadata.sequence,
                        )
                    }
                    if (comparison == 0) {
                        return invalid(
                            errorCode = "raw_trip_duplicate_record_key",
                            sequence = chunk.metadata.sequence,
                        )
                    }
                }

                val lastChannelElapsed = lastChannelElapsedNanos[record.channel]
                if (lastChannelElapsed != null && record.tripElapsedNanos <= lastChannelElapsed) {
                    return invalid(
                        errorCode = "raw_trip_channel_time_invalid",
                        sequence = chunk.metadata.sequence,
                    )
                }
                lastChannelElapsedNanos[record.channel] = record.tripElapsedNanos
                previousRecord = record
            }
            previousChunk = chunk
        }

        return RawTelemetryTripDecodeResult.Success(
            DecodedRawTelemetryTrip(
                tripId = first.tripId,
                chunkEncodingVersion = first.encodingVersion,
                telemetrySchemaVersion = first.telemetrySchemaVersion,
                chunks = ordered.toList(),
            ),
        )
    }

    private fun invalid(
        errorCode: String,
        inputIndex: Int? = null,
        sequence: Long? = null,
    ): RawTelemetryTripDecodeResult.Invalid =
        RawTelemetryTripDecodeResult.Invalid(
            errorCode = errorCode,
            inputIndex = inputIndex,
            sequence = sequence,
        )
}

data class AnalysisTimelineConfig(
    val timelineVersion: Int = ANALYSIS_TIMELINE_VERSION,
    val intervalNanos: Long = DEFAULT_ANALYSIS_INTERVAL_NANOS,
    val maxImuInterpolationGapNanos: Long = DEFAULT_MAX_IMU_INTERPOLATION_GAP_NANOS,
) {
    init {
        require(timelineVersion == ANALYSIS_TIMELINE_VERSION)
        require(intervalNanos > 0)
        require(maxImuInterpolationGapNanos >= 0)
    }
}

enum class ImuAlignment {
    EXACT,
    INTERPOLATED,
}

enum class ImuMissingReason {
    CHANNEL_UNAVAILABLE,
    OUTSIDE_SOURCE_COVERAGE,
    SOURCE_DISCONTINUITY,
    INTERPOLATION_GAP_TOO_LARGE,
}

sealed interface ResampledImuValue {
    val targetElapsedNanos: Long

    data class Available(
        override val targetElapsedNanos: Long,
        val x: Double,
        val y: Double,
        val z: Double,
        val alignment: ImuAlignment,
        val lowerTripElapsedNanos: Long,
        val upperTripElapsedNanos: Long,
        val lowerSourceTimestampNanos: Long,
        val upperSourceTimestampNanos: Long,
        val accuracyStatus: Int,
        val qualityFlags: Set<ImuQualityFlag>,
    ) : ResampledImuValue

    data class Missing(
        override val targetElapsedNanos: Long,
        val reason: ImuMissingReason,
    ) : ResampledImuValue
}

data class AnalysisTimelineFrame(
    val timelineVersion: Int = ANALYSIS_TIMELINE_VERSION,
    val tripElapsedNanos: Long,
    val gnssSamples: List<RawGnssSample>,
    val accelerometerDeviceMetresPerSecondSquared: ResampledImuValue,
    val gyroscopeDeviceRadiansPerSecond: ResampledImuValue,
) {
    init {
        require(timelineVersion == ANALYSIS_TIMELINE_VERSION)
        require(tripElapsedNanos >= 0)
        require(gnssSamples.all { requireNotNull(it.tripElapsedNanos) >= 0 })
    }
}

class AnalysisTimeline internal constructor(
    val trip: DecodedRawTelemetryTrip,
    val config: AnalysisTimelineConfig,
    val firstFrameElapsedNanos: Long,
    val lastFrameElapsedNanos: Long,
) {
    init {
        require(firstFrameElapsedNanos >= 0)
        require(lastFrameElapsedNanos >= firstFrameElapsedNanos)
        require((lastFrameElapsedNanos - firstFrameElapsedNanos) % config.intervalNanos == 0L)
    }

    val frameCount: Long
        get() = (lastFrameElapsedNanos - firstFrameElapsedNanos) / config.intervalNanos + 1L

    /** Returns a fresh lazy iterator on every call; long trips are not materialized eagerly. */
    fun frames(): Sequence<AnalysisTimelineFrame> = sequence {
        val gnss = GnssBucketCursor(trip.gnssSamples().iterator())
        val accelerometer = ImuResamplingCursor(trip.imuSamples(TelemetryChannel.ACCELEROMETER).iterator())
        val gyroscope = ImuResamplingCursor(trip.imuSamples(TelemetryChannel.GYROSCOPE).iterator())
        var targetElapsedNanos = firstFrameElapsedNanos

        while (true) {
            val bucketEndExclusive =
                if (targetElapsedNanos > Long.MAX_VALUE - config.intervalNanos) {
                    Long.MAX_VALUE
                } else {
                    targetElapsedNanos + config.intervalNanos
                }
            yield(
                AnalysisTimelineFrame(
                    tripElapsedNanos = targetElapsedNanos,
                    gnssSamples = gnss.takeBefore(bucketEndExclusive),
                    accelerometerDeviceMetresPerSecondSquared =
                        accelerometer.valueAt(
                            targetElapsedNanos,
                            config.maxImuInterpolationGapNanos,
                        ),
                    gyroscopeDeviceRadiansPerSecond =
                        gyroscope.valueAt(
                            targetElapsedNanos,
                            config.maxImuInterpolationGapNanos,
                        ),
                ),
            )
            if (targetElapsedNanos == lastFrameElapsedNanos) break
            targetElapsedNanos += config.intervalNanos
        }
    }
}

sealed interface AnalysisTimelineBuildResult {
    data class Success(val timeline: AnalysisTimeline) : AnalysisTimelineBuildResult

    data class Invalid(val errorCode: String) : AnalysisTimelineBuildResult
}

object AnalysisTimelineResampler {
    fun build(
        trip: DecodedRawTelemetryTrip,
        config: AnalysisTimelineConfig = AnalysisTimelineConfig(),
    ): AnalysisTimelineBuildResult {
        val firstFrame = floorToInterval(trip.startElapsedNanos, config.intervalNanos)
        val lastFrame = floorToInterval(trip.endElapsedNanos, config.intervalNanos)
        if (lastFrame < firstFrame) {
            return AnalysisTimelineBuildResult.Invalid("analysis_timeline_bounds_invalid")
        }
        return AnalysisTimelineBuildResult.Success(
            AnalysisTimeline(
                trip = trip,
                config = config,
                firstFrameElapsedNanos = firstFrame,
                lastFrameElapsedNanos = lastFrame,
            ),
        )
    }

    private fun floorToInterval(value: Long, interval: Long): Long = value - value % interval
}

private fun DecodedRawTelemetryTrip.gnssSamples(): Sequence<RawGnssSample> =
    records(TelemetryChannel.GNSS).map { (it as TelemetrySampleRecord.Gnss).sample }

private fun DecodedRawTelemetryTrip.imuSamples(
    channel: TelemetryChannel,
): Sequence<RawImuSample> =
    records(channel).map { (it as TelemetrySampleRecord.Imu).sample }

private class GnssBucketCursor(samples: Iterator<RawGnssSample>) {
    private val iterator = samples
    private var next: RawGnssSample? = iterator.nextOrNull()

    fun takeBefore(endElapsedNanosExclusive: Long): List<RawGnssSample> = buildList {
        while (true) {
            val sample = next ?: break
            if (requireNotNull(sample.tripElapsedNanos) >= endElapsedNanosExclusive) break
            add(sample)
            next = iterator.nextOrNull()
        }
    }
}

private class ImuResamplingCursor(samples: Iterator<RawImuSample>) {
    private val iterator = samples
    private var lower: RawImuSample? = null
    private var upper: RawImuSample? = iterator.nextOrNull()
    private val channelAvailable = upper != null

    fun valueAt(
        targetElapsedNanos: Long,
        maxInterpolationGapNanos: Long,
    ): ResampledImuValue {
        while (true) {
            val candidate = upper ?: break
            if (candidate.elapsedNanos >= targetElapsedNanos) break
            lower = candidate
            upper = iterator.nextOrNull()
        }

        val next = upper
        if (next != null && next.elapsedNanos == targetElapsedNanos) {
            return next.asExactValue(targetElapsedNanos)
        }

        val previous = lower
        if (!channelAvailable) {
            return missing(targetElapsedNanos, ImuMissingReason.CHANNEL_UNAVAILABLE)
        }
        if (previous == null || next == null) {
            return missing(targetElapsedNanos, ImuMissingReason.OUTSIDE_SOURCE_COVERAGE)
        }

        if (
            previous.hasDiscontinuityEvidence() ||
            next.hasDiscontinuityEvidence()
        ) {
            return missing(targetElapsedNanos, ImuMissingReason.SOURCE_DISCONTINUITY)
        }

        val sourceGapNanos = next.elapsedNanos - previous.elapsedNanos
        if (sourceGapNanos <= 0 || sourceGapNanos > maxInterpolationGapNanos) {
            return missing(targetElapsedNanos, ImuMissingReason.INTERPOLATION_GAP_TOO_LARGE)
        }

        val fraction =
            (targetElapsedNanos - previous.elapsedNanos).toDouble() / sourceGapNanos.toDouble()
        return ResampledImuValue.Available(
            targetElapsedNanos = targetElapsedNanos,
            x = interpolate(previous.x, next.x, fraction),
            y = interpolate(previous.y, next.y, fraction),
            z = interpolate(previous.z, next.z, fraction),
            alignment = ImuAlignment.INTERPOLATED,
            lowerTripElapsedNanos = previous.elapsedNanos,
            upperTripElapsedNanos = next.elapsedNanos,
            lowerSourceTimestampNanos = previous.sourceTimestampNanos,
            upperSourceTimestampNanos = next.sourceTimestampNanos,
            accuracyStatus = minOf(previous.accuracyStatus, next.accuracyStatus),
            qualityFlags = previous.qualityFlags + next.qualityFlags,
        )
    }

    private fun RawImuSample.asExactValue(targetElapsedNanos: Long): ResampledImuValue.Available =
        ResampledImuValue.Available(
            targetElapsedNanos = targetElapsedNanos,
            x = x.toDouble(),
            y = y.toDouble(),
            z = z.toDouble(),
            alignment = ImuAlignment.EXACT,
            lowerTripElapsedNanos = elapsedNanos,
            upperTripElapsedNanos = elapsedNanos,
            lowerSourceTimestampNanos = sourceTimestampNanos,
            upperSourceTimestampNanos = sourceTimestampNanos,
            accuracyStatus = accuracyStatus,
            qualityFlags = qualityFlags,
        )

    private fun RawImuSample.hasDiscontinuityEvidence(): Boolean =
        ImuQualityFlag.CLOCK_DISCONTINUITY in qualityFlags ||
            ImuQualityFlag.IMU_DROPOUT in qualityFlags

    private fun missing(
        targetElapsedNanos: Long,
        reason: ImuMissingReason,
    ): ResampledImuValue.Missing =
        ResampledImuValue.Missing(
            targetElapsedNanos = targetElapsedNanos,
            reason = reason,
        )

    private fun interpolate(
        lower: Float,
        upper: Float,
        fraction: Double,
    ): Double = lower.toDouble() + (upper.toDouble() - lower.toDouble()) * fraction

    private val RawImuSample.elapsedNanos: Long
        get() = requireNotNull(tripElapsedNanos)
}

private fun <T> Iterator<T>.nextOrNull(): T? = if (hasNext()) next() else null
