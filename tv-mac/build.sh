#!/bin/bash
# TVFloat – Build-Script (kein Xcode nötig, nur CLI-Tools)
# Aufruf: cd tv-mac && bash build.sh
set -euo pipefail

APP="TVFloat"
BUNDLE="${APP}.app/Contents"

echo "▶ Kompiliere…"
swift build -c release 2>&1

echo "▶ Erstelle App-Bundle…"
rm -rf "${APP}.app"
mkdir -p "${BUNDLE}/MacOS" "${BUNDLE}/Resources"

cp ".build/release/${APP}" "${BUNDLE}/MacOS/${APP}"
cp "Resources/AppIcon.icns" "${BUNDLE}/Resources/AppIcon.icns"

cat > "${BUNDLE}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>          <string>MacTV</string>
  <key>CFBundleDisplayName</key>   <string>MacTV</string>
  <key>CFBundleIdentifier</key>    <string>local.mactv</string>
  <key>CFBundleVersion</key>       <string>1.0</string>
  <key>CFBundleShortVersionString</key> <string>1.0</string>
  <key>CFBundleIconFile</key>       <string>AppIcon</string>
  <key>CFBundleExecutable</key>    <string>TVFloat</string>
  <key>CFBundlePackageType</key>   <string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <!-- Kein Dock-Icon; nur Menüleiste -->
  <key>LSUIElement</key>           <true/>
  <key>NSHighResolutionCapable</key><true/>
  <!-- HTTP-Streams erlauben -->
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key><true/>
  </dict>
</dict>
</plist>
PLIST

echo "▶ Signiere (ad-hoc)…"
codesign --force --deep --sign - "${APP}.app"

echo ""
echo "✓ ${APP}.app bereit"
echo ""
echo "Tastatur-Shortcuts:"
echo "  ↑ / →     Nächster Sender"
echo "  ↓ / ←     Vorheriger Sender"
echo "  1 – 9     Direktwahl"
echo "  0         Sender 10"
echo "  M         Ton an/aus"
echo "  F         Vollbild"
echo "  📺         Menüleisten-Icon → Ein-/Ausblenden"
echo ""

read -p "App jetzt starten? [j/N] " ans
[[ "${ans,,}" == "j" ]] && open "${APP}.app"
