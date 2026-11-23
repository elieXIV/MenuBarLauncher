#!/bin/bash
# Build script for MenuBarLauncher

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_NAME="MenuBarLauncher"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "🔨 Building ${APP_NAME}..."

# Build with Swift Package Manager
swift build -c release --package-path "${PROJECT_DIR}"

# Create app bundle structure
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
cp "${PROJECT_DIR}/Sources/MenuBarLauncher/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

# Make executable
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "✅ Build complete!"
echo "📦 App bundle: ${APP_BUNDLE}"
echo ""
echo "To run: open \"${APP_BUNDLE}\""
echo "To install: cp -r \"${APP_BUNDLE}\" /Applications/"