#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CACHE_DIR="/tmp/clang-cache"
mkdir -p "$CACHE_DIR"

APP_NAME="Quillfolio"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "==> Czyszczenie poprzedniej kompilacji..."
rm -rf "$APP_DIR" "$APP_NAME"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "==> Tworzenie Info.plist..."
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Quillfolio</string>
    <key>CFBundleIdentifier</key>
    <string>io.quillfolio.app</string>
    <key>CFBundleName</key>
    <string>Quillfolio</string>
    <key>CFBundleDisplayName</key>
    <string>Quillfolio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    echo "==> Kopiowanie AppIcon.icns..."
    cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "==> Kompilacja aplikacji Swift..."
SWIFT_FILES=$(find Sources -name "*.swift")

swiftc -disable-sandbox \
       -module-cache-path "$CACHE_DIR" \
       -parse-as-library \
       -O \
       $SWIFT_FILES \
       -o "$MACOS_DIR/$APP_NAME"

# Kopiowanie również jako standalone binary dla wygody
cp "$MACOS_DIR/$APP_NAME" "$SCRIPT_DIR/$APP_NAME"

# Instalacja do ~/Applications (indeksowane przez Spotlight, Launchpad oraz Dock)
USER_APPS="$HOME/Applications"
mkdir -p "$USER_APPS"
rm -rf "$USER_APPS/$APP_NAME.app"
cp -R "$APP_DIR" "$USER_APPS/"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R -f "$USER_APPS/$APP_NAME.app" 2>/dev/null || true

echo "==> Sukces! Utworzono aplikację macOS: $APP_DIR"
echo "==> Zainstalowano w: $USER_APPS/$APP_NAME.app (dostępna w Spotlight i Launchpad)"
echo "==> Możesz ją uruchomić za pomocą: open $APP_DIR lub ./$APP_NAME"
