#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Calendar Timer"
EXEC_NAME="CalendarTimer"
BUNDLE_ID="com.kolma.calendartimer"
VERSION="1.0"
APP_DIR="${APP_NAME}.app"

echo "▶ Compiling Swift sources…"
swiftc -O CalendarTimer.swift \
    -o "$EXEC_NAME" \
    -framework Cocoa \
    -framework EventKit \
    -framework ServiceManagement

echo "▶ Assembling $APP_DIR…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mv "$EXEC_NAME" "$APP_DIR/Contents/MacOS/$EXEC_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXEC_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Calendar Timer shows a live countdown to the end of your current calendar event.</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# Ad-hoc code-sign so SMAppService / EventKit permissions stick across launches
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "✅ Built $(pwd)/$APP_DIR"
echo ""
echo "Next steps:"
echo "  1. Move \"$APP_DIR\" to /Applications  (needed for Launch at Login)"
echo "  2. Launch it — approve Calendar access when prompted"
echo "  3. Use the ⏱ menubar icon to toggle visibility or enable Launch at Login"
