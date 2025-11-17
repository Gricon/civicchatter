# Civic Chatter - Complete Project Directory

## 📁 Project Overview
Civic Chatter is a social media platform built with Flutter for the frontend and Supabase (PostgreSQL) for the backend. The app supports web deployment via Netlify with plans for Android/iOS mobile apps.

---

## 🗂️ Root Directory Structure

### `/android/` - Android Build Configuration
Android-specific build files and configuration for the mobile app.
- **`build.gradle`** - Android project-level Gradle configuration
- **`settings.gradle`** - Gradle settings for Android modules
- **`gradle.properties`** - Android build properties and SDK settings
- **`local.properties`** - Local machine paths (not committed to git)
- **`app/`** - Main Android application module
  - **`build.gradle`** - App-level Gradle build configuration
  - **`proguard-rules.pro`** - Code obfuscation rules for release builds
  - **`release.keystore`** - Keystore file for signing Android releases
  - **`src/`** - Android source code and resources

### `/backend/` - Python Backend Services
Optional backend services (currently minimal, most logic is in Supabase).
- **`main.py`** - Python backend entry point (for future API extensions)
- **`requirements.txt`** - Python dependencies

### `/db/` - Database Migrations & Setup
SQL migration files for setting up and modifying the Supabase PostgreSQL database.
- **`add_custom_reactions.sql`** - Adds custom emoji support to reactions table
- **`add_is_private_to_posts.sql`** - Adds privacy field to posts
- **`add_site_settings_column.sql`** - Site settings column migration
- **`allow_multiple_reactions.sql`** - Enables up to 2 reactions per post per user
- **`backfill_profiles.sql`** - Populates profiles for existing users
- **`create_auth_trigger.sql`** - Auto-creates profiles when users sign up
- **`create_comments_table.sql`** - Creates comments table with relationships
- **`create_posts_table.sql`** - Creates main posts table
- **`create_reactions_table.sql`** - Creates reactions table (6 standard emojis)
- **`create_reports_table.sql`** - Creates post reporting system
- **`create_trigger_error_table.sql`** - Error logging table
- **`fix_posts_profiles_relationship.sql`** - Fixes foreign key relationships
- **`posts_rls_policies.sql`** - Row Level Security policies for posts
- **`rls_policies.sql`** - General RLS policies for authentication
- **`README.md`** - Database setup documentation
- **`SETUP_INSTRUCTIONS.md`** - Detailed database setup guide

### `/flutter_app/` - Main Flutter Application
The complete Flutter application source code.

#### `/flutter_app/lib/` - Flutter Application Code

##### `/lib/config/` - App Configuration
- **`supabase_config.dart`** - Supabase connection settings (URL, anon key)

##### `/lib/providers/` - State Management
- **`auth_provider.dart`** - Authentication state management (login, logout, session)
- **`theme_provider.dart`** - Theme management (dark mode toggle)

##### `/lib/router/` - Navigation
- **`app_router.dart`** - GoRouter configuration for navigation
  - Routes: `/`, `/login`, `/register`, `/home`, `/debates`, `/profile`, `/settings`, `/post/:id`
  - Auth guards and redirects

##### `/lib/screens/` - UI Screens

###### `/lib/screens/auth/` - Authentication Screens
- **`login_screen.dart`** - User login with email/password
- **`register_screen.dart`** - New user registration

###### `/lib/screens/debates/` - Debates Feature
- **`debates_screen.dart`** - Debate pages listing and management

###### `/lib/screens/home/` - Main Feed
- **`home_screen.dart`** - Main application screen with:
  - Post creation (rich text editor with Quill)
  - Post feed (newest/oldest/popular sorting)
  - Filter options (all/public/private)
  - Reaction system (up to 2 reactions per post)
  - Comment viewing
  - Post menu (share, copy link, report, edit, delete)
  - Privacy toggle (public/private posts)
  - Custom background support

###### `/lib/screens/posts/` - Post Details
- **`post_detail_screen.dart`** - Individual post view with:
  - Full post content
  - Comments section with nested replies
  - Reaction system
  - Share functionality
  - Same menu actions as home feed

###### `/lib/screens/profile/` - User Profile
- **`profile_screen.dart`** - User profile display with:
  - Avatar upload/display
  - Display name and handle
  - Bio editing
  - User's posts
  - Profile privacy settings

###### `/lib/screens/settings/` - App Settings
- **`settings_screen.dart`** - Main settings hub
- **`background_settings_screen.dart`** - Background customization:
  - Solid color picker
  - Gradient designer (2-color gradients)
  - Image upload (converts to base64)
  - Preview of selected background

