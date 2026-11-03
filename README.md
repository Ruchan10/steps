# Footnote

Every step, noted. A simple Android step counter built with Flutter. Steps are
recorded in the background by a native foreground service using the hardware
step counter, and shown in the app (today + history), in a permanent
notification and in two home screen widgets that adapt their layout to the size
they're given.

The app is in English and Nepali (नेपाली). It follows the phone's language, or
the language picked in the app, which also applies to the widgets and the
notification.

## Translations

App strings live in `lib/l10n/app_<language>.arb`; the Dart classes are
generated from them by `flutter pub get` (see `l10n.yaml`). The widgets and the
notification use Android string resources in
`android/app/src/main/res/values*/strings.xml`. To add a language, add both,
then list it in `AppLocale.supported` (`Metrics.kt`) and in the language
choices (`lib/settings_sheets.dart`, `lib/onboarding.dart`).

## Run locally

```sh
flutter run
```

## Releasing

Releases are built by GitHub Actions (`.github/workflows/release.yml`) when a
version tag is pushed. It produces one APK per CPU architecture
(`footnote-<version>-arm64-v8a.apk`, `-armeabi-v7a.apk`, `-x86_64.apk`) and
attaches them to a GitHub release. The app checks that release on launch and
offers the APK matching the phone's architecture.

### One-time setup: signing key

Every release must be signed with the same key, otherwise Android won't install
an update over the existing app. Keep the keystore and passwords somewhere safe —
if you lose them, users have to uninstall to update.

```sh
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000

# Add the repository secrets (or via Settings → Secrets and variables → Actions)
gh secret set KEYSTORE_BASE64 < <(base64 -w0 upload-keystore.jks)
gh secret set KEYSTORE_PASSWORD
gh secret set KEY_ALIAS --body upload
gh secret set KEY_PASSWORD
```

To build signed release APKs locally, create `android/key.properties`
(gitignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

### Publishing a version

```sh
git tag v1.1.0
git push origin v1.1.0
```

The tag sets the version name (`1.1.0`); the workflow run number sets the build
number. Users on an older version see the update dialog the next time they open
the app.
# steps
