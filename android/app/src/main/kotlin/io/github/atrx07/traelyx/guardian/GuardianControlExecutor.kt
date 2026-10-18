package io.github.atrx07.traelyx.guardian

import java.util.concurrent.ScheduledThreadPoolExecutor

internal fun guardianControlExecutor() = ScheduledThreadPoolExecutor(1).apply {
    // Replaced expiry wakes must leave the queue immediately, not retain
    // cancelled tasks until their old (potentially ten-minute) deadlines.
    removeOnCancelPolicy = true
}
