import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()
    private let gifController = GIFController()
    var monitorTarget: MonitorTarget = .cpu

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor.onUpdate = { [weak self] cpu, ram in
            guard let self else { return }
            let usage: Double
            switch self.monitorTarget {
            case .cpu:  usage = cpu
            case .ram:  usage = ram
            case .both: usage = max(cpu, ram)
            }
            print(String(format: "[GifCat] CPU: %5.1f%%  RAM: %5.1f%%  speed: %.0ffps",
                         cpu * 100, ram * 100, 1.0 / (0.200 - usage * 0.167)))
            self.gifController.updateSpeed(usage: usage)
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        gifController.stop()
    }
}
