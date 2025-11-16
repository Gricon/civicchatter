#!/bin/bash

# Civic Chatter Flutter App - Quick Start Script

echo "🚀 Starting Civic Chatter Flutter App Setup..."
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Navigate to flutter_app directory
cd "$(dirname "$0")/flutter_app" || exit 1

echo "📦 Installing dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo ""
echo "✅ Dependencies installed successfully!"
echo ""

# Check for connected devices
echo "🔍 Checking for connected devices..."
flutter devices

echo ""
echo "✨ Setup complete!"
echo ""
echo "📱 To run the app:"
echo "   cd flutter_app"
echo "   flutter run"
echo ""
echo "🏗️  To build for production:"
echo "   Android APK:     flutter build apk --release"
echo "   Android Bundle:  flutter build appbundle --release"
echo "   iOS:            flutter build ios --release"
echo ""
echo "📚 See flutter_app/README.md for more details"
