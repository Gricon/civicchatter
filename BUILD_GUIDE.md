# 📱 Civic Chatter - Build Guide

## Quick Commands

### For Android App 📱
```bash
cd flutter_app
./build-android.sh
```
**Output:** `build/app/outputs/flutter-apk/app-release.apk`
**Does NOT affect web build!**

### For Web App 🌐
```bash
cd flutter_app
./build-web.sh
```
**Output:** `build/web/` (also copies to `../frontend/`)
**Does NOT affect Android build!**

### Deploy to Production 🚀
```bash
./deploy-web.sh "Your commit message"
```
**This builds web, copies to frontend/, commits, and pushes to Git**

---

## Detailed Guide

### Android Development

#### Build APK
```bash
cd flutter_app
./build-android.sh
```

#### Install on Device
```bash
# Connect your Android device via USB
flutter install

# OR use adb directly
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### Run in Development
```bash
cd flutter_app
flutter run
```

### Web Development

#### Build for Production
```bash
cd flutter_app
./build-web.sh
```

#### Test Locally
```bash
cd flutter_app/build/web
python3 -m http.server 8000
# Visit: http://localhost:8000
```

#### Deploy to Production
```bash
# From project root
./deploy-web.sh "Your custom commit message"
```

---

## Responsive Design ✨

The app now features responsive layouts:

### Mobile (< 500px width)
- Dropdown and Submit button stack vertically
- Full-width layout
- Optimized for touch
- Comfortable padding

### Tablet/Desktop (> 500px width)
- Dropdown and Submit button in a row
- Content constrained to 800px max width
- Centered layout
- More breathing room

### Large Screens (> 900px)
- Same as tablet but with extra horizontal padding
- Perfect for web browsers

---

## File Structure

```
civicchatter/
├── flutter_app/
│   ├── build-android.sh       # Build Android APK
│   ├── build-web.sh           # Build web app
│   ├── lib/
│   │   └── screens/
│   │       └── home/
│   │           ├── home_screen.dart      # Responsive layout
│   │           └── home_screen_old.dart  # Backup
│   └── build/
│       ├── app/               # Android builds
│       └── web/               # Web builds
├── frontend/                  # Web deployment target
└── deploy-web.sh             # Build & deploy script
```

---

## Key Features

### Separate Builds
- ✅ Android and web builds are independent
- ✅ Building Android doesn't touch web files
- ✅ Building web doesn't affect Android
- ✅ Both can coexist in the same project

### Responsive UI
- ✅ Adapts to screen size automatically
- ✅ Mobile-first design
- ✅ Works great on all devices
- ✅ Same codebase for all platforms

### Easy Deployment
- ✅ One command to build and deploy web
- ✅ Separate command for Android builds
- ✅ No conflicts between platforms

---

## Tips 💡

### For Android Development
1. Keep Android Studio updated
2. Test on real devices when possible
3. Use `flutter run --release` for performance testing
4. Android builds go to `build/app/` directory

### For Web Development
1. Always build with `--release` for production
2. Web builds go to `build/web/` directory
3. Frontend folder is for Git deployment
4. Test on multiple browsers

### Best Practices
- ✅ Build Android locally, don't commit APK files
- ✅ Build web and commit to deploy
- ✅ Use descriptive commit messages
- ✅ Test responsive layout at different screen sizes

---

## Troubleshooting

### "flutter not found"
```bash
export PATH="$PATH:`pwd`/flutter/bin"
```

### "pubspec.yaml not found"
Make sure you're in the `flutter_app` directory before running build scripts.

### Web build takes a long time
This is normal. Web builds compile Dart to JavaScript and optimize assets.

### Android build fails
```bash
cd flutter_app
flutter clean
flutter pub get
./build-android.sh
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Build Android | `cd flutter_app && ./build-android.sh` |
| Build Web | `cd flutter_app && ./build-web.sh` |
| Deploy Web | `./deploy-web.sh "message"` |
| Run Dev | `cd flutter_app && flutter run` |
| Clean | `cd flutter_app && flutter clean` |

---

**Happy Building!** 🎉📱🌐
