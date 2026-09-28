#!/bin/bash
# Buduje instalator build/Calcy.dmg (aplikacja + skrót do Aplikacji, na własnym tle).
# Wymaga: brew install create-dmg
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
swift scripts/make-dmg-background.swift

STAGING="build/dmg"
rm -rf "$STAGING" build/Calcy.dmg
mkdir -p "$STAGING"
cp -R build/Calcy.app "$STAGING/"

create-dmg \
    --volname "Calcy" \
    --volicon build/Calcy.app/Contents/Resources/Calcy-ico.icns \
    --background Resources/dmg-background.png \
    --window-pos 300 160 \
    --window-size 640 400 \
    --icon-size 100 \
    --icon "Calcy.app" 160 190 \
    --app-drop-link 480 190 \
    --hide-extension "Calcy.app" \
    --no-internet-enable \
    build/Calcy.dmg "$STAGING"

rm -rf "$STAGING"
echo "Gotowe: build/Calcy.dmg"
