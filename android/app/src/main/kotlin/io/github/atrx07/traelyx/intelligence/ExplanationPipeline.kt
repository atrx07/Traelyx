package io.github.atrx07.traelyx.intelligence

import kotlin.math.roundToLong

object ExplanationPipeline {
    fun explainTrip(
        sourceTimeline: MergedEventTimeline,
        scoreAudit: TripScoreAudit = ScoringPipeline.score(sourceTimeline),
        config: ExplanationConfig = ExplanationConfig(),
    ): TripExplanationAudit {
        require(sourceTimeline.sourceTripId() == scoreAudit.tripId)
        val events =
            sourceTimeline.events().toList().sortedWith(
                compareBy<MergedDrivingEvent> { it.startTripElapsedNanos }
                    .thenBy { it.eventId },
            )
        require(events.map { it.eventId }.distinct().size == events.size)
        require(events.all { it.tripId == scoreAudit.tripId })
        val sourceVersions = requireNotNull(scoreAudit.integrityAudit.sourceVersions)
        require(sourceTimeline.sourceTimeline.config.taxonomyVersion == sourceVersions.taxonomyVersion)
        require(sourceTimeline.config.mergeVersion == sourceVersions.mergeVersion)
        require(events.all { it.taxonomyVersion == sourceVersions.taxonomyVersion })
        require(events.all { it.mergeVersion == sourceVersions.mergeVersion })

        val allContributions =
            scoreAudit.dimensions.values
                .flatMap { it.contributions }
        require(
            allContributions.map { it.contributionId }.distinct().size ==
                allContributions.size,
        )
        val contributions = allContributions.sortedBy { it.contributionId }
        require(
            contributions.flatMap { it.supportingEventIds }.toSet()
                .all { supportingId -> events.any { it.eventId == supportingId } },
        )
        val contributionsByEvent =
            events.associate { event ->
                event.eventId to
                    contributions.filter { event.eventId in it.supportingEventIds }
            }
        val eventPaths =
            events.map { event ->
                eventExplanation(event, contributionsByEvent.getValue(event.eventId))
            }
        val integrityPath = integrityExplanation(scoreAudit.integrityAudit)
        val dimensionPaths =
            ScoringDimension.entries.associateWith { dimension ->
                scoreDimensionExplanation(scoreAudit, scoreAudit.dimensions.getValue(dimension))
            }
        val overallPath = overallScoreExplanation(scoreAudit)
        return TripExplanationAudit(
            explanationVersion = config.explanationVersion,
            tripId = scoreAudit.tripId,
            eventPaths = java.util.Collections.unmodifiableList(eventPaths),
            integrityPath = integrityPath,
            scoreDimensionPaths = immutableExplanationMap(dimensionPaths),
            overallScorePath = overallPath,
            sourceAcceptedEventIds =
                java.util.Collections.unmodifiableList(events.map { it.eventId }),
            sourceScoreContributionIds =
                java.util.Collections.unmodifiableList(contributions.map { it.contributionId }),
            sourceVersions =
                TripExplanationSourceVersions(
                    explanationVersion = config.explanationVersion,
                    integrityVersion = scoreAudit.integrityAudit.integrityVersion,
                    scoringSourceVersions = scoreAudit.sourceVersions,
                ),
            configSnapshot = config.copy(),
        )
    }

    fun explainDriveDna(
        lifecycleAudit: DriveDnaLifecycleAudit,
        config: ExplanationConfig = ExplanationConfig(),
    ): DriveDnaExplanationAudit {
        val dimensions =
            ScoringDimension.entries.associateWith { dimension ->
                driveDnaDimensionExplanation(
                    baselineKey = lifecycleAudit.baselineKey,
                    audit = lifecycleAudit.profile.dimensions.getValue(dimension),
                )
            }
        return DriveDnaExplanationAudit(
            explanationVersion = config.explanationVersion,
            baselineKey = lifecycleAudit.baselineKey,
            lifecyclePath = lifecycleExplanation(lifecycleAudit),
            profileDimensionPaths = immutableExplanationMap(dimensions),
            sourceCandidateTripIds =
                java.util.Collections.unmodifiableList(
                    lifecycleAudit.candidateObservations.map { it.tripObservation.tripId },
                ),
            sourceVersions =
                DriveDnaExplanationSourceVersions(
                    explanationVersion = config.explanationVersion,
                    lifecycleVersion = lifecycleAudit.lifecycleVersion,
                    driveDnaVersion = lifecycleAudit.profile.driveDnaVersion,
                    candidateSourceVersions = lifecycleAudit.candidateSourceVersions,
                ),
            configSnapshot = config.copy(),
        )
    }
}

