# Execution Plan — M8.7 signed APK build

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M8.7
**Started / last updated:** 2026-11-18

## Context / goal

Authorized by "continue" after M8.6 closure `c7023fe`. Read root/android/tests
AGENTS, docs index, RELEASE_SIGNING, SECURITY, ADR-0009, testing/completion policy,
MVP scope, roadmap M8.7 and release checklist; inspect existing Gradle, custody,
APK inventory/privacy tooling and installed Flutter split-version rules.

Produce locally held production-signed APKs with pinned certificate, ABI/manifest
checks, alignment checks and SHA256SUMS. Do not install, tag, publish or distribute.

## Scope / design

- Explicit Gradle unsigned-release opt-in; normal CI/development signing retained.
- Compile three ABI splits: arm64-v8a primary, armeabi-v7a legacy candidate,
  x86_64 emulator candidate. Packaging is not physical compatibility acceptance.
- Sign after compilation with Android SDK apksigner; password enters only a local
  masked prompt and short-lived proof/signer children, never Gradle or files.
- Require clean source commit, public certificate pin, ordinary package/version,
  one runnable Flutter ABI, SDK signature verification, alignment and privacy audit.
- Keep artifacts/plans/logs under ignored build/; commit only sanitized evidence.
- Version remains 0.1.0+1, internal candidate. Flutter ABI split version codes are
  1001/2001/4001; future upgrade versions must account for these offsets.

## Privacy / compatibility / risks

No runtime/schema/recorder/scoring/dependency/permission change. Existing public
client configuration may be compiled; no service-role credentials, user tokens,
private telemetry or signing material may enter APKs. Key remains outside Git.
Password recovery and phone custody limits from M8.6 remain. Changing certificate
cannot update existing debug installations; do not replace ordinary phone data.
Distribution, private reporting, profiling and M6.8/M7 acceptance holds remain.

## Steps / validation

- [x] Prepare unsigned opt-in, local signing/verification and private prompt.
- [x] Test fail-closed identity/ABI/version/source/no-clobber/secret boundaries.
- [ ] Validate source, app gates, affected unsigned/development builds and source CI.
- [ ] Compile from clean pinned source and prepare immutable input hashes.
- [ ] Owner enters existing password privately; sign and verify actual APKs.
- [ ] Audit packaged privacy, record checksums/size/provenance and limitations.
- [ ] Synchronize records, commit/push and verify clean main; stop before M8.8.

## Completion

Local checkpoint: all40 custody/APK tests pass, including disposable real SDK
three-ABI signing, v2/v3 proof and no-overwrite. Python syntax, PowerShell prompt
parser, repository contracts and static analysis pass. Actual unsigned app splits
compile and pass package/version/one-runnable-ABI/alignment checks (SDK24–36).
One fixture parser initially assumed the older sdkVersion label; supporting the
SDK37 minSdkVersion label fixed the test without weakening its SDK requirement.
Custody fixture keys use normal temporary storage outside Git, as policy requires.
The operator invokes compilation itself and brackets it with clean-source checks
to prevent arbitrary stale APKs from being attributed to a newer source commit.

Pending actual production signing and verification. No installation or publication
is authorized by this substep. No key generation/replacement is needed or allowed.
