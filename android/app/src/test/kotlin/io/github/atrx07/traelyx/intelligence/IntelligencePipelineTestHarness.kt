package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.telemetry.AnalysisTimelineBuildResult
import io.github.atrx07.traelyx.telemetry.AnalysisTimelineConfig
import io.github.atrx07.traelyx.telemetry.AnalysisTimelineResampler
import io.github.atrx07.traelyx.telemetry.DerivedMotionContextSegment
import io.github.atrx07.traelyx.telemetry.DerivedMotionContextTimeline
import io.github.atrx07.traelyx.telemetry.DerivedTelemetryBuildResult
import io.github.atrx07.traelyx.telemetry.DerivedTelemetryPipeline
import io.github.atrx07.traelyx.telemetry.FrameVector3
import io.github.atrx07.traelyx.telemetry.GnssProcessingResult
import io.github.atrx07.traelyx.telemetry.GnssSanityFilter
import io.github.atrx07.traelyx.telemetry.ImuStationaryCalibrator
import io.github.atrx07.traelyx.telemetry.OrientationChangeState
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecodeResult
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecoder
import io.github.atrx07.traelyx.telemetry.StationaryOrientationChangeDetector
import io.github.atrx07.traelyx.telemetry.TelemetryConfidencePipeline
import io.github.atrx07.traelyx.telemetry.TelemetryConfidenceTimeline
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TiltOrientationResolution
import io.github.atrx07.traelyx.telemetry.TiltOrientationResolver
import io.github.atrx07.traelyx.telemetry.VehicleMountAlignmentResolver

internal fun confidenceTimelineFor(
    fixture: TelemetryRegressionFixture,
): TelemetryConfidenceTimeline {
    val trip =
        (RawTelemetryTripDecoder.decode(fixture.encodedChunks()) as
            RawTelemetryTripDecodeResult.Success).trip
    val analysis =
        (AnalysisTimelineResampler.build(
            trip,
            AnalysisTimelineConfig(
                intervalNanos = TelemetryRegressionFixtureCorpus.SAMPLE_INTERVAL_NANOS,
            ),
        ) as AnalysisTimelineBuildResult.Success).timeline
    val gnss = (GnssSanityFilter.process(trip) as GnssProcessingResult.Success).summary
    val referenceCalibration =
        ImuStationaryCalibrator.calibrate(
            frames =
                analysis.frames().filter {
                    it.tripElapsedNanos <=
                        TelemetryRegressionFixtureCorpus.REFERENCE_CALIBRATION_END_NANOS
                },
            analysisIntervalNanos = analysis.config.intervalNanos,
        )
    val subsequentCalibration =
        ImuStationaryCalibrator.calibrate(
            frames =
                analysis.frames().filter {
                    it.tripElapsedNanos in
                        TelemetryRegressionFixtureCorpus.SUBSEQUENT_CALIBRATION_START_NANOS..
                            TelemetryRegressionFixtureCorpus.SUBSEQUENT_CALIBRATION_END_NANOS
                },
            analysisIntervalNanos = analysis.config.intervalNanos,
        )
    val orientation =
        (TiltOrientationResolver.resolve(referenceCalibration) as
            TiltOrientationResolution.Available).orientation
    val orientationChange =
        StationaryOrientationChangeDetector.compare(orientation, subsequentCalibration)
    val mountAlignment =
        VehicleMountAlignmentResolver.resolve(
            orientation = orientation,
            explicitForwardHintDevice = FrameVector3.DEVICE_TOP,
            orientationChange = orientationChange,
        )
    val contexts =
        if (orientationChange.state == OrientationChangeState.INVALIDATED) {
            DerivedMotionContextTimeline(
                listOf(
                    DerivedMotionContextSegment(
                        startTripElapsedNanos = 0L,
                        endTripElapsedNanosExclusive =
                            TelemetryRegressionFixtureCorpus.PHONE_MOVE_START_NANOS,
                        calibrationResult = referenceCalibration,
                        mountAlignment =
                            VehicleMountAlignmentResolver.resolve(
                                orientation = orientation,
                                explicitForwardHintDevice = FrameVector3.DEVICE_TOP,
                            ),
                    ),
                    DerivedMotionContextSegment(
                        startTripElapsedNanos =
                            TelemetryRegressionFixtureCorpus.PHONE_MOVE_START_NANOS,
                        endTripElapsedNanosExclusive = null,
                        calibrationResult = referenceCalibration,
                        mountAlignment = mountAlignment,
                    ),
                ),
            )
        } else {
            DerivedMotionContextTimeline.fixed(referenceCalibration, mountAlignment)
        }
    val derived =
        (DerivedTelemetryPipeline.build(
            sourceTimeline = analysis,
            gnssSummary = gnss,
            motionContexts = contexts,
        ) as DerivedTelemetryBuildResult.Success).timeline
    return TelemetryConfidencePipeline.build(derived)
}