private fun eventExplanation(
    event: MergedDrivingEvent,
    contributions: List<ScoreContribution>,
): ExplanationPath {
    val eventReference = sourceReferences(ExplanationSourceKind.MERGED_EVENT, listOf(event.eventId))
    val steps = mutableListOf<ExplanationStep>()
    steps +=
        explanationStep(
            layer = ExplanationLayer.DETECTED_EVENT,
            role = ExplanationReasonRole.SUPPORTING,
            messageKey = explanationMessageKey("explanation", "event", event.eventType.machineId, "detected"),
            arguments =
                listOf(
                    machineCode("event_type", event.eventType.machineId),
                    integerValue("start", event.startTripElapsedNanos, ExplanationValueUnit.NANOSECONDS),
                    integerValue("peak", event.peakTripElapsedNanos, ExplanationValueUnit.NANOSECONDS),
                    integerValue("end", event.endTripElapsedNanos, ExplanationValueUnit.NANOSECONDS),
                    integerValue(
                        "source_window_count",
                        event.sourceSummary.sourceWindowCount.toLong(),
                        ExplanationValueUnit.COUNT,
                    ),
                    machineCodes("rule_evidence", event.ruleEvidence.map { it.name }),
                ),
            sourceReferences = eventReference,
        )
    event.primaryMeasurements.forEach { measurement ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.MEASUREMENT,
                role = ExplanationReasonRole.SUPPORTING,
                messageKey = explanationMessageKey("explanation", "event", "measurement", measurement.kind.name),
                arguments =
                    listOf(
                        machineCode("measurement_kind", measurement.kind.name),
                        decimalValue(
                            "signed_value",
                            measurement.signedValue,
                            measurement.unit.toExplanationUnit(),
                        ),
                    ),
                sourceReferences = eventReference,
            )
    }
    when (val severity = event.severity) {
        is EventSeverityEvidence.Measured ->
            steps +=
                explanationStep(
                    layer = ExplanationLayer.MEASUREMENT,
                    role = ExplanationReasonRole.SUPPORTING,
                    messageKey = explanationMessageKey("explanation", "event", "activation_threshold"),
                    arguments =
                        listOf(
                            decimalValue(
                                "physical_magnitude",
                                severity.physicalMagnitude,
                                event.severityUnit(),
                            ),
                            decimalValue(
                                "activation_threshold",
                                severity.activationThreshold,
                                event.severityUnit(),
                            ),
                            integerValue(
                                "activation_ratio",
                                (severity.activationRatio * 1_000.0).roundToLong(),
                                ExplanationValueUnit.PERMILLE,
                            ),
                        ),
                    sourceReferences = eventReference,
                )
        EventSeverityEvidence.UnavailableForPhoneMovement ->
            steps +=
                explanationStep(
                    layer = ExplanationLayer.MEASUREMENT,
                    role = ExplanationReasonRole.LIMITING,
                    messageKey =
                        explanationMessageKey(
                            "explanation",
                            "event",
                            "measurement_unavailable_phone_movement",
                        ),
                    arguments =
                        listOf(machineCode("reason", "PHONE_MOVEMENT_MAGNITUDE_NOT_CALIBRATED")),
                    sourceReferences = eventReference,
                )
    }
    val confidenceArguments = mutableListOf<ExplanationArgument>()
    confidenceArguments += machineCode("confidence", event.confidence.name)
    if (event.qualityFlags.isNotEmpty()) {
        confidenceArguments += machineCodes("quality_flags", event.qualityFlags.map { it.name })
    }
    val limitingComponents =
        event.sourceSummary.metricEvidence.values.flatMap { it.limitingComponents }.map { it.name }
    if (limitingComponents.isNotEmpty()) {
        confidenceArguments += machineCodes("limiting_components", limitingComponents)
    }
    val confidenceReasons =
        event.sourceSummary.componentEvidence.values.flatMap { it.reasons }.map { it.name }
    if (confidenceReasons.isNotEmpty()) {
        confidenceArguments += machineCodes("confidence_reasons", confidenceReasons)
    }
    steps +=
        explanationStep(
            layer = ExplanationLayer.CONFIDENCE,
            role =
                if (event.confidence == EventEvidenceConfidence.SUPPORTED) {
                    ExplanationReasonRole.SUPPORTING
                } else {
                    ExplanationReasonRole.LIMITING
                },
            messageKey = explanationMessageKey("explanation", "event", "confidence", event.confidence.name),
            arguments = confidenceArguments,
            sourceReferences = eventReference,
        )
    event.sourceSummary.metricEvidence.toSortedMap(compareBy { it.ordinal }).forEach {
        (metric, evidence) ->
        val arguments = mutableListOf<ExplanationArgument>()
        arguments += machineCode("metric", metric.name)
        arguments += machineCodes("observed_eligibility", evidence.observedEligibility.map { it.name })
        arguments += machineCodes("eligibility_reasons", evidence.reasons.map { it.name })
        arguments += machineCodes("required_components", evidence.requiredComponents.map { it.name })
        if (evidence.limitingComponents.isNotEmpty()) {
            arguments += machineCodes("limiting_components", evidence.limitingComponents.map { it.name })
        }
        if (evidence.sourceMissingReasons.isNotEmpty()) {
            arguments += machineCodes("source_missing_reasons", evidence.sourceMissingReasons.map { it.name })
        }
        steps +=
            explanationStep(
                layer = ExplanationLayer.CONFIDENCE,
                role =
                    if (evidence.limitingComponents.isEmpty()) {
                        ExplanationReasonRole.SUPPORTING
                    } else {
                        ExplanationReasonRole.LIMITING
                    },
                messageKey =
                    explanationMessageKey(
                        "explanation",
                        "event",
                        "confidence",
                        "metric",
                        metric.name,
                    ),
                arguments = arguments,
                sourceReferences = eventReference,
            )
    }
    val limitingComponentKinds =
        event.sourceSummary.metricEvidence.values.flatMapTo(linkedSetOf()) {
            it.limitingComponents
        }
    event.sourceSummary.componentEvidence.toSortedMap(compareBy { it.ordinal }).forEach {
        (component, evidence) ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.CONFIDENCE,
                role =
                    if (component in limitingComponentKinds) {
                        ExplanationReasonRole.LIMITING
                    } else {
                        ExplanationReasonRole.SUPPORTING
                    },
                messageKey =
                    explanationMessageKey(
                        "explanation",
                        "event",
                        "confidence",
                        "component",
                        component.name,
                    ),
                arguments =
                    listOf(
                        machineCode("component", component.name),
                        machineCodes("observed_states", evidence.observedStates.map { it.name }),
                        machineCodes("reasons", evidence.reasons.map { it.name }),
                    ),
                sourceReferences = eventReference,
            )
    }
    if (contributions.isEmpty()) {
        steps +=
            explanationStep(
                layer = ExplanationLayer.SCORING_CONSEQUENCE,
                role = ExplanationReasonRole.INFORMATIONAL,
                messageKey = explanationMessageKey("explanation", "event", "score", "no_direct_v1_consequence"),
                arguments = listOf(machineCode("scoring_version", "SCORING_V1")),
                sourceReferences = eventReference,
            )
    } else {
        contributions.forEach { contribution ->
            steps += contributionExplanationStep(contribution, eventReference)
        }
    }
    return explanationPath(
        subjectKind = ExplanationSubjectKind.DRIVING_EVENT,
        subjectId = event.eventId,
        subjectMachineId = event.eventType.machineId,
        stateMachineCode = event.confidence.name,
        headlineMessageKey = explanationMessageKey("explanation", "event", event.eventType.machineId, "headline"),
        steps = steps,
    )
}

