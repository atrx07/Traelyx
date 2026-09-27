# Optional Android Guardian push provider

## Current boundary

Firebase Messaging 25.0.1 is a replaceable native registration adapter for M6.8.
It is not called by startup or the current UI. No registration or alert occurs
just because this dependency is present. Full delivery remains unimplemented.

The ignored `.dart_tool/firebase/google-services.json` contains Android **client**
configuration for `traelyx-e28ff`, package `io.github.atrx07.traelyx`. Gradle selects
that package and emits only the four required public client values into generated
Android resources under ignored `build/`. Do not move this file into tracked
sources or paste its contents into logs. Service-account JSON is rejected.
An absent file generates an unconfigured adapter; accountless features build.

The Firebase initialization provider is removed from the merged manifest.
Messaging auto-init, analytics/data collection, delivery-metric export and
notification delegation are disabled. Registration requires explicit account-
bound notification consent, the Android notification permission where required,
and available Google Play services. The adapter reports unavailable without
forcing Play services installation. Supabase remains the account provider.

## Dependency review (2026-09-27)

- Purpose: Android background push cannot be supplied by a foreground Dart
  connection. Platform-only polling would have worse battery/lifecycle behavior.
- Pin: `com.google.firebase:firebase-messaging:25.0.1`; primary Maven POM declares
  Apache-2.0, compatible with the repository. Its maintained public source and
  version history were inspected. The public repository advisory page showed
  no published advisories; this is not proof of absence of vulnerabilities.
- Transitives include Firebase common/components/installations/encoders/transport,
  Google Play services base/tasks/cloud-messaging/stats, AndroidX annotations and
  Kotlin. The measurement connector is an interface; Firebase Analytics itself
  is not included. Play services artifacts have separate Google terms and the
  service/device runtime is proprietary. Do not describe the entire stack as
  open source. The resolved dependency graph contains no Firebase Analytics artifact.
- Android: the merged app remains min SDK 24 / target SDK 36. FCM adds
  ACCESS_NETWORK_STATE, WAKE_LOCK and the Google message-receive permission;
  it does not change recorder location permissions or sensor sampling. FCM needs Google Play services; devices without it
  retain local features. No location/sensor dependency is introduced.
- Data: explicit registration sends Firebase installation/configuration/device
  metadata to Google and obtains a routing token. The token must not authorize
  alert detail access. No routes, names or telemetry belong in FCM payloads.
- Cost: Cloud Messaging is a no-cost Firebase product; project stays on Spark
  without billing details. Free-tier delivery/availability is not guaranteed.
- Battery/size: the release-validation APK is 64,608,754 bytes versus the prior
  63,096,854 bytes (+1,511,900 bytes, about 1.44 MiB). The merged manifest removes
  FirebaseInitProvider and keeps all four collection/delegation defaults false.
  Configured and unconfigured debug builds, release build and 253 native tests
  pass. Physical locked/background delivery remains unverified.
- Replacement: `GuardianPushRegistration` isolates the provider. Backend HTTP v1
  dispatch, refresh/rotation handling, durable account binding and UI consent are
  separate integration gates before activation.

Primary references:

- https://dl.google.com/dl/android/maven2/com/google/firebase/firebase-messaging/25.0.1/firebase-messaging-25.0.1.pom
- https://github.com/firebase/firebase-android-sdk
- https://github.com/firebase/firebase-android-sdk/security/advisories
- https://firebase.google.com/support/release-notes/android
- https://firebase.google.com/docs/cloud-messaging/android/get-started
- https://firebase.google.com/docs/projects/billing/firebase-pricing-plans

Backend sender credentials have not been created. They will belong only in
Supabase Edge Function secrets after deployment review, never in this client file,
the app, a repository commit, or chat.

For an explicitly unconfigured local validation build, use Gradle property
`-PtraelyxFirebaseEnabled=false`; no config file needs to be moved or deleted.

Physical Android 14 startup proof passed: configured=true, Firebase remained
uninitialized before consent, and no registration was requested. Cold launch,
saved sign-in, and all 7,546 raw files / 59,570 KiB were preserved. This does not
verify registration, push delivery, background receipt or battery use after opt-in.
