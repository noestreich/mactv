import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var panel:        NSPanel!
    private var playerLayer:  AVPlayerLayer!
    private var player:       AVPlayer!
    private var statusItem:   NSStatusItem!
    private var currentIndex  = 0

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        createPanel()
        tune(to: 0)
    }

    // MARK: - Menu-Bar icon

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📺"

        let menu = NSMenu()
        menu.addItem(withTitle: "Einblenden / Ausblenden",
                     action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())

        // Schnellzugriff erste 9 Sender
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

    // MARK: - Floating Panel

    private func createPanel() {
        let rect = NSRect(x: 0, y: 0, width: 480, height: 270)

        panel = NSPanel(
            contentRect: rect,
            styleMask:   [.titled, .closable, .resizable, .hudWindow],
            backing:     .buffered,
            defer:       false
        )
        panel.level              = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.delegate           = self

        // Explizit auf Hauptbildschirm zentrieren
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let origin = NSPoint(
                x: sf.minX + (sf.width  - rect.width)  / 2,
                y: sf.minY + (sf.height - rect.height) / 2
            )
            panel.setFrameOrigin(origin)
        }

        // AVPlayerLayer direkt ins contentView – zuverlässiger als AVPlayerView
        player = AVPlayer()

        let cv = panel.contentView!
        cv.wantsLayer = true
        cv.layer?.backgroundColor = NSColor.black.cgColor

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame             = cv.bounds
        playerLayer.autoresizingMask  = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.videoGravity      = .resizeAspect
        cv.layer?.addSublayer(playerLayer)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Sender wechseln

    func tune(to index: Int) {
        currentIndex = ((index % allChannels.count) + allChannels.count) % allChannels.count
        let ch = allChannels[currentIndex]
        guard let url = URL(string: ch.url) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        panel.title = "\(currentIndex + 1)  \(ch.name)"
    }

    // MARK: - Tastatur
    // ↑/→  nächster Sender    ↓/←  vorheriger
    // 1–9  direkter Sprung     0    Sender 10
    // M    Ton an/aus          F    Vollbild

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        if let special = event.specialKey {
            switch special {
            case .upArrow, .rightArrow:   tune(to: currentIndex + 1); return nil
            case .downArrow, .leftArrow:  tune(to: currentIndex - 1); return nil
            default: break
            }
        }

        guard let ch = event.characters?.lowercased() else { return event }
        switch ch {
        case "1"..."9":
            tune(to: (Int(ch) ?? 1) - 1);        return nil
        case "0":
            tune(to: 9);                          return nil
        case "m":
            player.isMuted.toggle();              return nil
        case "f":
            panel.toggleFullScreen(nil); return nil
        default:
            return event
        }
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        panel.isVisible ? panel.orderOut(nil) : panel.makeKeyAndOrderFront(nil)
    }

    @objc private func menuTune(_ sender: NSMenuItem) {
        tune(to: sender.tag)
        if !panel.isVisible { panel.makeKeyAndOrderFront(nil) }
    }

    // Panel schließen → nur ausblenden, App läuft weiter
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel.orderOut(nil)
        return false
    }
}
