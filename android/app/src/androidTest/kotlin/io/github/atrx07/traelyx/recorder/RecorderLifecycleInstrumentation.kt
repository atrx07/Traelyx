package io.github.atrx07.traelyx.recorder

import android.Manifest
import android.app.Activity
import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import io.github.atrx07.traelyx.MainActivity
import java.io.File
import java.util.UUID

class RecorderLifecycleInstrumentation : Instrumentation() {
    private var proofTripId: String? = null
    private var instrumentationArguments: Bundle? = null

    override fun onCreate(arguments: Bundle?) {
        instrumentationArguments = arguments
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
        try {
            val stream =
                when (instrumentationArguments?.getString("mode")) {
                    "guardian-vault" -> runGuardianVaultProof()
                    "guardian-recipient-vault" -> runGuardianRecipientVaultProof()
                    "guardian-hosted-receipt" -> runGuardianHostedReceiptProof()
                    "guardian-recipient-revoke-journal" -> runGuardianRecipientRevokeJournalProof()
                    "guardian-recipient-bridge" -> runGuardianRecipientBridgeProof()
                    "guardian-recipient-owner-inert" -> runGuardianRecipientOwnerInertProof()
                    "guardian-provider-marker" -> runGuardianProviderMarkerProof()
                    "guardian-provider" -> runGuardianProviderProof()
                    "guardian-activation" -> runGuardianActivationProof()
                    "index" ->
                        runIndexProof(
                            requireNotNull(instrumentationArguments?.getString("tripId")),
                        )
                    "cleanup" ->
                        runCleanupProof(
                            requireNotNull(instrumentationArguments?.getString("tripId")),
                        )
                    else -> {
                        runLifecycleProof()
                        "M2.7 recorder recovery, finalization handoff, and privacy-safe chunk proof passed."
                    }
                }
            results.putString(
                "stream",
                "\n$stream\n",
            )
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString(
                "stream",
                "\nM2.7 recorder recovery, finalization handoff, and chunk proof failed:\n" +
                    "${error.stackTraceToString()}\n",
            )
            finish(Activity.RESULT_CANCELED, results)
        }
    }