private fun scoreDimensionExplanation(
    scoreAudit: TripScoreAudit,
    dimension: DimensionScore,
): ExplanationPath {
    val steps = mutableListOf<ExplanationStep>()
    val summaryArguments = mutableListOf<ExplanationArgument>()
    summaryArguments += machineCode("dimension", dimension.dimension.machineId)
    summaryArguments += machineCode("state", dimension.state.name)
    dimension.scoreMilliPoints?.let {
        summaryArguments += integerValue("score", it, ExplanationValueUnit.SCORE_MILLI_POINTS)
    }
    steps +=
        explanationStep(
            layer = ExplanationLayer.SCORING_CONSEQUENCE,
            role =
                if (dimension.state == ScoreDimensionState.UNAVAILABLE) {
                    ExplanationReasonRole.LIMITING
                } else {
                    ExplanationReasonRole.INFORMATIONAL
                },
            messageKey =
                explanationMessageKey(
                    "explanation",
                    "score",
                    "dimension",
                    dimension.dimension.machineId,
                    dimension.state.name,
                ),
            arguments = summaryArguments,
        )
    steps +=
        explanationStep(
            layer = ExplanationLayer.MEASUREMENT,
            role = ExplanationReasonRole.INFORMATIONAL,
            messageKey = explanationMessageKey("explanation", "score", "evidence_coverage"),
            arguments =
                listOf(
                    integerValue(
                        "moving_duration",
                        dimension.evidence.movingDurationNanos,
                        ExplanationValueUnit.NANOSECONDS,
                    ),
                    integerValue(
                        "opportunity_duration",
                        dimension.evidence.opportunityDurationNanos,
                        ExplanationValueUnit.NANOSECONDS,
                    ),
                    integerValue(
                        "usable_duration",
                        dimension.evidence.usableDurationNanos,
                        ExplanationValueUnit.NANOSECONDS,
                    ),
                    integerValue(
                        "fully_eligible_duration",
                        dimension.evidence.fullyEligibleDurationNanos,
                        ExplanationValueUnit.NANOSECONDS,
                    ),
                    integerValue(
                        "usable_coverage",
                        dimension.evidence.usableCoveragePermille.toLong(),
                        ExplanationValueUnit.PERMILLE,
                    ),
                    integerValue(
                        "fully_eligible_coverage",
                        dimension.evidence.fullyEligibleCoveragePermille.toLong(),
                        ExplanationValueUnit.PERMILLE,
                    ),
                ),
        )
    dimension.contributions.forEach { contribution ->
        steps += contributionExplanationStep(contribution)
    }
    if (dimension.scoreMilliPoints != null && dimension.contributions.isEmpty()) {
        steps +=
            explanationStep(
                layer = ExplanationLayer.SCORING_CONSEQUENCE,
                role = ExplanationReasonRole.INFORMATIONAL,
                messageKey = explanationMessageKey("explanation", "score", "no_governed_penalty"),
                arguments = listOf(machineCode("dimension", dimension.dimension.machineId)),
            )
    }
    dimension.provisionalReasons.sortedBy { it.ordinal }.forEach { reason ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.CONFIDENCE,
                role = ExplanationReasonRole.LIMITING,
                messageKey = explanationMessageKey("explanation", "score", "provisional", reason.name),
                arguments = listOf(machineCode("reason", reason.name)),
            )
    }
    dimension.unavailableReasons.sortedBy { it.ordinal }.forEach { reason ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.SCORING_CONSEQUENCE,
                role = ExplanationReasonRole.EXCLUDING,
                messageKey = explanationMessageKey("explanation", "score", "unavailable", reason.name),
                arguments = listOf(machineCode("reason", reason.name)),
            )
    }
    return explanationPath(
        subjectKind = ExplanationSubjectKind.SCORE_DIMENSION,
        subjectId = "${scoreAudit.tripId}:${dimension.dimension.machineId}",
        subjectMachineId = dimension.dimension.machineId,
        stateMachineCode = dimension.state.name,
        headlineMessageKey =
            explanationMessageKey("explanation", "score", "dimension", dimension.dimension.machineId, "headline"),
        steps = steps,
    )
}

