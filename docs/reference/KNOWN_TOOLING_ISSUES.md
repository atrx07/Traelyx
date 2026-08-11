# Known Tooling Issues

This is a lightweight, failure-triggered runbook for recurring local tooling problems. It is optional context: do not read it during normal startup. Search it when a host, toolchain, environment, build, or test command fails; when a symptom matches an entry below; or when the task explicitly concerns local build/test tooling.

Use the matching safe fix before inventing another workaround. If it fails, investigate the current evidence and revise the entry only after validating the replacement. Keep product defects, transient external failures, and one-off operator mistakes out of this file.

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
- **Last validated / notes:** Validated on 2026-08-11 during the M2.7 closeout. Rediscover the configured JDK if Android Studio moves.

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