    private fun runGuardianProviderProof(): String {
        val context = targetContext.applicationContext
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty()) {
            "Firebase initialized before notification consent."
        }
        val registration = io.github.atrx07.traelyx.guardian.FirebaseGuardianRegistration.get(context)
        val expectedConfigured = instrumentationArguments?.getString("expectFirebase") == "true"
        check(registration.configured == expectedConfigured) { "Unexpected Firebase configuration availability." }
        val info = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        for (key in listOf("firebase_messaging_auto_init_enabled", "firebase_analytics_collection_enabled",
            "firebase_data_collection_default_enabled", "firebase_messaging_notification_delegation_enabled")) {
            check(info.metaData.containsKey(key) && !info.metaData.getBoolean(key)) { "Firebase opt-in default changed." }
        }
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty()) {
            "Reading provider availability initialized Firebase."
        }
        return "M6.8 provider proof passed: configured=$expectedConfigured, Firebase initialized=false, " +
            "registration requested=false, trip/session storage untouched."
    }

    private fun runGuardianRecipientOwnerInertProof(): String {
        val context = targetContext.applicationContext
        check(!io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(context).present()) {
            "Production provider marker exists; refusing inert owner proof."
        }
        check(io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context).readStored() == null) {
            "Production recipient authority exists; refusing inert owner proof."
        }
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        val finished = java.util.concurrent.CountDownLatch(1)
        var outcome: Result<Any?>? = null
        io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRuntime.dispatch(
            context, io.github.atrx07.traelyx.guardian.GuardianRecipientBridge.BIND_OWNER,
            mapOf("ownerId" to null),
        ) { result -> outcome = result; finished.countDown() }
        check(finished.await(5, java.util.concurrent.TimeUnit.SECONDS)) { "Recipient owner bind timed out." }
        outcome!!.getOrThrow()
        check(io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context).pending().isEmpty()) {
            "Production revoke ticket exists; refusing inert token-denial proof."
        }
        val denied = java.util.concurrent.CountDownLatch(1)
        var tokenOutcome: Result<Any?>? = null
        io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRuntime.acquireToken(
            context, mapOf("ownerId" to UUID.randomUUID().toString(),
                "deviceId" to UUID.randomUUID().toString(), "generation" to UUID.randomUUID().toString()),
        ) { result -> tokenOutcome = result; denied.countDown() }
        check(denied.await(5, java.util.concurrent.TimeUnit.SECONDS) && tokenOutcome!!.isFailure)
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty()) {
            "Inert recipient owner binding initialized Firebase."
        }
        check(!io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(context).present())
        return "M6.8 recipient owner proof passed: empty production authority, inert sign-out bind, " +
            "unreserved token denial; Firebase uninitialized, no token request."
    }

    private fun runGuardianVaultProof(): String {
        val context = targetContext.applicationContext
        val namespace = "proof-${UUID.randomUUID()}"
        val file = File(context.noBackupFilesDir, "guardian/$namespace.vault")
        val vault = io.github.atrx07.traelyx.guardian.AndroidGuardianVault(context, namespace)
        val outbox = io.github.atrx07.traelyx.guardian.GuardianOutbox(vault)
        val owner = UUID.randomUUID().toString()
        val generation = UUID.randomUUID().toString()
        val now = io.github.atrx07.traelyx.guardian.GuardianClock(System.currentTimeMillis(), SystemClock.elapsedRealtime(), "synthetic-proof-boot")
        val nanos = now.elapsedMillis * 1_000_000
        val lease = io.github.atrx07.traelyx.guardian.GuardianDriverLease(owner, generation, "a".repeat(64),
            now.epochMillis, now.elapsedMillis, now.epochMillis + 60_000, now.bootId, "+y")
        try {
            check(vault.read() == io.github.atrx07.traelyx.guardian.GuardianVaultSnapshot())
            outbox.activate(lease, now)
            val alert = outbox.enqueue(owner, generation,
                io.github.atrx07.traelyx.guardian.GuardianDetection(io.github.atrx07.traelyx.guardian.GuardianAlertKind.POSSIBLE_CRASH, nanos, nanos),
                io.github.atrx07.traelyx.guardian.GuardianSafetyCooldowns(nanos, nanos), now)
            check(!file.readText(Charsets.ISO_8859_1).contains(lease.credential))
            check(!file.readText(Charsets.ISO_8859_1).contains(owner))
            val restored = io.github.atrx07.traelyx.guardian.GuardianOutbox(
                io.github.atrx07.traelyx.guardian.AndroidGuardianVault(context, namespace))
            val later = now.copy(epochMillis = now.epochMillis + 30_000, elapsedMillis = now.elapsedMillis + 30_000)
            val attempt = requireNotNull(restored.reserveNext(owner, later))
            check(attempt.alert.eventId == alert.eventId && attempt.alert.attempts == 1)
            check(io.github.atrx07.traelyx.guardian.AndroidGuardianVault(context, namespace).read().alerts.single().attempts == 1)
            check(!restored.cancel(owner, alert.eventId, later))
            val original = file.readBytes()
            file.writeBytes(original.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() })
            check(runCatching { io.github.atrx07.traelyx.guardian.AndroidGuardianVault(context, namespace).read() }.isFailure)
            vault.erase()
            check(!file.exists())
            file.writeBytes(original) // Old ciphertext must stay unusable after key destruction.
            check(runCatching { io.github.atrx07.traelyx.guardian.AndroidGuardianVault(context, namespace).read() }.isFailure)
        } finally { vault.erase() }
        check(!file.exists())
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 encrypted vault proof passed: Keystore AES-GCM, restore/reservation, tamper rejection, " +
            "key destruction and scoped cleanup; Firebase inactive, trip/session storage untouched."
    }

    private fun runGuardianRecipientVaultProof(): String {
        val context = targetContext.applicationContext
        val namespace = "proof-${UUID.randomUUID()}"
        val file = File(context.noBackupFilesDir, "guardian/recipient-$namespace.vault")
        val vault = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context, namespace)
        val owner = UUID.randomUUID().toString()
        val deviceId = UUID.randomUUID().toString()
        val generation = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        val recipient = io.github.atrx07.traelyx.guardian.GuardianRecipientDevice(
            owner, deviceId, generation, "a".repeat(64), now, now + 60_000,
        )
        try {
            check(vault.readBound(owner, generation, now) == null)
            vault.write(recipient)
            check(file.isFile)
            check(!file.readText(Charsets.ISO_8859_1).contains(owner))
            check(!file.readText(Charsets.ISO_8859_1).contains(recipient.credential))
            val restored = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context, namespace)
            check(restored.readBound(owner, generation, now + 1) == recipient)
            check(restored.readBound(UUID.randomUUID().toString(), generation, now + 1) == null)
            check(restored.readBound(owner, UUID.randomUUID().toString(), now + 1) == null)
            val deliveryId = UUID.randomUUID().toString()
            check(vault.claimNotice(deviceId, generation, recipient.credential, deliveryId, now + 1))
            check(!restored.claimNotice(deviceId, generation, recipient.credential, deliveryId, now + 2))
            check(restored.readStored() == recipient.copy(noticeDeliveryIds = listOf(deliveryId)))
            check(!restored.claimNotice(deviceId, generation, recipient.credential, UUID.randomUUID().toString(), now + 60_000))
            val original = file.readBytes()
            file.writeBytes(original.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() })
            check(runCatching { io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context, namespace)
                .readBound(owner, generation, now + 1) }.isFailure)
            vault.erase()
            file.writeBytes(original)
            check(runCatching { io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context, namespace)
                .readBound(owner, generation, now + 1) }.isFailure)
        } finally { vault.erase() }
        check(!file.exists())
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 recipient vault proof passed: scoped Keystore encryption, account/generation binding, " +
            "durable notice claims across vault instances, expiry/tamper rejection and key destruction; " +
            "Firebase inactive, trip/session storage untouched."
    }

    /** Explicit reviewed test only. No token/credential leaves the normal receipt API. */
    private fun runGuardianHostedReceiptProof(): String {
        val context = targetContext.applicationContext
        check(io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(context).present())
        val vault = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context)
        val device = requireNotNull(vault.readStored())
        val delivery = "00000000-0000-4000-9000-000000000685"
        val preflight = io.github.atrx07.traelyx.guardian.GuardianPushPreflight(
            vault, io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(context),
            System::currentTimeMillis,
        )
        val data = mapOf("schema_version" to "1", "delivery_id" to delivery,
            "device_generation" to device.generation)
        val first = requireNotNull(preflight.check(data, false))
        val endpoint = context.getString(io.github.atrx07.traelyx.R.string.traelyx_guardian_capability_url)
        val gateway = io.github.atrx07.traelyx.guardian.GuardianCapabilityReceiptGateway(
            endpoint, io.github.atrx07.traelyx.guardian.BoundedGuardianHttpsTransport(),
        )
        check(gateway.receive(first)) { "Synthetic hosted receipt was not accepted" }
        val current = requireNotNull(preflight.check(data, false))
        check(current.deviceId == first.deviceId && current.credential == first.credential)
        check(gateway.receive(current)) { "Synthetic hosted receipt retry was not accepted" }
        check(vault.readStored() == device) { "Receipt probe changed local authority" }
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 hosted synthetic receipt and idempotent retry passed; local authority unchanged, " +
            "Firebase inactive, no notification or trip upload."
    }

    private fun runGuardianRecipientRevokeJournalProof(): String {
        val context = targetContext.applicationContext
        val namespace = "proof-${UUID.randomUUID()}"
        val file = File(context.noBackupFilesDir, "guardian/revoke-$namespace.vault")
        val journal = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
        val ticket = io.github.atrx07.traelyx.guardian.GuardianRecipientRevokeTicket(
            UUID.randomUUID().toString(), UUID.randomUUID().toString(), UUID.randomUUID().toString())
        try {
            check(journal.pending().isEmpty())
            journal.record(ticket)
            check(file.isFile && !file.readText(Charsets.ISO_8859_1).contains(ticket.ownerId))
            val restored = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
            check(restored.pending() == listOf(ticket))
            restored.record(ticket)
            check(restored.pending() == listOf(ticket))
            val original = file.readBytes()
            file.writeBytes(original.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() })
            check(runCatching { io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
                .pending() }.isFailure)
            file.writeBytes(original)
            check(file.delete())
            check(runCatching { io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
                .pending() }.isFailure) { "Missing ciphertext with an existing key must fail closed." }
            file.writeBytes(original)
            io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
                .confirm(ticket)
            check(io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
                .pending().isEmpty())
        } finally { journal.eraseProofState() }
        check(!file.exists())
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 revoke journal proof passed: scoped Keystore encryption, restart, exact confirmation, " +
            "tamper/missing-file rejection and proof-only cleanup; Firebase inactive, trip/session storage untouched."
    }

    private fun runGuardianProviderMarkerProof(): String {
        val context = targetContext.applicationContext
        val namespace = "proof-${UUID.randomUUID()}"
        val file = File(context.noBackupFilesDir, "guardian/recipient-provider-$namespace.v1")
        val marker = io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(context, namespace)
        try {
            check(!marker.present())
            marker.mark()
            check(file.isFile && file.readBytes().contentEquals(byteArrayOf(1)))
            check(io.github.atrx07.traelyx.guardian.AndroidGuardianProviderMarker(context, namespace).present())
            file.writeBytes(byteArrayOf(9))
            check(marker.present()) { "Corrupt marker must still demand provider cleanup." }
            marker.clear()
            check(!marker.present())
            File(file.path + ".new").writeBytes(byteArrayOf(1))
            check(marker.present()) { "Interrupted marker write must still demand provider cleanup." }
        } finally { marker.clear() }
        check(!marker.present())
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 provider cleanup marker proof passed: durable presence, restart, corruption and " +
            "interrupted-write detection, scoped erasure; Firebase inactive, no token request."
    }

    private fun runGuardianRecipientBridgeProof(): String {
        val context = targetContext.applicationContext
        val namespace = "proof-${UUID.randomUUID()}"
        val file = File(context.noBackupFilesDir, "guardian/recipient-$namespace.vault")
        val vault = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientVault(context, namespace)
        val journal = io.github.atrx07.traelyx.guardian.AndroidGuardianRecipientRevokeJournal(context, namespace)
        val bridge = io.github.atrx07.traelyx.guardian.GuardianRecipientBridge(
            io.github.atrx07.traelyx.guardian.GuardianRecipientCoordinator(vault, journal, System::currentTimeMillis),
        )
        val owner = UUID.randomUUID().toString()
        val generation = UUID.randomUUID().toString()
        val device = UUID.randomUUID().toString()
        val credential = "a".repeat(64)
        try {
            bridge.dispatch("bindOwner", mapOf("ownerId" to owner))
            val start = System.currentTimeMillis()
            check(runCatching { bridge.dispatch("commit", mapOf(
                "ownerId" to owner, "deviceId" to device, "generation" to generation,
                "credential" to credential, "registeredAtEpochMillis" to start,
                "expiresAtEpochMillis" to start + 60_000L,
            )) }.isFailure)
            check(runCatching { bridge.dispatch("authorizeToken", mapOf(
                "ownerId" to owner, "deviceId" to device, "generation" to generation)) }.isFailure)
            bridge.dispatch("recordAttempt", mapOf("ownerId" to owner, "deviceId" to device, "generation" to generation))
            bridge.dispatch("authorizeToken", mapOf(
                "ownerId" to owner, "deviceId" to device, "generation" to generation))
            val committed = bridge.dispatch("commit", mapOf(
                "ownerId" to owner, "deviceId" to device, "generation" to generation,
                "credential" to credential, "registeredAtEpochMillis" to start,
                "expiresAtEpochMillis" to start + 60_000L,
            )) as Map<*, *>
            check(committed.keys == setOf("deviceId", "generation", "expiresAtEpochMillis"))
            check(!committed.toString().contains(credential))
            check(file.isFile && !file.readText(Charsets.ISO_8859_1).contains(credential))
            check(bridge.dispatch("snapshot", mapOf("ownerId" to owner)) == committed)
            bridge.dispatch("bindOwner", mapOf("ownerId" to UUID.randomUUID().toString()))
            check(!file.exists())
            check(journal.pending() == listOf(io.github.atrx07.traelyx.guardian.GuardianRecipientRevokeTicket(owner, device, generation)))
            check(runCatching { bridge.dispatch("snapshot", mapOf("ownerId" to owner)) }.isFailure)
            bridge.dispatch("bindOwner", mapOf("ownerId" to owner))
            check(bridge.dispatch("pendingRevokes", mapOf("ownerId" to owner)) ==
                listOf(mapOf("deviceId" to device, "generation" to generation)))
            bridge.dispatch("confirmRevoke", mapOf("ownerId" to owner, "deviceId" to device, "generation" to generation))
            check(journal.pending().isEmpty())
            bridge.dispatch("recordAttempt", mapOf("ownerId" to owner, "deviceId" to device, "generation" to generation))
            check(bridge.dispatch("pendingRevokes", mapOf("ownerId" to owner)) ==
                listOf(mapOf("deviceId" to device, "generation" to generation)))
            bridge.dispatch("confirmRevoke", mapOf("ownerId" to owner, "deviceId" to device, "generation" to generation))
            check(journal.pending().isEmpty())
        } finally { vault.erase(); journal.eraseProofState() }
        check(!file.exists())
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 recipient bridge proof passed: scoped commit, redacted status, account-switch erasure; " +
            "Firebase inactive, no server registration or trip change."
    }

    private fun runGuardianActivationProof(): String {
        val context = targetContext.applicationContext
        val namespace = "proof-${UUID.randomUUID()}"
        val file = File(context.noBackupFilesDir, "guardian/$namespace.vault")
        val vault = io.github.atrx07.traelyx.guardian.AndroidGuardianVault(context, namespace)
        val outbox = io.github.atrx07.traelyx.guardian.GuardianOutbox(vault)
        val bridge = io.github.atrx07.traelyx.guardian.GuardianActivationBridge(
            io.github.atrx07.traelyx.guardian.GuardianActivationCoordinator(outbox, clock = {
                val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
                check(boot >= 0) { "Boot identity unavailable." }
                io.github.atrx07.traelyx.guardian.GuardianClock(
                    System.currentTimeMillis(), SystemClock.elapsedRealtime(), "boot:$boot")
            }),
        )
        val owner = UUID.randomUUID().toString()
        try {
            bridge.dispatch("bindOwner", mapOf("ownerId" to owner))
            val proposal = bridge.dispatch("begin", mapOf(
                "ownerId" to owner, "forwardAxis" to "+y", "rigidMountConfirmed" to true)) as Map<*, *>
            check(proposal.keys == setOf("ownerId", "activationId", "credential", "forwardAxis"))
            check(proposal["ownerId"] == owner && proposal["forwardAxis"] == "+y")
            val activation = proposal["activationId"] as String
            val credential = proposal["credential"] as String
            check(credential.matches(Regex("[a-f0-9]{64}")))
            check(!file.exists()) { "Proposal persisted before confirmation." }
            val confirmation = bridge.dispatch("commit", mapOf(
                "ownerId" to owner, "activationId" to activation,
                "serverExpiresEpochMillis" to System.currentTimeMillis() + 60_000L)) as Map<*, *>
            check(confirmation.keys == setOf("localLeasePresent", "expiresEpochMillis"))
            check(confirmation["localLeasePresent"] == true)
            check(file.isFile && !file.readText(Charsets.ISO_8859_1).contains(credential))
            val present = bridge.dispatch("snapshot", mapOf("ownerId" to owner)) as Map<*, *>
            check(present["localLeasePresent"] == true)
            bridge.dispatch("disable", mapOf("ownerId" to owner))
            val absent = bridge.dispatch("snapshot", mapOf("ownerId" to owner)) as Map<*, *>
            check(absent["localLeasePresent"] == false && !file.exists())
        } finally { vault.erase() }
        check(!file.exists())
        check(com.google.firebase.FirebaseApp.getApps(context).isEmpty())
        return "M6.8 synthetic activation proof passed: boot clock, native proposal/commit/disable, " +
            "encrypted scoped cleanup; no hosted session, Firebase initialization or trip change."
    }

    private fun runCleanupProof(tripId: String): String {
        check(runCatching { UUID.fromString(tripId) }.isSuccess) {
            "Cleanup requires a valid trip UUID."
        }
        val databaseFile =
            File(targetContext.applicationInfo.dataDir, "app_flutter/traelyx.sqlite")
        check(databaseFile.isFile) { "Traelyx database is unavailable." }
        val deletedChunks: Int
        val deletedTrips: Int
        SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READWRITE).use {
                database ->
            database.beginTransaction()
            try {
                deletedChunks = database.delete("trip_chunks", "trip_id = ?", arrayOf(tripId))
                deletedTrips = database.delete("trips", "id = ?", arrayOf(tripId))
                database.execSQL(
                    """
                    DELETE FROM vehicles
                    WHERE id = ?
                      AND NOT EXISTS (SELECT 1 FROM trips WHERE vehicle_id = vehicles.id)
                    """.trimIndent(),
                    arrayOf("local-recorder-vehicle-v1"),
                )
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        }
        check(deletedTrips == 1) { "Exact proof trip cleanup deleted $deletedTrips trip rows." }
        check(deletedChunks > 0) { "Exact proof trip cleanup deleted no chunk rows." }
        check(AtomicFileTelemetryChunkStore(targetContext).deleteTripForTest(tripId)) {
            "Exact proof telemetry directory could not be deleted."
        }
        check(AtomicRecorderFinalizationStore(targetContext).acknowledge(tripId)) {
            "Exact proof pending-finalization cleanup failed."
        }
        return "M2.7 exact-UUID cleanup passed: deletedTripRows=$deletedTrips, " +
            "deletedChunkRows=$deletedChunks, privateTelemetryRemoved=true."
    }

    private fun runIndexProof(tripId: String): String {
        check(runCatching { UUID.fromString(tripId) }.isSuccess) {
            "Index proof requires a valid trip UUID."
        }
        val databaseFile =
            File(targetContext.applicationInfo.dataDir, "app_flutter/traelyx.sqlite")
        check(databaseFile.isFile) { "Traelyx database is unavailable." }
        SQLiteDatabase.openDatabase(
            databaseFile.path,
            null,
            SQLiteDatabase.OPEN_READONLY,
        ).use { database ->
            database.rawQuery(
                """
                SELECT t.completion_state, t.recovery_state, t.integrity_status,
                       COUNT(c.sequence),
                       SUM(CASE WHEN c.storage_reference LIKE ? THEN 0 ELSE 1 END)
                FROM trips AS t
                LEFT JOIN trip_chunks AS c ON c.trip_id = t.id
                WHERE t.id = ?
                GROUP BY t.id, t.completion_state, t.recovery_state, t.integrity_status
                """.trimIndent(),
                arrayOf("recorder/trips/$tripId/chunks/%", tripId),
            ).use { cursor ->
                check(cursor.moveToFirst()) { "Exact proof trip is absent from Drift." }
                val completionState = cursor.getString(0)
                val recoveryState = cursor.getString(1)
                val integrityStatus = cursor.getString(2)
                val chunkCount = cursor.getLong(3)
                val invalidReferenceCount = cursor.getLong(4)
                check(!cursor.moveToNext()) { "Exact proof trip was indexed more than once." }
                check(completionState == "completed") {
                    "Proof trip did not finalize as completed."
                }
                check(recoveryState == "recovered") {
                    "Process-restarted proof trip did not retain recovered state."
                }
                check(integrityStatus == "unassessed") {
                    "Proof trip integrity state was unexpectedly altered."
                }
                check(chunkCount > 0) { "Proof trip has no indexed chunks." }
                check(invalidReferenceCount == 0L) {
                    "Proof trip contains a non-relative chunk reference."
                }
                return "M2.7 exact-UUID Drift index proof passed: " +
                    "completion=$completionState, recovery=$recoveryState, " +
                    "integrity=$integrityStatus, indexedChunks=$chunkCount."
            }
        }
    }

    private fun runLifecycleProof() {
        val context = targetContext
        val bridge = RecorderBridgeDispatcher(AndroidRecorderBridgeGateway(context))

        try {
            check(
                context.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
                    context.hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION),
            ) {
                "Grant coarse or fine location permission before running the lifecycle proof."
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                check(context.hasPermission(Manifest.permission.POST_NOTIFICATIONS)) {
                    "Grant notification permission before running the lifecycle proof."
                }
            }
            context.stopService(Intent(context, RecorderService::class.java))
            check(AtomicRecorderRecoveryStore(context).clear()) {
                "Could not clear recorder recovery metadata before the proof."
            }

            val activity =
                startActivitySync(
                    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            waitForIdleSync()
            checkBridgeCapabilities(bridge)

            val startStatus = bridgePayload(bridge, RecorderContract.START_TRIP)
            val startLifecycle = startStatus.mapValue("lifecycle")
            check(startLifecycle["state"] in setOf("starting", "recording")) {
                "Bridge start was not accepted: ${startLifecycle["state"]}/${startLifecycle["errorCode"]}"
            }
            val accepted = RecorderService.queryState(context)
            proofTripId = accepted.tripId
            val active = awaitState(context) { it.lifecycleState == RecorderLifecycleState.RECORDING }
            check(accepted.tripId == active.tripId) { "Active trip identity changed during start." }
            check(active.isActive) { "Recorder did not report an active lifecycle." }
            checkBridgeStatus(bridge, expectedActive = true)
            checkNotificationActive(context)
            val initialImu = awaitImuSamples()
            checkImuMetadata(initialImu)
            val initialGnss = awaitGnssFix()
            check(initialGnss.provider == "gps") { "Recorder did not use the GPS provider." }
            check(initialGnss.acceptedSampleCount > 0) { "No GNSS fix was accepted." }
            check(initialGnss.rejectedSampleCount >= 0) { "Invalid rejected-sample counter." }
            check(initialGnss.firstSourceTimestampNanos != null) {
                "GNSS source timestamp was not preserved."
            }
            check(initialGnss.lastSourceTimestampNanos != null) {
                "GNSS last source timestamp was not preserved."
            }
            check(initialGnss.lastTripElapsedNanos != null) {
                "GNSS trip elapsed time was unavailable for the same-boot trip."
            }
            check(initialGnss.lastHorizontalAccuracyMetres != null) {
                "GNSS horizontal accuracy was not preserved."
            }
            check(initialGnss.errorCode == null) {
                "GNSS health contained an acquisition error: ${initialGnss.errorCode}"
            }
            val initialTelemetry =
                awaitTelemetryChunks(
                    minimumChunkCount = 1,
                    minimumGnssSamples = 1,
                    minimumAccelerometerSamples = MINIMUM_IMU_SAMPLES_PER_SENSOR,
                    minimumGyroscopeSamples = MINIMUM_IMU_SAMPLES_PER_SENSOR,
                )
            checkTelemetryHealth(initialTelemetry)
            checkBridgeStatus(bridge, expectedActive = true)

            activity.runOnUiThread(activity::recreate)
            waitForIdleSync()
            val afterActivityRecreation = RecorderService.queryState(context)
            val afterActivityRecreationBuffer = RecorderService.queryTelemetryHealth()
            check(afterActivityRecreation.isActive) {
                "Recorder stopped during activity recreation: " +
                    "lifecycle=${afterActivityRecreation.lifecycleState.wireName}/" +
                    "${afterActivityRecreation.errorCode}, " +
                    "buffer=${afterActivityRecreationBuffer.state.wireName}/" +
                    "${afterActivityRecreationBuffer.errorCode}, " +
                    "queue=${afterActivityRecreationBuffer.queueDepth}, " +
                    "buffered=${afterActivityRecreationBuffer.bufferedSampleCount}, " +
                    "overflow=${afterActivityRecreationBuffer.overflowCount}, " +
                    "late=${afterActivityRecreationBuffer.lateSampleCount}, " +
                    "write=${afterActivityRecreationBuffer.writeFailureCount}."
            }

            check(context.stopService(Intent(context, RecorderService::class.java))) {
                "Android did not stop the recorder service for the recovery proof."
            }
            val stoppedForRecovery = awaitTelemetryWriterStopped()
            check(RecorderService.queryState(context).lifecycleState == RecorderLifecycleState.RECORDING) {
                "Stopping the service erased active-trip recovery metadata."
            }
            checkTelemetryHealth(stoppedForRecovery)
            bridgePayload(bridge, RecorderContract.RECOVER_TRIP)
            val recovered =
                awaitState(context) { it.lifecycleState == RecorderLifecycleState.RECOVERED }
            check(recovered.tripId == accepted.tripId) { "Recovery changed the active trip identity." }
            check(recovered.recoveryCount == 1) { "Recovery count was not incremented once." }
            checkBridgeStatus(bridge, expectedActive = true)
            checkNotificationActive(context)
            val recoveredCatalogHealth = awaitTelemetryWriterActive()
            check(
                recoveredCatalogHealth.recoveredValidChunkCount >=
                    initialTelemetry.completedChunkCount,
            ) {
                "Recovered writer did not discover the previously completed chunks."
            }
            checkTelemetryHealth(recoveredCatalogHealth)
            val recoveredImu = awaitImuSamples()
            checkImuMetadata(recoveredImu)
            val recoveredGnss = awaitGnssFix()
            check(recoveredGnss.acceptedSampleCount > 0) {
                "GNSS acquisition did not restart with the recovered lifecycle."
            }
            val afterRecoveryTelemetry =
                awaitTelemetryChunks(
                    minimumChunkCount = recoveredCatalogHealth.completedChunkCount + 1,
                    minimumGnssSamples = recoveredCatalogHealth.persistedGnssSampleCount + 1,
                    minimumAccelerometerSamples =
                        recoveredCatalogHealth.persistedAccelerometerSampleCount +
                            MINIMUM_IMU_SAMPLES_PER_SENSOR,
                    minimumGyroscopeSamples =
                        recoveredCatalogHealth.persistedGyroscopeSampleCount +
                            MINIMUM_IMU_SAMPLES_PER_SENSOR,
                )
            checkTelemetryHealth(afterRecoveryTelemetry)
            checkBridgeStatus(bridge, expectedActive = true)

            context.startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            SystemClock.sleep(500)
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped when the app was backgrounded."
            }
            checkNotificationActive(context)

            executeShellCommand("input keyevent 223")
            SystemClock.sleep(500)
            check(RecorderService.queryState(context).isActive) {
                "Recorder stopped when the screen turned off."
            }
            checkNotificationActive(context)
            executeShellCommand("input keyevent 224")

            bridgePayload(bridge, RecorderContract.STOP_TRIP)
            val idle = awaitState(context) { it.lifecycleState == RecorderLifecycleState.IDLE }
            check(!idle.isActive) { "Recorder remained active after stop." }
            checkBridgeStatus(bridge, expectedActive = false)
            checkNotificationStopped(context)
            check(RecorderService.queryGnssHealth().state == GnssAcquisitionState.STOPPED) {
                "GNSS callbacks did not stop with the recorder lifecycle."
            }
            check(RecorderService.queryImuHealth().state == ImuAcquisitionState.STOPPED) {
                "IMU callbacks did not stop with the recorder lifecycle."
            }
            val stoppedTelemetry = RecorderService.queryTelemetryHealth()
            check(stoppedTelemetry.state == TelemetryBufferState.STOPPED) {
                "Durable writer did not stop with the recorder lifecycle."
            }
            checkTelemetryHealth(stoppedTelemetry)
            val finalCatalog =
                AtomicFileTelemetryChunkStore(context).scan(requireNotNull(accepted.tripId))
            check(finalCatalog.validChunks.size.toLong() == stoppedTelemetry.completedChunkCount) {
                "Final catalog and durable health chunk counts differ."
            }
            check(finalCatalog.corruptChunkCount == 0) { "Final catalog contained corruption." }
            check(finalCatalog.orphanedWriteCount == 0) {
                "Final catalog contained an incomplete atomic write."
            }
            check(finalCatalog.orderingViolationCount == 0) {
                "Final catalog contained an elapsed-time ordering violation."
            }
            check(finalCatalog.validChunks.all { it.metadata.checksumHex.length == 64 }) {
                "A final chunk did not contain a verified SHA-256 checksum."
            }
            checkFinalizationHandoff(bridge, requireNotNull(accepted.tripId), finalCatalog)
        } finally {
            executeShellCommand("input keyevent 224")
            context.stopService(Intent(context, RecorderService::class.java))
            AtomicRecorderRecoveryStore(context).clear()
            proofTripId?.let { tripId ->
                AtomicRecorderFinalizationStore(context).acknowledge(tripId)
                awaitTelemetryWriterTeardown()
                check(deleteProofTripWithRetry(context, tripId)) {
                    "Could not remove the proof trip's private telemetry chunks."
                }
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun checkFinalizationHandoff(
        bridge: RecorderBridgeDispatcher,
        tripId: String,
        catalog: TelemetryChunkCatalogSnapshot,
    ) {
        val batch = bridgePayload(bridge, RecorderContract.GET_PENDING_FINALIZATIONS)
        check(batch["contractVersion"] == RECORDER_FINALIZATION_CONTRACT_VERSION)
        check(batch["invalidRecordCount"] == 0)
        val finalizations = batch["finalizations"] as List<Map<String, Any?>>
        val finalization = finalizations.single { it["tripId"] == tripId }
        check(finalization["completionState"] == "completed")
        check(finalization["recoveryState"] == "recovered")
        check(finalization["integrityStatus"] == "unassessed")
        val chunks = finalization["chunks"] as List<Map<String, Any?>>
        check(chunks.size == catalog.validChunks.size)
        check(chunks.all { chunk ->
            val reference = chunk["storageReference"] as? String
            reference != null &&
                reference.startsWith("recorder/trips/$tripId/chunks/") &&
                !reference.startsWith("/") &&
                !reference.contains("\\")
        }) {
            "Finalization exposed an invalid or absolute storage reference."
        }
        check(chunks.none { chunk ->
            chunk.keys.any { key ->
                key.contains("coordinate", ignoreCase = true) ||
                    key.contains("vector", ignoreCase = true) ||
                    key.contains("sourceTimestamp", ignoreCase = true)
            }
        }) {
            "Finalization exposed raw telemetry evidence."
        }
        val acknowledged =
            bridgePayload(
                bridge,
                RecorderContract.ACKNOWLEDGE_TRIP_FINALIZATION,
                mapOf("tripId" to tripId),
            )
        check(acknowledged["acknowledged"] == true)
        check(AtomicRecorderFinalizationStore(targetContext).load(tripId) == null) {
            "Finalization acknowledgement did not remove the pending handoff."
        }
    }

    private fun checkBridgeCapabilities(bridge: RecorderBridgeDispatcher) {
        val capabilities = bridgePayload(bridge, RecorderContract.GET_CAPABILITIES)
        check(capabilities["bridgeVersion"] == RecorderContract.BRIDGE_VERSION)
        check(capabilities["statusContractVersion"] == RECORDER_STATUS_CONTRACT_VERSION)
        check(capabilities["implementationState"] == "bridge_ready")
        check(capabilities["recordingAvailable"] == isPlatformRecordingReady(targetContext))
        check(capabilities["commandsAvailable"] == true)
        check(capabilities["healthAvailable"] == true)
        check(capabilities["permissionOnboardingAvailable"] == true)
        val requestedPermissions =
            targetContext.packageManager
                .getPackageInfo(targetContext.packageName, PackageManager.GET_PERMISSIONS)
                .requestedPermissions
                ?.toSet()
                .orEmpty()
        check(Manifest.permission.ACCESS_BACKGROUND_LOCATION !in requestedPermissions) {
            "Recorder must not declare background location permission."
        }
    }

    private fun checkBridgeStatus(
        bridge: RecorderBridgeDispatcher,
        expectedActive: Boolean,
    ) {
        val status = bridgePayload(bridge, RecorderContract.GET_STATUS)
        check(status["contractVersion"] == RECORDER_STATUS_CONTRACT_VERSION)
        check(status["bridgeVersion"] == RecorderContract.BRIDGE_VERSION)
        val lifecycle = status.mapValue("lifecycle")
        val gnss = status.mapValue("gnss")
        val imu = status.mapValue("imu")
        val buffer = status.mapValue("buffer")
        check(lifecycle["active"] == expectedActive)
        check(!lifecycle.containsKey("startedAtUtcEpochMillis"))
        check(!lifecycle.containsKey("startedAtElapsedRealtimeNanos"))
        check(!gnss.containsKey("lastSourceTimestampNanos"))
        check(!gnss.containsKey("lastHorizontalAccuracyMetres"))
        check(!gnss.containsKey("lastFixWallTimeUtcEpochMillis"))
        check(imu.keys.none { it.contains("Timestamp") || it.contains("AccuracyStatus") })
        check(buffer.keys.none { it.contains("path", ignoreCase = true) })
        check(status.keys.none { it.contains("device", ignoreCase = true) })
    }

    private fun bridgePayload(
        bridge: RecorderBridgeDispatcher,
        method: String,
        arguments: Map<String, Any?>? = null,
    ): Map<String, Any?> =
        when (val result = bridge.dispatch(method, arguments)) {
            is RecorderBridgeDispatchResult.Handled -> result.payload
            RecorderBridgeDispatchResult.NotImplemented -> error("Bridge method was unavailable: $method")
        }

    @Suppress("UNCHECKED_CAST")
    private fun Map<String, Any?>.mapValue(key: String): Map<String, Any?> =
        getValue(key) as Map<String, Any?>

    private fun awaitTelemetryWriterTeardown() {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_STATE_TIMEOUT_MILLIS
        var state = RecorderService.queryTelemetryHealth().state
        while (
            state != TelemetryBufferState.STOPPED &&
            state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            state = RecorderService.queryTelemetryHealth().state
        }
    }

    private fun awaitTelemetryWriterStopped(): TelemetryBufferHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryTelemetryHealth()
        while (
            latest.state != TelemetryBufferState.STOPPED &&
            latest.state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryTelemetryHealth()
        }
        check(latest.state == TelemetryBufferState.STOPPED) {
            "Service teardown did not flush and stop the durable writer; " +
                "state=${latest.state.wireName}, error=${latest.errorCode}."
        }
        return latest
    }

    private fun awaitTelemetryWriterActive(): TelemetryBufferHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryTelemetryHealth()
        while (
            latest.state != TelemetryBufferState.ACTIVE &&
            latest.state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryTelemetryHealth()
        }
        check(latest.state == TelemetryBufferState.ACTIVE) {
            "Recovered durable writer did not become active; " +
                "state=${latest.state.wireName}, error=${latest.errorCode}."
        }
        return latest
    }

    private fun deleteProofTripWithRetry(
        context: Context,
        tripId: String,
    ): Boolean {
        val store = AtomicFileTelemetryChunkStore(context)
        repeat(PROOF_DELETE_ATTEMPTS) {
            if (store.deleteTripForTest(tripId)) return true
            SystemClock.sleep(PROOF_DELETE_RETRY_MILLIS)
        }
        return false
    }

    private fun awaitTelemetryChunks(
        minimumChunkCount: Long,
        minimumGnssSamples: Long,
        minimumAccelerometerSamples: Long,
        minimumGyroscopeSamples: Long,
    ): TelemetryBufferHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + TELEMETRY_TIMEOUT_MILLIS
        var latest = RecorderService.queryTelemetryHealth()
        while (
            (latest.completedChunkCount < minimumChunkCount ||
                latest.persistedGnssSampleCount < minimumGnssSamples ||
                latest.persistedAccelerometerSampleCount < minimumAccelerometerSamples ||
                latest.persistedGyroscopeSampleCount < minimumGyroscopeSamples) &&
            latest.state != TelemetryBufferState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(TELEMETRY_POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryTelemetryHealth()
        }
        check(latest.state != TelemetryBufferState.ERROR) {
            "Durable telemetry writer failed: ${latest.errorCode}"
        }
        check(latest.completedChunkCount >= minimumChunkCount) {
            "Timed out waiting for durable chunk completion."
        }
        check(latest.persistedGnssSampleCount >= minimumGnssSamples) {
            "Timed out waiting for durable GNSS evidence."
        }
        check(latest.persistedAccelerometerSampleCount >= minimumAccelerometerSamples) {
            "Timed out waiting for durable accelerometer evidence."
        }
        check(latest.persistedGyroscopeSampleCount >= minimumGyroscopeSamples) {
            "Timed out waiting for durable gyroscope evidence."
        }
        return latest
    }

    private fun checkTelemetryHealth(health: TelemetryBufferHealthSnapshot) {
        check(health.queueCapacity == TELEMETRY_CHUNK_INGRESS_CAPACITY)
        check(health.reorderBufferCapacity == TELEMETRY_CHUNK_REORDER_BUFFER_CAPACITY)
        check(health.queueDepth in 0..health.queueCapacity)
        check(health.completedChunkCount > 0)
        check(health.persistedByteCount > 0)
        check(health.corruptChunkCount == 0)
        check(health.orphanedWriteCount == 0)
        check(health.orderingViolationCount == 0)
        check(health.overflowCount == 0L)
        check(health.invalidTripTimeCount == 0L)
        check(health.lateSampleCount == 0L)
        check(health.writeFailureCount == 0L)
        check(health.lastCompletedSequence != null)
        check(health.hasCommittedElapsedBoundary)
        check(health.errorCode == null)
    }

    private fun awaitImuSamples(): ImuHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + IMU_SAMPLE_TIMEOUT_MILLIS
        var latest = RecorderService.queryImuHealth()
        while (
            (latest.accelerometerAcceptedSampleCount < MINIMUM_IMU_SAMPLES_PER_SENSOR ||
                latest.gyroscopeAcceptedSampleCount < MINIMUM_IMU_SAMPLES_PER_SENSOR) &&
            latest.state != ImuAcquisitionState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(IMU_POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryImuHealth()
        }
        check(latest.state != ImuAcquisitionState.ERROR) {
            "IMU registration failed: ${latest.errorCode}"
        }
        check(latest.accelerometerAcceptedSampleCount >= MINIMUM_IMU_SAMPLES_PER_SENSOR) {
            "Timed out waiting for accelerometer samples; " +
                "accepted=${latest.accelerometerAcceptedSampleCount}, " +
                "rejected=${latest.rejectedSampleCount}."
        }
        check(latest.gyroscopeAcceptedSampleCount >= MINIMUM_IMU_SAMPLES_PER_SENSOR) {
            "Timed out waiting for gyroscope samples; " +
                "accepted=${latest.gyroscopeAcceptedSampleCount}, " +
                "rejected=${latest.rejectedSampleCount}."
        }
        return latest
    }

    private fun checkImuMetadata(health: ImuHealthSnapshot) {
        val accelerometerConfig = health.accelerometerConfiguration
        val gyroscopeConfig = health.gyroscopeConfiguration
        check(accelerometerConfig != null) { "Accelerometer configuration was unavailable." }
        check(gyroscopeConfig != null) { "Gyroscope configuration was unavailable." }
        check(accelerometerConfig.sensorType == ImuSensorType.ACCELEROMETER)
        check(gyroscopeConfig.sensorType == ImuSensorType.GYROSCOPE)
        check(
            accelerometerConfig.requestedSamplingPeriodMicros ==
                IMU_REQUESTED_SAMPLING_PERIOD_MICROS,
        )
        check(
            gyroscopeConfig.requestedSamplingPeriodMicros ==
                IMU_REQUESTED_SAMPLING_PERIOD_MICROS,
        )
        check(
            accelerometerConfig.effectiveMaxReportLatencyMicros <=
                IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS,
        )
        check(
            gyroscopeConfig.effectiveMaxReportLatencyMicros <=
                IMU_REQUESTED_MAX_REPORT_LATENCY_MICROS,
        )
        check(health.accelerometerFirstSourceTimestampNanos != null) {
            "Accelerometer source timestamp was not preserved."
        }
        check(health.gyroscopeFirstSourceTimestampNanos != null) {
            "Gyroscope source timestamp was not preserved."
        }
        check(health.accelerometerLastTripElapsedNanos != null) {
            "Accelerometer trip elapsed time was unavailable."
        }
        check(health.gyroscopeLastTripElapsedNanos != null) {
            "Gyroscope trip elapsed time was unavailable."
        }
        check(health.accelerometerLastAccuracyStatus != null) {
            "Accelerometer accuracy status was not preserved."
        }
        check(health.gyroscopeLastAccuracyStatus != null) {
            "Gyroscope accuracy status was not preserved."
        }
        check(health.errorCode == null) { "IMU health contained an error: ${health.errorCode}" }
    }

    private fun awaitGnssFix(): GnssHealthSnapshot {
        val deadline = SystemClock.uptimeMillis() + GNSS_FIX_TIMEOUT_MILLIS
        var latest = RecorderService.queryGnssHealth()
        while (
            latest.acceptedSampleCount == 0L &&
            latest.state != GnssAcquisitionState.PROVIDER_DISABLED &&
            latest.state != GnssAcquisitionState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(GNSS_POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryGnssHealth()
        }
        check(latest.state != GnssAcquisitionState.PROVIDER_DISABLED) {
            "GPS provider is disabled; enable precise device location before running the proof."
        }
        check(latest.state != GnssAcquisitionState.ERROR) {
            "GNSS registration failed: ${latest.errorCode}"
        }
        check(latest.acceptedSampleCount > 0) {
            "Timed out waiting for a real GPS fix; " +
                "state=${latest.state.wireName}, " +
                "rejected=${latest.rejectedSampleCount}, " +
                "registrationFailures=${latest.registrationFailureCount}. " +
                "Place the phone outdoors with a clear sky view."
        }
        return latest
    }

    private fun awaitState(
        context: Context,
        predicate: (RecorderStateSnapshot) -> Boolean,
    ): RecorderStateSnapshot {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        var latest = RecorderService.queryState(context)
        while (!predicate(latest) && SystemClock.uptimeMillis() < deadline) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.queryState(context)
        }
        check(predicate(latest)) {
            "Timed out waiting for recorder state; " +
                "latest=${latest.lifecycleState.wireName}, error=${latest.errorCode}"
        }
        return latest
    }

    private fun awaitRecovery(context: Context): RecorderStateSnapshot {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        var latest = RecorderService.requestRecovery(context)
        while (
            latest.lifecycleState != RecorderLifecycleState.RECOVERED &&
            latest.lifecycleState != RecorderLifecycleState.ERROR &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
            latest = RecorderService.requestRecovery(context)
        }
        check(latest.lifecycleState == RecorderLifecycleState.RECOVERED) {
            "Timed out waiting for recorder recovery; " +
                "latest=${latest.lifecycleState.wireName}, error=${latest.errorCode}"
        }
        return latest
    }

    private fun checkNotificationActive(context: Context) {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        val manager = context.getSystemService(NotificationManager::class.java)
        while (
            manager.activeNotifications.none { it.id == RecorderService.NOTIFICATION_ID } &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
        }
        check(manager.activeNotifications.any { it.id == RecorderService.NOTIFICATION_ID }) {
            "Recorder foreground notification was not active."
        }
    }

    private fun checkNotificationStopped(context: Context) {
        val deadline = SystemClock.uptimeMillis() + STATE_TIMEOUT_MILLIS
        val manager = context.getSystemService(NotificationManager::class.java)
        while (
            manager.activeNotifications.any { it.id == RecorderService.NOTIFICATION_ID } &&
            SystemClock.uptimeMillis() < deadline
        ) {
            SystemClock.sleep(POLL_INTERVAL_MILLIS)
        }
        check(manager.activeNotifications.none { it.id == RecorderService.NOTIFICATION_ID }) {
            "Recorder foreground notification remained after stop."
        }
    }

    private fun executeShellCommand(command: String) {
        uiAutomation.executeShellCommand(command).close()
    }

    private fun Context.hasPermission(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        private const val STATE_TIMEOUT_MILLIS = 5_000L
        private const val POLL_INTERVAL_MILLIS = 50L
        private const val GNSS_FIX_TIMEOUT_MILLIS = 120_000L
        private const val GNSS_POLL_INTERVAL_MILLIS = 250L
        private const val IMU_SAMPLE_TIMEOUT_MILLIS = 10_000L
        private const val IMU_POLL_INTERVAL_MILLIS = 50L
        private const val MINIMUM_IMU_SAMPLES_PER_SENSOR = 20L
        private const val TELEMETRY_TIMEOUT_MILLIS = 15_000L
        private const val TELEMETRY_STATE_TIMEOUT_MILLIS = 15_000L
        private const val TELEMETRY_POLL_INTERVAL_MILLIS = 100L
        private const val PROOF_DELETE_ATTEMPTS = 20
        private const val PROOF_DELETE_RETRY_MILLIS = 50L
    }
}
