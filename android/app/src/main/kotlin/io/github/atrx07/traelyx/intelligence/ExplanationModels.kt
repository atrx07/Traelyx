package io.github.atrx07.traelyx.intelligence

import java.util.Collections

const val EXPLANATION_VERSION = 1
const val EXPLANATION_MESSAGE_CATALOG_VERSION = 1

/** M4.7 reason-path schema. Message copy is localized later without changing evidence meaning. */
data class ExplanationConfig(
    val explanationVersion: Int = EXPLANATION_VERSION,
    val messageCatalogVersion: Int = EXPLANATION_MESSAGE_CATALOG_VERSION,
) {
    init {
        require(explanationVersion == EXPLANATION_VERSION)
        require(messageCatalogVersion == EXPLANATION_MESSAGE_CATALOG_VERSION)
    }
}

enum class ExplanationSubjectKind {
    DRIVING_EVENT,
    INTEGRITY_STATUS,
    SCORE_DIMENSION,
    SCORE_OVERALL,
    DRIVE_DNA_DIMENSION,
    DRIVE_DNA_LIFECYCLE,
}

enum class ExplanationLayer {
    MEASUREMENT,
    DETECTED_EVENT,
    CONFIDENCE,
    SCORING_CONSEQUENCE,
    INTEGRITY,
    BASELINE,
}

enum class ExplanationReasonRole {
    SUPPORTING,
    CONTRIBUTING,
    LIMITING,
    EXCLUDING,
    INFORMATIONAL,
}

enum class ExplanationValueUnit {
    COUNT,
    NANOSECONDS,
    UTC_EPOCH_MICROSECONDS,
    SCORE_MILLI_POINTS,
    PERMILLE,
    BASIS_POINTS,
    METRES_PER_SECOND_SQUARED,
    METRES_PER_SECOND_CUBED,
}

enum class ExplanationSourceKind {
    MERGED_EVENT,
    SCORE_CONTRIBUTION,
    INTEGRITY_FINDING,
    DRIVE_DNA_TRIP,
}

sealed interface ExplanationArgument {
    val key: String

    data class MachineCode(
        override val key: String,
        val value: String,
    ) : ExplanationArgument {
        init {
            requireExplanationArgumentKey(key)
            require(MACHINE_CODE_REGEX.matches(value))
        }
    }

    data class MachineCodeList(
        override val key: String,
        val values: List<String>,
    ) : ExplanationArgument {
        init {
            requireExplanationArgumentKey(key)
            require(values.isNotEmpty())
            require(values == values.distinct().sorted())
            require(values.all(MACHINE_CODE_REGEX::matches))
        }
    }

    data class IntegerValue(
        override val key: String,
        val value: Long,
        val unit: ExplanationValueUnit,
    ) : ExplanationArgument {
        init {
            requireExplanationArgumentKey(key)
            require(value >= 0L)
        }
    }

    data class DecimalValue(
        override val key: String,
        val value: Double,
        val unit: ExplanationValueUnit,
    ) : ExplanationArgument {
        init {
            requireExplanationArgumentKey(key)
            require(value.isFinite())
            require(
                unit == ExplanationValueUnit.METRES_PER_SECOND_SQUARED ||
                    unit == ExplanationValueUnit.METRES_PER_SECOND_CUBED,
            )
        }
    }

    data class BooleanValue(
        override val key: String,
        val value: Boolean,
    ) : ExplanationArgument {
        init {
            requireExplanationArgumentKey(key)
        }
    }

    data class IdList(
        override val key: String,
        val values: List<String>,
    ) : ExplanationArgument {
        init {
            requireExplanationArgumentKey(key)
            require(values.isNotEmpty())
            require(values == values.distinct().sorted())
            require(values.all { it.isNotBlank() })
        }
    }
}

data class ExplanationSourceReference(
    val kind: ExplanationSourceKind,
    val id: String,
) {
    init {
        require(id.isNotBlank())
    }
}

data class ExplanationStep(
    val layer: ExplanationLayer,
    val role: ExplanationReasonRole,
    val messageKey: String,
    val arguments: List<ExplanationArgument>,
    val sourceReferences: List<ExplanationSourceReference>,
) {
    init {
        require(MESSAGE_KEY_REGEX.matches(messageKey))
        require(arguments.map { it.key } == arguments.map { it.key }.distinct().sorted())
        require(sourceReferences == sourceReferences.distinct().sortedWith(SOURCE_REFERENCE_ORDER))
    }
}

