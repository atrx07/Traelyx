package io.github.atrx07.traelyx.recorder

class RecorderLifecycleCoordinator(private val store: RecorderRecoveryStore) {
    fun query(): RecorderStateSnapshot =
        when (val read = store.load()) {
            RecorderRecoveryRead.Empty -> RecorderStateSnapshot.idle()
            is RecorderRecoveryRead.Available -> read.record.toSnapshot()
            is RecorderRecoveryRead.Invalid -> RecorderStateSnapshot.error(read.errorCode)
        }

    fun beginStart(
        tripId: String,
        startedAtUtcEpochMillis: Long,
        startedAtElapsedRealtimeNanos: Long,
    ): RecorderLifecycleOutcome =
        when (val read = store.load()) {
            RecorderRecoveryRead.Empty -> {
                val record =
                    runCatching {
                        ActiveTripRecoveryRecord(
                            tripId = tripId,
                            startedAtUtcEpochMillis = startedAtUtcEpochMillis,
                            startedAtElapsedRealtimeNanos = startedAtElapsedRealtimeNanos,
                            lifecycleState = RecorderLifecycleState.STARTING,
                        )
                    }.getOrElse {
                        return rejected("invalid_start_metadata")
                    }
                save(record)
            }

            is RecorderRecoveryRead.Available -> {
                if (read.record.lifecycleState.isActive) {
                    RecorderLifecycleOutcome(
                        RecorderLifecycleOutcomeKind.NO_OP,
                        read.record.toSnapshot(),
                    )
                } else {
                    RecorderLifecycleOutcome(
                        RecorderLifecycleOutcomeKind.REJECTED,
                        read.record.toSnapshot(),
                    )
                }
            }

            is RecorderRecoveryRead.Invalid -> rejected(read.errorCode)
        }

    fun markRecording(expectedTripId: String): RecorderLifecycleOutcome =
        updateMatching(expectedTripId) { record ->
            when (record.lifecycleState) {
                RecorderLifecycleState.STARTING ->
                    record.copy(lifecycleState = RecorderLifecycleState.RECORDING)

                RecorderLifecycleState.RECORDING,
                RecorderLifecycleState.RECOVERED,
                -> record

                else -> null
            }
        }

    fun recover(): RecorderLifecycleOutcome =
        when (val read = store.load()) {
            RecorderRecoveryRead.Empty ->
                RecorderLifecycleOutcome(
                    RecorderLifecycleOutcomeKind.NO_OP,
                    RecorderStateSnapshot.idle(),
                )

            is RecorderRecoveryRead.Invalid -> rejected(read.errorCode)
            is RecorderRecoveryRead.Available ->
                when (read.record.lifecycleState) {
                    RecorderLifecycleState.STARTING,
                    RecorderLifecycleState.RECORDING,
                    ->
                        save(
                            read.record.copy(
                                lifecycleState = RecorderLifecycleState.RECOVERED,
                                recoveryCount = read.record.recoveryCount + 1,
                            ),
                        )

                    RecorderLifecycleState.RECOVERED ->
                        RecorderLifecycleOutcome(
                            RecorderLifecycleOutcomeKind.NO_OP,
                            read.record.toSnapshot(),
                        )

                    RecorderLifecycleState.STOPPING -> completeStop()
                    RecorderLifecycleState.ERROR ->
                        RecorderLifecycleOutcome(
                            RecorderLifecycleOutcomeKind.REJECTED,
                            read.record.toSnapshot(),
                        )

                    RecorderLifecycleState.IDLE -> rejected("invalid_recovery_metadata")
                }
        }

    fun beginStop(): RecorderLifecycleOutcome =
        when (val read = store.load()) {
            RecorderRecoveryRead.Empty ->
                RecorderLifecycleOutcome(
                    RecorderLifecycleOutcomeKind.NO_OP,
                    RecorderStateSnapshot.idle(),
                )

            is RecorderRecoveryRead.Invalid ->
                if (store.clear()) {
                    RecorderLifecycleOutcome(
                        RecorderLifecycleOutcomeKind.APPLIED,
                        RecorderStateSnapshot.idle(),
                    )
                } else {
                    rejected("recovery_persistence_failed")
                }

            is RecorderRecoveryRead.Available ->
                save(
                    read.record.copy(
                        lifecycleState = RecorderLifecycleState.STOPPING,
                        errorCode = null,
                    ),
                )
        }

    fun completeStop(): RecorderLifecycleOutcome =
        if (store.clear()) {
            RecorderLifecycleOutcome(
                RecorderLifecycleOutcomeKind.APPLIED,
                RecorderStateSnapshot.idle(),
            )
        } else {
            rejected("recovery_persistence_failed")
        }

    fun markError(errorCode: String): RecorderLifecycleOutcome =
        when (val read = store.load()) {
            is RecorderRecoveryRead.Available ->
                save(
                    read.record.copy(
                        lifecycleState = RecorderLifecycleState.ERROR,
                        errorCode = errorCode,
                    ),
                )

            RecorderRecoveryRead.Empty -> rejected(errorCode)
            is RecorderRecoveryRead.Invalid -> rejected(read.errorCode)
        }

    private fun updateMatching(
        expectedTripId: String,
        transform: (ActiveTripRecoveryRecord) -> ActiveTripRecoveryRecord?,
    ): RecorderLifecycleOutcome =
        when (val read = store.load()) {
            RecorderRecoveryRead.Empty -> rejected("active_trip_missing")
            is RecorderRecoveryRead.Invalid -> rejected(read.errorCode)
            is RecorderRecoveryRead.Available -> {
                if (read.record.tripId != expectedTripId) {
                    rejected("active_trip_mismatch")
                } else {
                    val updated = transform(read.record) ?: return rejected("invalid_state_transition")
                    if (updated == read.record) {
                        RecorderLifecycleOutcome(
                            RecorderLifecycleOutcomeKind.NO_OP,
                            read.record.toSnapshot(),
                        )
                    } else {
                        save(updated)
                    }
                }
            }
        }

    private fun save(record: ActiveTripRecoveryRecord): RecorderLifecycleOutcome =
        if (store.save(record)) {
            RecorderLifecycleOutcome(
                RecorderLifecycleOutcomeKind.APPLIED,
                record.toSnapshot(),
            )
        } else {
            rejected("recovery_persistence_failed")
        }

    private fun rejected(errorCode: String): RecorderLifecycleOutcome =
        RecorderLifecycleOutcome(
            RecorderLifecycleOutcomeKind.REJECTED,
            RecorderStateSnapshot.error(errorCode),
        )
}
