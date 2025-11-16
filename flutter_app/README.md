# Civic Chatter Flutter App

A Flutter-based civic debate and profile coordination platform, converted from the original web application.

## 🎯 Overview

Civic Chatter is a mobile application that enables users to:
- Create and manage civic profiles
- Coordinate and participate in debates
- Connect with other civic-minded individuals
- Customize their app experience with themes and settings

## 📱 Features

### Implemented
- ✅ User authentication (sign up, sign in, logout)
- ✅ Profile management (public and private profiles)
- ✅ Avatar upload and management
- ✅ Theme customization (light, dark, system)
- ✅ Font size adjustment
- ✅ Responsive UI with Material Design 3
- ✅ Supabase backend integration

### Coming Soon
- 🔜 Full debate features (create, post, comment)
- 🔜 User search and discovery
- 🔜 Notifications
- 🔜 Cartoon filter for avatars
- 🔜 Password reset functionality

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- A Supabase account with the existing project

### Installation

1. **Clone the repository**
   ```bash
   cd /home/gricon/civicchatter/flutter_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter setup**
   ```bash
   flutter doctor
   ```

4. **Run the app**
   
   For Android:
   ```bash
   flutter run
   ```
   
   For iOS:
   ```bash
   flutter run -d ios
   ```
   
   For Web:
   ```bash
   flutter run -d chrome
   ```

### Configuration

The app is already configured with your Supabase credentials in:
```
lib/config/supabase_config.dart
```

**Supabase Setup Required:**
Ensure your Supabase project has the following tables:
- `profiles_public` - Public user profile information
- `profiles_private` - Private user information
- `debate_pages` - User debate pages
- Storage bucket named `avatars` for profile pictures

## 📁 Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   └── supabase_config.dart    # Supabase configuration
│   ├── providers/
│   │   ├── auth_provider.dart      # Authentication state management
│   │   └── theme_provider.dart     # Theme state management
│   ├── router/
│   │   └── app_router.dart         # Navigation routes
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── profile/
│   │   │   ├── private_profile_screen.dart
│   │   │   └── public_profile_screen.dart
│   │   ├── debates/
│   │   │   ├── debates_screen.dart
│   │   │   └── debate_detail_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   ├── services/
│   │   ├── profile_service.dart    # Profile CRUD operations
│   │   └── storage_service.dart    # File upload/download
│   └── widgets/
│       ├── custom_button.dart      # Reusable button widget
│       └── custom_text_field.dart  # Reusable input widget
├── pubspec.yaml                     # Dependencies
└── README.md                        # This file
```

## 🔧 Key Technologies

- **Flutter**: Cross-platform UI framework
- **Supabase**: Backend as a Service (authentication, database, storage)
- **Provider**: State management
- **GoRouter**: Navigation and routing
- **Material Design 3**: UI design system
- **Google Fonts**: Typography

## 📦 Dependencies

Main dependencies (from `pubspec.yaml`):
- `supabase_flutter: ^2.0.0` - Supabase client
- `provider: ^6.1.1` - State management
- `go_router: ^12.1.3` - Routing
- `image_picker: ^1.0.4` - Image selection
- `cached_network_image: ^3.3.0` - Image caching
- `shared_preferences: ^2.2.2` - Local storage
- `google_fonts: ^6.1.0` - Custom fonts

## 🎨 Design System

### Colors
- **Primary**: #002868 (US Flag Blue)
- **Secondary**: #BF0A30 (US Flag Red)
- **Background (Light)**: #F5F5F5
- **Background (Dark)**: #0b1220

### Typography
- Font family: Inter (via Google Fonts)
- Base font size: 16px (customizable in settings)

## 🔐 Authentication Flow

1. User lands on login screen
2. Can either:
   - Sign in with email/handle and password
   - Create a new account with full profile details
3. On successful auth, redirects to home screen
4. Auth state persists across app restarts

## 💾 Data Models

### Public Profile
- `id` - User ID (UUID)
- `handle` - Unique username
- `display_name` - Display name
- `bio` - User biography
- `city` - City location
- `avatar_url` - Profile picture URL
- `is_private` - Privacy flag
- `is_searchable` - Search visibility

### Private Profile
- `id` - User ID (UUID)
- `email` - Email address
- `phone` - Phone number (optional)
- `address` - Physical address (optional)
- `preferred_contact` - Contact preference

## 🚧 Migration Notes (Web → Flutter)

### What Changed
- **Framework**: HTML/CSS/JavaScript → Flutter/Dart
- **State Management**: Global variables → Provider pattern
- **Navigation**: Hash routing → GoRouter
- **Styling**: CSS → Material Design widgets
- **Forms**: HTML forms → Flutter Form widgets

### What Stayed the Same
- Supabase backend and database schema
- Authentication flow and logic
- Profile data structure
- Core features and functionality

### Known Differences
- Web app had inline cartoon filter (OpenCV.js)
  - Flutter version will use native image processing
- Web service worker caching → Flutter/Dart caching
- Web responsive CSS → Flutter adaptive layouts

## 🐛 Troubleshooting

### Common Issues

**1. Flutter not found**
```bash
# Ensure Flutter is in your PATH
export PATH="$PATH:`pwd`/flutter/bin"
```

**2. Supabase errors**
- Verify your Supabase URL and anon key in `supabase_config.dart`
- Check that database tables exist and have correct RLS policies

**3. Build errors**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

**4. Hot reload not working**
- Restart the app with `R` key or full restart with `Shift+R`

## 🏗️ Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### iOS (requires Mac)
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 📝 Development Workflow

1. **Start development server**
   ```bash
   flutter run
   ```

2. **Hot reload** - Press `r` in terminal
3. **Hot restart** - Press `R` in terminal
4. **Run tests**
   ```bash
   flutter test
   ```

## 🤝 Contributing

This is a conversion of the existing Civic Chatter web app. Follow these guidelines:
- Keep feature parity with the web version
- Maintain the existing color scheme and branding
- Use Material Design 3 guidelines
- Write clear, documented code
- Test on multiple devices

## 📄 License

[Same license as the original Civic Chatter project]

## 🔗 Related Files

- Original web app: `/home/gricon/civicchatter/frontend/`
- Backend API: `/home/gricon/civicchatter/backend/`
- Android build: `/home/gricon/civicchatter/android/`

## 📞 Support

For issues related to:
- **Flutter app**: Check this README and Flutter documentation
- **Backend/Supabase**: Check database schema in `/home/gricon/civicchatter/db/`
- **Original web app**: Check `/home/gricon/civicchatter/readme.md`

---

**Made with Flutter** 💙
