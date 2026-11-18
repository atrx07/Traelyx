# M8.6 maintainer-local release key custody v1

**Status:** Active — tooling locally validated; production identity/backup not yet verified
**Date:** 2026-11-18
**Source baseline:** `3e35532`

This establishes custody only. No production APK, Gradle production-signing
configuration, install/upgrade, publishing, hosted credentials or M8.7 work is
authorized. Current Gradle release-validation builds still use Android's debug
identity. See [ADR-0009](../decisions/ADR-0009-release-key-local-custody.md),
[RELEASE_SIGNING](../technical/RELEASE_SIGNING.md) and the
[execution plan](../exec-plans/active/M8_RELEASE_KEYSTORE_CUSTODY.md).

## Maintainer action

Run the reviewed tool yourself in a local interactive PowerShell/terminal from
the repository root. Python and JDK17+ are required; Android Studio's installed
JDK is supported and used as a fallback. Do not enter passwords in chat, command
arguments, environment setup commands, screenshots or repository files.

```powershell
python .\tool\release_signing_setup.py create
```

Before running, connect/create the protected backup storage and its directory.
The tool prompts for:

1. Primary key path. The default is the per-user local application-data directory,
   under Traelyx/release-signing/traelyx-release.p12, outside the checkout.
2. Backup file path in an existing independently protected directory, such as
   a trusted removable drive. Another folder/partition on the same physical disk
   does not establish independence. Use unsynced locations; known cloud-sync
   roots and network shares are rejected, but detection cannot cover every provider.
3. Explicit CREATE confirmation, then a hidden password and confirmation. Use
   at least16 characters, preferably a password-manager-generated secret or strong
   passphrase, stored separately from both key files.
4. Confirmation that both locations are unsynced, the backup independently
   protected, and its password kept separately. Do not attest until that is true.

No existing key, backup or configuration is overwritten. Creation refuses an
existing key/configuration or public identity pin. Use verify to resume an
interrupted setup with the retained original key; never create a replacement.
If a partial backup differs, retain it for inspection and choose an unused backup
file. If the primary key is missing, recover the original from backup before
verification; the tool does not silently restore, rotate or reset identities.

```powershell
python .\tool\release_signing_setup.py verify
```

Optional --keystore, --backup and --config arguments specify nonsecret absolute
paths. They never accept passwords. Protect the directories' access permissions;
the workflow inherits Windows ACLs and uses restrictive file modes where supported.
It does not certify storage encryption or securely erase physical media remnants.
One transient encrypted key copy is created in the protected primary directory
during first-time generation and removed after exclusive publication.

## What is verified / persisted

Creation uses the existing JDK keytool, PKCS#12, a fixed traelyx-release alias,
RSA4096,10000 days and a project-only certificate subject without personal data.
The initial proof requires4096 bits and more than25 years remaining. Subsequent
proof of a pinned identity requires a currently valid certificate, not a fresh
25-year lifetime, so ordinary aging never forces a new signing key.

The Java source probe opens the primary and backup independently, decrypts their
private key, signs a fresh random nonce with SHA256withRSA and verifies it with
the certificate public key. It verifies the self-signed certificate, rejects
debug subjects/unsupported entries and returns only allowlisted public metadata.
Backup bytes must also match, and source aliases, symlinks or hard links cannot
stand in for a distinct backup file. No signature, nonce, private key or password
is exported. No APK is created or signed by this proof.

Passwords exist only in the interactive process and a short-lived JDK child
environment. There is no plaintext password file, shell argument, persistent
environment assignment or child-output logging. This is local process handling,
not a claim of perfect memory erasure. Python/JVM processes exit after setup.

Private local config.json records key/backup paths, alias/type and public
fingerprint only. It remains outside Git. A sanitized receipt is written to
.dart_tool/release-signing/setup-receipt-v1.json only after proof and custody
attestation. It includes public certificate metadata, proof/attestation flags,
verification time and tool/probe source hashes; no local paths or passwords.
Starting another interactive attempt removes stale receipt evidence first.

After the maintainer reports completion, review the sanitized receipt and pin
the public certificate identity in docs/reference/release-signing-identity-v1.json.
Never commit the keystore, backup, local configuration or passwords. Public
certificate metadata is intentionally distinct from private signing material.
An existing public pin must match; mismatches require review, never regeneration.

## Software validation / limits

```powershell
python -W error::ResourceWarning -m unittest tests.tool.test_release_signing_setup
```

All19 local tests pass: Git/network/cloud path rejection, exclusive files,
hard-link/different-backup refusal, existing config/pin protection, child-only
password handling/redaction, JDK preflight, bounded unexpected failures,
attestation/receipt hygiene and real disposable JDK private-key/backup proof,
wrong-password rejection and debug-certificate refusal. Fixtures are temporary,
synthetic and never production identities; no actual signing key enters CI or
its artifacts. CI retains this test gate alongside existing app checks.

Actual production creation/backup remains a maintainer action. A byte/private-key
proof establishes current read/decrypt/sign capability; independent storage,
access protection and unsynced custody remain separately recorded attestations.
It does not prove future media survival, unattended disaster recovery or APK
signature/install compatibility. No runtime dependency/schema/permission change.

Android's [signing guidance](https://developer.android.com/studio/publish/app-signing)
explains key custody and update identity. Flutter's
[Android release guide](https://docs.flutter.dev/deployment/android) describes
local signing configuration. Production wiring, ABI/signature/checksum work
belongs to M8.7 after explicit authorization. Existing debug installs are not
silently replaceable with a different certificate; preserve their data and leave
that transition to separately reviewed install/upgrade work. Distribution,
profiling, private-reporting and carried M6.8/M7 acceptance holds remain.