##### `/lib/services/` - Business Logic Services
- **`supabase_service.dart`** - Supabase API wrapper functions:
  - User authentication
  - CRUD operations for posts, comments, reactions
  - Profile management
  - File storage operations

##### `/lib/utils/` - Utility Functions
- **`validators.dart`** - Form validation functions (email, password)
- **`constants.dart`** - App-wide constants
- **`helpers.dart`** - General helper functions

##### `/lib/widgets/` - Reusable UI Components
- **`civic_chatter_app_bar.dart`** - Custom app bar with:
  - App title
  - Navigation tabs (Home, Debates, Profile, Settings)
  - Dark mode toggle
  - Logout button
- **`custom_background.dart`** - Background widget with:
  - Static caching to prevent white flash on navigation
  - Support for solid colors, gradients, and images
  - Reads settings from SharedPreferences

##### `/lib/main.dart` - App Entry Point
- Initializes Supabase
- Sets up SharedPreferences
- Configures GoRouter
- Wraps app in Providers (AuthProvider, ThemeProvider)
- Applies CustomBackground globally

#### `/flutter_app/android/` - Flutter Android Config
Android-specific Flutter configuration (separate from root `/android/`)

#### `/flutter_app/build/` - Build Output
Generated files from `flutter build` commands. Not committed to git.
- **`web/`** - Compiled web application (deployed to `/frontend/`)

#### `/flutter_app/test/` - Unit Tests
Flutter unit and widget tests (currently minimal).

#### `/flutter_app/web/` - Web Configuration
- **`index.html`** - Web app entry point
- **`manifest.json`** - PWA manifest
- **`favicon.png`** - App icon
- **`icons/`** - Various icon sizes for PWA

#### Flutter Configuration Files
- **`pubspec.yaml`** - Flutter dependencies and asset configuration:
  - `supabase_flutter` - Backend integration
  - `go_router` - Navigation
  - `provider` - State management
  - `flutter_quill` - Rich text editor
  - `image_picker` - Image selection
  - `share_plus` - Native sharing
  - `cached_network_image` - Efficient image loading
  - `intl` - Date/time formatting
  - `shared_preferences` - Local storage
- **`analysis_options.yaml`** - Dart linter configuration
- **`civic_chatter.iml`** - IntelliJ project file

### `/frontend/` - Deployed Web Application
Compiled Flutter web app files deployed to Netlify.
- **`index.html`** - Web app entry point (copied from `flutter_app/build/web/`)
- **`main.dart.js`** - Compiled Dart code
- **`flutter.js`** - Flutter web engine
- **`flutter_service_worker.js`** - Service worker for PWA
- **`manifest.json`** - PWA manifest
- **`version.json`** - Build version info
- **`assets/`** - App assets (fonts, images)
- **`canvaskit/`** - CanvasKit rendering engine
- **`icons/`** - App icons

### `/frontend.old/` - Legacy Frontend (Archived)
Original vanilla JavaScript frontend before Flutter migration.
- **`index.html`** - Old home page
- **`app.js`** - Old JavaScript app logic
- **`styles.css`** - Old CSS styles
- **`auth-callback.html/js`** - Old auth flow
- **`reset-password.html/js`** - Old password reset
- **`netlify.toml`** - Old Netlify configuration

### `/mobile/` - Capacitor Mobile Configuration
Capacitor setup for converting web app to native mobile apps.
- **`capacitor.config.ts`** - Capacitor configuration
- **`package.json`** - Capacitor dependencies

### `/scripts/` - Build & Deployment Scripts
- **`build-android.sh`** - Android APK build script
- **`create_bucket.mjs`** - Supabase storage bucket creation script

### `/serverless/` - Serverless Function Examples
- **`replicate_cartoonize_example.md`** - Example of using Replicate API for image processing

---

## 🗄️ Database Schema (Supabase PostgreSQL)

### Tables

#### `profiles_public`
Public user profile information.
- `id` (UUID, FK to auth.users) - User ID
- `handle` (TEXT, unique) - Username/handle
- `display_name` (TEXT) - Display name
- `avatar_url` (TEXT) - Profile picture URL
- `bio` (TEXT) - User biography
- `created_at` (TIMESTAMPTZ) - Account creation date

#### `profiles_private`
Private user settings and data.
- `id` (UUID, FK to auth.users) - User ID
- `email` (TEXT) - User email
- `settings` (JSONB) - User settings object
- `created_at` (TIMESTAMPTZ)

#### `posts`
User-generated posts/content.
- `id` (UUID, PK) - Post ID
- `user_id` (UUID, FK to auth.users) - Post author
- `content` (TEXT) - Post text content
- `media_type` (TEXT) - Type of media attachment
- `media_url` (TEXT) - Media attachment URL
- `is_private` (BOOLEAN) - Privacy setting (public/private)
- `created_at` (TIMESTAMPTZ) - Post creation time
- `updated_at` (TIMESTAMPTZ) - Last edit time

