import AppKit

class OverlayContentView: NSView {
    private var dragStart: NSPoint?
    private var originOnDrag: NSPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // Called on main thread by GIFController
    func updateFrame(_ cgImage: CGImage) {
        layer?.contents = cgImage
    }

    // MARK: - Mouse events (active only when window.ignoresMouseEvents = false)

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        originOnDrag = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart,
              let origin = originOnDrag,
              let win = window else { return }
        let dx = event.locationInWindow.x - start.x
        let dy = event.locationInWindow.y - start.y
        win.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        // Persist final position after drag ends
        if let origin = window?.frame.origin {
            UserDefaults.standard.set(origin.x, forKey: UserDefaultsKeys.windowX)
            UserDefaults.standard.set(origin.y, forKey: UserDefaultsKeys.windowY)
        }
        dragStart = nil
        originOnDrag = nil
    }
}
