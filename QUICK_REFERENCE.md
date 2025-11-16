# 🚀 Quick Reference - Civic Chatter Flutter

## ⚡ Quick Start (Copy & Paste)

```bash
cd /home/gricon/civicchatter/flutter_app
flutter pub get
flutter run
```

## 📱 Common Commands

### Development
```bash
flutter run                    # Run app
flutter run -d android        # Run on Android
flutter run -d ios            # Run on iOS
flutter run -d chrome         # Run in browser

# While running:
r                             # Hot reload
R                             # Hot restart
q                             # Quit
```

### Building
```bash
flutter build apk             # Debug APK
flutter build apk --release   # Release APK
flutter build appbundle       # Play Store bundle
flutter build ios --release   # iOS build
```

### Maintenance
```bash
flutter clean                 # Clean build
flutter pub get               # Get dependencies
flutter pub upgrade           # Update dependencies
flutter doctor                # Check setup
flutter devices               # List devices
```

## 🗂️ Project Structure (Quick Reference)

```
flutter_app/lib/
├── main.dart                          # Start here
├── config/supabase_config.dart        # Backend settings
├── providers/
│   ├── auth_provider.dart             # Login/signup logic
│   └── theme_provider.dart            # Theme settings
├── services/
│   ├── profile_service.dart           # Profile API
│   └── storage_service.dart           # File uploads
└── screens/
    ├── auth/                          # Login & signup
    ├── home/                          # Dashboard
    ├── profile/                       # Profile pages
    ├── debates/                       # Debates (todo)
    └── settings/                      # Settings
```

## 🔑 Key Files to Know

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/config/supabase_config.dart` | Supabase credentials |
| `lib/providers/auth_provider.dart` | Authentication logic |
| `lib/router/app_router.dart` | Navigation routes |
| `pubspec.yaml` | Dependencies |

## 🎯 Common Tasks

### Change Supabase Credentials
Edit: `lib/config/supabase_config.dart`

### Add a New Screen
1. Create file in `lib/screens/`
2. Add route in `lib/router/app_router.dart`
3. Navigate with `context.go('/route')`

### Add New Dependency
1. Edit `pubspec.yaml`
2. Run `flutter pub get`

### Change Theme Colors
Edit: `lib/providers/theme_provider.dart`

### Debug Errors
```bash
flutter run --verbose
flutter analyze
flutter doctor
```

## 🐛 Quick Fixes

### "Flutter not found"
```bash
export PATH="$PATH:$HOME/flutter/bin"
```

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

### Hot reload not working
Press `R` (capital) for full restart

### Supabase errors
Check `lib/config/supabase_config.dart`

## 📊 App Stats

- **Screens**: 10+
- **Total Files**: 30+
- **Lines of Code**: ~2,500+
- **Dependencies**: 11 packages
- **Platforms**: Android, iOS, Web

## 🎨 Color Scheme

```dart
Primary:    Color(0xFF002868)  // US Flag Blue
Secondary:  Color(0xFFBF0A30)  // US Flag Red
Background: Color(0xFFF5F5F5)  // Light
Dark BG:    Color(0xFF0b1220)  // Dark
```

## 📚 Key Dependencies

```yaml
supabase_flutter: ^2.0.0      # Backend
provider: ^6.1.1               # State
go_router: ^12.1.3             # Routing
image_picker: ^1.0.4           # Images
google_fonts: ^6.1.0           # Fonts
```

## 🔗 Routes

```dart
/login              → Login screen
/signup             → Signup screen
/home               → Dashboard
/profile            → Edit profile
/u/:handle          → Public profile
/debates            → Debates list
/debates/:id        → Debate detail
/settings           → Settings
```

## 💾 State Management

```dart
// Get auth state
final auth = context.read<AuthProvider>();
final user = auth.user;

// Get theme
final theme = context.read<ThemeProvider>();
theme.setThemeMode(ThemeMode.dark);

// Watch for changes
final auth = context.watch<AuthProvider>();
```

## 🔐 Supabase

```dart
// Already configured!
URL: https://uoehxenaabrmuqzhxjdi.supabase.co
Key: (in supabase_config.dart)

// Tables:
- profiles_public
- profiles_private
- debate_pages
```

## 📱 Emulator Commands

```bash
# Android
flutter emulators
flutter emulators --launch <emulator_id>

# iOS (Mac only)
open -a Simulator

# List devices
flutter devices
```

## 🎓 Documentation

- `flutter_app/README.md` - Full guide
- `FLUTTER_MIGRATION.md` - Conversion details
- `FLUTTER_COMPLETE.md` - Summary

## ⚠️ Important Notes

1. **Supabase**: Same backend as web app
2. **Android**: Separate from `/android` (Capacitor)
3. **Debates**: Placeholder screens only
4. **Hot Reload**: Save file to trigger (in most IDEs)
5. **Production**: Use `--release` flag for builds

## 🆘 Get Help

```bash
flutter doctor -v              # Detailed diagnostics
flutter pub deps               # Show dependencies
flutter analyze                # Check for issues
```

## ✨ Pro Tips

1. Use `context.go()` not `Navigator.push()`
2. Wrap providers with `Consumer` or `context.watch()`
3. Always `await` Supabase calls
4. Use `const` constructors when possible
5. Hot reload with `r`, hot restart with `R`

---

**Ready to code!** 🚀

```bash
cd flutter_app && flutter run
```
