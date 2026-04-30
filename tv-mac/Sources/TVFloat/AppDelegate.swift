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
        NSApp.activate(ignoringOtherApps: true)
        setupMenuBar()
        createPanel()
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

    // MARK: - Fenster + WebView

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
        panel.appearance         = NSAppearance(named: .darkAqua)
        panel.backgroundColor    = .black
        panel.delegate           = self

        // Mitte des Hauptbildschirms
        let sf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: sf.minX + (sf.width  - w) / 2,
            y: sf.minY + (sf.height - h) / 2
        ))

        // WKWebView – Autoplay ohne User-Interaktion erlauben
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(
            frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)),
            configuration: config
        )
        webView.autoresizingMask   = [.width, .height]
        webView.navigationDelegate = self

        panel.contentView?.addSubview(webView)
        panel.orderFrontRegardless()

        loadChannel(0)
    }

    // MARK: - Sender laden

    func loadChannel(_ index: Int) {
        currentIndex = ((index % allChannels.count) + allChannels.count) % allChannels.count
        let ch = allChannels[currentIndex]
        panel.title = "\(currentIndex + 1)  \(ch.name)"

        if pageReady {
            // Seite bereits geladen → Stream via JavaScript wechseln (kein Reload)
            webView.evaluateJavaScript("zapTo(\(currentIndex))") { _, _ in }
        } else {
            // Erstmalig laden
            let playerFile = tvDir.appendingPathComponent("player.html")
            var comps = URLComponents(url: playerFile, resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "stream", value: ch.url)]
            if let url = comps.url {
                webView.loadFileURL(url, allowingReadAccessTo: tvDir)
            }
        }
    }

    // Sobald player.html fertig geladen ist
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) }
        else               { panel.orderFrontRegardless() }
    }

    @objc private func menuTune(_ sender: NSMenuItem) {
        loadChannel(sender.tag)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    // Schließen → nur ausblenden
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel.orderOut(nil)
        return false
    }
}
