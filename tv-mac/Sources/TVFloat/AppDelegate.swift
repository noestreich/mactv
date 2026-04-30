import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {

    private var panel:       NSPanel!
    private var webView:     WKWebView!
    private var statusItem:  NSStatusItem!
    private var currentIndex = 0
    private var pageReady    = false

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

        let menu = NSMenu()
        let show = NSMenuItem(title: "Einblenden / Ausblenden",
                              action: #selector(togglePanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())

        for (i, ch) in allChannels.prefix(9).enumerated() {
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

    // MARK: - Seite laden

    // HTML als String mit HTTPS-BaseURL laden – das erlaubt Cross-Origin-Requests
    // aus dem WKWebView heraus (hls.js, Stream-CDNs, etc.)
    private func loadPlayerPage() {
        let file = tvDir.appendingPathComponent("player.html")
        guard let html = try? String(contentsOf: file, encoding: .utf8) else { return }
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost/"))
    }

    // MARK: - Sender wechseln

    func loadChannel(_ index: Int) {
        currentIndex = ((index % allChannels.count) + allChannels.count) % allChannels.count
        let ch = allChannels[currentIndex]
        panel.title = "\(currentIndex + 1)  \(ch.name)"

        guard pageReady else { return }
        tuneWebView(to: currentIndex)
    }

    private func tuneWebView(to index: Int) {
        let ch = allChannels[index]

        if ch.name == "ZDF" {
            // ZDF über native URLSession laden (kein CORS), dann URL an JS übergeben
            ZDFLoader.fetchHLSURL { [weak self] url in
                guard let self else { return }
                if let url {
                    let safe = url.replacingOccurrences(of: "'", with: "\\'")
                    self.webView.evaluateJavaScript("playUrl('\(safe)')") { _, _ in }
                } else {
                    // Fallback: direkte URL probieren
                    self.webView.evaluateJavaScript("zapTo(\(index))") { _, _ in }
                }
            }
        } else {
            webView.evaluateJavaScript("zapTo(\(index))") { _, _ in }
        }

        // Sendername im Panel-Titel aktualisieren
        webView.evaluateJavaScript("document.getElementById('channel-name').textContent = \(jsString(ch.name))") { _, _ in }
    }

    private func jsString(_ s: String) -> String {
        "'\(s.replacingOccurrences(of: "'", with: "\\'"))'"
    }

    // Seite fertig geladen → initialen Sender starten
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        tuneWebView(to: currentIndex)
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
        panel.orderOut(nil)
        return false
    }
}
