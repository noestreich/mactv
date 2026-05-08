BINARY       = TVFloat
BUNDLE       = MacTV.app
BINARY_DIR   = .build/release
ENTITLEMENTS = MacTV.entitlements
ICON         = Resources/AppIcon.icns

DEV_ID           ?= Developer ID Application: aketo GmbH (9H7F5NMT97)
KEYCHAIN_PROFILE ?= DialControllerNotary
VERSION          ?= 1.0

.PHONY: build bundle clean sign-release zip notarize staple release

build:
	swift build -c release --arch arm64
	swift build -c release --arch x86_64
	lipo -create \
	    -output .build/release/$(BINARY) \
	    .build/arm64-apple-macosx/release/$(BINARY) \
	    .build/x86_64-apple-macosx/release/$(BINARY)

bundle: build
	@echo "→ Assembling $(BUNDLE)…"
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(BINARY_DIR)/$(BINARY) $(BUNDLE)/Contents/MacOS/$(BINARY)
	@cp $(ICON) $(BUNDLE)/Contents/Resources/AppIcon.icns
	@cp ../player.html $(BUNDLE)/Contents/Resources/player.html
	@/usr/libexec/PlistBuddy -c "Add :CFBundleName string MacTV" \
	  -c "Add :CFBundleDisplayName string MacTV" \
	  -c "Add :CFBundleIdentifier string de.aketo.mactv" \
	  -c "Add :CFBundleVersion string $(VERSION)" \
	  -c "Add :CFBundleShortVersionString string $(VERSION)" \
	  -c "Add :CFBundleIconFile string AppIcon" \
	  -c "Add :CFBundleExecutable string $(BINARY)" \
	  -c "Add :CFBundlePackageType string APPL" \
	  -c "Add :LSMinimumSystemVersion string 13.0" \
	  -c "Add :LSUIElement bool true" \
	  -c "Add :NSHighResolutionCapable bool true" \
	  -c "Add :NSAppTransportSecurity dict" \
	  -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" \
	  $(BUNDLE)/Contents/Info.plist
	@echo "✓ $(BUNDLE) assembled."

clean:
	@rm -rf .build $(BUNDLE) MacTV.zip

sign-release: bundle
	@echo "→ Signing with Developer ID…"
	@codesign --sign "$(DEV_ID)" \
	           --entitlements $(ENTITLEMENTS) \
	           --options runtime \
	           --timestamp \
	           --force \
	           --deep \
	           $(BUNDLE)
	@codesign --verify --deep --strict --verbose=2 $(BUNDLE)
	@echo "✓ Signed."

zip: sign-release
	@echo "→ Creating MacTV.zip…"
	@rm -f MacTV.zip
	@/usr/bin/ditto -c -k --keepParent $(BUNDLE) MacTV.zip
	@echo "✓ MacTV.zip ready."

notarize: zip
	@echo "→ Submitting to Apple notary service…"
	@xcrun notarytool submit MacTV.zip \
	       --keychain-profile "$(KEYCHAIN_PROFILE)" \
	       --wait

staple:
	@echo "→ Stapling notarisation ticket…"
	@xcrun stapler staple $(BUNDLE)
	@xcrun stapler validate $(BUNDLE)
	@spctl --assess --type execute --verbose=4 $(BUNDLE) || true
	@echo "→ Re-zipping stapled bundle…"
	@rm -f MacTV.zip
	@/usr/bin/ditto -c -k --keepParent $(BUNDLE) MacTV.zip

release: notarize staple
	@echo "✓ $(BUNDLE) is signed, notarised, and stapled. MacTV.zip is ready for distribution."