data class ExplanationPath(
    val subjectKind: ExplanationSubjectKind,
    val subjectId: String,
    val subjectMachineId: String,
    val stateMachineCode: String,
    val headlineMessageKey: String,
    val steps: List<ExplanationStep>,
) {
    init {
        require(subjectId.isNotBlank())
        require(MACHINE_CODE_REGEX.matches(subjectMachineId))
        require(MACHINE_CODE_REGEX.matches(stateMachineCode))
        require(MESSAGE_KEY_REGEX.matches(headlineMessageKey))
        require(steps.isNotEmpty())
    }
}

data class TripExplanationSourceVersions(
    val explanationVersion: Int,
    val integrityVersion: Int,
    val scoringSourceVersions: ScoringSourceVersions,
) {
    init {
        require(explanationVersion == EXPLANATION_VERSION)
        require(integrityVersion == INTEGRITY_RULES_VERSION)
        require(scoringSourceVersions.scoringVersion == SCORING_VERSION)
    }
}

data class TripExplanationAudit(
    val explanationVersion: Int,
    val tripId: String,
    val eventPaths: List<ExplanationPath>,
    val integrityPath: ExplanationPath,
    val scoreDimensionPaths: Map<ScoringDimension, ExplanationPath>,
    val overallScorePath: ExplanationPath,
    val sourceAcceptedEventIds: List<String>,
    val sourceScoreContributionIds: List<String>,
    val sourceVersions: TripExplanationSourceVersions,
    val configSnapshot: ExplanationConfig,
) {
    init {
        require(explanationVersion == EXPLANATION_VERSION)
        require(configSnapshot.explanationVersion == explanationVersion)
        require(sourceVersions.explanationVersion == explanationVersion)
        require(tripId.isNotBlank())
        require(sourceAcceptedEventIds.distinct().size == sourceAcceptedEventIds.size)
        require(sourceScoreContributionIds == sourceScoreContributionIds.distinct().sorted())
        require(eventPaths.map { it.subjectId } == sourceAcceptedEventIds)
        require(eventPaths.all { it.subjectKind == ExplanationSubjectKind.DRIVING_EVENT })
        require(integrityPath.subjectKind == ExplanationSubjectKind.INTEGRITY_STATUS)
        require(scoreDimensionPaths.keys == ScoringDimension.entries.toSet())
        require(
            scoreDimensionPaths.all { (dimension, path) ->
                path.subjectKind == ExplanationSubjectKind.SCORE_DIMENSION &&
                    path.subjectMachineId == dimension.machineId
            },
        )
        require(overallScorePath.subjectKind == ExplanationSubjectKind.SCORE_OVERALL)
        val allPaths =
            eventPaths + integrityPath + scoreDimensionPaths.values + overallScorePath
        require(
            allPaths.sourceIds(ExplanationSourceKind.MERGED_EVENT) ==
                sourceAcceptedEventIds.toSet(),
        )
        require(
            allPaths.sourceIds(ExplanationSourceKind.SCORE_CONTRIBUTION) ==
                sourceScoreContributionIds.toSet(),
        )
    }
}

data class DriveDnaExplanationSourceVersions(
    val explanationVersion: Int,
    val lifecycleVersion: Int,
    val driveDnaVersion: Int,
    val candidateSourceVersions: DriveDnaSourceVersions,
) {
    init {
        require(explanationVersion == EXPLANATION_VERSION)
        require(lifecycleVersion == DRIVE_DNA_LIFECYCLE_VERSION)
        require(driveDnaVersion == DRIVE_DNA_VERSION)
        require(candidateSourceVersions.driveDnaVersion == driveDnaVersion)
    }
}

data class DriveDnaExplanationAudit(
    val explanationVersion: Int,
    val baselineKey: String,
    val lifecyclePath: ExplanationPath,
    val profileDimensionPaths: Map<ScoringDimension, ExplanationPath>,
    val sourceCandidateTripIds: List<String>,
    val sourceVersions: DriveDnaExplanationSourceVersions,
    val configSnapshot: ExplanationConfig,
) {
    init {
        require(explanationVersion == EXPLANATION_VERSION)
        require(configSnapshot.explanationVersion == explanationVersion)
        require(sourceVersions.explanationVersion == explanationVersion)
        require(baselineKey.isNotBlank())
        require(lifecyclePath.subjectKind == ExplanationSubjectKind.DRIVE_DNA_LIFECYCLE)
        require(profileDimensionPaths.keys == ScoringDimension.entries.toSet())
        require(
            profileDimensionPaths.all { (dimension, path) ->
                path.subjectKind == ExplanationSubjectKind.DRIVE_DNA_DIMENSION &&
                    path.subjectMachineId == dimension.machineId
            },
        )
        require(sourceCandidateTripIds.distinct().size == sourceCandidateTripIds.size)
        require(
            (listOf(lifecyclePath) + profileDimensionPaths.values)
                .sourceIds(ExplanationSourceKind.DRIVE_DNA_TRIP) ==
                sourceCandidateTripIds.toSet(),
        )
    }
}

