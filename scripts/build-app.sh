#!/bin/bash
# Buduje build/Calcy.app. Z flagą --install kopiuje ją do ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

# Wersja: z CALCY_VERSION (ustawia ją GitHub Action), inaczej z pliku VERSION.
VERSION="${CALCY_VERSION:-$(cat VERSION 2>/dev/null || echo 0.1.0)}"

swift build -c release --product Calcy
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="build/Calcy.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Calcy" "$APP/Contents/MacOS/Calcy"
# Ikona z Icon Composer (Resources/Calcy-ico.icon) – actool robi z niej Assets.car + .icns.
ICON_NAME="Calcy-ico"
if xcrun actool Resources/Calcy-ico.icon \
    --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 15.0 \
    --app-icon Calcy-ico \
    --output-partial-info-plist "$APP/Contents/Resources/icon.plist" > /dev/null 2>&1; then
    rm -f "$APP/Contents/Resources/icon.plist"
else
    # Starszy Xcode nie zna formatu .icon – wtedy rysowana ikona zapasowa.
    echo "actool nie skompilował .icon – używam Resources/AppIcon.icns"
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    ICON_NAME="AppIcon"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Calcy</string>
    <key>CFBundleDisplayName</key><string>Calcy</string>
    <key>CFBundleIdentifier</key><string>local.calcy</string>
    <key>CFBundleExecutable</key><string>Calcy</string>
    <key>CFBundleIconFile</key><string>$ICON_NAME</string>
    <key>CFBundleIconName</key><string>$ICON_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Podpis ad-hoc – wystarczy do uruchamiania na własnym Macu, bez konta deweloperskiego.
codesign --force --sign - "$APP"
echo "Gotowe: $APP (wersja $VERSION)"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/Calcy.app"
    cp -R "$APP" "$HOME/Applications/"
    echo "Zainstalowano w ~/Applications/Calcy.app"
fi
