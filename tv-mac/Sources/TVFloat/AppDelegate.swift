import AppKit
import SwiftUI
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {

    private var panel:           NSPanel!
    private var webView:         WKWebView!
    private var statusItem:      NSStatusItem!
    private var settingsWindow:  NSWindow?
    private var currentIndex     = 0
    private var pageReady        = false

    private let channelStore = ChannelStore()
    private let tvDir = URL(fileURLWithPath: "/Users/nicolasoestreich/tv")

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        createPanel()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Menu-Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📺"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Einstellungen
        let settings = NSMenuItem(title: "Einstellungen…",
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        // Ein-/Ausblenden
        let toggle = NSMenuItem(title: "Einblenden / Ausblenden",
                                action: #selector(togglePanel),
                                keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        // Schnellzugriff erste 9 Sender
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
                              keyEquivalent: "q")
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
        panel.title              = "TVFloat"
        panel.level              = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
        let ch = channelStore.channels[currentIndex]
        panel.title = "\(currentIndex + 1)  \(ch.name)"
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
        webView.evaluateJavaScript("document.getElementById('channel-name').textContent='\(safeName)'") { _, _ in }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
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
            // Falls der aktuell gespielte Sender verschoben wurde → Index korrigieren
            if let self, self.currentIndex >= self.channelStore.channels.count {
                self.loadChannel(0)
            }
        }

        let hosting = NSHostingController(rootView: view)
        let window  = NSWindow(contentViewController: hosting)
        window.title      = "Einstellungen"
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

    @objc private func menuTune(_ sender: NSMenuItem) {
        loadChannel(sender.tag)
        if !panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel { panel.orderOut(nil); return false }
        return true
    }
}