#### `comments`
Comments on posts.
- `id` (UUID, PK) - Comment ID
- `post_id` (UUID, FK to posts) - Parent post
- `user_id` (UUID, FK to auth.users) - Comment author
- `content` (TEXT) - Comment text
- `created_at` (TIMESTAMPTZ) - Comment time

#### `reactions`
Emoji reactions to posts (up to 2 per user per post).
- `id` (UUID, PK) - Reaction ID
- `post_id` (UUID, FK to posts) - Target post
- `user_id` (UUID, FK to auth.users) - User who reacted
- `reaction_type` (TEXT) - Standard reaction: 'like', 'love', 'laugh', 'wow', 'sad', 'angry', or 'custom'
- `custom_emoji` (TEXT, nullable) - Custom emoji if reaction_type='custom'
- `created_at` (TIMESTAMPTZ) - Reaction time
- **Unique constraint**: `(post_id, user_id, reaction_type, custom_emoji)` - Prevents duplicate reactions
- **Check constraint**: Enforces either standard reaction or custom emoji with 'custom' type
- **Trigger**: Limits users to max 2 reactions per post

#### `reports`
Content moderation reports.
- `id` (UUID, PK) - Report ID
- `post_id` (UUID, FK to posts) - Reported post
- `user_id` (UUID, FK to auth.users) - Reporter
- `reason` (TEXT) - Report reason: 'spam', 'harassment', 'misinformation', 'other'
- `status` (TEXT) - Processing status: 'pending', 'reviewed', 'resolved', 'dismissed'
- `created_at` (TIMESTAMPTZ) - Report time

#### `debate_pages`
Structured debate pages.
- Schema TBD (feature in development)

### Row Level Security (RLS) Policies

#### Posts
- **SELECT**: Users can view public posts, or private posts they authored
- **INSERT**: Authenticated users can create posts
- **UPDATE**: Users can only update their own posts
- **DELETE**: Users can only delete their own posts

#### Comments
- **SELECT**: Anyone can read comments on visible posts
- **INSERT**: Authenticated users can comment
- **UPDATE/DELETE**: Users can only modify their own comments

#### Reactions
- **SELECT**: Anyone can view reactions
- **INSERT**: Authenticated users can add reactions
- **DELETE**: Users can only delete their own reactions

#### Reports
- **SELECT**: Users can view their own reports (admins see all via separate policy)
- **INSERT**: Authenticated users can create reports

#### Profiles
- **SELECT**: Everyone can read public profiles
- **UPDATE**: Users can only update their own profile

---

## 🔧 Configuration Files (Root Level)

### `capacitor.config.json`
Capacitor configuration for mobile app generation.
- App ID, name, web directory mapping

### `package.json`
Node.js dependencies for build tools and scripts.

### Deployment Scripts
- **`deploy-web.sh`** - Web deployment automation script
- **`flutter-run.sh`** - Flutter development server script
- **`setup_flutter.sh`** - Flutter environment setup
- **`compare_structures.sh`** - Utility to compare file structures

---

## 📚 Documentation Files

### Root Documentation
- **`README.md`** - Main project README with setup instructions
- **`START_HERE.md`** - Quick start guide for new developers
- **`DOC_INDEX.md`** - Index of all documentation files
- **`QUICK_REFERENCE.md`** - Quick reference for common tasks

### Technical Documentation
- **`ANDROID_BUILD.md`** - Android build process and troubleshooting
- **`BUILD_GUIDE.md`** - General build instructions
- **`FLUTTER_COMPLETE.md`** - Complete Flutter migration documentation
- **`FLUTTER_MIGRATION.md`** - Migration guide from vanilla JS to Flutter
- **`CONVERSION_SUMMARY.md`** - Summary of frontend conversion
- **`RESPONSIVE_UPDATE.md`** - Responsive design implementation notes
- **`VISUAL_SUMMARY.txt`** - Visual structure of the application

### Flutter-Specific Docs
- **`flutter_app/ANDROID_NOTES.md`** - Android-specific notes
- **`flutter_app/WEB_DEPLOYMENT.md`** - Web deployment guide
- **`flutter_app/README.md`** - Flutter app overview

---

## 🚀 Deployment & Build Process

### Web Deployment (Netlify)
1. Run `flutter build web --release` in `/flutter_app/`
2. Copy built files from `/flutter_app/build/web/` to `/frontend/`
3. Commit and push to GitHub
4. Netlify automatically deploys from `main` branch
5. Live at: `https://civicchatter.netlify.app`

