Android build instructions

This file documents how to build the Android APK/AAB locally and in CI.

Local debug build (quick)

1. Make the build script executable (one-time):

```bash
chmod +x scripts/build-android.sh
```

2. Build a debug APK (from repo root):

```bash
./scripts/build-android.sh debug
# or via npm script:
npm run build-android
```

3. The debug APK is produced at:

```
android/app/build/outputs/apk/debug/app-debug.apk
```

Local release build (unsigned)

```bash
./scripts/build-android.sh release
# or via npm script:
npm run build-android-release
```

Unsigned release APK and AAB are placed under:

```
android/app/build/outputs/apk/release/app-release-unsigned.apk
android/app/build/outputs/bundle/release/app-release.aab
```

Signing the release APK

Do NOT commit your keystore or passwords. The project supports signing from either:

- Gradle project properties (put values in `android/gradle.properties` or your `~/.gradle/gradle.properties`):

```
RELEASE_STORE_FILE=/absolute/path/to/release.keystore
RELEASE_STORE_PASSWORD=your_store_password
RELEASE_KEY_ALIAS=your_key_alias
RELEASE_KEY_PASSWORD=your_key_password
```

- OR environment variables (CI-friendly):

```
RELEASE_STORE_FILE  # path or place release.keystore at android/app/release.keystore
RELEASE_STORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
```

GitHub Actions

A workflow is present at `.github/workflows/android-build.yml`.

It will:

- Build web assets (detects `mobile/` build if available, otherwise copies `frontend/`).
- Run `npx cap sync android` and build `assembleRelease` and `bundleRelease`.
- Upload unsigned artifacts as workflow artifacts.
- Optionally sign the APK if you configure the following repository secrets:

  - `KEYSTORE_BASE64` (base64-encoded keystore file)
  - `KEYSTORE_PASSWORD`
  - `KEY_ALIAS`
  - `KEY_PASSWORD`

To prepare the keystore for the secret:

```bash
base64 -w0 release.keystore > release.keystore.base64
# paste the contents into the KEYSTORE_BASE64 secret in GitHub
```

Support

If you run into Gradle / SDK errors, open the `android/` directory in Android Studio to install missing SDK components, or run the sdkmanager commands described in the main README.
