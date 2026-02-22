# iOS Deployment Guide

This guide covers the process for building, signing, and deploying the SeaFoundry iOS app to TestFlight and the App Store.

## Prerequisites

### Apple Developer Account
- **Team ID**: SBZCR8XXAS
- **Bundle Identifier**: `com.seafoundry.mobile`
- **App ID**: Registered in Apple Developer Portal
- **Provisioning Profiles**: Must be created and downloaded for Distribution

### Xcode Configuration
- Xcode 15.0 or later
- macOS 13.0 (Ventura) or later
- Active Apple Developer account signed in to Xcode

## iOS Build Configuration

### Google Maps API Key

The app loads the Google Maps API key from `GoogleService-Info.plist` in the `AppDelegate.swift`:

```swift
// ios/Runner/AppDelegate.swift
if
  let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
  let dict = NSDictionary(contentsOfFile: path),
  let apiKey = dict["API_KEY"] as? String {
  GMSServices.provideAPIKey(apiKey)
}
```

**Important**: Ensure `GoogleService-Info.plist` contains the `API_KEY` field for Google Maps. This is typically the same key configured in your Firebase project.

### Google Sign-In URL Scheme

The iOS app requires a URL scheme for Google Sign-In to handle OAuth callbacks. This is configured in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.599860030371-9umb5pt0mturc8amd6kr8qbu3e4jgdlm</string>
    </array>
  </dict>
</array>
```

The URL scheme must match the `REVERSED_CLIENT_ID` from your `GoogleService-Info.plist`.

### Platform-Specific Google Sign-In Imports

To avoid `dart:ui_web` import issues that break iOS builds, the app uses conditional imports for web-only Google Sign-In functionality:

**Files affected:**
- `lib/screens/auth/auth_screen.dart` - Uses conditional import
- `lib/screens/auth/community_auth_screen.dart` - Uses conditional import
- `lib/screens/auth/google_sign_in_web_stub.dart` - Stub for non-web platforms

**Import pattern:**
```dart
// Conditional import for web-only code
import 'google_sign_in_web_stub.dart'
    if (dart.library.html) 'google_sign_in_web.dart';
```

### CocoaPods Configuration

CocoaPods must be run with UTF-8 locale to avoid encoding issues:

```bash
cd ios
LANG=en_US.UTF-8 pod install
```

If you encounter encoding errors during `pod install`, always use the `LANG=en_US.UTF-8` prefix.

## Code Signing Setup

### 1. Configure Automatic Signing (Development)

For local development builds:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities" tab
4. Check "Automatically manage signing"
5. Select your Team: **SBZCR8XXAS**
6. Ensure Bundle Identifier is `com.seafoundry.mobile`

### 2. Configure Manual Signing (Release)

For App Store distribution:

1. In Xcode, select the Runner target
2. Go to "Signing & Capabilities" tab
3. For "Release" configuration:
   - Uncheck "Automatically manage signing"
   - Select Provisioning Profile: **App Store Distribution Profile**
   - Ensure Team is **SBZCR8XXAS**

### 3. Provisioning Profile Requirements

You need the following provisioning profiles registered in Apple Developer Portal:

#### Development Profile
- **Type**: iOS App Development
- **App ID**: `com.seafoundry.mobile`
- **Devices**: Registered development devices
- **Certificates**: Development certificate for your machine

#### Distribution Profile
- **Type**: App Store
- **App ID**: `com.seafoundry.mobile`
- **Certificates**: Distribution certificate for your organization

#### Push Notification Setup
- Push Notifications capability enabled in both profiles
- APNs certificates configured (Production for Release builds)
- Entitlements configured in `RunnerRelease.entitlements`:
  ```xml
  <key>aps-environment</key>
  <string>production</string>
  ```

## Build Process

### 1. Update Version and Build Number

Edit `pubspec.yaml`:
```yaml
version: 1.0.0+10  # Format: version+buildNumber
```

Or use Flutter commands:
```bash
# Update version
flutter build ios --build-name=1.0.1

