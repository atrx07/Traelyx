# Execution Plan — M8.7 signed APK build

**Status:** Complete — local production-signed candidates verified; distribution held
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
- [x] Validate source, app gates, affected unsigned/development builds and source CI.
- [x] Compile from clean pinned source and prepare immutable input hashes.
- [x] Owner enters existing password privately; sign and verify actual APKs.
- [x] Audit packaged privacy, record checksums/size/provenance and limitations.
- [x] Synchronize records for completion commit; verify pushed main before reporting.

## Completion

Local checkpoint: all 40 custody/APK tests pass, including disposable real SDK
three-ABI signing, v2/v3 proof and no-overwrite. Python syntax, PowerShell prompt
parser, repository contracts and static analysis pass. Actual unsigned app splits
compile and pass package/version/one-runnable-ABI/alignment checks (SDK24–36).
One fixture parser initially assumed the older sdkVersion label; supporting the
SDK37 minSdkVersion label fixed the test without weakening its SDK requirement.
Custody fixture keys use normal temporary storage outside Git, as policy requires.
The operator invokes compilation itself and brackets it with clean-source checks
to prevent arbitrary stale APKs from being attributed to a newer source commit.

Source checkpoint `6409795ed8414393ac1d48123c8f160ac3f08339` passes all four
[CI jobs 44343328446](https://github.com/atrx07/Traelyx/actions/runs/44343328446),
including full app/native gates, existing development builds/privacy policy and
the new real unsigned-build preparation. The clean-source local operator build
passes; Gradle also rejects the production/QA combination. Its generated failure
report was moved to ignored local evidence, leaving source clean before signing.

The owner entered the existing password only in the local masked form. Three
actual APKs pass pinned certificate/single-signer v2/v3 verification, package,
version, ABI, ZIP alignment, exact checksums and independent packaged privacy
audits. All original ZIP payload entries remain byte-identical after signing;
only expected META-INF signing metadata is added. A supplemental comparison first
assumed no added ZIP entries; reviewing the standard signing metadata corrected
that assumption without relaxing original-payload equality. No APK repair/re-sign
or key replacement was needed. The owner closed the form; helper exit0 observed.

Supplemental ELF64 LOAD/GNU_RELRO layout checks pass for arm64/x86_64 payloads;
these are static checks, not an actual 16 KiB runtime test. Sanitized evidence and
exact artifact/tool/configuration hashes are in
`docs/reference/m8-signed-apk-v1-result.json`. Artifacts and SHA256SUMS remain
under ignored `build/release/m8.7-6409795/signed/` on the maintainer's PC.

M8.7 is complete. No installation, upload/publication, dependency/permission/schema,
recorder/scoring change, model promotion or key generation/copy/replacement.
No physical ABI, clean/upgrade install or signing-dependent provider acceptance
is claimed; distribution/profiling/private-reporting and M6.8/M7 holds remain.
Persist the docs/evidence closure, verify synchronized main and stop before M8.8.
