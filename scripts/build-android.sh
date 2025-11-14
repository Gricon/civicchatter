#!/usr/bin/env bash
set -euo pipefail

# Simple helper to build an Android debug APK from this repo.
# Usage: ./scripts/build-android.sh [debug|release]
# Defaults to debug.

MODE=${1:-debug}
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ANDROID_DIR="$ROOT_DIR/android"

echo "Project root: $ROOT_DIR"

echo "1) Copy static frontend -> Capacitor Android assets"
rm -rf "$ANDROID_DIR/app/src/main/assets/public"
mkdir -p "$ANDROID_DIR/app/src/main/assets/public"
cp -r "$ROOT_DIR/frontend"/* "$ANDROID_DIR/app/src/main/assets/public/" || true

echo "2) Sync Capacitor (ensure native project is up-to-date)"
npx cap sync android

cd "$ANDROID_DIR"

if [ "$MODE" = "debug" ]; then
  echo "3) Building debug APK"
  ./gradlew assembleDebug
  echo "Debug APK: $ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
else
  echo "3) Building release APK and AAB (unsigned by default)"
  ./gradlew assembleRelease bundleRelease
  echo "Unsigned release APK: $ANDROID_DIR/app/build/outputs/apk/release/app-release-unsigned.apk"
  echo "AAB: $ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
fi

echo "Done."
