import AppKit

class OverlayWindowController: NSWindowController {
    let id: String

    private var gifView: OverlayContentView!
    private let cascadeIndex: Int
    private let defaultsPrefix: String

    // MARK: - Init

    convenience init(id: String = "default", cascadeIndex: Int = 0) {
        self.init(window: OverlayWindowController.makeWindow(),
                  id: id,
                  cascadeIndex: cascadeIndex)
    }

    private init(window: NSWindow, id: String, cascadeIndex: Int) {
        self.id = id
        self.cascadeIndex = cascadeIndex
        self.defaultsPrefix = "overlay.\(id)."
        super.init(window: window)
        setupContentView()
        restoreFrame()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

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
        win.ignoresMouseEvents = true
        return win
    }

    private func setupContentView() {
        let view = OverlayContentView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        view.onFrameChanged = { [weak self] _ in self?.saveFrame() }
        window?.contentView = view
        gifView = view
    }

    // MARK: - Public interface

    func showOverlay() { window?.orderFrontRegardless() }
    func hideOverlay() { window?.orderOut(nil) }

    func updateFrame(_ cgImage: CGImage) {
        gifView.updateFrame(cgImage)
    }

    func setEditMode(_ enabled: Bool) {
        window?.ignoresMouseEvents = !enabled
        gifView.isEditMode = enabled
    }

    func setMoveMode(_ enabled: Bool) {
        setEditMode(enabled)
    }

    func setScale(_ scale: Double) {
        let side = max(48.0, 150.0 * scale)
        guard let win = window else { return }
        let newFrame = NSRect(x: win.frame.origin.x,
                              y: win.frame.origin.y,
                              width: side,
                              height: side)
        win.setFrame(newFrame, display: true)
        saveFrame()
    }

    func resetPosition() {
        setDefaultFrame()
        saveFrame()
    }

    // MARK: - Frame persistence

    func saveFrame() {
        guard let frame = window?.frame else { return }
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: key(UserDefaultsKeys.windowX))
        defaults.set(frame.origin.y, forKey: key(UserDefaultsKeys.windowY))
        defaults.set(frame.width, forKey: key(UserDefaultsKeys.windowWidth))
        defaults.set(frame.height, forKey: key(UserDefaultsKeys.windowHeight))
    }

    private func restoreFrame() {
        let defaults = UserDefaults.standard
        if let x = defaults.object(forKey: key(UserDefaultsKeys.windowX)) as? Double,
           let y = defaults.object(forKey: key(UserDefaultsKeys.windowY)) as? Double,
           let width = defaults.object(forKey: key(UserDefaultsKeys.windowWidth)) as? Double,
           let height = defaults.object(forKey: key(UserDefaultsKeys.windowHeight)) as? Double {
            window?.setFrame(NSRect(x: x, y: y,
                                    width: max(48.0, width),
                                    height: max(48.0, height)),
                             display: false)
        } else {
            setDefaultFrame()
        }
    }

    private func setDefaultFrame() {
        guard let screen = NSScreen.main, let win = window else { return }
        let size = win.frame.size
        let offset = CGFloat(cascadeIndex % 8) * 28
        let x = screen.visibleFrame.maxX - size.width - 50 - offset
        let y = screen.visibleFrame.minY + 100 + offset
        win.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height),
                     display: true)
    }

    private func key(_ base: String) -> String {
        "\(defaultsPrefix)\(base)"
    }
}
