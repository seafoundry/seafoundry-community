# Android Deployment Guide

This guide covers building, signing, and deploying the SeaFoundry Android app to the Google Play Store.

## Prerequisites

### Google Play Developer Account
- **Cost**: $25 one-time registration fee
- **URL**: https://play.google.com/console
- **Application ID**: `com.example.seafoundry_app` (see [App ID Migration](#app-id-migration) to change)

### Development Environment
- Android Studio (for debugging and keystore management)
- JDK 11+ (for `keytool`)
- Flutter SDK (current version from `flutter --version`)

### Firebase Configuration
- `android/app/google-services.json` must match the `applicationId` in `build.gradle.kts`
- Currently registered as `com.example.seafoundry_app` in Firebase Console
- If you change the app ID, you must also update the Firebase Android app registration

## Release Signing Setup

### 1. Generate a Release Keystore

```bash
keytool -genkey -v \
  -keystore seafoundry-release.keystore \
  -alias seafoundry \
  -keyalg RSA -keysize 2048 -validity 10000
```

You will be prompted for:
- Keystore password
- Key password
- Name, organization, location info

**Store the keystore and passwords securely.** Losing the keystore means you cannot update the app on Google Play. Use a team vault (1Password, etc.).

### 2. Create key.properties

Copy the template and fill in your values:

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:
```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=seafoundry
storeFile=/absolute/path/to/seafoundry-release.keystore
```

This file is gitignored. Never commit it.

### 3. Verify Signing Configuration

The `android/app/build.gradle.kts` is already configured to:
- Read `key.properties` if it exists
- Use the release signing config for release builds
- Fall back to debug signing if `key.properties` is absent (for development)
- Enable R8 minification and resource shrinking for release builds

No changes to `build.gradle.kts` are needed.

## Build Process

### 1. Update Version

Edit `pubspec.yaml`:
```yaml
version: 1.4.0+57  # major.minor.patch+buildNumber
```

The build number (`+57`) becomes Android's `versionCode`. It must increment for every Play Store upload.

### 2. Clean Build

```bash
flutter clean
flutter pub get
```

### 3. Build Release App Bundle (AAB)

Google Play requires AAB format (not APK):

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 4. Build APK (for direct distribution or testing)

```bash
# Fat APK (all architectures)
flutter build apk --release

# Split per ABI (smaller downloads)
flutter build apk --release --split-per-abi
```

Output: `build/app/outputs/flutter-apk/`

### 5. Test the Release Build

```bash
# Install release APK on connected device
flutter install --release

# Or install specific APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Google Play Console Setup

### 1. Create App Listing

1. Go to https://play.google.com/console
2. Click "Create app"
3. Fill in:
   - **App name**: SeaFoundry
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free (or Paid)
4. Accept declarations and create

### 2. Store Listing Metadata

Required before first release:

- **Short description** (80 chars max): Marine aquaculture platform for genetics, inventory, and monitoring
- **Full description** (4000 chars max): Detailed app description
- **Screenshots**: Phone (min 2), 7-inch tablet, 10-inch tablet
- **Feature graphic**: 1024x500 px
- **App icon**: 512x512 px (high-res)
- **Privacy policy URL**: Required for apps that collect user data
- **Category**: Tools or Productivity

### 3. Content Rating

Complete the content rating questionnaire in Play Console > Policy > App Content.

### 4. Data Safety

Declare data collection practices (parallel to iOS privacy questions):

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Email | Yes | No | Account management |
| Name | Yes | No | User profile |
| Location | Yes | No | Site mapping |
| Photos | Yes | No | Specimen documentation |

### 5. App Signing

Google Play manages app signing by default (App Signing by Google Play):
- You upload with your **upload key** (the keystore you created)
- Google re-signs with their **app signing key** for distribution
- This is the recommended approach

## Upload and Release

### Internal Testing (Recommended First)

1. Play Console > Testing > Internal testing
2. Create a new release
3. Upload `app-release.aab`
4. Add release notes
5. Add internal testers (by email)
6. Roll out to internal testing

Internal testers get access immediately (no review).

### Closed Testing (Beta)

1. Play Console > Testing > Closed testing
2. Create a track or use default
3. Upload AAB
4. Add tester groups
5. Submit for review (required for first release)

### Production Release

1. Play Console > Production
2. Create new release
3. Upload AAB (or promote from testing track)
4. Add release notes
5. Submit for review

**First review**: 1-7 days. Subsequent reviews: 1-3 days typically.

## App ID Migration

The current app ID is `com.example.seafoundry_app` — a placeholder from project creation. Before publishing to Play Store, you should change it to a proper ID (e.g., `com.seafoundry.mobile` to match iOS).

**This requires coordinated changes:**

1. **Firebase Console**: Register a new Android app with the new package name, download updated `google-services.json`
2. **build.gradle.kts**: Update `namespace` and `applicationId`
3. **AndroidManifest.xml**: No changes needed (namespace comes from gradle)
4. **MainActivity.kt**: Update `package` declaration and move file to matching directory structure
5. **google-services.json**: Replace with new one from Firebase Console

```bash
# Example: migrate from com.example.seafoundry_app to com.seafoundry.mobile
# 1. Update build.gradle.kts
#    namespace = "com.seafoundry.mobile"
#    applicationId = "com.seafoundry.mobile"
#
# 2. Move and update MainActivity.kt
#    mkdir -p android/app/src/main/kotlin/com/seafoundry/mobile
#    mv android/app/src/main/kotlin/com/example/sea_foundry_app/MainActivity.kt \
#       android/app/src/main/kotlin/com/seafoundry/mobile/
#    # Update package declaration in MainActivity.kt
#
# 3. Replace google-services.json with new Firebase config
#
# 4. Clean and rebuild
#    flutter clean && flutter pub get
```

**Do this BEFORE your first Play Store upload.** The app ID cannot be changed after publishing.

## Permissions

### Declared Permissions

| Permission | Purpose | Runtime? |
|-----------|---------|----------|
| `INTERNET` | Network access for Firebase | No |
| `CAMERA` | Specimen photo capture | Yes (Android 6+) |
| `ACCESS_FINE_LOCATION` | GPS for site mapping | Yes (Android 6+) |
| `ACCESS_COARSE_LOCATION` | Approximate location | Yes (Android 6+) |
| `WAKE_LOCK` | Push notification delivery | No |
| `VIBRATE` | Notification haptics | No |
| `C2DM.RECEIVE` | Firebase Cloud Messaging | No |

Runtime permissions are requested by their respective Flutter plugins (`image_picker`, `geolocator`) when the feature is first used.

## Troubleshooting

### Build Fails with "key.properties not found"

Release builds fall back to debug signing automatically. If you need a signed release:
1. Verify `android/key.properties` exists (not just the `.example`)
2. Verify `storeFile` path is absolute and the keystore file exists
3. Verify passwords are correct

### "Execution failed for task ':app:minifyReleaseWithR8'"

R8/ProGuard minification issue. Check `android/app/proguard-rules.pro` for missing keep rules. Common fix:
```bash
# Temporarily disable minification to isolate the issue
# In build.gradle.kts, set:
#   isMinifyEnabled = false
#   isShrinkResources = false
```

### Version Code Already Used

Play Store rejects uploads with a `versionCode` that was previously uploaded. Increment the build number in `pubspec.yaml`:
```yaml
version: 1.4.0+58  # Was +57, now +58
```

### APK Too Large

- Use `--split-per-abi` for APK builds
- Use AAB format (Play Store generates optimized APKs per device)
- Check for accidentally bundled assets

### Google Maps Not Working

Verify the API key in `google-services.json` has the Maps SDK for Android enabled in Google Cloud Console. Unlike iOS (which loads the key in `AppDelegate.swift`), Android loads it automatically from the Firebase config.

### Firebase Crashlytics Missing Symbols

For obfuscated release builds, upload mapping files:
```bash
firebase crashlytics:symbols:upload --app=1:599860030371:android:3448844faa75594e2bc816 \
  build/app/outputs/mapping/release/mapping.txt
```

## CI/CD (Future)

### GitHub Actions Release Workflow

A future `android_release.yml` workflow would:
1. Trigger on version tag push (`v*`)
2. Decode base64-encoded keystore from GitHub Secrets
3. Build AAB with `flutter build appbundle --release`
4. Upload to Play Store via `r0adkll/upload-google-play` action
5. Post to internal testing track

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file |
| `ANDROID_KEY_ALIAS` | Key alias (e.g., `seafoundry`) |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Google Play API service account key |

## Pre-Release Checklist

- [ ] Version bumped in `pubspec.yaml` (build number must be higher than last upload)
- [ ] `key.properties` configured with valid keystore
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes
- [ ] Release build succeeds: `flutter build appbundle --release`
- [ ] Test release APK on physical device
- [ ] Play Store listing metadata complete (screenshots, description, privacy policy)
- [ ] Data safety form completed
- [ ] Content rating questionnaire completed
- [ ] App ID migrated from `com.example.seafoundry_app` (if not done yet)

## Resources

- **Google Play Console**: https://play.google.com/console
- **Flutter Android Deployment**: https://docs.flutter.dev/deployment/android
- **App Signing**: https://developer.android.com/studio/publish/app-signing
- **Play Store Policies**: https://play.google.com/about/developer-content-policy
- **Firebase Console**: https://console.firebase.google.com (project: `seafoundryapp`)
