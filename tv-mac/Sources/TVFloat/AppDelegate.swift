import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var panel:       NSPanel!
    private var playerLayer: AVPlayerLayer!
    private var player:      AVPlayer!
    private var statusItem:  NSStatusItem!
    private var currentIndex = 0

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        setupMenuBar()
        createPanel()
        tune(to: 0)
    }

    // MARK: - Menu-Bar icon

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

    // MARK: - Floating Panel

    private func createPanel() {
        let w: CGFloat = 480
        let h: CGFloat = 270

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

        // Bildschirmmitte
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: sf.minX + (sf.width  - w) / 2,
            y: sf.minY + (sf.height - h) / 2
        ))

        // AVPlayerLayer direkt auf contentView
        player = AVPlayer()
        let cv = panel.contentView!
        cv.wantsLayer = true
        cv.layer?.backgroundColor = NSColor.black.cgColor

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame            = cv.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.videoGravity     = .resizeAspect
        cv.layer?.addSublayer(playerLayer)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

        // orderFrontRegardless bringt das Fenster ohne Aktivierung nach vorne
        panel.orderFrontRegardless()
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
    // ↑ / →   nächster Sender
    // ↓ / ←   vorheriger Sender
    // 1–9     Direktwahl
    // 0       Sender 10
    // M       Ton an/aus
    // F       Vollbild

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        if let special = event.specialKey {
            switch special {
            case .upArrow, .rightArrow:  tune(to: currentIndex + 1); return nil
            case .downArrow, .leftArrow: tune(to: currentIndex - 1); return nil
            default: break
            }
        }
        guard let ch = event.characters?.lowercased() else { return event }
        switch ch {
        case "1"..."9": tune(to: (Int(ch) ?? 1) - 1); return nil
        case "0":       tune(to: 9);                  return nil
        case "m":       player.isMuted.toggle();       return nil
        case "f":       panel.toggleFullScreen(nil);   return nil
        default:        return event
        }
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) }
        else               { panel.orderFrontRegardless() }
    }

    @objc private func menuTune(_ sender: NSMenuItem) {
        tune(to: sender.tag)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    // Schließen → ausblenden statt beenden
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel.orderOut(nil)
        return false
    }
}
