# Execution Plan — M8.6 release keystore setup/backup

**Status:** Complete — authorized local identity and physical-phone backup verified
**Owner:** maintainer/agent
**Milestone:** M8.6
**Started / last updated:** 2026-11-18

## Goal / context

Authorized after M8.5 closure `3e35532`. Maintainer reports no known production
key; android/key.properties is absent and Gradle still explicitly uses debug
signing for release-validation builds. Establish a maintainer-controlled production
identity, secure local custody, verified backup and public identity evidence.

Read root/android/tests AGENTS, RELEASE_SIGNING, SECURITY, ADR-0009,
release-checklist, roadmap M8.6 and the execution-plan template. Android and
Flutter official signing guidance supplies current verification context.

## Scope / boundaries

Provide a local interactive setup/verification tool using installed JDK keytool
and Java cryptography APIs. Password input stays in the maintainer's private prompt and
short-lived child environment, never command arguments, logs, repository files
or chat. Store/backup paths must remain outside Git worktrees. Creation and copy
must refuse overwrites. Backup verification must compare bytes and prove access
to the restored private key by signing/verifying a nonce, without making an APK.

Only sanitized public certificate metadata and custody/verification dispositions
may enter repository evidence. Physical-device selection and byte/private-key
proof are mechanical checks; password recovery is separately maintainer-attested.
Phone-folder sync/access is not automatically verified. No secrets in CI.

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
- [x] Provide the reviewed private local password prompt and authorized setup.
- [x] Verify sanitized setup/backup receipt and pin the public certificate identity.
- [x] Pass source CI and synchronize status/roadmap for the completion commit.

## Compatibility / privacy / risks

No schema, runtime dependency, permission, payload, sensor or scoring change.
The future production identity will differ from installed debug APKs; installing
over them may fail or require a separately reviewed migration later. Do not
uninstall or change application ID to hide that incompatibility. Losing this
production key affects future direct-APK updates; never auto-generate a replacement.
No claim of encrypted media, geographically independent storage or future recovery
from an offline backup follows from a byte comparison alone.

## Progress / completion

Core tooling checkpoint `ead7d1f` was followed by explicitly authorized phone/
private-prompt workflow `0d3243f`. All 26 local tests, Python syntax, Windows prompt
parser, repository contracts and whitespace checks pass. Real TECNO disposable
marker USB readback/no-clobber preflight passed; owned markers were removed.

After local password entry and separately recoverable-password attestation,
authorized production generation and actual phone byte readback/private-key proof
passed. The receipt matches all four local tool/probe source hashes. Only public
certificate metadata is pinned in release-signing-identity-v1.json; private key,
password, local config, device serial and phone plan stay outside Git. No password
fields were inspected. The prompt stayed attached until the maintainer closed it;
an initial detached launch exited without creating a key.

All four [source CI jobs 44335799328](https://github.com/atrx07/Traelyx/actions/runs/44335799328)
pass for `0d3243fbf6bb5925508b87a3e5d6be39c8ecd374`, including 26 custody tests,
full Flutter/native suites, generated schemas, UI captures, QA/ordinary validation
builds, lint and packaged privacy policy. No production key enters CI/artifacts.

M8.6 is complete. Password recovery is maintainer-attested; phone-folder sync/access,
media encryption and future disaster survival are not automatically verified.
No app schema/runtime dependency/permission/scoring/recorder change, ordinary app
replacement, production APK, provider change or distribution. Existing release,
profiling/private-reporting and M6.8/M7 acceptance holds remain. Persist this
docs/public-metadata closure to origin/main and verify clean synchronization.
Stop before M8.7; the signed APK build requires explicit authorization.
