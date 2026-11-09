# Known Tooling Issues

This is a lightweight, failure-triggered runbook for recurring local tooling problems. It is optional context: do not read it during normal startup. Search it when a host, toolchain, environment, build, or test command fails; when a symptom matches an entry below; or when the task explicitly concerns local build/test tooling.

Use the matching safe fix before inventing another workaround. If it fails, investigate the current evidence and revise the entry only after validating the replacement. Keep product defects, transient external failures, and one-off operator mistakes out of this file.

## SQLite release URL caches an HTTP error body in CI

- **Scope:** Linux and Android native hooks for pinned `sqlite3` 3.5.1 in CI.
- **Symptom:** Drift schema verification reports downloaded hash `bef140a1…`
  instead of published `b1772918…`; a fresh-runner retry fails identically.
- **Confirmed evidence:** The default official release URL returned HTTP 504,
  92 bytes, whose SHA-256 exactly matched the rejected response. The same official
  asset with a fresh query returned the package's expected SHA-256. Source repair
  CI 42566948992 attempts 1/2 stopped here before application tests.
- **Safe fix:** The CI precache step requests that immutable official release asset
  through GitHub's asset API with `Accept: application/octet-stream`, uses bounded
  curl retries with HTTP failure detection, verifies the exact
  package-published hash, then populates the native hook's hash-keyed cache. The
  hook independently verifies cached bytes. Recheck the version/hash/cache layout
  deliberately when upgrading sqlite3; a different hook hash ignores this cache.
- **Verification:** The fresh-query route returned correct bytes once locally but
  failed with HTTP 504 in CI 42567704116. The immutable asset API returns the
  expected digest locally (2026-11-09). CI 42567971147 passed that Linux cache,
  schema gates and all 432 Flutter tests; Android then rejected the same HTTP
  504 digest for its ARM library. The precache covers Linux x64 plus Android
  ARM/ARM64/x64 with each published hash. CI 42568702628 verifies all four assets
  and app tests; its Android build instead hit the Gradle issue below.
  Do not claim a failed run passed.
- **Do not:** Disable checksum/TLS checks, accept the HTTP error's digest, alter
  package cache source, replace SQLite with a different system build, or loosen
  schema/test gates.

## Gradle release URL caches HTTP 504 in CI

- **Scope:** Gradle wrapper 9.1.0 `all` distribution on fresh GitHub runners.
- **Symptom/evidence:** CI 42568702628 attempts 1/2 pass app checks, then fail
  on the official Gradle GitHub release download with HTTP 504 before compilation.
- **Safe fix:** CI fetches the identical immutable official release asset through
  GitHub's API, verifies published SHA-256 `b84e04fa…`, then populates the wrapper's
  existing URL-derived ZIP cache. The wrapper still extracts/runs the same version.
  A guard requires the expected wrapper URL. Update asset/hash/cache key together
  deliberately on wrapper upgrades; never bypass hash or TLS verification.
- **Verification:** Official API download hash and URL-derived cache key verified
  locally on 2026-11-09; CI 42569557135 passes this step and starts compilation.
  Its next failure is the compiler download below. The ordinary repair build
  already passes using the existing cached distribution.

## Kotlin compiler artifact download returns HTTP 504 in CI

- **Scope:** Existing compiler-embeddable JARs 2.2.20 (Flutter Gradle plugin) and
  2.3.20 (app), not a Kotlin version upgrade.
- **Evidence:** CI 42569557135 passes app/schema/download gates, then Maven's
  compiler download resolves to an official JetBrains release URL returning 504;
  Flutter's normal build retry fails identically.
- **Safe fix:** Fetch the exact official immutable assets through GitHub's API;
  verify their published SHA-256 before placing them in Gradle's existing
  content-addressed artifact cache. Derive its SHA-1 directory only after the
  stronger SHA-256 verification. Keep normal repository metadata resolution.
- **Verification:** Official digests match both locally used compiler JARs;
  2.2.20 API download verified locally. Full CI of the cache remedy is pending.
  Do not substitute an unverified compiler, change repository trust or skip tests.

## PowerShell JSON timestamps lose UTC when reparsed through strings

- **Scope:** PowerShell 7 operator contexts containing ISO UTC timestamps.
- **Symptom:** A valid event/window appears expired before an operator job starts.
- **Cause:** `ConvertFrom-Json` can produce UTC `DateTime` objects. Passing those
  objects to `DateTimeOffset.Parse` first coerces them to culture-formatted text,
  losing UTC kind and milliseconds; this host then interpreted them as +05:30.
- **Safe fix:** Use the reviewed pair operator's `-ContextPath` input, which
  preserves UTC objects and validates UTC ISO strings. Do not call `.Parse` on an
  already parsed date object. Ambiguous/local dates and non-UTC offsets fail closed.
- **Verification:** `tests/tool/test_guardian_duplicate_pair.ps1` passes 37 checks,
  including the real context instant/budget, both string/object paths, precision
  and malformed/ambiguous inputs. Validated on 2026-10-10 in PowerShell 7; execution
  of the same file in legacy Windows PowerShell was blocked by host authorization.