private fun overallScoreExplanation(scoreAudit: TripScoreAudit): ExplanationPath {
    val steps = mutableListOf<ExplanationStep>()
    val summaryArguments = mutableListOf<ExplanationArgument>()
    summaryArguments += machineCode("state", scoreAudit.state.name)
    summaryArguments +=
        integerValue(
            "available_weight",
            scoreAudit.availableOverallWeightBasisPoints.toLong(),
            ExplanationValueUnit.BASIS_POINTS,
        )
    scoreAudit.overallScoreMilliPoints?.let {
        summaryArguments += integerValue("score", it, ExplanationValueUnit.SCORE_MILLI_POINTS)
    }
    steps +=
        explanationStep(
            layer = ExplanationLayer.SCORING_CONSEQUENCE,
            role = ExplanationReasonRole.INFORMATIONAL,
            messageKey = explanationMessageKey("explanation", "score", "overall", scoreAudit.state.name),
            arguments = summaryArguments,
        )
    scoreAudit.availableOverallDimensions.sortedBy { it.ordinal }.forEach { dimension ->
        val component = scoreAudit.dimensions.getValue(dimension)
        steps +=
            explanationStep(
                layer = ExplanationLayer.SCORING_CONSEQUENCE,
                role = ExplanationReasonRole.CONTRIBUTING,
                messageKey = explanationMessageKey("explanation", "score", "overall", "dimension_component"),
                arguments =
                    listOf(
                        machineCode("dimension", dimension.machineId),
                        integerValue(
                            "score",
                            requireNotNull(component.scoreMilliPoints),
                            ExplanationValueUnit.SCORE_MILLI_POINTS,
                        ),
                        integerValue(
                            "weight",
                            component.weightBasisPoints.toLong(),
                            ExplanationValueUnit.BASIS_POINTS,
                        ),
                    ),
            )
    }
    steps +=
        explanationStep(
            layer = ExplanationLayer.SCORING_CONSEQUENCE,
            role =
                if (scoreAudit.riskGuardrailApplied) {
                    ExplanationReasonRole.LIMITING
                } else {
                    ExplanationReasonRole.INFORMATIONAL
                },
            messageKey =
                explanationMessageKey(
                    "explanation",
                    "score",
                    "overall",
                    "guardrail",
                    if (scoreAudit.riskGuardrailApplied) "applied" else "not_applied",
                ),
            arguments = listOf(booleanValue("applied", scoreAudit.riskGuardrailApplied)),
        )
    scoreAudit.provisionalReasons.sortedBy { it.ordinal }.forEach { reason ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.CONFIDENCE,
                role = ExplanationReasonRole.LIMITING,
                messageKey = explanationMessageKey("explanation", "score", "provisional", reason.name),
                arguments = listOf(machineCode("reason", reason.name)),
            )
    }
    scoreAudit.unavailableReasons.sortedBy { it.ordinal }.forEach { reason ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.SCORING_CONSEQUENCE,
                role = ExplanationReasonRole.EXCLUDING,
                messageKey = explanationMessageKey("explanation", "score", "unavailable", reason.name),
                arguments = listOf(machineCode("reason", reason.name)),
            )
    }
    steps +=
        explanationStep(
            layer = ExplanationLayer.INTEGRITY,
            role =
                if (scoreAudit.integrityAudit.state == TripIntegrityState.VERIFIED) {
                    ExplanationReasonRole.SUPPORTING
                } else {
                    ExplanationReasonRole.LIMITING
                },
            messageKey =
                explanationMessageKey(
                    "explanation",
                    "score",
                    "integrity",
                    scoreAudit.integrityAudit.state.name,
                ),
            arguments = listOf(machineCode("integrity_state", scoreAudit.integrityAudit.state.name)),
        )
    steps +=
        explanationStep(
            layer = ExplanationLayer.INTEGRITY,
            role =
                if (scoreAudit.rankingStatus == ScoreRankingStatus.ELIGIBLE) {
                    ExplanationReasonRole.SUPPORTING
                } else {
                    ExplanationReasonRole.LIMITING
                },
            messageKey = explanationMessageKey("explanation", "score", "ranking", scoreAudit.rankingStatus.name),
            arguments = listOf(machineCode("ranking_status", scoreAudit.rankingStatus.name)),
        )
    return explanationPath(
        subjectKind = ExplanationSubjectKind.SCORE_OVERALL,
        subjectId = "${scoreAudit.tripId}:overall",
        subjectMachineId = "SCORE_OVERALL",
        stateMachineCode = scoreAudit.state.name,
        headlineMessageKey = explanationMessageKey("explanation", "score", "overall", "headline"),
        steps = steps,
    )
}

