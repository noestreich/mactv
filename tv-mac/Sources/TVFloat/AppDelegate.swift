import AppKit
import SwiftUI
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {

    private var panel:           NSPanel!
    private var webView:         WKWebView!
    private var statusItem:      NSStatusItem!
    private var settingsWindow:  NSWindow?
    private var floatingItem:    NSMenuItem?
    private var subtitleItem:    NSMenuItem?
    private var currentIndex     = 0
    private var pageReady        = false
    private var isFloating       = true
    private var subtitlesOn      = false

    private let channelStore = ChannelStore()
    private let tvDir = URL(fileURLWithPath: "/Users/nicolasoestreich/tv")

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupMenuBar()
        createPanel()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hauptmenü (⌘W, ⌘Q, ⌘,)

    private func setupMainMenu() {
        let main = NSMenu()

        // App-Menü
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "MacTV")
        appItem.submenu = appMenu
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
        panel.level              = .floating
        // .fullScreenPrimary erlaubt die grüne Vollbild-Taste
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate  = false
        panel.appearance         = NSAppearance(named: .darkAqua)
        panel.backgroundColor    = .black
        panel.delegate           = self

        let sf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: sf.minX + (sf.width  - w) / 2,
            y: sf.minY + (sf.height - h) / 2
        ))

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(
            frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)),
            configuration: config
        )
        webView.autoresizingMask   = [.width, .height]
        webView.navigationDelegate = self

        panel.contentView?.addSubview(webView)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        loadPlayerPage()
    }

    private func loadPlayerPage() {
        let file = tvDir.appendingPathComponent("player.html")
        guard let html = try? String(contentsOf: file, encoding: .utf8) else { return }
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost/"))
    }

    // MARK: - Sender wechseln

    func loadChannel(_ index: Int) {
        currentIndex = ((index % channelStore.channels.count) + channelStore.channels.count) % channelStore.channels.count
        updatePanelTitle()
        guard pageReady else { return }
        tuneWebView(to: currentIndex)
    }

    private func tuneWebView(to index: Int) {
        guard index < channelStore.channels.count else { return }
        let ch = channelStore.channels[index]

        if ch.useZDFApi {
            ZDFLoader.fetchHLSURL { [weak self] url in
                guard let self else { return }
                if let url {
                    let safe = url.replacingOccurrences(of: "'", with: "\\'")
                    self.webView.evaluateJavaScript("playUrl('\(safe)')") { _, _ in }
                } else {
                    self.webView.evaluateJavaScript("zapTo(\(index))") { _, _ in }
                }
            }
        } else {
            webView.evaluateJavaScript("zapTo(\(index))") { _, _ in }
        }

        let safeName = ch.name.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript(
            "document.getElementById('channel-name').textContent='\(safeName)'"
        ) { _, _ in }
    }

    private func updatePanelTitle() {
        guard currentIndex < channelStore.channels.count else { return }
        let ch = channelStore.channels[currentIndex]
        panel.title    = "MacTV"
        panel.subtitle = "\(currentIndex + 1)  \(ch.name)"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        updatePanelTitle()
        tuneWebView(to: currentIndex)
    }

    // MARK: - Einstellungen

    @objc private func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(store: channelStore) { [weak self] in
            self?.rebuildMenu()
            if let self, self.currentIndex >= self.channelStore.channels.count {
                self.loadChannel(0)
            }
        }

        let hosting = NSHostingController(rootView: view)
        let window  = NSWindow(contentViewController: hosting)
        window.title      = "MacTV – Einstellungen"
        window.styleMask  = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 640, height: 440))
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
        subtitleItem?.state = subtitlesOn ? .on : .off
        webView.evaluateJavaScript("toggleSubtitles()") { _, _ in }
    }

    @objc private func toggleFloating() {
        isFloating.toggle()
        panel.level = isFloating ? .floating : .normal
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
