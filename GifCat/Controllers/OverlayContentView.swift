import AppKit

class OverlayContentView: NSView {
    var isEditMode: Bool = false {
        didSet {
            updateEditAppearance()
            needsDisplay = true
        }
    }
    var onFrameChanged: ((NSRect) -> Void)?
    var onDeleteRequested: (() -> Void)?

    private enum Interaction {
        case move(start: NSPoint, origin: NSPoint)
        case resize(handle: ResizeHandle, start: NSPoint, frame: NSRect)
    }

    private enum ResizeHandle {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private var interaction: Interaction?
    private var handleLayers: [CALayer] = []
    private lazy var deleteButton: NSButton = makeDeleteButton()
    private let handleSize: CGFloat = 18
    private let deleteButtonSize: CGFloat = 22
    private let minimumSide: CGFloat = 48

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        addSubview(deleteButton)
        updateEditAppearance()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // Called on main thread by GIFController
    func updateFrame(_ cgImage: CGImage) {
        layer?.contents = cgImage
    }

    // MARK: - Edit mode

    private func updateEditAppearance() {
        layer?.borderWidth = isEditMode ? 2 : 0
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = NSColor.clear.cgColor
        ensureHandleLayers()
        updateHandleLayers()
        updateDeleteButtonFrame()
        handleLayers.forEach { $0.isHidden = !isEditMode }
        deleteButton.isHidden = !isEditMode
    }

    override func layout() {
        super.layout()
        updateHandleLayers()
        updateDeleteButtonFrame()
    }

    private func makeDeleteButton() -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .circular
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Delete GIF")
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(deleteButtonClicked)
        button.toolTip = "이 GIF 삭제"
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemRed.cgColor
        button.layer?.cornerRadius = deleteButtonSize / 2
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.85).cgColor
        button.layer?.borderWidth = 1
        button.isHidden = true
        return button
    }

    private func updateDeleteButtonFrame() {
        deleteButton.frame = NSRect(x: bounds.midX - deleteButtonSize / 2,
                                    y: bounds.maxY - deleteButtonSize - 4,
                                    width: deleteButtonSize,
                                    height: deleteButtonSize)
    }

    private func ensureHandleLayers() {
        guard handleLayers.isEmpty, let layer else { return }
        handleLayers = (0..<4).map { _ in
            let handle = CALayer()
            handle.backgroundColor = NSColor.controlAccentColor.cgColor
            handle.cornerRadius = 3
            handle.isHidden = !isEditMode
            layer.addSublayer(handle)
            return handle
        }
    }

    private func updateHandleLayers() {
        guard handleLayers.count == 4 else { return }
        for (index, rect) in handleRects().enumerated() {
            handleLayers[index].frame = rect
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard isEditMode, let win = window else { return }

        let point = event.locationInWindow
        if deleteButton.frame.contains(point) { return }
        if let handle = resizeHandle(at: point) {
            interaction = .resize(handle: handle, start: point, frame: win.frame)
        } else {
            interaction = .move(start: point, origin: win.frame.origin)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEditMode, let win = window, let interaction else { return }

        let point = event.locationInWindow
        switch interaction {
        case let .move(start, origin):
            let dx = point.x - start.x
            let dy = point.y - start.y
            win.setFrameOrigin(clampedOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy),
                                             size: win.frame.size))
        case let .resize(handle, start, frame):
            let dx = point.x - start.x
            let dy = point.y - start.y
            win.setFrame(resizedFrame(from: frame, handle: handle, dx: dx, dy: dy),
                         display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        interaction = nil
        if let frame = window?.frame {
            onFrameChanged?(frame)
        }
    }

    @objc private func deleteButtonClicked() {
        onDeleteRequested?()
    }

    private func handleRects() -> [NSRect] {
        [
            NSRect(x: 0, y: 0, width: handleSize, height: handleSize),
            NSRect(x: bounds.maxX - handleSize, y: 0, width: handleSize, height: handleSize),
            NSRect(x: 0, y: bounds.maxY - handleSize, width: handleSize, height: handleSize),
            NSRect(x: bounds.maxX - handleSize, y: bounds.maxY - handleSize,
                   width: handleSize, height: handleSize),
        ]
    }

    private func resizeHandle(at point: NSPoint) -> ResizeHandle? {
        let bottomLeft = NSRect(x: 0, y: 0, width: handleSize, height: handleSize)
        let bottomRight = NSRect(x: bounds.maxX - handleSize, y: 0,
                                 width: handleSize, height: handleSize)
        let topLeft = NSRect(x: 0, y: bounds.maxY - handleSize,
                             width: handleSize, height: handleSize)
        let topRight = NSRect(x: bounds.maxX - handleSize, y: bounds.maxY - handleSize,
                              width: handleSize, height: handleSize)

        if bottomLeft.contains(point) { return .bottomLeft }
        if bottomRight.contains(point) { return .bottomRight }
        if topLeft.contains(point) { return .topLeft }
        if topRight.contains(point) { return .topRight }
        return nil
    }

    private func resizedFrame(from frame: NSRect, handle: ResizeHandle,
                              dx: CGFloat, dy: CGFloat) -> NSRect {
        var next = frame
        switch handle {
        case .bottomLeft:
            let width = max(minimumSide, frame.width - dx)
            let height = max(minimumSide, frame.height - dy)
            next.origin.x = frame.maxX - width
            next.origin.y = frame.maxY - height
            next.size = NSSize(width: width, height: height)
        case .bottomRight:
            next.size.width = max(minimumSide, frame.width + dx)
            let height = max(minimumSide, frame.height - dy)
            next.origin.y = frame.maxY - height
            next.size.height = height
        case .topLeft:
            let width = max(minimumSide, frame.width - dx)
            next.origin.x = frame.maxX - width
            next.size.width = width
            next.size.height = max(minimumSide, frame.height + dy)
        case .topRight:
            next.size.width = max(minimumSide, frame.width + dx)
            next.size.height = max(minimumSide, frame.height + dy)
        }

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(next) }) ?? NSScreen.main {
            next.origin = clampedOrigin(next.origin, size: next.size, visibleFrame: screen.visibleFrame)
        }
        return next
    }

    private func clampedOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let visibleFrame = NSScreen.screens.first { $0.visibleFrame.contains(origin) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        return clampedOrigin(origin, size: size, visibleFrame: visibleFrame)
    }

    private func clampedOrigin(_ origin: NSPoint, size: NSSize,
                               visibleFrame: NSRect?) -> NSPoint {
        guard let visibleFrame else { return origin }
        return NSPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }
}
