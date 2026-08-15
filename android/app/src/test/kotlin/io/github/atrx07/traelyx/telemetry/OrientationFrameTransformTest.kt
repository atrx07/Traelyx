package io.github.atrx07.traelyx.telemetry

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuQualityFlag
import io.github.atrx07.traelyx.recorder.testGnssSample
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OrientationFrameTransformTest {
    @Test
    fun `flat device resolves tilt but keeps geographic yaw unobservable`() {
        val result = TiltOrientationResolver.resolve(calibration(up = FrameVector3.DEVICE_SCREEN_OUT))
        val orientation = (result as TiltOrientationResolution.Available).orientation

        assertEquals(TiltOrientationQuality.RESOLVED, orientation.quality)
        assertVector(
            FrameVector3.DEVICE_RIGHT,
            orientation.deviceToLeveledRightForwardUp.transform(FrameVector3.DEVICE_RIGHT),
        )
        assertVector(
            FrameVector3.DEVICE_TOP,
            orientation.deviceToLeveledRightForwardUp.transform(FrameVector3.DEVICE_TOP),
        )
        assertVector(
            FrameVector3.DEVICE_SCREEN_OUT,
            orientation.deviceToLeveledRightForwardUp.transform(
                FrameVector3.DEVICE_SCREEN_OUT,
            ),
        )
        assertTrue(TiltOrientationEvidence.DEVICE_TOP_HORIZONTAL_REFERENCE in orientation.evidence)
        assertTrue(TiltOrientationEvidence.GEOGRAPHIC_YAW_UNOBSERVABLE in orientation.evidence)
    }

    @Test
    fun `upright device uses deterministic horizontal fallback without claiming north`() {
        val result = TiltOrientationResolver.resolve(calibration(up = FrameVector3.DEVICE_TOP))
        val orientation = (result as TiltOrientationResolution.Available).orientation

        assertVector(
            FrameVector3(0.0, 0.0, 1.0),
            orientation.deviceToLeveledRightForwardUp.transform(FrameVector3.DEVICE_TOP),
        )
        assertTrue(
            TiltOrientationEvidence.DEVICE_RIGHT_HORIZONTAL_REFERENCE_FALLBACK in
                orientation.evidence,
        )
        assertTrue(TiltOrientationEvidence.GEOGRAPHIC_YAW_UNOBSERVABLE in orientation.evidence)
    }

    @Test
    fun `degraded and insufficient calibration remain explicit`() {
        val degraded =
            (TiltOrientationResolver.resolve(
                calibration(up = FrameVector3.DEVICE_SCREEN_OUT, degraded = true),
            ) as TiltOrientationResolution.Available).orientation
        assertEquals(TiltOrientationQuality.DEGRADED, degraded.quality)
        assertTrue(TiltOrientationEvidence.CALIBRATION_DEGRADED in degraded.evidence)

        val unavailable = TiltOrientationResolver.resolve(insufficientCalibration())
            as TiltOrientationResolution.Unavailable
        assertEquals(
            TiltOrientationUnavailableReason.CALIBRATION_INSUFFICIENT,
            unavailable.reason,
        )
        assertTrue(ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION in unavailable.calibrationEvidence)
    }

    @Test
    fun `persistent gravity direction change invalidates tilt assumptions`() {
        val reference = resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT)
        val angleRadians = 20.0 * PI / 180.0
        val changedUp = FrameVector3(sin(angleRadians), 0.0, cos(angleRadians))

        val changed =
            StationaryOrientationChangeDetector.compare(
                reference,
                calibration(up = changedUp, startTripElapsedNanos = 3_000_000_000L),
            )

        assertEquals(OrientationChangeState.INVALIDATED, changed.state)
        assertEquals(20.0, requireNotNull(changed.gravityDirectionChangeDegrees), 1e-9)
        assertTrue(OrientationChangeEvidence.GRAVITY_DIRECTION_CHANGED in changed.evidence)
        assertTrue(OrientationChangeEvidence.YAW_CHANGE_UNOBSERVABLE in changed.evidence)
    }

    @Test
    fun `unchanged gravity cannot prove that yaw stayed fixed`() {
        val reference = resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT)

        val result =
            StationaryOrientationChangeDetector.compare(
                reference,
                calibration(
                    up = FrameVector3.DEVICE_SCREEN_OUT,
                    startTripElapsedNanos = 3_000_000_000L,
                ),
            )

        assertEquals(OrientationChangeState.CONSISTENT, result.state)
        assertEquals(0.0, requireNotNull(result.gravityDirectionChangeDegrees), 0.0)
        assertEquals(setOf(OrientationChangeEvidence.YAW_CHANGE_UNOBSERVABLE), result.evidence)
    }

    @Test
    fun `insufficient subsequent evidence makes orientation change indeterminate`() {
        val result =
            StationaryOrientationChangeDetector.compare(
                resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT),
                insufficientCalibration(),
            )

        assertEquals(OrientationChangeState.INDETERMINATE, result.state)
        assertEquals(null, result.gravityDirectionChangeDegrees)
        assertTrue(
            OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_INSUFFICIENT in result.evidence,
        )
    }

    @Test
    fun `orientation comparison requires a genuinely later stationary window`() {
        val result =
            StationaryOrientationChangeDetector.compare(
                resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT),
                calibration(up = FrameVector3.DEVICE_SCREEN_OUT),
            )

        assertEquals(OrientationChangeState.INDETERMINATE, result.state)
        assertTrue(
            OrientationChangeEvidence.SUBSEQUENT_CALIBRATION_NOT_LATER in result.evidence,
        )
    }

    @Test
    fun `explicit device top alignment maps Android axes to forward left up`() {
        val resolution =
            VehicleMountAlignmentResolver.resolve(
                orientation = resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT),
                explicitForwardHintDevice = FrameVector3.DEVICE_TOP,
                orientationChange = consistentOrientationChange(),
            )
        val alignment = (resolution as VehicleMountAlignmentResolution.Available).alignment

        assertEquals(VehicleMountAlignmentQuality.RESOLVED, alignment.quality)
        assertVector(
            FrameVector3(1.0, 0.0, 0.0),
            alignment.deviceToVehicleForwardLeftUp.transform(FrameVector3.DEVICE_TOP),
        )
        assertVector(
            FrameVector3(0.0, 1.0, 0.0),
            alignment.deviceToVehicleForwardLeftUp.transform(
                FrameVector3.DEVICE_RIGHT * -1.0,
            ),
        )
        assertVector(
            FrameVector3(0.0, 0.0, 1.0),
            alignment.deviceToVehicleForwardLeftUp.transform(
                FrameVector3.DEVICE_SCREEN_OUT,
            ),
        )
    }

    @Test
    fun `mount alignment refuses invalidated orientation and vertical forward hint`() {
        val orientation = resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT)
        val invalidated =
            StationaryOrientationChangeDetector.compare(
                orientation,
                calibration(
                    up = FrameVector3(sin(20.0 * PI / 180.0), 0.0, cos(20.0 * PI / 180.0)),
                    startTripElapsedNanos = 3_000_000_000L,
                ),
            )
        val moved =
            VehicleMountAlignmentResolver.resolve(
                orientation,
                FrameVector3.DEVICE_TOP,
                invalidated,
            ) as VehicleMountAlignmentResolution.Unavailable
        assertEquals(VehicleMountAlignmentUnavailableReason.ORIENTATION_INVALIDATED, moved.reason)

        val vertical =
            VehicleMountAlignmentResolver.resolve(
                orientation,
                FrameVector3.DEVICE_SCREEN_OUT,
                consistentOrientationChange(),
            ) as VehicleMountAlignmentResolution.Unavailable
        assertEquals(
            VehicleMountAlignmentUnavailableReason.FORWARD_HINT_PARALLEL_TO_UP,
            vertical.reason,
        )

        val foreignReference =
            resolvedTilt(
                up = FrameVector3.DEVICE_SCREEN_OUT,
                startTripElapsedNanos = 10_000_000_000L,
            )
        val mismatchedChange =
            StationaryOrientationChangeDetector.compare(
                foreignReference,
                calibration(
                    up = FrameVector3.DEVICE_SCREEN_OUT,
                    startTripElapsedNanos = 13_000_000_000L,
                ),
            )
        val mismatched =
            VehicleMountAlignmentResolver.resolve(
                orientation,
                FrameVector3.DEVICE_TOP,
                mismatchedChange,
            ) as VehicleMountAlignmentResolution.Unavailable
        assertEquals(
            VehicleMountAlignmentUnavailableReason.ORIENTATION_CHANGE_REFERENCE_MISMATCH,
            mismatched.reason,
        )
    }

    @Test
    fun `indeterminate movement check degrades rather than fabricates certainty`() {
        val orientation = resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT)
        val unevaluated =
            (VehicleMountAlignmentResolver.resolve(
                orientation,
                FrameVector3.DEVICE_TOP,
            ) as VehicleMountAlignmentResolution.Available).alignment
        assertEquals(VehicleMountAlignmentQuality.DEGRADED, unevaluated.quality)
        assertTrue(
            VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_NOT_EVALUATED in
                unevaluated.evidence,
        )

        val indeterminate =
            StationaryOrientationChangeDetector.compare(orientation, insufficientCalibration())
        val alignment =
            (VehicleMountAlignmentResolver.resolve(
                orientation,
                FrameVector3.DEVICE_TOP,
                indeterminate,
            ) as VehicleMountAlignmentResolution.Available).alignment

        assertEquals(VehicleMountAlignmentQuality.DEGRADED, alignment.quality)
        assertTrue(
            VehicleMountAlignmentEvidence.ORIENTATION_CHANGE_INDETERMINATE in alignment.evidence,
        )
    }

    @Test
    fun `GNSS course maps north and east bearings into ENU`() {
        val north = resolvedCourse(bearingDegrees = 0.0f)
        assertVector(FrameVector3.ENU_NORTH, north.forwardEnu)
        assertVector(FrameVector3(-1.0, 0.0, 0.0), north.leftEnu)
        assertVector(
            FrameVector3.ENU_NORTH,
            north.vehicleForwardLeftUpToEnu.transform(FrameVector3(1.0, 0.0, 0.0)),
        )

        val east = resolvedCourse(bearingDegrees = 90.0f)
        assertVector(FrameVector3.ENU_EAST, east.forwardEnu)
        assertVector(FrameVector3.ENU_NORTH, east.leftEnu)
        assertVector(
            FrameVector3.ENU_EAST,
            east.vehicleForwardLeftUpToEnu.transform(FrameVector3(1.0, 0.0, 0.0)),
        )
    }

    @Test
    fun `GNSS course requires usable speed bearing accuracy and sanity evidence`() {
        assertCourseUnavailable(
            raw = testGnssSample().copy(bearingDegrees = null, bearingAccuracyDegrees = null),
            expected = GnssCourseUnavailableReason.BEARING_UNAVAILABLE,
        )
        assertCourseUnavailable(
            raw = testGnssSample().copy(speedMetresPerSecond = null),
            expected = GnssCourseUnavailableReason.SPEED_UNAVAILABLE,
        )
        assertCourseUnavailable(
            raw = testGnssSample().copy(speedMetresPerSecond = 2.0f),
            expected = GnssCourseUnavailableReason.SPEED_BELOW_HEADING_THRESHOLD,
        )
        assertCourseUnavailable(
            raw = testGnssSample().copy(bearingAccuracyDegrees = null),
            expected = GnssCourseUnavailableReason.BEARING_ACCURACY_UNAVAILABLE,
        )
        assertCourseUnavailable(
            raw = testGnssSample().copy(bearingAccuracyDegrees = 31.0f),
            expected = GnssCourseUnavailableReason.BEARING_ACCURACY_TOO_LOW,
        )
        assertCourseUnavailable(
            raw =
                testGnssSample().copy(
                    horizontalAccuracyMetres = 60.0f,
                    qualityFlags = setOf(GnssQualityFlag.GNSS_LOW_ACCURACY),
                ),
            expected = GnssCourseUnavailableReason.GNSS_SAMPLE_REJECTED,
        )
        assertCourseUnavailable(
            raw = testGnssSample().copy(speedMetresPerSecond = 101.0f),
            expected = GnssCourseUnavailableReason.SOURCE_SPEED_IMPLAUSIBLE,
        )
        assertCourseUnavailable(
            raw = testGnssSample(tripElapsedNanos = 100_000_000L),
            expected = GnssCourseUnavailableReason.COURSE_SOURCE_AFTER_TARGET,
            targetTripElapsedNanos = 99_999_999L,
        )
        assertCourseUnavailable(
            raw = testGnssSample(tripElapsedNanos = 100_000_000L),
            expected = GnssCourseUnavailableReason.COURSE_TOO_OLD,
            targetTripElapsedNanos = 2_100_000_001L,
        )
    }

    @Test
    fun `mock course remains usable only as degraded evidence`() {
        val raw =
            testGnssSample().copy(
                bearingDegrees = 0.0f,
                isMockSignal = true,
                qualityFlags = setOf(GnssQualityFlag.MOCK_LOCATION_SIGNAL),
            )
        val result = resolveCourse(raw) as GnssCourseResolution.Available

        assertEquals(GnssCourseQuality.DEGRADED, result.course.quality)
        assertEquals(setOf(GnssCourseEvidence.MOCK_LOCATION_SIGNAL), result.course.evidence)
    }

    @Test
    fun `complete transform maps device evidence into vehicle and ENU frames`() {
        val mount =
            VehicleMountAlignmentResolver.resolve(
                resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT),
                FrameVector3.DEVICE_TOP,
                consistentOrientationChange(),
            )
        val course =
            GnssCourseResolution.Available(
                resolvedCourse(
                    bearingDegrees = 0.0f,
                    tripElapsedNanos = 3_000_000_000L,
                ),
            )
        val result = WorldFrameTransformResolver.resolve(mount, course)
            as WorldFrameTransformResolution.Available
        val transform = result.transform

        assertEquals(NavigationFrameConvention.EAST_NORTH_UP, transform.navigationConvention)
        assertEquals(VehicleFrameConvention.FORWARD_LEFT_UP, transform.vehicleConvention)
        assertVector(
            FrameVector3.ENU_NORTH,
            transform.deviceToWorldEnu.transform(FrameVector3.DEVICE_TOP),
        )
        assertVector(
            FrameVector3(-1.0, 0.0, 0.0),
            transform.deviceToWorldEnu.transform(FrameVector3.DEVICE_RIGHT * -1.0),
        )
        assertVector(
            FrameVector3.ENU_UP,
            transform.deviceToWorldEnu.transform(FrameVector3.DEVICE_SCREEN_OUT),
        )
        val arbitrary = FrameVector3(2.0, -3.0, 4.0)
        assertEquals(
            arbitrary.magnitude,
            transform.deviceToWorldEnu.transform(arbitrary).magnitude,
            1e-9,
        )
    }

    @Test
    fun `world transform propagates degraded evidence and unavailable prerequisites`() {
        val degradedMount =
            VehicleMountAlignmentResolver.resolve(
                resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT, degraded = true),
                FrameVector3.DEVICE_TOP,
                consistentOrientationChange(),
            )
        val mockCourse =
            resolveCourse(
                testGnssSample(tripElapsedNanos = 3_000_000_000L).copy(
                    bearingDegrees = 0.0f,
                    isMockSignal = true,
                    qualityFlags = setOf(GnssQualityFlag.MOCK_LOCATION_SIGNAL),
                ),
            )
        val degraded = WorldFrameTransformResolver.resolve(degradedMount, mockCourse)
            as WorldFrameTransformResolution.Available
        assertEquals(WorldFrameTransformQuality.DEGRADED, degraded.transform.quality)
        assertEquals(
            setOf(
                WorldFrameTransformEvidence.MOUNT_ALIGNMENT_DEGRADED,
                WorldFrameTransformEvidence.GNSS_COURSE_DEGRADED,
            ),
            degraded.transform.evidence,
        )

        val noMount =
            WorldFrameTransformResolver.resolve(
                VehicleMountAlignmentResolution.Unavailable(
                    VehicleMountAlignmentUnavailableReason.FORWARD_HINT_PARALLEL_TO_UP,
                ),
                mockCourse,
            ) as WorldFrameTransformResolution.Unavailable
        assertEquals(
            WorldFrameTransformUnavailableReason.MOUNT_ALIGNMENT_UNAVAILABLE,
            noMount.reason,
        )

        val noCourse =
            WorldFrameTransformResolver.resolve(
                degradedMount,
                resolveCourse(
                    testGnssSample(tripElapsedNanos = 3_000_000_000L).copy(
                        speedMetresPerSecond = 1.0f,
                    ),
                ),
            ) as WorldFrameTransformResolution.Unavailable
        assertEquals(WorldFrameTransformUnavailableReason.GNSS_COURSE_UNAVAILABLE, noCourse.reason)
        assertEquals(
            GnssCourseUnavailableReason.SPEED_BELOW_HEADING_THRESHOLD,
            noCourse.courseReason,
        )

        val mountFromFuture =
            WorldFrameTransformResolver.resolve(
                degradedMount,
                GnssCourseResolution.Available(resolvedCourse(bearingDegrees = 0.0f)),
            ) as WorldFrameTransformResolution.Unavailable
        assertEquals(
            WorldFrameTransformUnavailableReason.MOUNT_CALIBRATION_AFTER_TARGET,
            mountFromFuture.reason,
        )
    }

    @Test
    fun `default frame contract is explicitly versioned`() {
        val config = OrientationFrameTransformConfig()

        assertEquals(ORIENTATION_FRAME_TRANSFORM_VERSION, config.transformVersion)
        assertEquals(0.1, config.minimumHorizontalReferenceNorm, 0.0)
        assertEquals(10.0, config.maximumGravityDirectionChangeDegrees, 0.0)
        assertEquals(3.0, config.minimumGnssHeadingSpeedMetresPerSecond, 0.0)
        assertEquals(30.0, config.maximumGnssBearingAccuracyDegrees, 0.0)
        assertEquals(2_000_000_000L, config.maximumGnssHeadingAgeNanos)
    }

    private fun resolvedTilt(
        up: FrameVector3,
        degraded: Boolean = false,
        startTripElapsedNanos: Long = 0L,
    ): TiltOrientation =
        (TiltOrientationResolver.resolve(
            calibration(
                up = up,
                degraded = degraded,
                startTripElapsedNanos = startTripElapsedNanos,
            ),
        ) as TiltOrientationResolution.Available).orientation

    private fun calibration(
        up: FrameVector3,
        degraded: Boolean = false,
        startTripElapsedNanos: Long = 0L,
    ): ImuStationaryCalibrationResult {
        val unitUp = up.normalized()
        val flags =
            if (degraded) {
                setOf(ImuQualityFlag.SENSOR_UNRELIABLE)
            } else {
                emptySet()
            }
        return ImuStationaryCalibrationResult(
            state =
                if (degraded) {
                    ImuCalibrationState.CALIBRATED_DEGRADED
                } else {
                    ImuCalibrationState.CALIBRATED
                },
            config = ImuStationaryCalibrationConfig(),
            calibration =
                ImuBiasCalibration(
                    startTripElapsedNanos = startTripElapsedNanos,
                    endTripElapsedNanos = startTripElapsedNanos + 2_000_000_000L,
                    sampleCount = 201,
                    meanAccelerometerDeviceMetresPerSecondSquared =
                        unitUp.toCalibrationVector() *
                            STANDARD_GRAVITY_METRES_PER_SECOND_SQUARED,
                    gravityDirectionDevice = unitUp.toCalibrationVector(),
                    observableAccelerometerRadialBiasMetresPerSecondSquared = 0.0,
                    observableAccelerometerRadialBiasDeviceMetresPerSecondSquared =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    gyroscopeBiasDeviceRadiansPerSecond = CalibrationVector3(0.0, 0.0, 0.0),
                    accelerometerAxisStandardDeviationMetresPerSecondSquared =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    gyroscopeAxisStandardDeviationRadiansPerSecond =
                        CalibrationVector3(0.0, 0.0, 0.0),
                    accelerometerMinimumAccuracyStatus = if (degraded) 0 else 3,
                    gyroscopeMinimumAccuracyStatus = 3,
                    accelerometerInterpolatedFrameCount = 0,
                    gyroscopeInterpolatedFrameCount = 0,
                    rawQualityFlags = flags,
                ),
            evidence =
                if (degraded) {
                    setOf(ImuCalibrationEvidence.SENSOR_UNRELIABLE)
                } else {
                    emptySet()
                },
            diagnostics = diagnostics(),
        )
    }

    private fun insufficientCalibration(): ImuStationaryCalibrationResult =
        ImuStationaryCalibrationResult(
            state = ImuCalibrationState.INSUFFICIENT_EVIDENCE,
            config = ImuStationaryCalibrationConfig(),
            calibration = null,
            evidence = setOf(ImuCalibrationEvidence.INSUFFICIENT_STATIONARY_DURATION),
            diagnostics = diagnostics(),
        )

    private fun consistentOrientationChange(): OrientationChangeResult =
        StationaryOrientationChangeDetector.compare(
            resolvedTilt(FrameVector3.DEVICE_SCREEN_OUT),
            calibration(
                up = FrameVector3.DEVICE_SCREEN_OUT,
                startTripElapsedNanos = 3_000_000_000L,
            ),
        )

    private fun diagnostics(): ImuCalibrationDiagnostics =
        ImuCalibrationDiagnostics(
            totalFrameCount = 0L,
            pairedAvailableFrameCount = 0L,
            stationaryCandidateFrameCount = 0L,
            longestCandidateDurationNanos = 0L,
            accelerometerMissingFrameCount = 0L,
            gyroscopeMissingFrameCount = 0L,
            sourceDiscontinuityFrameCount = 0L,
            accelerometerNotGravityLikeFrameCount = 0L,
            gyroscopeMotionFrameCount = 0L,
            unstableWindowCount = 0L,
        )

    private fun resolvedCourse(
        bearingDegrees: Float,
        tripElapsedNanos: Long = 100_000_000L,
    ): ResolvedGnssCourse =
        (resolveCourse(
            testGnssSample(tripElapsedNanos = tripElapsedNanos).copy(
                bearingDegrees = bearingDegrees,
            ),
        ) as GnssCourseResolution.Available).course

    private fun resolveCourse(
        raw: io.github.atrx07.traelyx.recorder.RawGnssSample,
        targetTripElapsedNanos: Long = requireNotNull(raw.tripElapsedNanos),
    ): GnssCourseResolution =
        GnssCourseResolver.resolve(
            sample = processed(raw),
            targetTripElapsedNanos = targetTripElapsedNanos,
        )

    private fun processed(raw: io.github.atrx07.traelyx.recorder.RawGnssSample): ProcessedGnssSample =
        ((GnssSanityFilter.processSamples(sequenceOf(raw)) as GnssProcessingResult.Success)
            .summary.samples.single())

    private fun assertCourseUnavailable(
        raw: io.github.atrx07.traelyx.recorder.RawGnssSample,
        expected: GnssCourseUnavailableReason,
        targetTripElapsedNanos: Long = requireNotNull(raw.tripElapsedNanos),
    ) {
        val result = resolveCourse(raw, targetTripElapsedNanos) as GnssCourseResolution.Unavailable
        assertEquals(expected, result.reason)
    }

    private fun FrameVector3.toCalibrationVector(): CalibrationVector3 =
        CalibrationVector3(x, y, z)

    private fun assertVector(
        expected: FrameVector3,
        actual: FrameVector3,
        tolerance: Double = 1e-9,
    ) {
        assertEquals(expected.x, actual.x, tolerance)
        assertEquals(expected.y, actual.y, tolerance)
        assertEquals(expected.z, actual.z, tolerance)
    }
}
