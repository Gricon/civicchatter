# Flutter App - Android-specific configuration

This directory would contain Android-specific configuration for the Flutter app.

## Integration Options

### Option 1: New Flutter Android Build
The Flutter app will generate its own Android build in:
```
flutter_app/android/
```

### Option 2: Use Existing Android Directory
You can integrate with the existing `/android` directory if needed, though Flutter typically manages its own Android project.

## Current Android Setup
The existing `/android` directory contains a Capacitor-based Android build for the web app. This is separate from the Flutter Android build.

### Two Android Builds:
1. **Web app (Capacitor)**: `/android/` - Wraps the web app
2. **Flutter app**: `/flutter_app/android/` - Native Flutter

## Recommended Approach
Use the Flutter-generated Android project for the best native experience and performance.