internal fun explanationStep(
    layer: ExplanationLayer,
    role: ExplanationReasonRole,
    messageKey: String,
    arguments: List<ExplanationArgument> = emptyList(),
    sourceReferences: List<ExplanationSourceReference> = emptyList(),
): ExplanationStep =
    ExplanationStep(
        layer = layer,
        role = role,
        messageKey = messageKey,
        arguments = Collections.unmodifiableList(arguments.sortedBy { it.key }),
        sourceReferences =
            Collections.unmodifiableList(
                sourceReferences.distinct().sortedWith(SOURCE_REFERENCE_ORDER),
            ),
    )

internal fun explanationPath(
    subjectKind: ExplanationSubjectKind,
    subjectId: String,
    subjectMachineId: String,
    stateMachineCode: String,
    headlineMessageKey: String,
    steps: List<ExplanationStep>,
): ExplanationPath =
    ExplanationPath(
        subjectKind = subjectKind,
        subjectId = subjectId,
        subjectMachineId = subjectMachineId,
        stateMachineCode = stateMachineCode,
        headlineMessageKey = headlineMessageKey,
        steps = Collections.unmodifiableList(ArrayList(steps)),
    )

internal fun explanationMessageKey(vararg parts: String): String =
    parts.joinToString(".") { part ->
        part.lowercase().replace(Regex("[^a-z0-9_]+"), "_").trim('_')
    }

internal fun machineCode(
    key: String,
    value: String,
): ExplanationArgument = ExplanationArgument.MachineCode(key, value)

internal fun machineCodes(
    key: String,
    values: Collection<String>,
): ExplanationArgument =
    ExplanationArgument.MachineCodeList(
        key,
        Collections.unmodifiableList(values.distinct().sorted()),
    )

internal fun integerValue(
    key: String,
    value: Long,
    unit: ExplanationValueUnit,
): ExplanationArgument = ExplanationArgument.IntegerValue(key, value, unit)

internal fun decimalValue(
    key: String,
    value: Double,
    unit: ExplanationValueUnit,
): ExplanationArgument = ExplanationArgument.DecimalValue(key, value, unit)

internal fun booleanValue(
    key: String,
    value: Boolean,
): ExplanationArgument = ExplanationArgument.BooleanValue(key, value)

internal fun idList(
    key: String,
    values: Collection<String>,
): ExplanationArgument =
    ExplanationArgument.IdList(
        key,
        Collections.unmodifiableList(values.distinct().sorted()),
    )

internal fun sourceReferences(
    kind: ExplanationSourceKind,
    ids: Collection<String>,
): List<ExplanationSourceReference> =
    ids.map { ExplanationSourceReference(kind, it) }

internal fun <K, V> immutableExplanationMap(values: Map<K, V>): Map<K, V> =
    Collections.unmodifiableMap(LinkedHashMap(values))

private fun List<ExplanationPath>.sourceIds(kind: ExplanationSourceKind): Set<String> =
    flatMap { path -> path.steps }
        .flatMap { step -> step.sourceReferences }
        .filter { it.kind == kind }
        .mapTo(linkedSetOf()) { it.id }

private fun requireExplanationArgumentKey(key: String) {
    require(ARGUMENT_KEY_REGEX.matches(key))
}

private val ARGUMENT_KEY_REGEX = Regex("[a-z][a-z0-9_]*")
private val MESSAGE_KEY_REGEX = Regex("[a-z0-9_]+(?:\\.[a-z0-9_]+)+")
private val MACHINE_CODE_REGEX = Regex("[A-Z][A-Z0-9_]*")
private val SOURCE_REFERENCE_ORDER =
    compareBy<ExplanationSourceReference> { it.kind.ordinal }.thenBy { it.id }
