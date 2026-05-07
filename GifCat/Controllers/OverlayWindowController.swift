import AppKit

class OverlayWindowController: NSWindowController {
    private var gifView: OverlayContentView!

    // MARK: - Init

    convenience init() {
        self.init(window: OverlayWindowController.makeWindow())
        setupContentView()
        restorePosition()
    }

    private static func makeWindow() -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 150),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.ignoresMouseEvents = true  // click-through by default
        return win
    }

    private func setupContentView() {
        let view = OverlayContentView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        window?.contentView = view
        gifView = view
    }

    // MARK: - Public interface

    func showOverlay() { window?.orderFrontRegardless() }
    func hideOverlay() { window?.orderOut(nil) }

    func updateFrame(_ cgImage: CGImage) {
        gifView.updateFrame(cgImage)
    }

    func setMoveMode(_ enabled: Bool) {
        window?.ignoresMouseEvents = !enabled
    }

    func setScale(_ scale: Double) {
        let side = 150.0 * scale
        guard let win = window else { return }
        let newFrame = NSRect(x: win.frame.origin.x,
                              y: win.frame.origin.y,
                              width: side, height: side)
        win.setFrame(newFrame, display: true)
        UserDefaults.standard.set(scale, forKey: UserDefaultsKeys.windowScale)
    }

    func resetPosition() {
        setDefaultPosition()
        savePosition()
    }

    // MARK: - Position persistence

    func savePosition() {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set(origin.x, forKey: UserDefaultsKeys.windowX)
        UserDefaults.standard.set(origin.y, forKey: UserDefaultsKeys.windowY)
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if let x = defaults.object(forKey: UserDefaultsKeys.windowX) as? Double,
           let y = defaults.object(forKey: UserDefaultsKeys.windowY) as? Double {
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            setDefaultPosition()
        }
    }

    private func setDefaultPosition() {
        guard let screen = NSScreen.main, let win = window else { return }
        let x = screen.visibleFrame.maxX - win.frame.width - 50
        let y = screen.visibleFrame.minY + 100
        win.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
