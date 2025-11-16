#!/bin/bash

# Deploy Web to Production (Git Push)
# This builds the web app, copies to frontend/, and pushes to Git

set -e  # Exit on error

echo "🚀 Deploying Civic Chatter to Production..."
echo "==========================================="

# Navigate to project root (where the script is located)
cd "$(dirname "$0")"

# Build web app
echo "📦 Building web app..."
cd flutter_app
flutter build web --release

# Copy to frontend
echo "📂 Copying to frontend/..."
cp -r build/web/* ../frontend/

# Git commit and push
cd ..
echo "📤 Pushing to Git..."
git add -A

# Get commit message from argument or use default
COMMIT_MSG="${1:-Update Civic Chatter web app}"

git commit -m "$COMMIT_MSG"
git push

echo ""
echo "✅ Deployment complete!"
echo "🌐 Your changes are live!"
echo ""