- **Do not:** Weaken execution policy or convert times through local/culture text.

## Guardian operator confirmation exceeds the default handoff wait

- **Scope:** The reviewed first-phone duplicate operator, not receiver delivery.
- **Symptom:** First phase/requeue pass, but no second-send sentinel is created.
- **Cause:** Browser SQL verification and local gate publication can exceed the
  default 45-second wait; one measured handoff took about 68 seconds.
- **Safe fix:** After source CI and fresh live-scope review, use explicit
  `-GateWaitSeconds 90`. The operator ends earlier at the event/window budget
  cutoff and still rechecks all pre-send budgets. Prepare the gate publication
  path before enabling; publish only after observing a successful SQL requeue.
- **Verification:** 51 PowerShell checks cover the measured handoff, strict
  boundaries, shortened waits and no-send Plan; twelve phone/probe tests pass.
- **Do not:** Extend the six-minute server lease, waive a send budget, signal an
  unobserved SQL result or retry an expired/already attempted job.

## Gradle cannot find Java in a clean PowerShell session

- **Scope:** Windows PowerShell; Android/Gradle commands.
- **Symptom:** Gradle exits before the build because `JAVA_HOME` is unset or Java cannot be found.
- **Cause:** A clean or restarted task shell does not inherit a usable JDK configuration. Android Studio's bundled JDK is available on the current Traelyx Windows host at `C:\Program Files\Android\Android Studio\jbr`.
- **Fast safe fix:** Set the variable for the current task shell only, then rerun the intended Gradle command:

  ```powershell
  $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
  .\android\gradlew.bat -p android <task> --no-daemon
  ```

- **Verification:** The intended Gradle task starts with that JDK and completes with its expected result.
- **Do not:** Change the user's global `JAVA_HOME`, system `PATH`, or Android Studio installation to repair one task shell.
- **Last validated / notes:** Revalidated on 2026-10-11: the bundled runtime is Java 21. Android SDK 36 dependency Robolectric tests reject Java 17 before running; use Java 21 for the complete `testDebugUnitTest` task. Rediscover the configured JDK if Android Studio moves.

## Unqualified Android lint also checks dependency modules in isolation

- **Scope:** Direct Gradle lint on the Flutter Android project.
- **Symptom:** `lintDebug` fails in a plugin's own source/manifest (observed: `flutter_secure_storage` reports `USE_BIOMETRIC` missing), while the app target passes.
- **Cause:** The unqualified task runs each subproject's standalone lint, beyond the app's merged-manifest check.
- **Fast safe fix:** Run the intended app gate explicitly: `:app:lintDebug`. Keep `testDebugUnitTest` for all native suites; use Java 21 when Android 36 Robolectric tests are included. Inspect the failing module before choosing a target.
- **Verification:** On 2026-10-11, all native suites plus `:app:lintDebug` passed together; all 375 app tests had zero failures/errors/skips.
- **Do not:** Add app permissions, edit plugin cache source, suppress lint errors, or change test assertions to silence an isolated dependency-manifest failure. A failure in `:app:lintDebug` still requires investigation.

## Windows escaping in `android/local.properties` breaks Android lint

- **Scope:** Windows; ignored `android/local.properties`; Android lint through Gradle.
- **Symptom:** Android lint fails while parsing SDK or Flutter paths even though Flutter commands previously worked. Flutter may have rewritten the ignored file using Windows path text that Gradle's Java-properties parser interprets differently.
- **Cause:** Backslashes and the drive-letter colon are not escaped in the form required by this lint path. This is a machine-local tooling representation issue, not evidence of a source defect.
- **Fast safe fix:** Preserve the pre-lint file byte-for-byte when the workflow requires restoration. Temporarily normalize the affected values to Java-properties escaping, using the actual paths on the host. The current host's expected form is:

  ```properties
  sdk.dir=C\:\\Users\\atrx07\\AppData\\Local\\Android\\sdk
  flutter.sdk=C\:\\Users\\atrx07\\develop\\flutter
  ```

  Run the intended lint task. If Gradle reports a stale `UP-TO-DATE` result after the normalization, force that lint task to rerun once with `--rerun-tasks`. Restore the exact pre-lint bytes afterward if the surrounding workflow expects Flutter's generated state.
  Keep Flutter commands sequential with this temporary lint normalization: a concurrent Flutter command can rewrite the file and undo the escaping while lint is running. A sequential rerun passed on 2026-10-05 after this race reproduced.
- **Verification:** Gradle demonstrably rereads the normalized file, the intended lint task passes, and `android/local.properties` ends in the intended machine-local state.
- **Do not:** Commit the ignored file, weaken lint, change application source to mask the parser failure, or repeatedly force unrelated tasks.
- **Last validated / notes:** Validated on 2026-08-11 during the M2.7 Android validation. Treat other lint failures according to their own evidence.

## Dart formatter check-only mode reports drift but does not repair it

