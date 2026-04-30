import AppKit

let app      = NSApplication.shared
app.setActivationPolicy(.accessory)   // kein Dock-Icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()
