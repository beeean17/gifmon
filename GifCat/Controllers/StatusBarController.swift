import AppKit
import UserNotifications

class StatusBarController {
    private let statusItem: NSStatusItem

    // Callbacks → AppDelegate handles the actual work
    var onMonitorTargetChange: ((MonitorTarget) -> Void)?
    var onScaleChange: ((Double) -> Void)?
    var onSpeedChange: ((Double, Double) -> Void)?  // (minFPS, maxFPS)
    var onGIFSwap: (() -> Void)?
    var onResetPosition: (() -> Void)?
    var onMoveModeToggle: ((Bool) -> Void)?
    var onLaunchAtLoginToggle: ((Bool) -> Void)?

    // Reflected state (set by AppDelegate to keep menu in sync)
    var monitorTarget: MonitorTarget = .cpu { didSet { refreshTargetCheckmarks() } }
    var windowScale: Double = 1.0           { didSet { refreshScaleCheckmarks() } }
    var speedMinFPS: Double = 5.0           { didSet { refreshSpeedCheckmarks() } }
    var speedMaxFPS: Double = 30.0          { didSet { refreshSpeedCheckmarks() } }
    var isMoveMode: Bool = false            { didSet { moveModeItem?.state = isMoveMode ? .on : .off } }
    var launchAtLogin: Bool = false         { didSet { launchAtLoginItem?.state = launchAtLogin ? .on : .off } }

    // Menu items that need dynamic state
    private var statsItem: NSMenuItem?
    private var cpuItem: NSMenuItem?
    private var ramItem: NSMenuItem?
    private var bothItem: NSMenuItem?
    private var smallItem: NSMenuItem?
    private var mediumItem: NSMenuItem?
    private var largeItem: NSMenuItem?
    private var moveModeItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var speedMinItems: [NSMenuItem] = []
    private var speedMaxItems: [NSMenuItem] = []

