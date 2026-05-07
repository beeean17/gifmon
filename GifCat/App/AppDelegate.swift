import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ResourceMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor.onUpdate = { cpu, ram in
            print(String(format: "[GifCat] CPU: %5.1f%%  RAM: %5.1f%%",
                         cpu * 100, ram * 100))
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}
