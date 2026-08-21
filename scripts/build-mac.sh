#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

APP_NAME="SwiftTemp"
BUNDLE_ID="com.razorbackroar.swifttemp"

VERSION="$(sed -n 's/.*"version".*"\([^"]*\)".*/\1/p' "$PROJECT_DIR/Sources/SwiftTemp/Resources/version.json")"

RELEASE_DIR="$PROJECT_DIR/build/Release"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"
EXEC_PATH="$PROJECT_DIR/.build/release/$APP_NAME"
RESOURCE_BUNDLE="$PROJECT_DIR/.build/release/${APP_NAME}_${APP_NAME}.bundle"

echo "Building $APP_NAME release..."
cd "$PROJECT_DIR"

swift build -c release

echo "Packaging $APP_NAME.app..."
rm -rf "$APP_PATH" "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$EXEC_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Sources/SwiftTemp/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Sources/SwiftTemp/Resources/version.json" "$APP_PATH/Contents/Resources/version.json"

if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"
fi

cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © $(date +%Y) RazorBackRoar. All rights reserved.</string>
</dict>
</plist>
EOF

chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

RAZORCORE_DIR="$(cd "$SCRIPT_DIR/../../.razorcore" && pwd)"
"$RAZORCORE_DIR/patch-app-branding.sh" "$APP_PATH"

echo "Ad-hoc signing $APP_NAME.app..."
codesign --force --deep --sign - "$APP_PATH"

echo "Creating $APP_NAME.dmg with shared layout..."
mkdir -p "$RELEASE_DIR"
"$RAZORCORE_DIR/package-dmg.sh" \
  --app "$APP_PATH" \
  --dmg "$DMG_PATH" \
  --app-name "$APP_NAME" \
  --volname "$APP_NAME"

# package-dmg.sh owns Desktop copy / mount. Never install into /Applications.
rm -rf "$APP_PATH" "$RELEASE_DIR/.previous-build"

echo "Build complete: ${HOME}/Desktop/${APP_NAME}.dmg"
