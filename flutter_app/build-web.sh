#!/bin/bash

# Build Web version for Civic Chatter Flutter App
# This script builds the web app and deploys to frontend/

set -e  # Exit on error

echo "🌐 Building Civic Chatter Web App..."
echo "===================================="

# Navigate to flutter_app directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Are you in the flutter_app directory?"
    exit 1
fi

# Build web app
echo "📦 Building web app (release mode)..."
flutter build web --release

echo ""
echo "✅ Web build complete!"
echo ""

# Copy to frontend directory
FRONTEND_DIR="../frontend"
if [ -d "$FRONTEND_DIR" ]; then
    echo "📂 Deploying to $FRONTEND_DIR..."
    cp -r build/web/* "$FRONTEND_DIR/"
    echo "✅ Deployed to frontend/"
else
    echo "⚠️  Warning: $FRONTEND_DIR not found. Skipping deployment."
fi

echo ""
echo "🌐 Web build output:"
echo "   flutter_app/build/web/"
echo ""
echo "🚀 Test locally:"
echo "   cd build/web && python3 -m http.server 8000"
echo "   Then visit: http://localhost:8000"
echo ""
