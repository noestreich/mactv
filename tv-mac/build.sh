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
cp "../player.html"          "${BUNDLE}/Resources/player.html"

cat > "${BUNDLE}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>          <string>MacTV</string>
  <key>CFBundleDisplayName</key>   <string>MacTV</string>
  <key>CFBundleIdentifier</key>    <string>com.aketo.mactv</string>
  <key>CFBundleVersion</key>       <string>1.7.1</string>
  <key>CFBundleShortVersionString</key> <string>1.7.1</string>
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

# SIGN_IDENTITY gesetzt (z. B. via release.sh) → Developer-ID-Signatur mit
# Hardened Runtime und Timestamp (Voraussetzung für Notarisierung),
# sonst wie bisher ad-hoc für lokale Builds.
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "▶ Signiere (${SIGN_IDENTITY})…"
  codesign --force --deep --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP}.app"
else
  echo "▶ Signiere (ad-hoc)…"
  codesign --force --deep --sign - "${APP}.app"
fi

echo ""
echo "✓ ${APP}.app bereit"
echo ""
echo "Tastatur-Shortcuts:"
echo "  ← / →     Sender wechseln"
echo "  ↑ / ↓     Lautstärke"
echo "  Leertaste Screenshot speichern"
echo "  Tab       EPG-Übersicht aller Sender"
echo "  1 – 9     Direktwahl"
echo "  0         Sender 10"
echo "  M         Ton an/aus"
echo "  U         Untertitel"
echo "  F         Vollbild"
echo "  📺         Menüleisten-Icon → Ein-/Ausblenden"
echo ""

# Nur im interaktiven Terminal nachfragen (nicht bei Aufruf aus release.sh)
if [[ -t 0 ]]; then
  read -p "App jetzt starten? [j/N] " ans
  [[ "$ans" == [jJ] ]] && open "${APP}.app"
fi
exit 0