private fun integrityExplanation(audit: TripIntegrityAudit): ExplanationPath {
    val steps = mutableListOf<ExplanationStep>()
    steps +=
        explanationStep(
            layer = ExplanationLayer.INTEGRITY,
            role =
                if (audit.state == TripIntegrityState.VERIFIED) {
                    ExplanationReasonRole.SUPPORTING
                } else {
                    ExplanationReasonRole.LIMITING
                },
            messageKey = explanationMessageKey("explanation", "integrity", audit.state.name),
            arguments =
                listOf(
                    machineCode("integrity_state", audit.state.name),
                    machineCode("rank_eligibility", audit.rankEligibility.name),
                ),
        )
    if (audit.findings.isEmpty()) {
        steps +=
            explanationStep(
                layer = ExplanationLayer.INTEGRITY,
                role = ExplanationReasonRole.INFORMATIONAL,
                messageKey = explanationMessageKey("explanation", "integrity", "no_v1_findings"),
                arguments = listOf(machineCode("meaning", "NO_VERSIONED_RULE_FIRED")),
            )
    } else {
        audit.findings.forEach { finding ->
            val args = mutableListOf<ExplanationArgument>()
            args += machineCode("rule", finding.ruleId.machineId)
            args += machineCode("kind", finding.kind.name)
            args += machineCode("state", finding.state.name)
            finding.eventMachineId?.let { args += machineCode("event_machine_id", it) }
            args += machineCodes("dimensions", finding.dimensions.map { it.name })
            args += machineCodes("evidence_reasons", finding.evidenceReasons.map { it.name })
            if (finding.confidenceReasons.isNotEmpty()) {
                args += machineCodes("confidence_reasons", finding.confidenceReasons.map { it.name })
            }
            args += integerValue("occurrence_count", finding.occurrenceCount, ExplanationValueUnit.COUNT)
            finding.firstTripElapsedNanos?.let {
                args += integerValue("first_observation", it, ExplanationValueUnit.NANOSECONDS)
            }
            finding.lastTripElapsedNanos?.let {
                args += integerValue("last_observation", it, ExplanationValueUnit.NANOSECONDS)
            }
            finding.maximumContinuousDurationNanos?.let {
                args += integerValue("maximum_continuous_duration", it, ExplanationValueUnit.NANOSECONDS)
            }
            steps +=
                explanationStep(
                    layer = ExplanationLayer.INTEGRITY,
                    role = ExplanationReasonRole.LIMITING,
                    messageKey = explanationMessageKey("explanation", "integrity", "finding", finding.ruleId.machineId),
                    arguments = args,
                    sourceReferences =
                        sourceReferences(
                            ExplanationSourceKind.INTEGRITY_FINDING,
                            listOf(finding.ruleId.machineId),
                        ) +
                            finding.representativeMergedEventId?.let { eventId ->
                                sourceReferences(
                                    ExplanationSourceKind.MERGED_EVENT,
                                    listOf(eventId),
                                )
                            }.orEmpty(),
                )
        }
    }
    return explanationPath(
        subjectKind = ExplanationSubjectKind.INTEGRITY_STATUS,
        subjectId = audit.tripId ?: "raw_trip_rejected",
        subjectMachineId = "INTEGRITY_TRIP",
        stateMachineCode = audit.state.name,
        headlineMessageKey = explanationMessageKey("explanation", "integrity", "headline"),
        steps = steps,
    )
}

