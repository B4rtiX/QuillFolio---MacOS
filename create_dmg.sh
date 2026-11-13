#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Quillfolio"
DMG_NAME="Quillfolio.dmg"
STAGING_DIR="/tmp/dmg_staging_$APP_NAME"

echo "==> Przygotowanie instalatora .dmg dla Quillfolio..."

if [ ! -d "$SCRIPT_DIR/$APP_NAME.app" ]; then
    echo "==> Budowanie aplikacji..."
    ./build.sh
fi

rm -rf "$STAGING_DIR" "$SCRIPT_DIR/$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Kopiowanie paczki .app
cp -R "$SCRIPT_DIR/$APP_NAME.app" "$STAGING_DIR/"

# Skrót do folderu /Applications (Drag and Drop)
ln -s /Applications "$STAGING_DIR/Applications"

# Tworzenie skompresowanego obrazu instalacyjnego DMG (UDZO)
hdiutil create -volname "Quillfolio" \
               -srcfolder "$STAGING_DIR" \
               -ov \
               -format UDZO \
               "$SCRIPT_DIR/$DMG_NAME"

rm -rf "$STAGING_DIR"

echo "==> Gotowe! Plik instalacyjny .dmg został utworzony:"
echo "    $SCRIPT_DIR/$DMG_NAME"
