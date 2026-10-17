package io.github.atrx07.traelyx.guardian

/** The host serializes callbacks on the same worker as authority and the vault. */
internal fun interface GuardianScheduledWake { fun cancel() }

/** One cancellable wake, no idle polling and no network worker until explicitly enabled. */
internal class GuardianDispatchSchedule(
    private val controls: GuardianCancellationControls,
    private val clock: () -> GuardianClock,
    private val enabled: () -> Boolean = { false },
    private val createDispatch: (post: (() -> Unit) -> Unit) -> GuardianOutboxDispatchCoordinator,
    private val postControl: (() -> Unit) -> Unit,
    private val schedule: (Long, () -> Unit) -> GuardianScheduledWake,
) : AutoCloseable {
    private var dispatch: GuardianOutboxDispatchCoordinator? = null
    private var wake: GuardianScheduledWake? = null
    private var generation = 0L
    private var closed = false
    private var failed = false

    /** Before relevant owner/activation/Stop changes. Does not release an unsettled IO slot. */
    fun invalidate() {
        cancelWake()
        dispatch?.invalidate()
        controls.invalidate()
    }

    /** Enqueue, explicit checks/cancel, authority changes and completion all converge here. */
    fun refresh() {
        cancelWake()
        if (closed || failed) return
        try {
            controls.refresh()
            val sending = enabled()
            if (!sending) dispatch?.invalidate()
            val dispatcher = if (sending) dispatch ?: createDispatch { action ->
                postControl {
                    try { action() } finally { refresh() }
                }
            }.also { dispatch = it } else null
            val dispatchAt = dispatcher?.pump()
            val noticeAt = controls.nextRefreshAt()
            val at = listOfNotNull(dispatchAt, noticeAt).minOrNull() ?: return
            val delay = Math.subtractExact(at, clock().elapsedMillis).coerceAtLeast(1L)
            val token = generation
            wake = schedule(delay) { if (token == generation) refresh() }
        } catch (_: Exception) {
            failed = true
            invalidate()
        }
    }

    private fun cancelWake() {
        generation++ // A dequeued but cancelled callback must also be inert.
        val previous = wake
        wake = null
        if (runCatching { previous?.cancel() }.isFailure) {
            failed = true
            dispatch?.invalidate()
            controls.invalidate()
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        invalidate()
        dispatch?.close()
    }
}
