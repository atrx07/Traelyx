# Execution Plan — M8.6 release keystore setup/backup

**Status:** Active
**Owner:** maintainer/agent
**Milestone:** M8.6
**Started / last updated:** 2026-11-18

## Goal / context

Authorized after M8.5 closure `3e35532`. Maintainer reports no known production
key; android/key.properties is absent and Gradle still explicitly uses debug
signing for release-validation builds. Establish a maintainer-created production
identity, secure local custody, verified backup and public identity evidence.

Read root/android/tests AGENTS, RELEASE_SIGNING, SECURITY, ADR-0009,
release-checklist, roadmap M8.6 and the execution-plan template. Android and
Flutter official signing guidance supplies current verification context.

## Scope / boundaries

Provide a local interactive setup/verification tool using installed JDK keytool
and Java cryptography APIs. Password input stays in the maintainer's console and
short-lived child environment, never command arguments, logs, repository files
or chat. Store/backup paths must remain outside Git worktrees. Creation and copy
must refuse overwrites. Backup verification must compare bytes and prove access
to the restored private key by signing/verifying a nonce, without making an APK.

Only sanitized public certificate metadata and custody/verification dispositions
may enter repository evidence. Independent backup storage is a maintainer
attestation, separate from automated byte/private-key proof. No secrets in CI.

Initial preparation kept key creation maintainer-run. The maintainer subsequently
explicitly instructed: "take over and do the setup for me" and authorized the
connected physical phone as the backup destination because no second disk is
available. This authorizes agent-orchestrated first-time generation, satisfying
SECURITY's explicit-instruction exception. Password choice/recovery stays with
the maintainer through a private local prompt; never chat or command arguments.
No key rotation, cloud upload, app/data replacement, production signed APK,
Gradle production-signing wiring, M8.7 work or distribution. Existing CI remains
debug/release validation and does not establish production signing readiness.

## Steps / gates

- [x] Inspect existing signing policy/configuration and confirm first-time setup.
- [x] Prepare interactive create/resume verification and backup proof workflow.
- [x] Validate fail-closed paths, redaction and real JDK fixture proof locally.
- [ ] Provide the concrete reviewed command for maintainer-local execution.
- [ ] Verify sanitized setup/backup receipt and pin the public certificate identity.
- [ ] Pass source CI, synchronize status/roadmap, commit/push and verify.

## Compatibility / privacy / risks

No schema, runtime dependency, permission, payload, sensor or scoring change.
The future production identity will differ from installed debug APKs; installing
over them may fail or require a separately reviewed migration later. Do not
uninstall or change application ID to hide that incompatibility. Losing this
production key affects future direct-APK updates; never auto-generate a replacement.
No claim of encrypted media, geographically independent storage or future recovery
from an offline backup follows from a byte comparison alone.

## Progress / completion

Active. Complete preparation/validation before requesting the maintainer's
necessary local secret-entry/custody action. M8.7 remains unauthorized.
All 19 local custody tests pass, including real disposable JDK proofs and backup,
wrong-password/debug rejection, no-overwrite/replacement, path and receipt guards.
No production key has been created or read by the agent. Python syntax,
repository JSON/YAML/secret contracts and whitespace checks pass. Source CI
remains pending; actual maintainer setup/backup is still required.
Steering: physical TECNO LH8n is connected and its ADB authorization approved.
Prepare USB phone copy/readback and a private local password prompt; never use
the emulator as an independent backup. Preserve existing phone app/data and any
existing key/backup files. Record direct-USB proof separately from phone-folder
sync/access assumptions and password-recovery attestation.
All 26 local tests and the Windows prompt parser pass. Real TECNO disposable
marker USB readback and no-clobber behavior pass; only owned marker files/folder
were removed. Dedicated backup folder is writable. No production key exists yet.
