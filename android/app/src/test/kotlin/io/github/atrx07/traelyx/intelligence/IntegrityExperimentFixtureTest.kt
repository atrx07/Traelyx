package io.github.atrx07.traelyx.intelligence

import io.github.atrx07.traelyx.recorder.GnssQualityFlag
import io.github.atrx07.traelyx.recorder.ImuSensorType
import io.github.atrx07.traelyx.recorder.TelemetrySampleRecord
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecodeResult
import io.github.atrx07.traelyx.telemetry.RawTelemetryTripDecoder
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixture
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionFixtureCorpus
import io.github.atrx07.traelyx.telemetry.TelemetryRegressionScenario
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.util.Locale
import kotlin.math.sqrt
import org.junit.Assert.*
import org.junit.Test

/** Generated aggregate export only. No production code or private telemetry input. */
internal object IntegrityExperimentFixtures {
    const val VERSION = 1
    val featureNames = listOf("speed_mean_mps", "speed_max_mps", "speed_std_mps",
        "accel_norm_mean_mps2", "accel_norm_std_mps2", "gyro_norm_mean_radps",
        "gyro_norm_max_radps", "gyro_norm_std_radps")
    val clean = listOf("STATIONARY", "SMOOTH_STRAIGHT", "SMOOTH_ACCELERATION", "BRAKING",
        "LEFT_CORNER", "RIGHT_CORNER", "POTHOLE", "MOTORCYCLE_VIBRATION")
    val extra = listOf("SPEED_INJECTION", "GYRO_INJECTION", "ACCEL_INJECTION", "MOCK_SIGNAL",
        "GNSS_LOSS", "PHONE_MOVE", "CORRUPT_HEADER", "TRUNCATED_CHUNK")

    fun partition(profile: Int): String = when (profile) {
        1, 3, 5, 7, 9 -> "train"
        2, 8 -> "validation"
        4, 6 -> "test"
        else -> error("unknown generated profile")
    }

    fun category(scenario: String): String = when (scenario) {
        in clean -> "clean"
        "SPEED_INJECTION", "GYRO_INJECTION", "ACCEL_INJECTION" -> "numeric_inconsistency"
        "MOCK_SIGNAL" -> "platform_signal"
        "GNSS_LOSS", "PHONE_MOVE" -> "quality_limitation"
        "CORRUPT_HEADER", "TRUNCATED_CHUNK" -> "corruption"
        else -> error("unknown generated scenario")
    }

    fun generate(): ByteArray {
        check(TelemetryRegressionFixtureCorpus.VERSION == 1 && INTEGRITY_RULES_VERSION == 1)
        val header = listOf("case_id", "profile", "partition", "scenario", "category", "decoder",
            "corpus_version", "integrity_version", "baseline_state", "baseline_kinds", "baseline_rules") + featureNames
        val rows = mutableListOf(header.joinToString(","))
        for (profile in 1..9) {
            // Assign profile before generation; no overlapping windows or post-hoc split.
            val split = partition(profile)
            val profileId = String.format(Locale.ROOT, "sim-profile-%02d", profile)
            for (scenario in clean + if (split == "train") emptyList() else extra) {
                val fixture = fixture(profile, scenario)
                val chunks = fixture.encodedChunks().map { it.copyOf() }.toMutableList()
                if (scenario == "CORRUPT_HEADER") chunks[0][0] = (chunks[0][0].toInt() xor 1).toByte()
                if (scenario == "TRUNCATED_CHUNK") chunks[chunks.lastIndex] = chunks.last().dropLast(1).toByteArray()
                val decoded = RawTelemetryTripDecoder.decode(chunks)
                val rejected = decoded is RawTelemetryTripDecodeResult.Invalid
                val audit = if (decoded is RawTelemetryTripDecodeResult.Invalid) {
                    IntegrityPipeline.audit(decoded)
                } else {
                    require(decoded is RawTelemetryTripDecodeResult.Success)
                    IntegrityPipeline.audit(EventMergePipeline.build(EventTaxonomyPipeline.build(confidenceTimelineFor(fixture))))
                }
                check(rejected == (category(scenario) == "corruption"))
                if (category(scenario) == "clean") check(audit.state == TripIntegrityState.VERIFIED)
                val features = if (rejected) List(8) { "" } else features(fixture).map { it.toString() }
                rows += (listOf("$profileId-${scenario.lowercase(Locale.ROOT)}", profileId, split, scenario,
                    category(scenario), if (rejected) "rejected" else "valid", TelemetryRegressionFixtureCorpus.VERSION.toString(),
                    INTEGRITY_RULES_VERSION.toString(), audit.state.name,
                    audit.findings.map { it.kind.name }.distinct().sorted().joinToString("|"),
                    audit.findings.map { it.ruleId.machineId }.distinct().sorted().joinToString("|")) + features).joinToString(",")
            }
        }
        check(rows.size == 105)
        return (rows.joinToString("\n") + "\n").toByteArray(Charsets.UTF_8)
    }

