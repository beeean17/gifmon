import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()
    private let gifController = GIFController()
    private var overlay: OverlayWindowController?
    private var statusBar: StatusBarController?
    private var monitorTarget: MonitorTarget = .cpu

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let ow = OverlayWindowController()
        overlay = ow
        ow.showOverlay()

        gifController.onFrame = { [weak ow] image in
            ow?.updateFrame(image)
        }

        statusBar = StatusBarController()

        monitor.onUpdate = { [weak self] cpu, ram in
            guard let self else { return }
            let usage: Double
            switch self.monitorTarget {
            case .cpu:  usage = cpu
            case .ram:  usage = ram
            case .both: usage = max(cpu, ram)
            }
            self.gifController.updateSpeed(usage: usage)
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        gifController.stop()
    }
}
