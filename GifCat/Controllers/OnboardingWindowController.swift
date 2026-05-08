import AppKit
import UniformTypeIdentifiers

class OnboardingWindowController: NSWindowController {
    var onGIFSelected: ((URL) -> Void)?

    // MARK: - Init

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "GifCat"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.center()

        self.init(window: panel)
        buildUI()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() { window?.orderOut(nil) }

    // MARK: - UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let dropZone = DropZoneView(frame: contentView.bounds)
        dropZone.autoresizingMask = [.width, .height]
        dropZone.onFileDropped = { [weak self] url in self?.onGIFSelected?(url) }
        contentView.addSubview(dropZone)

        let label = NSTextField(wrappingLabelWithString: "GIF를 드래그하거나\n아래 버튼으로 선택")
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        dropZone.addSubview(label)

        let button = NSButton(title: "GIF 선택하기", target: self, action: #selector(openFilePicker))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        dropZone.addSubview(button)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor, constant: -20),
            button.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 18),
            button.widthAnchor.constraint(equalToConstant: 130),
        ])
    }

    @objc private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["gif", "png", "apng"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "GIF 또는 APNG 파일을 선택하세요"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onGIFSelected?(url)
    }
}

// MARK: - DropZoneView

private class DropZoneView: NSView {
    var onFileDropped: ((URL) -> Void)?
    private var isHighlighted = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.cornerRadius = 12
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHighlighted {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            bounds.fill()
        }
        let borderColor: NSColor = isHighlighted ? .controlAccentColor : .separatorColor
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 10), xRadius: 8, yRadius: 8)
        path.lineWidth = 2
        path.setLineDash([8, 4], count: 2, phase: 0)
        borderColor.setStroke()
        path.stroke()
    }

    // MARK: NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard gifURL(from: sender) != nil else { return [] }
        isHighlighted = true; needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false; needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false; needsDisplay = true
        guard let url = gifURL(from: sender) else { return false }
        onFileDropped?(url)
        return true
    }

    private func gifURL(from info: NSDraggingInfo) -> URL? {
        guard let urls = info.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        else { return nil }
        return urls.first { ["gif", "png", "apng"].contains($0.pathExtension.lowercased()) }
    }
}