private fun contributionExplanationStep(
    contribution: ScoreContribution,
    additionalSources: List<ExplanationSourceReference> = emptyList(),
): ExplanationStep =
    explanationStep(
        layer = ExplanationLayer.SCORING_CONSEQUENCE,
        role = ExplanationReasonRole.CONTRIBUTING,
        messageKey = explanationMessageKey("explanation", "score", "contribution", contribution.rule.machineId),
        arguments =
            listOf(
                machineCode("rule", contribution.rule.machineId),
                machineCode("dimension", contribution.rule.dimension.machineId),
                machineCode("kind", contribution.kind.name),
                integerValue(
                    "base_penalty",
                    scorePointsToMilli(contribution.basePoints),
                    ExplanationValueUnit.SCORE_MILLI_POINTS,
                ),
                integerValue(
                    "severity_multiplier",
                    contribution.severityMultiplierPermille.toLong(),
                    ExplanationValueUnit.PERMILLE,
                ),
                integerValue(
                    "confidence_weight",
                    contribution.confidenceWeightPermille.toLong(),
                    ExplanationValueUnit.PERMILLE,
                ),
                integerValue(
                    "raw_penalty",
                    contribution.rawPointsMilli,
                    ExplanationValueUnit.SCORE_MILLI_POINTS,
                ),
                integerValue(
                    "applied_penalty",
                    contribution.appliedPointsMilli,
                    ExplanationValueUnit.SCORE_MILLI_POINTS,
                ),
                idList("supporting_event_ids", contribution.supportingEventIds),
            ),
        sourceReferences =
            additionalSources +
                sourceReferences(
                    ExplanationSourceKind.SCORE_CONTRIBUTION,
                    listOf(contribution.contributionId),
                ) +
                sourceReferences(
                    ExplanationSourceKind.MERGED_EVENT,
                    contribution.supportingEventIds,
                ),
    )

