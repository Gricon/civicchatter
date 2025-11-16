#!/bin/bash

# Build Android APK for Civic Chatter Flutter App
# This script builds the Android app WITHOUT affecting the web build

set -e  # Exit on error

echo "🤖 Building Civic Chatter Android App..."
echo "========================================"

# Navigate to flutter_app directory
cd "$(dirname "$0")"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Are you in the flutter_app directory?"
    exit 1
fi

# Clean previous builds (optional, uncomment if needed)
# echo "🧹 Cleaning previous builds..."
# flutter clean
# flutter pub get

# Build Android APK
echo "📦 Building Android APK (release mode)..."
flutter build apk --release

echo ""
echo "✅ Android build complete!"
echo ""
echo "📱 APK Location:"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📊 APK Size:"
ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print "   " $5}'
echo ""
echo "🚀 Install on device:"
echo "   flutter install"
echo "   OR"
echo "   adb install build/app/outputs/flutter-apk/app-release.apk"
echo ""