# Update build number
flutter build ios --build-number=11
```

### 2. Clean Build

```bash
# Clean Flutter build
flutter clean
flutter pub get

# Clean iOS build with UTF-8 locale
cd ios
rm -rf build/ Pods/ Podfile.lock
LANG=en_US.UTF-8 pod install
cd ..
```

**Note**: Always use `LANG=en_US.UTF-8` when running `pod install` to avoid encoding issues. If the Xcode build still fails after cleaning, also try:

```bash
# Clear Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
```

### 3. Build Release Archive

```bash
# Build iOS release
flutter build ios --release --no-codesign

# Or with version flags
flutter build ios --release --no-codesign --build-name=1.0.0 --build-number=10
```

### 4. Create Archive in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device (arm64)" as the build destination
3. Select **Product > Archive**
4. Wait for archive to complete
5. Organizer window will open showing your archive

## TestFlight Deployment

### 1. Upload to App Store Connect

From Xcode Organizer:

1. Select your archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Click "Upload"
5. Select distribution options:
   - Include bitcode: No (Flutter apps don't use bitcode)
   - Upload symbols: Yes (for crash reporting)
   - Manage version and build: Automatic
6. Select provisioning profile (App Store Distribution)
7. Click "Upload"

### 2. Configure TestFlight

In App Store Connect:

1. Go to your app
2. Select "TestFlight" tab
3. Wait for build to process (10-30 minutes)
4. Add external testers:
   - Create test groups
   - Add tester emails
   - Provide test information (What to Test)
5. Submit build for review (if external testing)

### 3. Internal Testing

- Internal testers (up to 100) can test immediately after processing
- Add internal testers in App Store Connect > Users and Access
- Testers receive email with TestFlight invitation

## App Store Submission

### Pre-Submission Checklist

- [ ] All required metadata complete in App Store Connect
- [ ] Screenshots uploaded (all required device sizes)
- [ ] App icon uploaded (1024x1024px)
- [ ] Privacy Policy URL configured
- [ ] Support URL configured
- [ ] App description, keywords, and categories set
- [ ] Age rating questionnaire completed
- [ ] Export compliance information provided
- [ ] TestFlight testing completed successfully

### Submission Process

1. In App Store Connect, go to your app
2. Select "App Store" tab
3. Click "+" to create new version
4. Enter version number (e.g., 1.0.0)
5. Fill in "What's New in This Version"
6. Select build from TestFlight
7. Complete app information if first submission
8. Submit for review

### Review Timeline

- Initial review: 24-48 hours (sometimes longer)
- Re-submission after rejection: 24 hours typically
- Expedited review: Available for critical bug fixes (request via App Store Connect)

## Privacy and Permissions

### Info.plist Permissions

Required permission descriptions are configured in `ios/Runner/Info.plist`:

- **NSCameraUsageDescription**: Camera access for specimen photos
- **NSLocationWhenInUseUsageDescription**: Location access for site mapping
- **NSLocationAlwaysAndWhenInUseUsageDescription**: Background location (if needed)
- **NSPhotoLibraryUsageDescription**: Photo library read access
- **NSPhotoLibraryAddUsageDescription**: Photo library write access

### Privacy Manifest

The app includes `PrivacyInfo.xcprivacy` declaring:

- **Data Collection**: Location, Photos, Email, Name (all for App Functionality)
- **No Tracking**: `NSPrivacyTracking` set to false
- **Required Reason APIs**: File timestamp, UserDefaults, disk space, system boot time

### App Store Privacy Questions

When submitting, you'll need to answer:

1. **Does your app collect data?** Yes
2. **Data types collected**:
   - Precise Location (for site mapping)
   - Photos (for specimen documentation)
   - Email Address (for user account)
   - Name (for user profile)
3. **How is data used?** App Functionality only
4. **Is data linked to user?** Yes (Email, Name)
5. **Do you track users?** No

## Troubleshooting

### Common Build Issues

#### Code Signing Error
```
error: Provisioning profile "..." doesn't include signing certificate "..."
```
**Solution**:
- Verify certificate is valid and not expired
- Regenerate provisioning profile if needed
- Refresh profiles in Xcode: Preferences > Accounts > Download Manual Profiles

#### Missing Permissions
```
Missing Info.plist key - NSLocationWhenInUseUsageDescription
```
**Solution**: Verify all required permission strings are in `Info.plist`

#### Archive Not Showing in Organizer
**Solution**:
- Ensure build destination is "Any iOS Device (arm64)"
- Check scheme is set to "Release"
- Verify signing is configured correctly

#### dart:ui_web Import Error on iOS
```
Error: Dart library 'dart:ui_web' is not available on this platform.
```
**Solution**: This occurs when web-only code is imported on iOS. The app uses conditional imports with stub files to prevent this. See the "Platform-Specific Google Sign-In Imports" section above.

#### CocoaPods Encoding Error
```
encoding error or invalid byte sequence in UTF-8
```
**Solution**: Run pod install with UTF-8 locale:
```bash
LANG=en_US.UTF-8 pod install
```

#### GMSServices Precondition Failure
```
Google Maps SDK precondition failure: provideAPIKey not called
```
**Solution**: Ensure `AppDelegate.swift` loads the API key from `GoogleService-Info.plist` and that the plist contains the `API_KEY` field. See the "Google Maps API Key" section above.

#### Stale Build Cache Errors
If you see import errors for classes that clearly exist:
```bash
# Full clean including Xcode caches
flutter clean
rm -rf ios/build ios/Pods ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
flutter pub get
cd ios && LANG=en_US.UTF-8 pod install && cd ..
```

### TestFlight Issues

#### Build Processing Forever
- Wait 24 hours before contacting Apple
- Check for email about missing compliance information
- Verify export compliance is set in App Store Connect

#### Testers Not Receiving Invites
- Check email addresses are correct
- Verify build is available for testing
- Check spam folders
- Resend invite from App Store Connect

### App Review Rejections

Common rejection reasons and fixes:

1. **Missing Privacy Policy**: Add URL in App Store Connect
2. **App Crashes on Launch**: Test thoroughly on physical devices
3. **Incomplete Functionality**: Ensure all features work without backend dependencies
4. **Misleading Metadata**: Screenshots and description must accurately represent app

## Version Management

### Version Numbering Scheme
- **Major.Minor.Patch+BuildNumber**
- Example: `1.2.3+45`
  - Major (1): Breaking changes, major features
  - Minor (2): New features, backward compatible
  - Patch (3): Bug fixes
  - Build (45): Incremental build counter

### Version Update Process
1. Update `pubspec.yaml` version
2. Update `CHANGELOG.md` with changes
3. Create git tag: `git tag v1.2.3`
4. Build and deploy
5. Push tag: `git push --tags`

## Automation (Future)

### Fastlane Integration (Planned)

Consider setting up Fastlane for automated builds:

```ruby
# Fastfile example
lane :beta do
  build_app(scheme: "Runner")
  upload_to_testflight
end

lane :release do
  build_app(scheme: "Runner")
  upload_to_app_store
end
```

### CI/CD Integration (Planned)

GitHub Actions workflow for automated builds:
- Trigger on tag push (v*)
- Build iOS archive
- Upload to TestFlight
- Notify team via Slack/email

## Support and Resources

- **Apple Developer Portal**: https://developer.apple.com
- **App Store Connect**: https://appstoreconnect.apple.com
- **TestFlight**: https://developer.apple.com/testflight/
- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios
- **Team ID**: SBZCR8XXAS
- **Bundle ID**: com.seafoundry.mobile

## Contacts

- **Developer Account Admin**: [Add admin contact]
- **Technical Lead**: [Add tech lead contact]
- **App Store Contact**: [Add App Store contact email]
