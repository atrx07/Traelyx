package io.github.atrx07.traelyx.diagnostics

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import java.io.File

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
            // These storage systems do not exist yet. Returning explicit zeroes is
            // more honest than inventing future directory contracts in M1.
            "rawTelemetryBytes" to 0L,
            "mapCacheBytes" to 0L,
            "localModelBytes" to 0L,
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