    // MARK: - Init

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            let img = NSImage(systemSymbolName: "cpu", accessibilityDescription: "GifCat")
            img?.isTemplate = true
            btn.image = img
            btn.title = img == nil ? "GIF" : ""
        }
        statusItem.menu = buildMenu()
    }

    // MARK: - Public

    func update(cpu: Double, ram: Double) {
        statsItem?.title = String(format: "  CPU: %.0f%%  |  RAM: %.0f%%", cpu * 100, ram * 100)
    }

    // Shows ⚠ icon + modal alert; called when GIF load fails
    func showGIFError(_ message: String) {
        let errImg = NSImage(systemSymbolName: "exclamationmark.triangle",
                             accessibilityDescription: "GifCat – error")
        errImg?.isTemplate = true
        statusItem.button?.image = errImg
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "GIF 로드 실패"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }

    // Restores normal cpu icon after a successful load
    func clearError() {
        let img = NSImage(systemSymbolName: "cpu", accessibilityDescription: "GifCat")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Real-time stats (non-clickable label)
        let stats = NSMenuItem(title: "  CPU: --  |  RAM: --", action: nil, keyEquivalent: "")
        stats.isEnabled = false
        menu.addItem(stats)
        statsItem = stats

        menu.addItem(.separator())

        // 모니터링 대상
        addHeader("모니터링 대상", to: menu)
        cpuItem  = addItem("CPU",            action: #selector(selectCPU),  indent: 1, to: menu)
        ramItem  = addItem("RAM",            action: #selector(selectRAM),  indent: 1, to: menu)
        bothItem = addItem("CPU + RAM (max)", action: #selector(selectBoth), indent: 1, to: menu)

        menu.addItem(.separator())

        // 속도
        let speedMenuItem = NSMenuItem(title: "속도", action: nil, keyEquivalent: "")
        speedMenuItem.submenu = buildSpeedSubMenu()
        menu.addItem(speedMenuItem)

        menu.addItem(.separator())

        // 크기
        addHeader("크기", to: menu)
        smallItem  = addItem("작게 (0.5x)", action: #selector(selectSmall),  indent: 1, to: menu)
        mediumItem = addItem("보통 (1x)",   action: #selector(selectMedium), indent: 1, to: menu)
        largeItem  = addItem("크게 (1.5x)", action: #selector(selectLarge),  indent: 1, to: menu)

        menu.addItem(.separator())

        addItem("GIF 교체...", action: #selector(swapGIF),       to: menu)
        addItem("위치 초기화",  action: #selector(resetPosition), to: menu)

        menu.addItem(.separator())

        moveModeItem     = addItem("이동 모드",          action: #selector(toggleMoveMode),     to: menu)
        launchAtLoginItem = addItem("로그인 시 자동 실행", action: #selector(toggleLaunchAtLogin), to: menu)

        menu.addItem(.separator())

        addItem("종료", action: #selector(quitApp), to: menu)

        refreshTargetCheckmarks()
        refreshScaleCheckmarks()
        refreshSpeedCheckmarks()
        return menu
    }

    private func buildSpeedSubMenu() -> NSMenu {
        let sub = NSMenu()

        let minHeader = NSMenuItem(title: "최소 속도 (유휴 시)", action: nil, keyEquivalent: "")
        minHeader.isEnabled = false
        sub.addItem(minHeader)

        for fps in [5.0, 10.0, 15.0, 20.0] {
            let item = NSMenuItem(title: "\(Int(fps)) fps", action: #selector(selectMinFPS(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = fps
            item.indentationLevel = 1
            sub.addItem(item)
            speedMinItems.append(item)
        }

        sub.addItem(.separator())

        let maxHeader = NSMenuItem(title: "최대 속도 (최대 부하 시)", action: nil, keyEquivalent: "")
        maxHeader.isEnabled = false
        sub.addItem(maxHeader)

        for fps in [20.0, 30.0, 60.0] {
            let item = NSMenuItem(title: "\(Int(fps)) fps", action: #selector(selectMaxFPS(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = fps
            item.indentationLevel = 1
            sub.addItem(item)
            speedMaxItems.append(item)
        }

        return sub
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector,
                         indent: Int = 0, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.indentationLevel = indent
        menu.addItem(item)
        return item
    }

    private func addHeader(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    // MARK: - State refresh

    private func refreshTargetCheckmarks() {
        cpuItem?.state  = monitorTarget == .cpu  ? .on : .off
        ramItem?.state  = monitorTarget == .ram  ? .on : .off
        bothItem?.state = monitorTarget == .both ? .on : .off
    }

    private func refreshScaleCheckmarks() {
        smallItem?.state  = windowScale == 0.5 ? .on : .off
        mediumItem?.state = windowScale == 1.0 ? .on : .off
        largeItem?.state  = windowScale == 1.5 ? .on : .off
    }

    private func refreshSpeedCheckmarks() {
        for item in speedMinItems {
            item.state = (item.representedObject as? Double) == speedMinFPS ? .on : .off
        }
        for item in speedMaxItems {
            item.state = (item.representedObject as? Double) == speedMaxFPS ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func selectCPU()  { monitorTarget = .cpu;  onMonitorTargetChange?(.cpu) }
    @objc private func selectRAM()  { monitorTarget = .ram;  onMonitorTargetChange?(.ram) }
    @objc private func selectBoth() { monitorTarget = .both; onMonitorTargetChange?(.both) }

    @objc private func selectSmall()  { windowScale = 0.5; onScaleChange?(0.5) }
    @objc private func selectMedium() { windowScale = 1.0; onScaleChange?(1.0) }
    @objc private func selectLarge()  { windowScale = 1.5; onScaleChange?(1.5) }

    @objc private func selectMinFPS(_ sender: NSMenuItem) {
        guard let fps = sender.representedObject as? Double else { return }
        speedMinFPS = min(fps, speedMaxFPS - 5)
        onSpeedChange?(speedMinFPS, speedMaxFPS)
    }

    @objc private func selectMaxFPS(_ sender: NSMenuItem) {
        guard let fps = sender.representedObject as? Double else { return }
        speedMaxFPS = max(fps, speedMinFPS + 5)
        onSpeedChange?(speedMinFPS, speedMaxFPS)
    }

    @objc private func swapGIF()       { onGIFSwap?() }
    @objc private func resetPosition() { onResetPosition?() }

    @objc private func toggleMoveMode() {
        isMoveMode.toggle()
        onMoveModeToggle?(isMoveMode)
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        onLaunchAtLoginToggle?(launchAtLogin)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
