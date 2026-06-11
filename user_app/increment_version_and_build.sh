#!/bin/bash

# Script to increment version in pubspec.yaml and optionally build release app bundle
# Usage: ./increment_version_and_build.sh [patch|minor|major] [--no-build]
# Default: patch increment with build
# Build number ALWAYS increments regardless of version type

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root."
    exit 1
fi

# Parse arguments
INCREMENT_TYPE="patch"
NO_BUILD=false

for arg in "$@"; do
    case $arg in
        patch|minor|major)
            INCREMENT_TYPE="$arg"
            ;;
        --no-build)
            NO_BUILD=true
            ;;
        *)
            print_error "Invalid argument: $arg. Use: [patch|minor|major] [--no-build]"
            exit 1
            ;;
    esac
done

print_status "Incrementing $INCREMENT_TYPE version..."

# Extract current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD_NUMBER=$(grep "^version:" pubspec.yaml | sed 's/.*+//')

print_status "Current version: $CURRENT_VERSION+$BUILD_NUMBER"

# Split version into major.minor.patch
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment based on type
case $INCREMENT_TYPE in
    "major")
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    "minor")
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    "patch")
        PATCH=$((PATCH + 1))
        ;;
esac

# ALWAYS increment build number
BUILD_NUMBER=$((BUILD_NUMBER + 1))

# Create new version string
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD_NUMBER"

print_status "New version: $NEW_VERSION"

# Update pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml
else
    # Linux
    sed -i "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml
fi

print_status "Updated pubspec.yaml with new version"

if [ "$NO_BUILD" = true ]; then
    print_status "✅ Version increment completed!"
    print_status "Version updated to: $NEW_VERSION"
    print_status "Skipping build (--no-build flag used)"
else
    # Clean previous builds
    print_status "Cleaning previous builds..."
    flutter clean

    # Get dependencies
    print_status "Getting dependencies..."
    flutter pub get

    # Build release app bundle
    print_status "Building release app bundle..."
    flutter build apk --release

    # Check if build was successful
    if [ $? -eq 0 ]; then
        print_status "✅ Build completed successfully!"
        print_status "Version updated to: $NEW_VERSION"
        print_status "App bundle location: build/app/outputs/bundle/release/app-release.aab"
        
        # Show file size
        if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
            FILE_SIZE=$(ls -lh "build/app/outputs/bundle/release/app-release.aab" | awk '{print $5}')
            print_status "Bundle size: $FILE_SIZE"
        fi
    else
        print_error "❌ Build failed!"
        exit 1
    fi
fi

print_status "Done! 🎉"