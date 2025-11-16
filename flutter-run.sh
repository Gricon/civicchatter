#!/bin/bash
# Wrapper script to run Flutter commands from the civicchatter root directory.
# Usage: ./flutter-run.sh [flutter args...]
# Example: ./flutter-run.sh run -d chrome
#          ./flutter-run.sh build web

cd "$(dirname "$0")/flutter_app" || exit 1
flutter "$@"
