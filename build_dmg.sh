#!/bin/bash
set -e

# Define variables
APP_NAME="ADHDMode"
BUILD_DIR="build"
DMG_CONTENT_DIR="dmg_content"
DMG_NAME="${APP_NAME}.dmg"

echo "🚀 Starting build process for ${APP_NAME}..."

# 1. Clean and Build
echo "🛠️  Building application..."
xcodebuild -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}" \
  clean build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

# Check if build was successful
if [ ! -d "${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app" ]; then
    echo "❌ Build failed. App not found."
    exit 1
fi

# 2. Prepare DMG Content
echo "📂 Preparing DMG content..."
rm -rf "${DMG_CONTENT_DIR}"
mkdir -p "${DMG_CONTENT_DIR}"

# Copy the built app
cp -R "${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app" "${DMG_CONTENT_DIR}/"

# Copy the help text
if [ -f "提示_已损坏怎么办.txt" ]; then
    cp "提示_已损坏怎么办.txt" "${DMG_CONTENT_DIR}/"
else
    echo "⚠️  Warning: '提示_已损坏怎么办.txt' not found."
fi

# Create a symlink to Applications folder
ln -s /Applications "${DMG_CONTENT_DIR}/Applications"

# 3. Create DMG
echo "📦 Creating DMG..."
rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_CONTENT_DIR}" -ov -format UDZO "${DMG_NAME}"

# Cleanup
echo "🧹 Cleaning up..."
rm -rf "${DMG_CONTENT_DIR}"

echo "✅ Done! DMG created at $(pwd)/${DMG_NAME}"