    private fun fixture(profile: Int, scenario: String): TelemetryRegressionFixture {
        val baseScenario = if (scenario in clean || scenario in listOf("GNSS_LOSS", "PHONE_MOVE")) {
            TelemetryRegressionScenario.valueOf(scenario)
        } else TelemetryRegressionScenario.SMOOTH_STRAIGHT
        val source = TelemetryRegressionFixtureCorpus.generate(baseScenario)
        val gain = 1f + ((profile * 7) % 13 - 6) * .002f
        val bias = ((profile * 17) % 11 - 5) * .0007f
        return source.copy(records = source.records.map { record ->
            val action = record.tripElapsedNanos in 5_000_000_000L..11_500_000_000L
            when (record) {
                is TelemetrySampleRecord.Imu -> {
                    val sample = record.sample
                    record.copy(sample = sample.copy(
                        x = sample.x * gain + bias,
                        y = sample.y * gain - bias + if (action && scenario == "ACCEL_INJECTION" && sample.sensorType == ImuSensorType.ACCELEROMETER) 12f else 0f,
                        z = sample.z * gain + if (action && scenario == "GYRO_INJECTION" && sample.sensorType == ImuSensorType.GYROSCOPE) 4f else 0f,
                    ))
                }
                is TelemetrySampleRecord.Gnss -> record.copy(sample = record.sample.copy(
                    speedMetresPerSecond = if (action && scenario == "SPEED_INJECTION") 400f else record.sample.speedMetresPerSecond,
                    isMockSignal = scenario == "MOCK_SIGNAL",
                    qualityFlags = record.sample.qualityFlags + if (scenario == "MOCK_SIGNAL") setOf(GnssQualityFlag.MOCK_LOCATION_SIGNAL) else emptySet(),
                ))
            }
        })
    }

    private fun features(fixture: TelemetryRegressionFixture): List<Double> {
        val speeds = fixture.records.filterIsInstance<TelemetrySampleRecord.Gnss>().map {
            requireNotNull(it.sample.speedMetresPerSecond).toDouble()
        }
        fun norms(sensor: ImuSensorType) = fixture.records.filterIsInstance<TelemetrySampleRecord.Imu>()
            .filter { it.sample.sensorType == sensor }.map { record -> record.sample.let {
                sqrt(it.x.toDouble() * it.x + it.y.toDouble() * it.y + it.z.toDouble() * it.z)
            } }
        val acceleration = norms(ImuSensorType.ACCELEROMETER)
        val gyro = norms(ImuSensorType.GYROSCOPE)
        fun deviation(values: List<Double>): Double {
            val mean = values.average()
            return sqrt(values.sumOf { (it - mean) * (it - mean) } / values.size)
        }
        return listOf(speeds.average(), speeds.max(), deviation(speeds), acceleration.average(),
            deviation(acceleration), gyro.average(), gyro.max(), deviation(gyro)).also {
            check(it.size == 8 && it.all { value -> value.isFinite() && value >= 0.0 })
        }
    }
}

class IntegrityExperimentFixtureTest {
    @Test fun `generated profile corpus compares native baseline repeatably without raw export`() {
        val bytes = IntegrityExperimentFixtures.generate()
        assertArrayEquals(bytes, IntegrityExperimentFixtures.generate())
        val lines = bytes.toString(Charsets.UTF_8).trimEnd().lines()
        assertEquals(105, lines.size)
        assertFalse(lines.first().contains("latitude"))
        assertFalse(lines.first().contains("timestamp"))
        val counts = lines.drop(1).groupingBy { it.split(',')[2] }.eachCount()
        assertEquals(mapOf("train" to 40, "validation" to 32, "test" to 32), counts)
        for (line in lines.drop(1)) {
            val values = line.split(',')
            assertEquals(19, values.size)
            if (values[4] == "corruption") {
                assertEquals("rejected", values[5])
                assertEquals("UNRANKED", values[8])
                assertEquals("DATA_CORRUPTION", values[9])
                assertTrue(values.drop(11).all { it.isEmpty() })
            }
        }
        // Explicit generated-only export for host/CI CPU experiment. Never overwrite.
        System.getenv("TRAELYX_INTEGRITY_FIXTURE_OUTPUT")?.let { target ->
            val file = File(target)
            require(file.isAbsolute && file.name == "integrity-fixtures-v1.csv")
            val root = File(requireNotNull(System.getProperty("user.dir"))).toPath().toAbsolutePath().normalize()
            val repository = if (root.fileName.toString() == "app") root.parent.parent else root.parent
            val approved = repository.resolve(".dart_tool").toRealPath()
            require(approved == repository.toRealPath().resolve(".dart_tool"))
            require(requireNotNull(file.parentFile).toPath().toRealPath() == approved)
            Files.write(file.toPath(), bytes, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE)
        }
    }
}
