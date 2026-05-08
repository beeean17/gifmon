import AppKit
import UniformTypeIdentifiers
import ServiceManagement

private final class ManagedGIFOverlay {
    let id: String
    let url: URL
    let controller: GIFController
    let window: OverlayWindowController

    init(id: String, url: URL, controller: GIFController, window: OverlayWindowController) {
        self.id = id
        self.url = url
        self.controller = controller
        self.window = window
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()
    private var overlays: [ManagedGIFOverlay] = []
    private var menuBarGIFController: GIFController?
    private var menuBarGIFURL: URL?
    private var statusBar: StatusBarController?
    private var onboarding: OnboardingWindowController?

    private var monitorTarget: MonitorTarget = .cpu
    private var isResourceLinked = true
    private var isEditMode = false
    private var windowScale = 1.0
    private var speedMinFPS = 5.0
    private var speedMaxFPS = 30.0
    private var speedFixedFPS = 15.0
    private var isMenuBarAnimationEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let defaults = UserDefaults.standard
        monitorTarget = MonitorTarget(rawValue: defaults.integer(forKey: UserDefaultsKeys.monitorTarget)) ?? .cpu
        windowScale = sanitizedScale(defaults.object(forKey: UserDefaultsKeys.windowScale) as? Double ?? 1.0)
        isEditMode = defaults.bool(forKey: UserDefaultsKeys.moveMode)
        isResourceLinked = defaults.object(forKey: UserDefaultsKeys.resourceLinked) as? Bool ?? true
        speedMinFPS = sanitizedFPS(defaults.object(forKey: UserDefaultsKeys.speedMinFPS) as? Double ?? 5.0)
        speedMaxFPS = max(sanitizedFPS(defaults.object(forKey: UserDefaultsKeys.speedMaxFPS) as? Double ?? 30.0),
                          speedMinFPS + 1.0)
        speedFixedFPS = sanitizedFPS(defaults.object(forKey: UserDefaultsKeys.speedFixedFPS) as? Double ?? 15.0)
        isMenuBarAnimationEnabled = defaults.bool(forKey: UserDefaultsKeys.menuBarAnimationEnabled)
        if let path = defaults.string(forKey: UserDefaultsKeys.menuBarGIFPath) {
            menuBarGIFURL = URL(fileURLWithPath: path)
        }

        let sb = StatusBarController()
        statusBar = sb
        sb.monitorTarget = monitorTarget
        sb.windowScale = windowScale
        sb.speedMinFPS = speedMinFPS
        sb.speedMaxFPS = speedMaxFPS
        sb.speedFixedFPS = speedFixedFPS
        sb.isResourceLinked = isResourceLinked
        sb.isMoveMode = isEditMode
        sb.isMenuBarAnimationEnabled = isMenuBarAnimationEnabled

        let actualLaunchAtLogin = SMAppService.mainApp.status == .enabled
        sb.launchAtLogin = actualLaunchAtLogin
        defaults.set(actualLaunchAtLogin, forKey: UserDefaultsKeys.launchAtLogin)

        wireStatusBarCallbacks(sb, defaults: defaults)
        wireResourceMonitor()

        monitor.start()
        restoreMenuBarGIFIfNeeded()
        restoreSavedGIFs()
        if overlays.isEmpty {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        for overlay in overlays {
            overlay.window.saveFrame()
            overlay.controller.stop()
        }
        menuBarGIFController?.stop()
        saveOverlayList()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        restoreStatusBarIcon()
        return true
    }

    // MARK: - Wiring

    private func wireStatusBarCallbacks(_ sb: StatusBarController, defaults: UserDefaults) {
        sb.onMonitorTargetChange = { [weak self] target in
            self?.monitorTarget = target
            defaults.set(target.rawValue, forKey: UserDefaultsKeys.monitorTarget)
        }
        sb.onScaleChange = { [weak self] newScale in
            guard let self else { return }
            self.windowScale = self.sanitizedScale(newScale)
            defaults.set(self.windowScale, forKey: UserDefaultsKeys.windowScale)
            for overlay in self.overlays {
                overlay.window.setScale(self.windowScale)
            }
        }
        sb.onSpeedChange = { [weak self] minValue, maxValue in
            guard let self else { return }
            self.speedMinFPS = self.sanitizedFPS(minValue)
            self.speedMaxFPS = Swift.max(self.sanitizedFPS(maxValue), self.speedMinFPS + 1.0)
            defaults.set(self.speedMinFPS, forKey: UserDefaultsKeys.speedMinFPS)
            defaults.set(self.speedMaxFPS, forKey: UserDefaultsKeys.speedMaxFPS)
            self.applySpeedSettingsToAll()
        }
        sb.onFixedSpeedChange = { [weak self] fps in
            guard let self else { return }
            self.speedFixedFPS = self.sanitizedFPS(fps)
            defaults.set(self.speedFixedFPS, forKey: UserDefaultsKeys.speedFixedFPS)
            self.applySpeedSettingsToAll()
        }
        sb.onResourceLinkedToggle = { [weak self] enabled in
            guard let self else { return }
            self.isResourceLinked = enabled
            defaults.set(enabled, forKey: UserDefaultsKeys.resourceLinked)
            self.applySpeedSettingsToAll()
        }
        sb.onMenuBarGIFSelect = { [weak self] in
            self?.openMenuBarGIFPanel()
        }
        sb.onMenuBarAnimationToggle = { [weak self, weak sb] enabled in
            guard let self else { return }
            self.setMenuBarAnimationEnabled(enabled, statusBar: sb)
        }
        sb.onMenuBarAnimationReset = { [weak self] in
            self?.resetMenuBarAnimation()
        }
        sb.onGIFAdd = { [weak self] in
            self?.openGIFPanel(replaceExisting: false)
        }
        sb.onGIFReplaceAll = { [weak self] in
            self?.openGIFPanel(replaceExisting: true)
        }
        sb.onGIFRemoveAll = { [weak self] in
            self?.removeAllGIFs(showPicker: true)
        }
        sb.onResetPosition = { [weak self] in
            guard let self else { return }
            for overlay in self.overlays {
                overlay.window.resetPosition()
            }
        }
        sb.onMoveModeToggle = { [weak self] enabled in
            guard let self else { return }
            self.isEditMode = enabled
            defaults.set(enabled, forKey: UserDefaultsKeys.moveMode)
            for overlay in self.overlays {
                overlay.window.setEditMode(enabled)
            }
        }
        sb.onHideFromMenuBar = { [weak self] in
            self?.hideStatusBarIcon()
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
                sb?.launchAtLogin = !enabled
            }
        }
    }