- **Scope:** Dart formatting in local checks or CI-equivalent validation.
- **Symptom:** A formatter check reports files that would change; rerunning the same check leaves the drift in place.
- **Cause:** Check-only mode verifies formatting and intentionally does not write files.
- **Fast safe fix:** Run the normal formatter over the intended paths, inspect the changes, then rerun check-only mode. For example:

  ```powershell
  dart format lib test tool
  dart format --output=none --set-exit-if-changed lib test tool
  ```

  Adjust paths to the command defined by the active repository workflow.
- **Verification:** The write-mode run produces only intended formatting changes and the subsequent check-only command exits successfully without proposed changes.
- **Do not:** Expect check-only mode to modify files or bypass inspection of formatter-written changes.
- **Last validated / notes:** Confirmed in the M2.7 validation workflow on 2026-08-11.

## Concurrent Flutter or Dart commands contend for shared tool state

- **Scope:** Local Flutter/Dart commands sharing SDK cache, snapshots, analysis state, or tool locks.
- **Symptom:** Parallel commands hang, time out, or stop producing output while equivalent commands normally complete independently.
- **Cause:** Concurrent tool invocations can contend for shared Flutter/Dart state. A timeout alone does not prove a source failure.
- **Fast safe fix:** Stop launching Flutter/Dart validation commands in parallel for that session. Inspect running processes and terminate only a confirmed stale tool process. Rerun the required commands sequentially with bounded timeouts.
- **Verification:** Each sequential command starts, emits normal progress, and reaches a conclusive exit result.
- **Do not:** Delete SDK/cache lock files blindly, kill unrelated Java/Dart/Flutter processes, or report a source failure without command output that supports it.
- **Last validated / notes:** Observed and recovered during the M2.7 closeout on 2026-08-11.

## Flutter Windows batch wrappers stall after tool contention

- **Scope:** Current Traelyx Windows host; Flutter/Dart batch wrappers after confirmed local tool contention.
- **Symptom:** `dart` or `flutter` batch commands stall without useful output, while the underlying SDK executable responds normally. This entry applies only after that difference is verified.
- **Cause:** In the validated session, the wrapper/shared-tool-state path remained stalled after contention. The direct SDK executable and Flutter tool snapshot were healthy; no application-source cause was established.
- **Fast safe fix:** First verify the underlying executable:

  ```powershell
  & 'C:\Users\atrx07\develop\flutter\bin\cache\dart-sdk\bin\dart.exe' --version
  ```

  If it responds while the wrapper remains confirmed stalled, invoke the required Dart command directly. For a Flutter command, invoke the Flutter tool snapshot as a separate bounded command:

  ```powershell
  $env:FLUTTER_ROOT = 'C:\Users\atrx07\develop\flutter'
  & 'C:\Users\atrx07\develop\flutter\bin\cache\dart-sdk\bin\dart.exe' `
    --packages='C:\Users\atrx07\develop\flutter\packages\flutter_tools\.dart_tool\package_config.json' `
    'C:\Users\atrx07\develop\flutter\bin\cache\flutter_tools.snapshot' test
  ```

  Substitute only the intended Flutter subcommand and arguments. If a direct analysis command is blocked from its legitimate per-user state directory such as `%LOCALAPPDATA%\.dartServer`, rerun it with the required filesystem permission rather than modifying source or SDK state.
- **Verification:** The underlying executable reports its version, and the direct bounded command completes with a conclusive result for the intended operation.
- **Do not:** Use this fallback before confirming the wrapper-specific stall, permanently change global environment variables, modify the Flutter SDK/cache, delete lock files, or infer an application-source failure from the wrapper hang.
- **Last validated / notes:** Validated on 2026-08-11 during M2.7: the SDK executable and direct Flutter tool snapshot completed while the batch wrappers remained stalled. Rediscover `FLUTTER_ROOT` if the SDK moves.

## Unpinned Flutter stable advances and dirties CI checkout

- **Scope:** GitHub Actions or another clean environment that resolves the latest Flutter `stable` release.
- **Symptom:** `flutter pub get` or `build_runner` is followed by an unrelated `git diff --exit-code` failure in files such as `analysis_options.yaml` or SDK-pinned transitive entries in `pubspec.lock`.
- **Cause:** The runner's unpinned `stable` channel advanced beyond Traelyx's documented Flutter baseline and performed SDK migration or dependency resolution changes before the intended gate.
- **Fast safe fix:** Pin `subosito/flutter-action` with both `channel: stable` and the exact Flutter version declared in `docs/technical/TECH_STACK.md`. Upgrade that baseline only as a deliberate toolchain change with regenerated files and full validation.
- **Verification:** The clean CI setup reports the documented Flutter/Dart versions, generated-source verification leaves the checkout clean, and the remaining workflow gates run.
- **Do not:** Commit runner-generated migrations or lockfile upgrades as part of an unrelated product change, weaken the generated-source diff gate, or leave CI on a floating channel while claiming a reproducible baseline.
- **Last validated / notes:** Added after GitHub's stable channel advanced to Flutter 3.47.0 on 2026-08-13 while Traelyx remained validated on Flutter 3.44.9/Dart 3.12.2.
