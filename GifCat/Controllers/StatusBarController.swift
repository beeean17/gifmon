import AppKit

class StatusBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "GifCat")
        }
        statusItem.menu = buildBaseMenu()
    }

    private func buildBaseMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "종료", action: #selector(quitApp), keyEquivalent: "q")
            .target = self
        return menu
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
