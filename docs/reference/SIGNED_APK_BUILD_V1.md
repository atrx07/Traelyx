# M8.7 local signed APK workflow v1

**Status:** Active — local tooling/unsigned checks pass; source CI and production proof pending
**Date:** 2026-11-18

Read for trusted local release signing, ABI packaging or checksum verification.
Key custody remains in [M8.6](RELEASE_KEYSTORE_CUSTODY_V1.md); private key/password
never enter Git, CI, Gradle, command arguments or persistent password files.

## Packaging / version contract

| ABI | Role | Internal version name/code |
|---|---|---|
| arm64-v8a | Primary modern physical-phone candidate | 0.1.0 / 2001 |
| armeabi-v7a | Legacy 32-bit candidate | 0.1.0 / 1001 |
| x86_64 | Emulator/compatible-device candidate | 0.1.0 / 4001 |

Flutter 3.44.9's split version rule adds ABI offsets 1000/2000/4000 to base build
number1. Preserve each ABI's monotonic code on upgrades; do not switch to a lower
universal code. Runtime/device acceptance is separate from packaged ABI evidence.
No version/tag/public release is claimed by these internal 0.1.0 candidates.

## Build and prepare without credentials

From a clean committed checkout on the trusted machine:

```powershell
python -m tool.release_apk build --output-dir build/release/<new-source-specific-directory>
```

The operator invokes the installed Flutter SDK directly with release/split-per-ABI
and the unsigned-production property, then requires the source to remain clean
and unchanged. It accepts no arbitrary prebuilt APKs as current-source evidence.
An optional auth-config.local.json must contain only the existing public Supabase
URL/current publishable key; secret/legacy keys are rejected. Absence yields an
explicitly unconfigured account build.
Existing Firebase Android client configuration is handled by the normal Gradle
client-only checks. User credentials, service-role keys and private telemetry are
never release inputs. Guardian/model activation remains unchanged and gated.

The explicit property disables signing for the release build only and rejects QA
package combinations. Normal development/CI builds stay development-signed.
The operator requires three genuinely unsigned ABI APKs, clean source, ordinary
package/version, one runnable Flutter ABI each, ZIP integrity/private-filename
checks and 16 KiB zip alignment. It snapshots inputs with SHA-256 hashes into a
new ignored directory. It refuses existing destinations and signed inputs.

## Private local signing

```powershell
powershell.exe -NoProfile -STA -File tool/signing/Start-ApkSigning.ps1 -PythonExe <python.exe> -Repository <absolute-checkout> -Plan <absolute-plan.local.json>
```

Enter the existing password in the masked local field. No key is generated or
copied. The helper reads the password-free local custody config outside Git,
proves the existing private key and requires its public pin. Password reaches
only short-lived proof/apksigner JVMs through a child environment; it is cleared
from the prompt and is not given to package-inspection children. Raw signer output
is withheld on errors. This is not a guarantee of perfect memory erasure.

Each APK must pass SDK verification with one pinned signer and v2/v3 schemes,
the same package/version/ABI checks and alignment. No post-sign APK mutation is
allowed. Output is held locally under the plan's `signed/` directory:

- three `traelyx-v0.1.0-<abi>.apk` files;
- SHA256SUMS.txt;
- sanitized verification-v1.json (source/input/tool/artifact hashes and results).

Source and input hashes are rechecked. No overwrite is allowed; the aggregate
receipt is published last. An interrupted partial destination is retained for
review and cannot be silently reused. Inspect it before preparing a new directory.
Run the packaged privacy audit for every actual signed APK before step closure.

## Validation / limits

Tests cover child-only secret handling, source/input drift, signed-input refusal,
pin mismatch, ABI/signature rejection, output confinement and disposable real SDK
signing/verification across three synthetic ABI packages with no-clobber checks.
Dummy fixture native bytes are not executable runtime evidence. CI also builds
unsigned app splits and verifies their preparation without production credentials.

All40 local custody/APK tests, static analysis, Python/PowerShell syntax and
repository checks pass. Actual unsigned app splits compile with SDK24 minimum,
SDK36 target and exactly one runnable ABI each. Source CI, clean-source operator
build and actual production signature/privacy evidence remain pending.
No install/upgrade, signing-dependent
provider configuration, physical compatibility or release publication is implied.
M8.8/M8.9 and distribution retain their explicit gates. Existing debug-signed app
data cannot be silently replaced by this different certificate. No runtime/schema,
sampling, scoring, permission or dependency change is introduced.

Android's [apksigner](https://developer.android.com/tools/apksigner) reference
documents environment password input and verification. Its
[zipalign](https://developer.android.com/tools/zipalign) reference requires alignment
before signing and provides 16 KiB check mode; [Flutter's release guide](https://docs.flutter.dev/deployment/android)
documents split-per-ABI builds. The selected SDK executable output is verified
locally; packaging checks do not prove ELF/runtime support for every device.
