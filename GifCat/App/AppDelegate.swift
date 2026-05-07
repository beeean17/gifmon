import AppKit
import UniformTypeIdentifiers

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()
    private let gifController = GIFController()
    private var overlay: OverlayWindowController?
    private var statusBar: StatusBarController?
    private var monitorTarget: MonitorTarget = .cpu

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let defaults = UserDefaults.standard
        monitorTarget = MonitorTarget(rawValue: defaults.integer(forKey: UserDefaultsKeys.monitorTarget)) ?? .cpu
        let scale    = defaults.object(forKey: UserDefaultsKeys.windowScale) as? Double ?? 1.0
        let moveMode = defaults.bool(forKey: UserDefaultsKeys.moveMode)

        // Overlay window
        let ow = OverlayWindowController()
        overlay = ow
        ow.setScale(scale)
        ow.setMoveMode(moveMode)
        ow.showOverlay()

        gifController.onFrame = { [weak ow] image in
            ow?.updateFrame(image)
        }

        // Status bar
        let sb = StatusBarController()
        statusBar = sb
        sb.monitorTarget = monitorTarget
        sb.windowScale   = scale
        sb.isMoveMode    = moveMode
        sb.launchAtLogin = defaults.bool(forKey: UserDefaultsKeys.launchAtLogin)

        sb.onMonitorTargetChange = { [weak self] target in
            self?.monitorTarget = target
            defaults.set(target.rawValue, forKey: UserDefaultsKeys.monitorTarget)
        }
        sb.onScaleChange = { [weak ow] newScale in
            ow?.setScale(newScale)
        }
        sb.onGIFSwap = { [weak self] in
            self?.openGIFPanel()
        }
        sb.onResetPosition = { [weak ow] in
            ow?.resetPosition()
        }
        sb.onMoveModeToggle = { [weak ow] enabled in
            ow?.setMoveMode(enabled)
            defaults.set(enabled, forKey: UserDefaultsKeys.moveMode)
        }
        sb.onLaunchAtLoginToggle = { enabled in
            defaults.set(enabled, forKey: UserDefaultsKeys.launchAtLogin)
            // LaunchAtLogin service: Step 7
        }

        // Resource monitor → GIFController speed + status bar label
        monitor.onUpdate = { [weak self] cpu, ram in
            guard let self else { return }
            let usage: Double
            switch self.monitorTarget {
            case .cpu:  usage = cpu
            case .ram:  usage = ram
            case .both: usage = max(cpu, ram)
            }
            self.gifController.updateSpeed(usage: usage)
            self.statusBar?.update(cpu: cpu, ram: ram)
        }
        monitor.start()

        // Restore saved GIF from previous session
        if let path = defaults.string(forKey: UserDefaultsKeys.gifFilePath) {
            loadGIF(url: URL(fileURLWithPath: path))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        gifController.stop()
    }

    // MARK: - GIF loading

    func loadGIF(url: URL) {
        do {
            try gifController.load(gifURL: url)
            gifController.start()
            UserDefaults.standard.set(url.path, forKey: UserDefaultsKeys.gifFilePath)
        } catch {
            print("[GifCat] GIF load failed: \(error)")
        }
    }

    private func openGIFPanel() {
        let panel = NSOpenPanel()
        if let gifType = UTType(filenameExtension: "gif") {
            panel.allowedContentTypes = [gifType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "GIF 파일을 선택하세요"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadGIF(url: url)
    }
}
