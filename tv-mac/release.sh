#!/bin/bash
# MacTV – Release-Script: bauen, signieren, notarisieren, stapeln
#
# Voraussetzungen:
#   1. Developer-ID-Zertifikat im Schlüsselbund
#   2. Einmalig Notarisierungs-Zugangsdaten hinterlegen:
#        xcrun notarytool store-credentials mactv-notary \
#          --apple-id "<deine Apple-ID>" --team-id 9H7F5NMT97
#      (fragt nach einem App-spezifischen Passwort von appleid.apple.com)
#
# Aufruf: cd tv-mac && bash release.sh
set -euo pipefail

APP="TVFloat"
IDENTITY="Developer ID Application: aketo GmbH (9H7F5NMT97)"
PROFILE="${NOTARY_PROFILE:-mactv-notary}"

# Bauen + mit Developer-ID signieren (Hardened Runtime, Timestamp)
SIGN_IDENTITY="${IDENTITY}" bash build.sh < /dev/null

VERSION=$(plutil -extract CFBundleShortVersionString raw "${APP}.app/Contents/Info.plist")
ZIP="MacTV-${VERSION}.zip"

echo "▶ Prüfe Signatur…"
codesign --verify --strict --verbose=2 "${APP}.app"

echo "▶ Notarisiere (Profil: ${PROFILE})…"
ditto -c -k --keepParent "${APP}.app" "${ZIP}"
xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

echo "▶ Staple Ticket an die App…"
xcrun stapler staple "${APP}.app"

# Zip neu erstellen, damit das gestapelte Ticket mit ausgeliefert wird
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP}.app" "${ZIP}"

echo "▶ Gatekeeper-Check…"
spctl --assess --type execute --verbose=2 "${APP}.app"

echo ""
echo "✓ ${APP}.app notarisiert und gestapelt"
echo "✓ ${ZIP} bereit für die Verteilung"
