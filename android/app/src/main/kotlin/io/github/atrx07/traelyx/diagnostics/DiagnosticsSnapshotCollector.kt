package io.github.atrx07.traelyx.diagnostics

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import java.io.File
import io.github.atrx07.traelyx.intelligence.LocalCommentaryStorage

class DiagnosticsSnapshotCollector(
    private val context: Context,
) {
    fun collect(): Map<String, Any> {
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        val applicationInfo = context.applicationInfo
        val appBytes = DiagnosticsStorage.sumFiles(
            buildList {
                add(File(applicationInfo.sourceDir))
                applicationInfo.splitSourceDirs?.forEach { add(File(it)) }
            },
        )
        val databaseBytes = DiagnosticsStorage.sumFiles(
            listOf(
                File(applicationInfo.dataDir, "app_flutter/traelyx.sqlite"),
                File(applicationInfo.dataDir, "app_flutter/traelyx.sqlite-wal"),
                File(applicationInfo.dataDir, "app_flutter/traelyx.sqlite-shm"),
            ),
        )
        val rawTelemetryBytes = DiagnosticsStorage.sizeOf(
            File(context.applicationContext.noBackupFilesDir, "recorder/trips"),
        )

        @Suppress("DEPRECATION")
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }

        return mapOf(
            "contractVersion" to DiagnosticsContract.CONTRACT_VERSION,
            "packageName" to context.packageName,
            "versionName" to (packageInfo.versionName ?: "unknown"),
            "versionCode" to versionCode,
            "buildMode" to if (
                applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
            ) {
                "debug"
            } else {
                "release"
            },
            "appBytes" to appBytes,
            "databaseBytes" to databaseBytes,
            "rawTelemetryBytes" to rawTelemetryBytes,
            // The offline-canvas map stores no files. Local model accounting
            // includes partial downloads and receipts, without hashing weights.
            "mapCacheBytes" to 0L,
            "localModelBytes" to LocalCommentaryStorage.bytes(LocalCommentaryStorage.root(context.noBackupFilesDir)),
        )
    }
}

internal object DiagnosticsStorage {
    fun sumFiles(files: Iterable<File>): Long = files.sumOf(::sizeOf)

    fun sizeOf(file: File): Long {
        if (!file.exists()) return 0L
        if (file.isFile) return file.length().coerceAtLeast(0L)
        return file.listFiles()?.sumOf(::sizeOf) ?: 0L
    }
}
