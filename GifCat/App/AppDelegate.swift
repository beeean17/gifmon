import AppKit
import UniformTypeIdentifiers
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()
    private let gifController = GIFController()
    private var overlay: OverlayWindowController?
    private var statusBar: StatusBarController?
    private var onboarding: OnboardingWindowController?
    private var monitorTarget: MonitorTarget = .cpu

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let defaults = UserDefaults.standard
        monitorTarget = MonitorTarget(rawValue: defaults.integer(forKey: UserDefaultsKeys.monitorTarget)) ?? .cpu
        let scale    = defaults.object(forKey: UserDefaultsKeys.windowScale) as? Double ?? 1.0
        let moveMode = defaults.bool(forKey: UserDefaultsKeys.moveMode)

        // Overlay window (hidden until GIF is loaded)
        let ow = OverlayWindowController()
        overlay = ow
        ow.setScale(scale)
        ow.setMoveMode(moveMode)

        gifController.onFrame = { [weak ow] image in
            ow?.updateFrame(image)
        }

        // Status bar
        let sb = StatusBarController()
        statusBar = sb
        sb.monitorTarget = monitorTarget
        sb.windowScale   = scale
        sb.isMoveMode    = moveMode
        // Sync with actual SMAppService state (truth), not just stored pref
        let actualLaunchAtLogin = SMAppService.mainApp.status == .enabled
        sb.launchAtLogin = actualLaunchAtLogin
        defaults.set(actualLaunchAtLogin, forKey: UserDefaultsKeys.launchAtLogin)

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
        sb.onLaunchAtLoginToggle = { [weak sb] enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                defaults.set(enabled, forKey: UserDefaultsKeys.launchAtLogin)
            } catch {
                // Revert toggle on failure
                sb?.launchAtLogin = !enabled
            }
        }

        // Resource monitor
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

        // First run: show onboarding; otherwise restore saved GIF
        if let path = defaults.string(forKey: UserDefaultsKeys.gifFilePath) {
            loadGIF(url: URL(fileURLWithPath: path))
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        gifController.stop()
    }

    // MARK: - GIF loading

    func loadGIF(url: URL) {
        // File moved/deleted since last session → back to onboarding
        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.gifFilePath)
            showOnboarding()
            return
        }
        do {
            try gifController.load(gifURL: url)
            gifController.start()
            UserDefaults.standard.set(url.path, forKey: UserDefaultsKeys.gifFilePath)
            overlay?.showOverlay()
            statusBar?.clearError()
        } catch {
            statusBar?.showGIFError("'\(url.lastPathComponent)' 파일을 읽을 수 없습니다.")
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let oc = OnboardingWindowController()
        onboarding = oc
        oc.onGIFSelected = { [weak self] url in
            self?.onboarding?.hide()
            self?.onboarding = nil
            self?.loadGIF(url: url)
        }
        oc.show()
    }

    // MARK: - GIF swap (from menu)

    private func openGIFPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["gif", "png", "apng"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "GIF 파일을 선택하세요"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadGIF(url: url)
    }
}