private fun driveDnaDimensionExplanation(
    baselineKey: String,
    audit: DriveDnaDimensionAudit,
): ExplanationPath {
    val steps = mutableListOf<ExplanationStep>()
    val args = mutableListOf<ExplanationArgument>()
    args += machineCode("dimension", audit.dimension.machineId)
    args += machineCode("state", audit.state.name)
    args += integerValue("candidate_trip_count", audit.candidateTripCount.toLong(), ExplanationValueUnit.COUNT)
    args += integerValue("eligible_trip_count", audit.eligibleTripCount.toLong(), ExplanationValueUnit.COUNT)
    audit.valueMilliPoints?.let {
        args += integerValue("value", it, ExplanationValueUnit.SCORE_MILLI_POINTS)
    }
    steps +=
        explanationStep(
            layer = ExplanationLayer.BASELINE,
            role =
                if (audit.state == DriveDnaDimensionState.AVAILABLE) {
                    ExplanationReasonRole.INFORMATIONAL
                } else {
                    ExplanationReasonRole.LIMITING
                },
            messageKey =
                explanationMessageKey(
                    "explanation",
                    "drive_dna",
                    "dimension",
                    audit.dimension.machineId,
                    audit.state.name,
                ),
            arguments = args,
            sourceReferences = sourceReferences(ExplanationSourceKind.DRIVE_DNA_TRIP, audit.sourceTripIds),
        )
    audit.sourceMeanAbsoluteDeviationMilliPoints?.let { deviation ->
        val aggregationArguments = mutableListOf<ExplanationArgument>()
        aggregationArguments +=
            integerValue(
                "source_mean_absolute_deviation",
                deviation,
                ExplanationValueUnit.SCORE_MILLI_POINTS,
            )
        if (audit.contributingDimensions.isNotEmpty()) {
            aggregationArguments +=
                machineCodes("contributing_dimensions", audit.contributingDimensions.map { it.machineId })
        }
        steps +=
            explanationStep(
                layer = ExplanationLayer.BASELINE,
                role = ExplanationReasonRole.SUPPORTING,
                messageKey =
                    explanationMessageKey(
                        "explanation",
                        "drive_dna",
                        "aggregation",
                        if (audit.dimension == ScoringDimension.CONSISTENCY) "consistency" else "median",
                    ),
                arguments = aggregationArguments,
                sourceReferences = sourceReferences(ExplanationSourceKind.DRIVE_DNA_TRIP, audit.sourceTripIds),
            )
    }
    audit.unavailableReasons.sortedBy { it.ordinal }.forEach { reason ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.BASELINE,
                role = ExplanationReasonRole.EXCLUDING,
                messageKey = explanationMessageKey("explanation", "drive_dna", "unavailable", reason.name),
                arguments = listOf(machineCode("reason", reason.name)),
            )
    }
    return explanationPath(
        subjectKind = ExplanationSubjectKind.DRIVE_DNA_DIMENSION,
        subjectId = "$baselineKey:${audit.dimension.machineId}",
        subjectMachineId = audit.dimension.machineId,
        stateMachineCode = audit.state.name,
        headlineMessageKey =
            explanationMessageKey(
                "explanation",
                "drive_dna",
                "dimension",
                audit.dimension.machineId,
                "headline",
            ),
        steps = steps,
    )
}