    private func wireResourceMonitor() {
        monitor.onUpdate = { [weak self] cpu, ram in
            guard let self else { return }
            let usage: Double
            switch self.monitorTarget {
            case .cpu:  usage = cpu
            case .ram:  usage = ram
            case .both: usage = max(cpu, ram)
            }
            for overlay in self.overlays {
                overlay.controller.updateSpeed(usage: usage)
            }
            self.menuBarGIFController?.updateSpeed(usage: usage)
            self.statusBar?.update(cpu: cpu, ram: ram)
        }
    }

    // MARK: - GIF loading

    @discardableResult
    func addGIF(url: URL, id: String = UUID().uuidString, shouldSave: Bool = true) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            statusBar?.showGIFError("'\(url.lastPathComponent)' 파일을 찾을 수 없습니다.")
            return false
        }

        let window = OverlayWindowController(id: id, cascadeIndex: overlays.count)
        window.setEditMode(isEditMode)
        if !hasSavedFrame(for: id) {
            window.setScale(windowScale)
        }

        let controller = GIFController()
        controller.applySpeedSettings(minFPS: speedMinFPS,
                                      maxFPS: speedMaxFPS,
                                      fixedFPS: speedFixedFPS,
                                      resourceLinked: isResourceLinked)
        controller.onFrame = { [weak window] image in
            window?.updateFrame(image)
        }

        do {
            try controller.load(gifURL: url)
            controller.start()
            window.showOverlay()
            overlays.append(ManagedGIFOverlay(id: id,
                                              url: url,
                                              controller: controller,
                                              window: window))
            statusBar?.clearError()
            if shouldSave {
                saveOverlayList()
            }
            return true
        } catch {
            statusBar?.showGIFError("'\(url.lastPathComponent)' 파일을 읽을 수 없습니다.")
            return false
        }
    }

    private func removeAllGIFs(showPicker: Bool) {
        for overlay in overlays {
            overlay.window.saveFrame()
            overlay.controller.stop()
            overlay.window.hideOverlay()
        }
        overlays.removeAll()
        saveOverlayList()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.gifFilePath)
        if showPicker {
            showOnboarding()
        }
    }

    private func openGIFPanel(replaceExisting: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["gif", "png", "apng"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = replaceExisting ? "표시할 GIF/APNG 파일을 선택하세요" : "추가할 GIF/APNG 파일을 선택하세요"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }

        let urls = panel.urls
        guard !urls.isEmpty else { return }

        if replaceExisting {
            removeAllGIFs(showPicker: false)
        }
        for url in urls {
            addGIF(url: url)
        }
    }

    private func applySpeedSettingsToAll() {
        for overlay in overlays {
            overlay.controller.applySpeedSettings(minFPS: speedMinFPS,
                                                  maxFPS: speedMaxFPS,
                                                  fixedFPS: speedFixedFPS,
                                                  resourceLinked: isResourceLinked)
        }
        menuBarGIFController?.applySpeedSettings(minFPS: speedMinFPS,
                                                 maxFPS: speedMaxFPS,
                                                 fixedFPS: speedFixedFPS,
                                                 resourceLinked: isResourceLinked)
    }

    // MARK: - Menu bar animation

    private func restoreMenuBarGIFIfNeeded() {
        guard isMenuBarAnimationEnabled, let url = menuBarGIFURL else {
            statusBar?.restoreDefaultIcon()
            return
        }
        loadMenuBarGIF(url: url)
    }

    private func openMenuBarGIFPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["gif", "png", "apng"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "메뉴바 아이콘으로 사용할 GIF/APNG 파일을 선택하세요"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        menuBarGIFURL = url
        UserDefaults.standard.set(url.path, forKey: UserDefaultsKeys.menuBarGIFPath)
        isMenuBarAnimationEnabled = true
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.menuBarAnimationEnabled)
        statusBar?.isMenuBarAnimationEnabled = true
        loadMenuBarGIF(url: url)
    }

    private func setMenuBarAnimationEnabled(_ enabled: Bool, statusBar sb: StatusBarController?) {
        if enabled, menuBarGIFURL == nil {
            sb?.isMenuBarAnimationEnabled = false
            isMenuBarAnimationEnabled = false
            UserDefaults.standard.set(false, forKey: UserDefaultsKeys.menuBarAnimationEnabled)
            openMenuBarGIFPanel()
            return
        }

        isMenuBarAnimationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.menuBarAnimationEnabled)

        if enabled, let url = menuBarGIFURL {
            loadMenuBarGIF(url: url)
        } else {
            menuBarGIFController?.stop()
            menuBarGIFController = nil
            statusBar?.restoreDefaultIcon()
        }
    }

    private func resetMenuBarAnimation() {
        menuBarGIFController?.stop()
        menuBarGIFController = nil
        menuBarGIFURL = nil
        isMenuBarAnimationEnabled = false
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKeys.menuBarAnimationEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.menuBarGIFPath)
        statusBar?.isMenuBarAnimationEnabled = false
        statusBar?.restoreDefaultIcon()
    }

    private func loadMenuBarGIF(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            resetMenuBarAnimation()
            statusBar?.showGIFError("'\(url.lastPathComponent)' 메뉴바 GIF 파일을 찾을 수 없습니다.")
            return
        }

        let controller = GIFController()
        controller.applySpeedSettings(minFPS: speedMinFPS,
                                      maxFPS: speedMaxFPS,
                                      fixedFPS: speedFixedFPS,
                                      resourceLinked: isResourceLinked)
        controller.onFrame = { [weak self] image in
            self?.statusBar?.updateMenuBarFrame(image)
        }

        do {
            try controller.load(gifURL: url)
            menuBarGIFController?.stop()
            menuBarGIFController = controller
            controller.start()
            statusBar?.isMenuBarAnimationEnabled = true
            statusBar?.clearError()
        } catch {
            resetMenuBarAnimation()
            statusBar?.showGIFError("'\(url.lastPathComponent)' 메뉴바 GIF를 읽을 수 없습니다.")
        }
    }

    private func hideStatusBarIcon() {
        menuBarGIFController?.stop()
        menuBarGIFController = nil
        statusBar?.hideFromMenuBar()
    }

    private func restoreStatusBarIcon() {
        statusBar?.restoreToMenuBar()
        if isMenuBarAnimationEnabled {
            restoreMenuBarGIFIfNeeded()
        } else {
            statusBar?.restoreDefaultIcon()
        }
    }

    // MARK: - Persistence

    private func restoreSavedGIFs() {
        let defaults = UserDefaults.standard
        var restoredAny = false

        if let saved = defaults.array(forKey: UserDefaultsKeys.gifOverlays) as? [[String: String]] {
            for item in saved {
                guard let id = item["id"], let path = item["path"] else { continue }
                restoredAny = addGIF(url: URL(fileURLWithPath: path), id: id, shouldSave: false) || restoredAny
            }
        } else if let path = defaults.string(forKey: UserDefaultsKeys.gifFilePath) {
            restoredAny = addGIF(url: URL(fileURLWithPath: path), shouldSave: false)
        }

        if restoredAny {
            saveOverlayList()
        } else {
            defaults.removeObject(forKey: UserDefaultsKeys.gifFilePath)
            defaults.removeObject(forKey: UserDefaultsKeys.gifOverlays)
        }
    }

    private func saveOverlayList() {
        let snapshot = overlays.map { ["id": $0.id, "path": $0.url.path] }
        let defaults = UserDefaults.standard
        defaults.set(snapshot, forKey: UserDefaultsKeys.gifOverlays)
        if let first = overlays.first {
            defaults.set(first.url.path, forKey: UserDefaultsKeys.gifFilePath)
        } else {
            defaults.removeObject(forKey: UserDefaultsKeys.gifFilePath)
        }
    }

    private func hasSavedFrame(for id: String) -> Bool {
        UserDefaults.standard.object(forKey: "overlay.\(id).\(UserDefaultsKeys.windowX)") != nil
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        if onboarding != nil { return }
        let oc = OnboardingWindowController()
        onboarding = oc
        oc.onGIFSelected = { [weak self] url in
            self?.onboarding?.hide()
            self?.onboarding = nil
            self?.addGIF(url: url)
        }
        oc.show()
    }

    // MARK: - Validation

    private func sanitizedScale(_ value: Double) -> Double {
        guard value.isFinite else { return 1.0 }
        return max(0.25, min(4.0, value))
    }

    private func sanitizedFPS(_ value: Double) -> Double {
        guard value.isFinite else { return 5.0 }
        return max(1.0, min(120.0, value))
    }
}
