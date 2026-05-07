import AppKit

class OverlayContentView: NSView {
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

    // MARK: - Mouse events (active only when ignoresMouseEvents = false)

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