private fun lifecycleExplanation(audit: DriveDnaLifecycleAudit): ExplanationPath {
    val candidateIds = audit.candidateObservations.map { it.tripObservation.tripId }
    val steps = mutableListOf<ExplanationStep>()
    steps +=
        explanationStep(
            layer = ExplanationLayer.BASELINE,
            role =
                if (audit.state == DriveDnaPersonalLifecycleState.ESTABLISHED) {
                    ExplanationReasonRole.SUPPORTING
                } else {
                    ExplanationReasonRole.INFORMATIONAL
                },
            messageKey = explanationMessageKey("explanation", "drive_dna", "lifecycle", audit.state.name),
            arguments =
                listOf(
                    machineCode("state", audit.state.name),
                    integerValue("candidate_trip_count", candidateIds.size.toLong(), ExplanationValueUnit.COUNT),
                    integerValue(
                        "current_epoch_eligible_trip_count",
                        audit.currentEpochEligibleTripCount.toLong(),
                        ExplanationValueUnit.COUNT,
                    ),
                    integerValue(
                        "selected_trip_count",
                        audit.selectedTripIds.size.toLong(),
                        ExplanationValueUnit.COUNT,
                    ),
                ),
            sourceReferences = sourceReferences(ExplanationSourceKind.DRIVE_DNA_TRIP, candidateIds),
        )
    if (audit.selectedTripIds.isNotEmpty()) {
        steps +=
            explanationStep(
                layer = ExplanationLayer.BASELINE,
                role = ExplanationReasonRole.CONTRIBUTING,
                messageKey = explanationMessageKey("explanation", "drive_dna", "lifecycle", "selected_cohort"),
                arguments =
                    listOf(
                        idList("selected_trip_ids", audit.selectedTripIds),
                        integerValue(
                            "window_start",
                            requireNotNull(audit.windowStartUtcEpochMicros),
                            ExplanationValueUnit.UTC_EPOCH_MICROSECONDS,
                        ),
                        integerValue(
                            "window_end",
                            requireNotNull(audit.windowEndUtcEpochMicros),
                            ExplanationValueUnit.UTC_EPOCH_MICROSECONDS,
                        ),
                    ),
                sourceReferences = sourceReferences(ExplanationSourceKind.DRIVE_DNA_TRIP, audit.selectedTripIds),
            )
    }
    audit.activeRecalibrationReasons.sortedBy { it.ordinal }.forEach { reason ->
        steps +=
            explanationStep(
                layer = ExplanationLayer.BASELINE,
                role = ExplanationReasonRole.LIMITING,
                messageKey = explanationMessageKey("explanation", "drive_dna", "recalibration", reason.name),
                arguments = listOf(machineCode("reason", reason.name)),
            )
    }
    DriveDnaCohortExclusionReason.entries.forEach { reason ->
        val excludedIds =
            audit.cohortDecisions
                .filter { reason in it.exclusionReasons }
                .map { it.tripId }
        if (excludedIds.isNotEmpty()) {
            steps +=
                explanationStep(
                    layer = ExplanationLayer.BASELINE,
                    role = ExplanationReasonRole.EXCLUDING,
                    messageKey = explanationMessageKey("explanation", "drive_dna", "cohort_exclusion", reason.name),
                    arguments =
                        listOf(
                            machineCode("reason", reason.name),
                            integerValue("trip_count", excludedIds.size.toLong(), ExplanationValueUnit.COUNT),
                        ),
                    sourceReferences = sourceReferences(ExplanationSourceKind.DRIVE_DNA_TRIP, excludedIds),
                )
        }
    }
    return explanationPath(
        subjectKind = ExplanationSubjectKind.DRIVE_DNA_LIFECYCLE,
        subjectId = audit.baselineKey,
        subjectMachineId = "DRIVE_DNA_LIFECYCLE",
        stateMachineCode = audit.state.name,
        headlineMessageKey = explanationMessageKey("explanation", "drive_dna", "lifecycle", "headline"),
        steps = steps,
    )
}

private fun EventMeasurementUnit.toExplanationUnit(): ExplanationValueUnit =
    when (this) {
        EventMeasurementUnit.METRES_PER_SECOND_SQUARED ->
            ExplanationValueUnit.METRES_PER_SECOND_SQUARED
        EventMeasurementUnit.METRES_PER_SECOND_CUBED ->
            ExplanationValueUnit.METRES_PER_SECOND_CUBED
    }

private fun MergedDrivingEvent.severityUnit(): ExplanationValueUnit =
    when (eventType) {
        DrivingEventType.ABRUPT_ACCELERATION_TRANSITION,
        DrivingEventType.ABRUPT_BRAKING_TRANSITION,
        DrivingEventType.ABRUPT_CORNER_ENTRY,
        DrivingEventType.ABRUPT_CORNER_EXIT,
        -> ExplanationValueUnit.METRES_PER_SECOND_CUBED
        DrivingEventType.STRONG_ACCELERATION,
        DrivingEventType.STRONG_BRAKING,
        DrivingEventType.HIGH_LATERAL_LOAD_LEFT,
        DrivingEventType.HIGH_LATERAL_LOAD_RIGHT,
        DrivingEventType.ROAD_IMPACT_OR_BUMP,
        -> ExplanationValueUnit.METRES_PER_SECOND_SQUARED
        DrivingEventType.PHONE_MOVED -> error("Phone movement has no measured severity")
    }

private fun MergedEventTimeline.sourceTripId(): String =
    sourceTimeline.sourceTimeline.sourceTimeline.sourceTimeline.trip.tripId
