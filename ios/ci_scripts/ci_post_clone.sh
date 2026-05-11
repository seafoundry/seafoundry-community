#!/bin/sh
# Xcode Cloud post-clone script for Flutter projects
# This script runs after the repository is cloned and before the build starts

set -e  # Exit on any error

echo "=== SeaFoundry Xcode Cloud Build Setup ==="
echo "Current directory: $(pwd)"
echo "Repository root: $CI_PRIMARY_REPOSITORY_PATH"

# Navigate to repository root
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Check if Flutter is available, install if not
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found, installing..."

    # Clone Flutter SDK
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
    export PATH="$PATH:$HOME/flutter/bin"

    # Pre-cache iOS artifacts
    flutter precache --ios
fi

echo "Flutter version:"
flutter --version

# Get Flutter dependencies
echo "=== Getting Flutter dependencies ==="
flutter pub get

# Generate Flutter iOS build files
echo "=== Generating Flutter iOS build files ==="
flutter build ios --config-only --release --no-codesign

# Navigate to iOS directory
cd ios

# Install CocoaPods dependencies
echo "=== Installing CocoaPods dependencies ==="
pod install --repo-update

echo "=== Xcode Cloud setup complete ==="
