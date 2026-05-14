import AppKit
import SwiftUI
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandler {

    private var panel:          NSPanel!
    private var webView:        WKWebView!
    private var statusItem:     NSStatusItem!
    private var settingsWindow: NSWindow?
    private var floatingItem:   NSMenuItem?
    private var subtitleItem:   NSMenuItem?
    private var currentIndex    = 0
    private var pageReady       = false
    private var isFloating      = true
    private var subtitlesOn     = false
    private var isMuted         = false

    private let channelStore = ChannelStore()

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Gespeicherte Einstellungen laden
        isFloating   = UserDefaults.standard.object(forKey: "isFloating") as? Bool ?? true
        subtitlesOn  = UserDefaults.standard.bool(forKey: "subtitlesOn")
        isMuted      = UserDefaults.standard.bool(forKey: "isMuted")
        currentIndex = UserDefaults.standard.integer(forKey: "lastChannelIndex")

        setupMainMenu()
        setupMenuBar()
        createPanel()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hauptmenü (⌘W · ⌘Q · ⌘, · Bearbeiten für Textfelder)

    private func setupMainMenu() {
        let main = NSMenu()

        // App-Menü
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "MacTV")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Über MacTV",
                        action: #selector(showAbout),
                        keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Einstellungen…",
                        action: #selector(openSettings),
                        keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "MacTV beenden",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        // Ablage-Menü
        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "Ablage")
        fileItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Fenster ausblenden",
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")

        // Bearbeiten-Menü – ermöglicht ⌘C / ⌘V / Ctrl+C in SwiftUI-Textfeldern
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "Bearbeiten")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Ausschneiden",   action: #selector(NSText.cut(_:)),       keyEquivalent: "x")
        editMenu.addItem(withTitle: "Kopieren",        action: #selector(NSText.copy(_:)),      keyEquivalent: "c")
        editMenu.addItem(withTitle: "Einsetzen",       action: #selector(NSText.paste(_:)),     keyEquivalent: "v")
        editMenu.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = main
    }

    // MARK: - Menüleisten-Icon

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let img = NSImage(systemSymbolName: "tv", accessibilityDescription: "MacTV") {
            img.isTemplate = true
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "📺"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Einstellungen…",
                                      action: #selector(openSettings),
                                      keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let toggleItem = NSMenuItem(title: "Einblenden / Ausblenden",
                                    action: #selector(togglePanel),
                                    keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let fi = NSMenuItem(title: "Immer im Vordergrund",
                            action: #selector(toggleFloating),
                            keyEquivalent: "")
        fi.target = self
        fi.state  = isFloating ? .on : .off
        menu.addItem(fi)
        floatingItem = fi

        let si = NSMenuItem(title: "Untertitel",
                            action: #selector(toggleSubtitlesAction),
                            keyEquivalent: "")
        si.target = self
        si.state  = subtitlesOn ? .on : .off
        menu.addItem(si)
        subtitleItem = si

        menu.addItem(.separator())

        for (i, ch) in channelStore.channels.prefix(9).enumerated() {
            let item = NSMenuItem(title: "\(i + 1)  \(ch.name)",
                                  action: #selector(menuTune(_:)),
                                  keyEquivalent: "")
            item.tag    = i
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Beenden",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Panel + WebView

    private func createPanel() {
        let w: CGFloat = 640
        let h: CGFloat = 390

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask:   [.titled, .closable, .resizable],
            backing:     .buffered,
            defer:       false
        )
        panel.title              = "MacTV"
        panel.level              = isFloating ? .floating : .normal
        panel.collectionBehavior = isFloating
            ? [.canJoinAllSpaces, .fullScreenPrimary]
            : [.fullScreenPrimary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate  = false
        panel.appearance         = NSAppearance(named: .darkAqua)
        panel.backgroundColor    = .black
        panel.delegate           = self

        // Beim ersten Start zentrieren; danach stellt setFrameAutosaveName die Position wieder her
        let sf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: sf.minX + (sf.width  - w) / 2,
            y: sf.minY + (sf.height - h) / 2
        ))
        panel.setFrameAutosaveName("MacTVPlayer")

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        // WebKit-Inspector für Debugging aktivieren (Rechtsklick → Untersuchen)
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        // requestPlay: WebView meldet Senderindex → Swift löst URL auf und spielt ab
        config.userContentController.add(self, name: "requestPlay")
        // muteChanged: WebView meldet Mute-State → Swift persistiert ihn
        config.userContentController.add(self, name: "muteChanged")

        webView = WKWebView(
            frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)),
            configuration: config
        )
        webView.autoresizingMask   = [.width, .height]
        webView.navigationDelegate = self

        panel.contentView?.addSubview(webView)
        // Frame auf tatsächliche Content-Größe setzen (kann nach setFrameAutosaveName
        // größer als die Initialgröße sein)
        if let cv = panel.contentView { webView.frame = cv.bounds }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        loadPlayerPage()
    }

    private func loadPlayerPage() {
        guard let file = Bundle.main.url(forResource: "player", withExtension: "html"),
              let html = try? String(contentsOf: file, encoding: .utf8) else { return }
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost/"))
    }

    // MARK: - Senderliste in WebView injizieren

    /// Übergibt den aktuellen ChannelStore als JSON an setChannels() im WebView.
    private func injectChannels() {
        guard pageReady else { return }
        let chs     = channelStore.channels
        let chNames = chs.map { $0.name }
        let chUrls  = chs.map { $0.url }
        guard let namesData = try? JSONSerialization.data(withJSONObject: chNames),
              let urlsData  = try? JSONSerialization.data(withJSONObject: chUrls),
              let namesStr  = String(data: namesData, encoding: .utf8),
              let urlsStr   = String(data: urlsData, encoding: .utf8) else { return }
        webView.evaluateJavaScript("setChannels(\(namesStr), \(urlsStr))") { _, _ in }
    }

    // MARK: - Sender wechseln

    func loadChannel(_ index: Int) {
        guard !channelStore.channels.isEmpty else { return }
        currentIndex = ((index % channelStore.channels.count) + channelStore.channels.count) % channelStore.channels.count
        UserDefaults.standard.set(currentIndex, forKey: "lastChannelIndex")
        updatePanelTitle()
        guard pageReady else { return }
        tuneWebView(to: currentIndex)
    }

    /// Löst die Stream-URL auf (inkl. ZDF-API) und startet die Wiedergabe via playUrl().
    /// Ruft NIE zapTo() auf – die JS-Senderliste ist nur für Browser-Navigation.
    private func tuneWebView(to index: Int) {
        guard index < channelStore.channels.count else { return }
        let ch = channelStore.channels[index]

        // WebView-UI synchronisieren (Titelzeile + Dropdown)
        let safeName = ch.name.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("updateChannelUI(\(index), '\(safeName)')") { _, _ in }

        // URL auflösen und Wiedergabe starten
        if ch.useZDFApi {
            ZDFLoader.fetchHLSURL { [weak self] url in
                guard let self else { return }
                let resolved = url ?? ch.url
                let safe = resolved.replacingOccurrences(of: "'", with: "\\'")
                DispatchQueue.main.async {
                    self.webView.evaluateJavaScript("playUrl('\(safe)')") { _, _ in }
                }
            }
        } else {
            let safe = ch.url.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("playUrl('\(safe)')") { _, _ in }
        }
    }

    private func updatePanelTitle() {
        guard currentIndex < channelStore.channels.count else { return }
        let ch = channelStore.channels[currentIndex]
        panel.title    = "MacTV"
        panel.subtitle = "\(currentIndex + 1)  \(ch.name)"
    }

    // MARK: - WKScriptMessageHandler

    /// requestPlay wird vom WebView gesendet wenn der User per Tastatur/Button/Dropdown
    /// einen Sender wählt. Swift löst die URL auf (ZDF-sicher) und spielt ab.
    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        switch message.name {
        case "requestPlay":
            guard let idx = message.body as? Int, !channelStore.channels.isEmpty else { return }
            currentIndex = ((idx % channelStore.channels.count) + channelStore.channels.count) % channelStore.channels.count
            UserDefaults.standard.set(currentIndex, forKey: "lastChannelIndex")
            updatePanelTitle()
            tuneWebView(to: currentIndex)
        case "muteChanged":
            guard let muted = message.body as? Bool else { return }
            isMuted = muted
            UserDefaults.standard.set(muted, forKey: "isMuted")
        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        injectChannels()
        // Gespeicherte Zustände synchronisieren
        webView.evaluateJavaScript("setSubtitles(\(subtitlesOn ? "true" : "false"))") { _, _ in }
        webView.evaluateJavaScript("setMuted(\(isMuted ? "true" : "false"))") { _, _ in }
        updatePanelTitle()
        tuneWebView(to: currentIndex)
    }

    // MARK: - Einstellungen

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName:    "MacTV",
            .applicationVersion: version,
            .credits: NSAttributedString(
                string: "Leichtgewichtige macOS-App für Live-TV aus der ARD-, ZDF- und Arte-Mediathek.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
            )
        ])
    }

    @objc private func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(store: channelStore) { [weak self] in
            guard let self else { return }
            self.rebuildMenu()
            self.injectChannels()
            // Falls aktueller Index durch Löschen ungültig wurde, auf 0 zurück
            if self.currentIndex >= self.channelStore.channels.count {
                self.currentIndex = 0
            }
            self.updatePanelTitle()
            if self.pageReady {
                self.tuneWebView(to: self.currentIndex)
            }
        }

        let hosting = NSHostingController(rootView: view)
        let window  = NSWindow(contentViewController: hosting)
        window.title      = "MacTV – Einstellungen"
        window.styleMask  = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 640, height: 520))
        window.minSize    = NSSize(width: 400, height: 480)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func toggleSubtitlesAction() {
        subtitlesOn.toggle()
        UserDefaults.standard.set(subtitlesOn, forKey: "subtitlesOn")
        subtitleItem?.state = subtitlesOn ? .on : .off
        webView.evaluateJavaScript("setSubtitles(\(subtitlesOn ? "true" : "false"))") { _, _ in }
    }

    @objc private func toggleFloating() {
        isFloating.toggle()
        UserDefaults.standard.set(isFloating, forKey: "isFloating")
        panel.level              = isFloating ? .floating : .normal
        panel.collectionBehavior = isFloating
            ? [.canJoinAllSpaces, .fullScreenPrimary]
            : [.fullScreenPrimary]
        floatingItem?.state = isFloating ? .on : .off
    }

    @objc private func menuTune(_ sender: NSMenuItem) {
        loadChannel(sender.tag)
        if !panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // ⌘W → ausblenden statt schließen
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel { panel.orderOut(nil); return false }
        return true
    }
}