### Android Build
1. Configure signing with `release.keystore`
2. Run `flutter build apk --release`
3. APK generated in `/flutter_app/build/app/outputs/flutter-apk/`

### Database Updates
1. Write SQL migration in `/db/`
2. Run migration in Supabase SQL Editor
3. Test RLS policies
4. Document in database README

---

## 🎨 Key Features

### Authentication
- Email/password signup and login
- Supabase Auth integration
- Session management
- Password reset flow

### Post Management
- Rich text post creation (Quill editor)
- Public/private post visibility
- Edit and delete your own posts
- Timestamp display in 24-hour format with timezone

### Social Features
- Up to 2 reactions per post (6 standard emojis + custom)
- Comments with nested display
- Share posts via native share dialog
- Copy post links to clipboard
- Report inappropriate content

### Customization
- Dark mode toggle
- Custom backgrounds:
  - Solid colors
  - 2-color gradients
  - Uploaded images
- Profile customization (avatar, bio, display name)

### Content Discovery
- Sort posts: Newest, Oldest, Popular
- Filter posts: All, Public, Private
- Post detail pages with full comments

---

## 🔐 Environment Variables & Secrets

### Supabase Configuration (in `lib/config/supabase_config.dart`)
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Public anonymous key

### Android Signing (in `android/app/build.gradle`)
- Keystore password
- Key alias and password

**Note**: Sensitive values should be in `.env` files (not committed to git)

---

## 📦 Dependencies

### Flutter Packages (from `pubspec.yaml`)
- **supabase_flutter**: ^2.0.0 - Supabase client
- **go_router**: ^12.1.3 - Declarative routing
- **provider**: ^6.1.1 - State management
- **flutter_quill**: ^11.5.0 - Rich text editor
- **image_picker**: ^1.0.5 - Image selection
- **share_plus**: ^10.1.2 - Native sharing
- **cached_network_image**: ^3.3.0 - Image caching
- **intl**: ^0.20.2 - Internationalization/date formatting
- **shared_preferences**: ^2.2.2 - Local key-value storage
- **url_launcher**: ^6.2.1 - Launch URLs

---

## 🧪 Testing

### Unit Tests
Located in `/flutter_app/test/`
- Currently minimal, needs expansion

### Manual Testing Checklist
1. Auth flow (signup, login, logout)
2. Post CRUD operations
3. Reaction system (standard + custom)
4. Comment system
5. Share and copy link
6. Report functionality
7. Edit/delete posts
8. Background customization
9. Profile editing
10. Dark mode toggle

---

## 🐛 Known Issues & Future Enhancements

### Current Limitations
- No real-time updates (requires page refresh)
- Report moderation requires manual database access
- No admin dashboard
- Limited search functionality
- No notifications system

### Planned Features
- Real-time post/comment updates via Supabase Realtime
- Admin moderation panel
- User mentions (@username)
- Hashtags and trending topics
- Search and discovery
- Push notifications (mobile)
- Direct messaging
- Post drafts
- Media attachments (images, videos)

---

## 📞 Support & Resources

### Documentation Locations
- Database setup: `/db/README.md`
- Flutter migration: `/FLUTTER_MIGRATION.md`
- Quick reference: `/QUICK_REFERENCE.md`
- Start guide: `/START_HERE.md`

### External Resources
- Flutter: https://flutter.dev/docs
- Supabase: https://supabase.com/docs
- GoRouter: https://pub.dev/packages/go_router
- Flutter Quill: https://pub.dev/packages/flutter_quill

---

## 🏗️ Architecture Summary

```
┌─────────────────────────────────────────────────┐
│              User Interface (Flutter)           │
│  ┌────────┐  ┌────────┐  ┌────────┐           │
│  │ Screens│  │Widgets │  │Providers│           │
│  └────────┘  └────────┘  └────────┘           │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│           Services Layer (Dart)                 │
│  ┌──────────────┐  ┌──────────────┐           │
│  │Supabase      │  │Local Storage │           │
│  │Service       │  │(SharedPrefs) │           │
│  └──────────────┘  └──────────────┘           │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│        Backend (Supabase PostgreSQL)            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │Auth      │  │Database  │  │Storage   │     │
│  │(GoTrue)  │  │(Postgres)│  │(S3)      │     │
│  └──────────┘  └──────────┘  └──────────┘     │
│                                                  │
│  Row Level Security (RLS) enforces permissions  │
└─────────────────────────────────────────────────┘
```

---

**Last Updated**: November 17, 2025  
**Project Version**: 1.0.0  
**Flutter Version**: 3.x  
**Dart SDK**: >=3.0.0
